/*******************************************************************************

    Performs non-blocking I/O, suspending the current task to wait for the I/O
    device to be ready if it would have blocked.
    Because the most common case is using a TCP socket, one TCP-specific
    facility (TCP Cork) is built into `TaskSelectTransceiver`. The simplicity,
    convenience (it avoids a custom implementation for output buffering) and
    frequency of use justifies having it in `TaskSelectTransceiver` rather than
    a separate class or module.

    Copyright:
        Copyright (c) 2017 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.select.protocol.task.TaskSelectTransceiver;

import ocean.io.select.client.model.ISelectClient;

/// ditto

class TaskSelectTransceiver
{
    import ocean.io.select.protocol.task.TaskSelectClient;
    import ocean.io.select.protocol.task.internal.BufferedReader;
    import ocean.io.device.IODevice: IODevice;

    import ocean.stdc.errno: errno, EAGAIN, EWOULDBLOCK, EINTR;
    import ocean.stdc.posix.sys.uio: iovec, readv;
    import ocean.stdc.posix.sys.socket: setsockopt;
    import ocean.stdc.posix.netinet.in_: IPPROTO_TCP;
    import ocean.sys.linux.tcp: TCP_CORK;

    import ocean.sys.Epoll: epoll_event_t;
    alias epoll_event_t.Event Event;

    import ocean.io.select.protocol.generic.ErrnoIOException: IOWarning, IOError;

    debug (Raw) import ocean.io.Stdout: Stdout;

    import ocean.core.Enforce: enforce;
    import ocean.transition;

    /***************************************************************************

        I/O device

    ***************************************************************************/

    private IODevice iodev;

    /***************************************************************************

        Task select client to wait for I/O events

    ***************************************************************************/

    private TaskSelectClient select_client;

    /***************************************************************************

        Read buffer manager

    ***************************************************************************/

    private BufferedReader buffered_reader;

    /***************************************************************************

        Possible values for the TCP Cork status of the I/O device. `Unknown`
        means TCP Cork support for the I/O device has not been queried yet,
        `Disabled` that the I/O device does not support TCP Cork.

    ***************************************************************************/

    private enum TcpCorkStatus: uint
    {
        Unknown = 0,
        Disabled,
        Enabled
    }

    /***************************************************************************

        The TCP Cork status of the I/O device. TCP Cork is a Linux
        feature to buffer outgoing data for TCP sockets to minimise the number
        of TCP frames sent.

    ***************************************************************************/

    private TcpCorkStatus tcp_cork_status;

    /***************************************************************************

        Thrown on EOF and remote hangup event

    ***************************************************************************/

    private IOWarning warning_e;

    /***************************************************************************

        Thrown on socket I/O error

    ***************************************************************************/

    private IOError error_e;

    /***************************************************************************

        Constructor.

        error_e and warning_e may be the same object if distinguishing between
        error and warning is not required.

        Params:
            iodev            = I/O device
            warning_e        = exception to throw on end-of-flow condition or if
                               the remote hung up
            error_e          = exception to throw on I/O error
            read_buffer_size = read buffer size


    ***************************************************************************/

    public this ( IODevice iodev, IOWarning warning_e, IOError error_e,
                  size_t read_buffer_size = BufferedReader.default_read_buffer_size )
    {
        this.iodev = iodev;
        this.warning_e = warning_e;
        this.error_e = error_e;
        this.select_client = new TaskSelectClient(iodev, &error_e.error_code);
        this.buffered_reader = new BufferedReader(read_buffer_size);
    }

    /***************************************************************************

        Populates `data` with data read from the I/O device.

        Params:
            data = destination data buffer

        Throws:
            IOException if no data were received nor will any arrive later:
                - IOWarning on end-of-flow condition or if the remote hung up,
                - IOError (IOWarning subclass) on I/O error.

    ***************************************************************************/

    public void read ( void[] data )
    {
        if (data.length)
            this.buffered_reader.readRaw(data, &this.deviceRead);
    }

    /***************************************************************************

        Populates `value` with `value.sizeof` bytes read from the I/O device.

        Params:
            value = reference to a variable to be populated

        Throws:
            IOException if no data were received nor will any arrive later:
                - IOWarning on end-of-flow condition or if the remote hung up,
                - IOError (IOWarning subclass) on I/O error.

    ***************************************************************************/

    public void readValue ( T ) ( out T value )
    {
        static if (T.sizeof)
            this.buffered_reader.readRaw((cast(void*)&value)[0 .. value.sizeof],
                &this.deviceRead);
    }

    /***************************************************************************

        Calls `consume` with data read from the I/O device.

        If `consume` feels that the amount of `data` passed to it is sufficient
        it should return the number of bytes it consumed, which is a value
        between 0 and `data.length` (inclusive). Otherwise, if `consume`
        consumed all `data` and still needs more data from the I/O device, it
        should return a value greater than `data.`length`; it will then called
        again after more data have been received.

        Params:
            consume = consumer callback delegate

        Throws:
            IOException if no data were received nor will any arrive later:
                - IOWarning on end-of-flow condition or if the remote hung up,
                - IOError (IOWarning subclass) on I/O error.

    ***************************************************************************/

    public void readConsume ( size_t delegate ( void[] data ) consume )
    {
        this.buffered_reader.readConsume(consume, &this.deviceRead);
    }

    /***************************************************************************

        Writes the byte data of `value` to the I/O device.
        If the I/O device is a TCP socket then the data may be buffered for at
        most 200ms using the TCP Cork feature of Linux. In this case call
        `flush()` to write all pending data immediately.

        Params:
            value = the value of which the byte data to write

        Throws:
            IOException if no data were sent nor will it be possible later:
                - IOWarning if the remote hung up,
                - IOError (IOWarning subclass) on I/O error.

    ***************************************************************************/

    public void writeValue ( T ) ( in T value )
    {
        static if (T.sizeof)
            this.write((cast(Const!(void*))&value)[0 .. value.sizeof]);
    }

    /***************************************************************************

        Writes `data` to the I/O device.
        If the I/O device is a TCP socket then `data` may be buffered for at
        most 200ms using the TCP Cork feature of Linux. In this case call
        `flush()` to write all pending data immediately.

        Params:
            data = data to write

        Throws:
            IOException if no data were sent nor will it be possible later:
                - IOWarning if the remote hung up,
                - IOError (IOWarning subclass) on I/O error.

    ***************************************************************************/

    public void write ( Const!(void)[] data )
    {
        while (data.length)
            data = data[this.deviceWrite(data) .. $];
    }

    /***************************************************************************

        Sends all pending output data immediately. Calling this method has an
        effect only if the I/O device is a TCP socket.

        Throws:
            IOError on I/O error.

    ***************************************************************************/

    public void flush ( )
    {
        if (this.tcp_cork_status == tcp_cork_status.Enabled)
        {
            this.setTcpCork(false);
            this.setTcpCork(true);
        }
    }

    /***************************************************************************

        Removes any remaining data from I/O buffers. Sends any pending output
        data immediately if possible.

        This method does not throw.

    ***************************************************************************/

    public void reset ( )
    {
        this.buffered_reader.reset();

        if (this.tcp_cork_status == tcp_cork_status.Enabled)
            this.setTcpCork(false, false);

        this.tcp_cork_status = tcp_cork_status.Unknown;
    }

    /***************************************************************************

        Calls `io_op` until it returns a positive value. Waits for `wait_event`
        if `io_op` fails with `EAGAIN` or `EWOULDBLOCK`.

        `io_op` should behave like POSIX `read/write` and return
          - the non-zero number of bytes read or written on success or
          - 0 on end-of-flow condition or
          - a negative value on error and set `errno` accordingly.

        Params:
            io_op      = I/O operation
            wait_event = the event to wait for if `io_op` fails with
                         `EAGAIN/EWOULDBLOCK`
            opname     = the name of the I/O operation for error messages

        Returns:
            the number of bytes read or written by `io_op`.

        Throws:
            IOException if no data were transmitted and won't be later:
                - IOWarning on end-of-flow condition or if a hung-up event was
                  reported for the I/O device,
                - IOError (IOWarning subclass) if `io_op` failed with an error
                  other than `EAGAIN`, `EWOULDBLOCK` or `EINTR` or if an error
                  event was reported for the I/O device.

        Note: POSIX says the following about the return value of `read`:

            When attempting to read from an empty pipe or FIFO [remark: includes
            sockets]:

            - If no process has the pipe open for writing, read() shall return 0
              to indicate end-of-file.

            - If some process has the pipe open for writing and O_NONBLOCK is
              set, read() shall return -1 and set errno to [EAGAIN].

            - If some process has the pipe open for writing and O_NONBLOCK is
              clear, read() shall block the calling thread until some data is
              written or the pipe is closed by all processes that had the pipe
              open for writing.

        @see http://pubs.opengroup.org/onlinepubs/009604499/functions/read.html

    ***************************************************************************/

    private size_t transfer ( lazy iodev.ssize_t io_op, Event wait_event, istring opname )
    out (n)
    {
        assert(n > 0);
    }
    body
    {
        // Prevent misinformation if an error happens that is not detected by
        // io_op, such as a socket error reported by getsockopt(SO_ERROR) or an
        // epoll event like EPOLLHUP or EPOLLERR.
        errno = 0;
        iodev.ssize_t n;

        // First call io_op. If io_op fails with EAGAIN/EWOULDBLOCK, enter a
        // loop, waiting for EPOLLIN and calliing io_op again, until
        //   - io_op succeeds (i.e. returns a positive value) or
        //   - io_op reports EOF (i.e. returns 0; only read() does that) or
        //   - io_op fails (i.e. returns a negative value) with errno other
        //     than EAGAIN/EWOULDBLOCK (or EINTR, see below) or
        //   - epoll reports EPOLLHUP or EPOLLERR.
        for (n = io_op; n <= 0; n = io_op)
        {
            enforce(this.warning_e, n, "end of flow whilst reading");
            switch (errno)
            {
                case EAGAIN:
                    static if (EAGAIN != EWOULDBLOCK)
                    {
                        case EWOULDBLOCK:
                    }
                    Event events = this.select_client.ioWait(wait_event);
                    enforce(this.warning_e, !(events & events.EPOLLHUP), "connection hung up");

                    if (!(events & events.EPOLLERR))
                        break;
                    else
                    {
                        this.error_e.checkDeviceError("epoll reported I/O device error");
                        enforce(this.error_e, false, "epoll reported I/O device error");
                    }
                    assert(false);

                default:
                    this.error_e.checkDeviceError("I/O error");
                    throw this.error_e.useGlobalErrno(opname);

                case EINTR:
                    // io_op was interrupted by a signal before data were read
                    // or written. May not be possible with non-blocking I/O,
                    // but neither POSIX nor Linux documentation clarifies that,
                    // so handle it by calling io_op again to be safe.
            }
        }

        return n;
    }

    /***************************************************************************

        Reads as much data from the I/O device as can be read with one
        successful `read` call but at most `dst.length` bytes, and stores the
        data in `dst`.

        Params:
            dst = destination buffer

        Returns:
            the number `n` of bytes read, which are stored in `dst[0 .. n]`.

        Throws:
            IOException if no data were received and won't arrive later:
                - IOWarning on end-of-flow condition or if a hung-up event was
                  reported for the I/O device,
                - IOError (IOWarning subclass) if `read` failed with an error
                  other than `EAGAIN`, `EWOULDBLOCK` or `EINTR` or if an error
                  event was reported for the I/O device.

    ***************************************************************************/

    private size_t deviceRead ( void[] dst )
    out (n)
    {
        debug (Raw) Stdout.formatln(
            "[{}] Read  {:X2} ({} bytes)", this.iodev.fileHandle, dst[0 .. n], n
        );
    }
    body
    {
        return this.transfer(this.iodev.read(dst), Event.EPOLLIN, "read");
    }

    /***************************************************************************

        Reads as much data from the I/O device as can be read with one
        successful `readv` call but at most `dst_a.length + dst_b.length` bytes,
        and stores the data in `dst_a` and `dst_b`.

        Params:
            dst_a = first destination buffer
            dst_b = second destination buffer

        Returns:
            the number `n` of bytes read, which are stored in
            - `dst_a[0 .. n]` if `n <= dst_a.length` or
            - `dst_a` and `dst_b[0 .. n - dst_a.length]` if `n > dst_a.length`.

        Throws:
            IOException if no data were received and won't arrive later:
                - IOWarning on end-of-flow condition or if a hung-up event was
                  reported for the I/O device,
                - IOError (IOWarning subclass) if `readv` failed with an error
                  other than `EAGAIN`, `EWOULDBLOCK` or `EINTR` or if an error
                  event was reported for the I/O device.

    ***************************************************************************/

    private size_t deviceRead ( void[] dst_a, void[] dst_b )
    out (n)
    {
        debug (Raw)
        {
            if (n > dst_a.length)
                Stdout.formatln("[{}] Read  {:X2}{:X2} ({} bytes)",
                    this.iodev.fileHandle, dst_a, dst_b[0 .. n - dst_a.length], n);
            else
                Stdout.formatln("[{}] Read  {:X2} ({} bytes)",
                    this.iodev.fileHandle, dst_a[0 .. n], n);
        }
    }
    body
    {
        version (D_Version2)
        {
            // Work around a linker error caused by a druntime packagin bug: The
            // druntime is by mistake currently not linked with the
            // core.sys.posix.sys.uio module.
            static dst_init = iovec.init;
            iovec[2] dst = dst_init;
        }
        else
            iovec[2] dst;

        dst[0] = iovec(dst_a.ptr, dst_a.length);
        dst[1] = iovec(dst_b.ptr, dst_b.length);
        int fd = this.iodev.fileHandle;
        return this.transfer(
            readv(fd, dst.ptr, cast(int)dst.length), Event.EPOLLIN, "readv"
        );
    }

    /***************************************************************************

        Writes as much data from the I/O device as can be read with one
        successful `write` call but at most `src.length` bytes, taking the data
        from `src`.

        Params:
            src = source buffer

        Returns:
            the number `n` of bytes written, which were taken from
            `src[0 .. n]`.

        Throws:
            IOException if no data were written and won't be later:
                - IOWarning if a hung-up event was reported for the I/O device,
                - IOError (IOWarning subclass) if `write` failed with an error
                  other than `EAGAIN`, `EWOULDBLOCK` or `EINTR` or if an error
                  event was reported for the I/O device.

    ***************************************************************************/

    private size_t deviceWrite ( Const!(void)[] src )
    {
        debug (Raw) Stdout.formatln(
            "[{}] Write  {:X2} ({} bytes)", this.iodev.fileHandle,
            src, src.length
        );

        if (!this.tcp_cork_status)
        {
            // Try enabling TCP Cork. If it fails then TCP Cork is not supported
            // for the I/O device.
            this.tcp_cork_status =
                this.setTcpCork(true, false)
                ? tcp_cork_status.Enabled
                : tcp_cork_status.Disabled;
        }

        return this.transfer(this.iodev.write(src), Event.EPOLLOUT, "write");
    }

    /***************************************************************************

        Sets the TCP_CORK option. Disabling (`enable` = 0) sends all pending
        data.

        Params:
            enable = 0 disables TCP_CORK and flushes if previously enabled, a
                different value enables TCP_CORK.
            throw_on_error = throw on error rather than returning `false`

        Returns:
            `true` on success or `false` on error if `throw_on_error` is
            `false`.

        Throws:
            `IOError` if the `TCP_CORK` option cannot be set for `socket` and
            `throw_on_error` is `true`. In practice this can fail only for one
            of the following reasons:
             - `socket.fileHandle` does not contain a valid file descriptor
               (`errno == EBADF`). This is the case if the socket was not
               created by `socket()` or `accept()` yet.
             - `socket.fileHandle` does not refer to a socket
               (`errno == ENOTSOCK`).

    ***************************************************************************/

    private bool setTcpCork ( int enable, bool throw_on_error = true )
    {
        if (!setsockopt(this.iodev.fileHandle, IPPROTO_TCP, TCP_CORK,
            &enable, enable.sizeof))
        {
            return true;
        }
        else if (throw_on_error)
        {
            this.error_e.checkDeviceError("setsockopt(TCP_CORK)");
            throw this.error_e.useGlobalErrno("setsockopt(TCP_CORK)");
        }
        else
        {
            return false;
        }
    }
}

