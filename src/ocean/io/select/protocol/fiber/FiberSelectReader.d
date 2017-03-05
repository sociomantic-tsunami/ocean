/******************************************************************************

    Fiber/coroutine based non-blocking input select client base class

    Base class for a non-blocking input select client using a fiber/coroutine to
    suspend operation while waiting for the read event and resume on that event.
    Provides a stream-like interface with consumer delegate invocation to
    receive and consume data from the input until the consumer indicates it has
    finished.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.io.select.protocol.fiber.FiberSelectReader;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.io.select.protocol.fiber.model.IFiberSelectProtocol;

import ocean.io.device.IODevice: IInputDevice;

import core.stdc.errno: errno, EAGAIN, EWOULDBLOCK, EINTR;

debug (Raw) import ocean.io.Stdout: Stderr;


/******************************************************************************/

class FiberSelectReader : IFiberSelectProtocol
{
    import ocean.core.Enforce: enforce;

    /**************************************************************************

        Default input buffer size (16 kB).

     **************************************************************************/

    public const size_t default_buffer_size = 16 * 1024;

    /**************************************************************************

        Consumer callback delegate type

        Params:
            data = data to consume

        Returns:
            - if finished, a value of [0, data.length] reflecting the number of
              elements (bytes) consumed or
            - a value greater than data.length if more data is required.

     **************************************************************************/

    alias size_t delegate ( void[] data ) Consumer;

    /**************************************************************************

        Input device

     **************************************************************************/

    public alias .IInputDevice IInputDevice;

    private IInputDevice input;

    /**************************************************************************

        Data buffer

     **************************************************************************/

    private void[] data;

    /**************************************************************************

        End index of available and consumed data.

        Available data is data received by receive() or read() and not yet
        consumed by the consumer delegate passed to consume() or read().
        Consumed data is data received by receive() or read() and already
        consumed by the consumer delegate passed to consume() or read().

     **************************************************************************/

    private size_t available = 0,
                   consumed  = 0;

    /**************************************************************************

        Invariant to assure consumed/available are in correct order and range

     **************************************************************************/

    invariant()
    {
        assert (available <= this.data.length);
        assert (consumed  <= this.data.length);
        assert (consumed  <= available);
    }

    /**************************************************************************

        Constructor.

        error_e and warning_e may be the same object if distinguishing between
        error and warning is not required.

        Params:
            input       = input device
            fiber       = input reading fiber
            warning_e   = exception to throw on end-of-flow condition or if the
                          remote hung up
            error_e     = exception to throw on I/O error
            buffer_size = input buffer size

        In:
            buffer_size must not be 0.

     **************************************************************************/

    public this ( IInputDevice input, SelectFiber fiber,
                  IOWarning warning_e, IOError error_e,
                  size_t buffer_size = this.default_buffer_size )
    in
    {
        assert (buffer_size, "zero input buffer size specified");
    }
    body
    {
        super(this.input = input, Event.EPOLLIN | Event.EPOLLRDHUP,
              fiber, warning_e, error_e);

        this.data = new ubyte[buffer_size];
    }

    /**************************************************************************

        Constructor

        Uses the conduit, fiber and exceptions from the other
        IFiberSelectProtocol instance. This is useful when this instance shares
        the conduit and fiber with another IFiberSelectProtocol instance, e.g.
        a FiberSelectWriter.

        The conduit owned by the other instance must have been downcast from
        IInputDevice.

        Params:
            other       = other instance of this class
            buffer_size = input buffer size

        In:
            buffer_size must not be 0.

     **************************************************************************/

    public this ( typeof (super) other,
                  size_t buffer_size = this.default_buffer_size )
    in
    {
        assert (buffer_size, "zero input buffer size specified");
    }
    body
    {
        super(other, Event.EPOLLIN | Event.EPOLLRDHUP);

        this.data = new ubyte[buffer_size];

        this.input = cast (IInputDevice) this.conduit;

        assert (this.input !is null, typeof (this).stringof ~ ": the conduit of "
                ~ "the other " ~ typeof (super).stringof ~ " instance must be a "
                ~ IInputDevice.stringof);
    }


    version (D_Version2) {}
    else
    {
        /***********************************************************************

            Called immediately when this instance is deleted.
            (Must be protected to prevent an invariant from failing.)

        ***********************************************************************/

        protected override void dispose ( )
        {
            super.dispose();

            delete this.data;
        }
    }


    /**************************************************************************

        Resets the amount of consumed/available data to 0.

        Returns:
            this instance

     **************************************************************************/

    public typeof (this) reset ( )
    {
        this.consumed  = 0;
        this.available = 0;

        return this;
    }

    /**************************************************************************

        Returns:
            data in buffer available and consumed so far

     **************************************************************************/

    public void[] consumed_data ( )
    {
        return this.data[0 .. this.consumed];
    }

    /**************************************************************************

        Returns:
            data in buffer available but not consumed so far

     **************************************************************************/

    public void[] remaining_data ( )
    {
        return this.data[this.consumed .. this.available];
    }