version (UnitTest)
{
    import ocean.io.device.IODevice;
    import ocean.io.select.protocol.generic.ErrnoIOException;
    import ocean.task.Task;
    import ocean.transition;
}

/// Example of sending and receiving data with the `TaskSelectTransceiver`.
unittest
{
    static class IOTaskDemo: Task
    {
        TaskSelectTransceiver tst;

        this ( )
        {
            // I/O device to read/write via. In the real world, this would
            // typically be your socket.
            IODevice iodev;
            this.tst = new TaskSelectTransceiver(
                iodev, new IOWarning(iodev), new IOError(iodev)
            );
        }

        override void run ( )
        {
            // Send a newline-terminated string.
            this.tst.write("Hello World!\n");
            // Send an integer value.
            this.tst.writeValue(3);
            this.tst.flush();

            // Receive a newline-terminated string.
            {
                char[] response;
                this.tst.readConsume(
                    (void[] data)
                    {
                        auto str = cast(char[])data;
                        foreach (i, c; str)
                        {
                            if (c == '\n')
                            {
                                response ~= str[0 .. i];
                                return i;
                            }
                        }

                        response ~= str;
                        return str.length + 1;
                    }
                );
            }

            // Receive an integer value.
            {
                int x;
                this.tst.readValue(x);
            }
        }
    }
}