    /**************************************************************************

        Invokes consume with the data that are currently available and haven't
        yet been consumed.
        If the amount of data is sufficient, consume must return the number of
        bytes it consumed. Otherwise if consume consumed all data and needs more
        input data to be read from the I/O device, it must return a value
        greater than the number of data bytes passed to it.

        Invokes consume to consume the available data until consume indicates to
        be finished or all available data is consumed.

        Params:
            consume = consumer callback delegate

        Returns:
            - true if all available data in buffer has been consumed and consume
              indicated that it requires more or
            - false if consume indicated to be finished.

     **************************************************************************/

    public bool consume ( Consumer consume )
    {
        size_t n   = consume(this.data[this.consumed .. this.available]),
               end = this.consumed + n;

        // n can be very big (size_t.max) so end may overflow, n will be greater
        // than this.available in this case.

        if (end <= this.available && n <= this.available)
        {
            this.consumed = end;

            return false;
        }
        else
        {
            // All data consumed: reset and return false if end == available.

            this.reset();

            return end != this.available;
        }
    }

     /**************************************************************************

        Reads T.sizeof bytes from the socket and writes it to 'value'
        Suspends if not enough data is available and resumes when
        the data became available

        Params:
            value = reference to a variable to be filled

        Returns:
            this instance

        Throws:
            IOException if no data were received and won't arrive later:
                - IOWarning on end-of-flow condition or if the remote hung up,
                - IOError (IOWarning subclass) on I/O error.

     **************************************************************************/

    public typeof (this) read ( T ) ( ref T value )
    {
        return this.readRaw((cast(ubyte*)&value)[0 .. value.sizeof]);
    }

    /**************************************************************************

        Reads data.length bytes from the socket and writes them to the array.

        Will only return once enough data is available and the array could
        be filled.

        Params:
            data_out = pre-allocated array which will be filled

        Returns:
            this instance

        Throws:
            IOException if no data were received and won't arrive later:
                - IOWarning on end-of-flow condition or if the remote hung up,
                - IOError (IOWarning subclass) on I/O error.

     **************************************************************************/

    public typeof (this) readRaw ( ubyte[] data_out )
    {
        auto available_data = this.data[this.consumed .. this.available];

        if (available_data.length >= data_out.length)
        {
            // Enough data are already in the buffer: Copy them into data_out
            // and return.
            data_out[] = cast(ubyte[])available_data[0 .. data_out.length];
            this.consumed += data_out.length;
            if (this.consumed == this.available)
                this.reset();
        }
        else
        {
            // Not enough data in the buffer: First copy all buffered data to
            // data_out.
            data_out[0 .. available_data.length] = cast(ubyte[])available_data;
            data_out = data_out[available_data.length .. $];
            this.reset();
            if (data_out.length > this.data.length)
            {
                // Read straight into data_out, circumventing the internal
                // buffer, as long as the amount of data left to read is greater
                // than the buffer size.
                auto this_data = this.data;
                this.data = data_out;
                try
                {
                    while ((this.data.length - this.available) > this_data.length)
                        this.receive();
                    data_out = cast(ubyte[])this.data[this.available .. $];
                }
                finally
                {
                    this.data = this_data;
                    this.reset();
                }
            }

            // Read the remaining data.
            while (this.available < data_out.length)
                this.receive();
            data_out[] = cast(ubyte[])
                this.data[0 .. this.consumed = data_out.length];
        }

        return this;
    }

    /**************************************************************************

        Reads data from the input conduit and appends them to the data buffer,
        waiting for data to be read from the input conduit if

        If no data is available from the input conduit, the input reading fiber
        is suspended and continues reading on resume.

        Returns:
            number of bytes read

        Throws:
            IOException if no data were received and won't arrive later:
                - IOWarning on end-of-flow condition or if the remote hung up,
                - IOError (IOWarning subclass) on I/O error.

     **************************************************************************/

    public size_t receive ( )
    {
        if (this.available >= this.data.length)
        {
            this.reset();
        }

        size_t available_before = this.available;

        this.transmitLoop();

        return this.available - available_before;
    }

    /**************************************************************************

        Reads data from the input conduit, appends it to the data buffer and
        invokes consume with the data that is currently available and hasn't
        yet been consumed.
        If consume feels that the amount of data passed to it is sufficient,
        it must return the number of bytes it consumed. Otherwise if consume
        consumed all the data and still needs more input data to be read from
        the I/O device, it must return a value greater than length of the the
        data passed to it. The fiber is then suspended to wait for more data
        to be available from the input device, and consume is invoked again
        with the newly available data.

        Params:
            consume = consumer callback delegate

        Returns:
            this instance

        Throws:
            IOException if no data was received and none will arrive later:
                - IOWarning on end-of-flow condition or if the remote hung up,
                - IOError (IOWarning subclass) on an I/O error.

     **************************************************************************/

    public typeof (this) readConsume ( Consumer consume )
    {
        bool more;

        do
        {
            if (this.consumed >= this.available) // only this.consumed == this.available possible
            {
                this.receive();
            }

            more = this.consume(consume);
        }
        while (more);

        return this;
    }