version (UnitTest)
{
    import ocean.stdc.posix.fcntl: O_NONBLOCK;
    import ocean.stdc.posix.unistd: write, close;
    import ocean.sys.ErrnoException;
    import ocean.task.Scheduler;
    import ocean.core.Test;

    extern (C) private int pipe2(ref int[2] fd, int flags);
}

unittest
{
    // This test uses a pipe as an I/O device.
    int[2] pipefd;

    if (pipe2(pipefd, O_NONBLOCK))
        throw (new ErrnoException).useGlobalErrno("pipe2");

    // This TaskSelectTransceiver subclass uses a tiny 3-bytes buffer to test
    // the reading loop.
    static scope class TestTaskSelectTransceiver: TaskSelectTransceiver
    {
        this ( IODevice iodev )
        {
            super(iodev, new IOWarning(iodev), new IOError(iodev), 3);
        }

        ~this ( ) { .close(this.iodev.fileHandle); }
    }

    // Create an input-only task select transceiver for the reading end of the
    // pipe.
    scope intst = new TestTaskSelectTransceiver(new class IODevice
    {
        Handle fileHandle ( ) { return cast(Handle)pipefd[0]; }
        override ssize_t write ( Const!(void)[] src ) { assert(false); }
    });

    // Create an output-only task select transceiver for the writing end of the
    // pipe.
    scope outtst = new TestTaskSelectTransceiver(new class IODevice
    {
        Handle fileHandle ( ) { return cast(Handle)pipefd[1]; }
        override ssize_t read ( void[] dst ) { assert(false); }
        override ssize_t write ( Const!(void)[] src )
        {
            return .write(pipefd[1], src.ptr, src.length);
        }
    });

    initScheduler(SchedulerConfiguration.init);

    const outstr = "Hello World!";
    char[outstr.length] instr;

    // Start a task that writes the test string to the pipe.
    theScheduler.schedule(new class Task
    {
        override void run     ( ) { outtst.write(outstr); }
        override void recycle ( ) { outtst.select_client.unregister(); }
    });

    // Start a task that reads the test string from the pipe.
    theScheduler.schedule(new class Task
    {
        override void run ( )
        {
            // Read only "Hello " to test readv().
            const hello = "Hello ".length;
            intst.read(instr[0 .. hello]);
            auto world = instr[hello .. $];

            // Read "World!". The input buffer size makes only 3 characters
            // arrive at once.
            intst.readConsume(
                (void[] data)
                {
                    world[0 .. data.length] = cast(char[])data;
                    world = world[data.length .. $];
                    return data.length + !!world.length;
                }
            );
        }

        override void recycle ( ) { intst.select_client.unregister(); }
    });

    theScheduler.eventLoop();

    test!("==")(instr, outstr);
}