    /**************************************************************************

        Reads data from the input conduit and appends them to the data buffer.

        Params:
            events = events reported for the input device

        Returns:
            true if data were received or false to retry later.

        Throws:
            IOException if no data were received and won't arrive later:
                - IOWarning on end-of-flow condition or if the remote hung up,
                - IOError (IOWarning subclass) on I/O error.

        Note: POSIX says the following about the return value of read():

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

     **************************************************************************/

    protected override bool transmit ( Event events )
    in
    {
        assert (this.available < this.data.length, "requested to receive nothing");
    }
    out (received)
    {
        assert (received <= data.length, "received length too high");
    }
    body
    {

        .errno = 0;

        input.ssize_t n = this.input.read(this.data[this.available .. $]);

        if (n <= 0)
        {
             // EOF or error: Check for socket error and hung-up event first.

            this.error_e.checkDeviceError(n? "read error" : "end of flow whilst reading", __FILE__, __LINE__);

            enforce(this.warning_e, !(events & events.EPOLLRDHUP), "connection hung up on read");
            enforce(this.warning_e, !(events & events.EPOLLHUP), "connection hung up");

            if (n)
            {
                // read() error and no socket error or hung-up event: Check
                // errno. Carry on if there are just currently no data available
                // (EAGAIN/EWOULDBLOCK/EINTR) or throw error otherwise.

                switch (.errno)
                {
                    default:
                        this.error_e.enforce(false, "read error");
                        assert (false);

                    case EINTR, EAGAIN:
                        static if ( EAGAIN != EWOULDBLOCK )
                        {
                            case EWOULDBLOCK:
                        }

                        // EAGAIN/EWOULDBLOCK: currently no data available.
                        // EINTR: read() was interrupted by a signal before data
                        //        became available.

                        n = 0;
                }
            }
            else
            {
                // EOF and no socket error or hung-up event: Throw EOF warning.
                enforce(this.warning_e, false, "end of flow whilst reading");
            }
        }
        else
        {
            debug (Raw) Stderr.formatln("[{}] Read  {:X2} ({} bytes)",
                super.conduit.fileHandle,
                this.data[this.available .. this.available + n], n);

            this.available += n;
        }

        assert (n >= 0);

        return !n;
    }
}

/******************************************************************************/

version (UnitTest)
{
    import ocean.io.select.client.model.ISelectClient;
    import ocean.io.select.fiber.SelectFiber;
    import core.sys.posix.stdlib;
    import ocean.core.Test;
    import ocean.transition;
}

unittest
{
    static class UnSelectFiber: SelectFiber
    {
        this ( ) { super(null, {assert(false);}); }
        override:
        Message start      (Message)                { assert(false); }
        Message suspend    (Token, Object, Message) { assert(false); }
        Message resume     (Token, Object, Message) { assert(false); }
        void    kill       (istring, long)          { assert(false); }
        bool    register   (ISelectClient)          { assert(false); }
        bool    unregister ()                       { assert(false); }
    }

    // All numeric constants related to buffer sizes and amounts of data below
    // are tuned to test the internals of readRaw().

    static class Input: IInputDevice
    {
        /// Input data for `read()`.
        void[] data;

        /// Copies `data[0 .. n]` into `dst[0 .. n]` where `n` is the minimum of
        /// `data.length`, `dst.length` and 15, and advances
        /// `data = data[n .. $]`. Returns `n`.
        ssize_t read ( void[] dst )
        {
            if (dst.length > this.data.length)
                dst = dst[0 .. this.data.length];
            if (dst.length > 15)
                dst = dst[0 .. 15];

            dst[] = this.data[0 .. dst.length];
            this.data = this.data[dst.length .. $];
            return dst.length;
        }

        Handle fileHandle ( ) { return cast(Handle)4711; } /// Interface method
    }

    static class TestFiberSelectReader: FiberSelectReader
    {
        this ( IInputDevice input, SelectFiber fiber )
        {
            auto e = new IOError(input);
            super(input, fiber, e, e, 50);
        }

        override protected void transmitLoop ( )
        {
            while (this.transmit(Event.init)) {}
        }
    }

    // The test starts here.

    scope input  = new Input,
          fiber  = new UnSelectFiber,
          reader = new TestFiberSelectReader(input, fiber);

    ubyte[100] input_data, output_data;

    ushort[3] xsubi;
    xsubi[0] = 0x330E; // see jrand48() documentation
    foreach (ref n; cast(uint[])input_data)
        n = cast(uint)jrand48(xsubi);

    input.data = input_data;

    reader.readRaw(output_data[0 .. 10]);
    test!("==")(input_data[0 .. 10], output_data[0 .. 10]);

    reader.readRaw(output_data[10 .. $ - 3]);
    test!("==")(input_data[10 .. $ - 3], output_data[10 .. $ - 3]);

    reader.readRaw(output_data[$ - 3 .. $]);
    test!("==")(input_data[$ - 3 .. $], output_data[$ - 3 .. $]);
}
