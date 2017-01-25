/*******************************************************************************

    Task based epoll select dispatcher client.

    Manages the epoll registration of a file descriptor, suspends a task to wait
    for I/O events to occur for that file descriptor, and resumes the task to
    handle the occurred events.

    Copyright:
        Copyright (c) 2017 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.select.protocol.task.TaskSelectClient;

import ocean.io.select.client.model.ISelectClient;

class TaskSelectClient: ISelectClient
{
    import ocean.task.Task: Task;
    import ocean.task.Scheduler: theScheduler;
    import ocean.io.select.protocol.task.TimeoutException;
    import ocean.core.Traits: StripTypedef;
    import ocean.util.log.Log;
    import ocean.transition;

    debug (SelectFiber) import ocean.io.Stdout: Stdout;

    /***************************************************************************

        The I/O device.

    ***************************************************************************/

    private ISelectable iodev;

    /***************************************************************************

        The I/O events passed to `epoll.register()/modify()`.
        Also used in logic to avoid unnecessary unregister/register sequences:
        A non-zero value means the I/O device is, zero that it is not registered
        with epoll.

    ***************************************************************************/

    private Event events_expected;

    /***************************************************************************

        The task that is suspended while waiting for events.

    ***************************************************************************/

    private Task task;

    /***************************************************************************

        The I/O events reported by epoll.

    ***************************************************************************/

    private Event events_reported;

    /***************************************************************************

        `true` if the I/O device timed out before an event occurred.

    ***************************************************************************/

    private bool timeout_reported;

    /***************************************************************************

        Reusable timeout exception.

    ***************************************************************************/

    private TimeoutException e_timeout;

    /***************************************************************************

        Obtains the current error status of the I/O device, such as socket
        error.

    ***************************************************************************/

    private int delegate ( ) error_code_dg;

    /***************************************************************************

        Constructor.

        Params:
            iodev         = the I/O device
            error_code_dg = delegate to query the I/O device error status

    ***************************************************************************/

    public this ( ISelectable iodev, int delegate ( ) error_code_dg )
    {
        this.iodev = iodev;
        this.error_code_dg = error_code_dg;
    }

    /**************************************************************************

        Suspends the current task until epoll reports any event in
        `events_expected` for the I/O device or the I/O device times out.

        Params:
            events_expected = the events to wait for (`EPOLLHUP` and `EPOLLERR`
                              are always implicitly added)

        Returns:
            the events reported by epoll.

        Throws:
            `EpollException` if registering with epoll failed,
            `TimeoutException` on timeout waiting for I/O events.

     **************************************************************************/

    public Event ioWait ( Event events_expected )
    in
    {
        assert(events_expected);
        assert(!this.task);
    }
    out
    {
        assert(!this.task);
    }
    body
    {
        // Based on the current value of this.events_expected do the following:
        // - If this.events_expected is 0 then the I/O device is not registered
        //   with epoll so register it.
        // - If this.events_expected is non-zero then the I/O device is still
        //   registered from a previous call of this method so
        //   - if this.events_expected differs from events_expected then change
        //     the events of the existing registration,
        //   - otherwise don't touch the existing registration.

        if (this.events_expected != events_expected)
        {
            bool already_registered = !!this.events_expected;
            this.events_expected = events_expected;
            auto epoll = theScheduler.epoll;
            if (already_registered)
                epoll.modify(this);
            else
                epoll.register(this);
        }

        try
        {
            this.task = task.getThis();
            assert(this.task);
            this.task.suspend();
            assert(!this.task);

            // At this point handle() has resumed the task and is blocked until
            // the task is suspended again (or terminates). In order to avoid
            // unecessary epoll unregister/register sequences we stay registered
            // with epoll. Now there are two possible scenarios:

            // 1. This method is called again without suspending in the mean
            // time the task so handle() is still waiting. We will find
            // events_expected as we left it i.e. not 0, meaning the I/O device
            // is still registered. Then we set this.task to the current task
            // and suspend again. This will resume handle(), which will see
            // this.task is not null and therefore return true to stay
            // registered with epoll and wait for events.

            // 2. The task is suspended or terminates outside the reach of this
            // class. handle() will be resumed and see this.task is null so it
            // will set this.events_expected = 0 and return false to request
            // being unregistered. If this method is called again, it will see
            // events_expected == 0, meaning the I/O device is not registered,
            // and register it.

            if (this.events_reported & events_reported.EPOLLERR)
                // Reset events_expected because with EPOLLERR the I/O device is
                // automatically unregistered.
                this.events_expected = events_expected.init;

            if (this.timeout_reported)
            {
                this.timeout_reported = false;
                if (this.e_timeout is null)
                    this.e_timeout = new TimeoutException;
                throw this.e_timeout;
            }

            return this.events_reported;
        }
        finally
            this.events_reported = this.events_reported.init;
    }

    /**************************************************************************

        Unregisters the I/O device.

       Returns:
            0 if everything worked as expected or `ENOENT` if the client was
            already unregistered.

        Throws:
            `EpollException` on error.

     **************************************************************************/

    public int unregister ( )
    {
        this.events_expected = events_expected.init;
        return theScheduler.epoll.unregister(this);
    }

    /**************************************************************************

        Resumes the task to handle `events`.

        Params:
            events = the events reported by epoll

        Returns:
            true to stay registered with epoll or false to be unregistered.

     **************************************************************************/

    override public bool handle ( Event events )
    {
        // This handler should only be called while ioWait() is blocked in the
        // task.suspend() call so this.task should always refer to the task to
        // be resumed.
        if (Task task = this.task)
        {
            this.task = null;

            debug ( SelectFiber ) Stdout.formatln(typeof(this).stringof ~
                ".handle: fd {} task resumed", this.fd);

            this.events_reported = events;
            task.resume();

            debug ( SelectFiber ) Stdout.formatln(typeof(this).stringof ~
                ".handle: fd {} task yielded", this.fd);

            if (this.task)
            {
                // After the task has been resumed, ioWait() has returned, then
                // it was called again and suspended the task again so stay
                // registered with epoll.
                return true;
            }
            else
            {
                // The task was suspended outside ioWait() or has terminated so
                // it is not waiting for events for this.iodev.
                this.events_expected = this.events_expected.init;
                return false;
            }
        }
        else
        {
            // Should not happen, unregister to make the event we cannot handle
            // firing.
            Log.lookup(typeof(this).stringof).error(
                "handle {} fd {} events {:X}: no task to resume, unregistering",
                this.iodev, this.fd, events
            );
            debug ( SelectFiber )
                Stdout.formatln(typeof(this).stringof ~
                ".handle: fd {} no task to resume, unregistering", this.fd);
            return false;
        }
    }

    /**************************************************************************

        Returns:
            the I/O device file handle.

     **************************************************************************/

    override public Handle fileHandle ( ) { return this.iodev.fileHandle; }

    /**************************************************************************

        Returns:
            the events to register the I/O device for.

     **************************************************************************/

    override public Event events ( ) { return this.events_expected; }

    /**************************************************************************

        Returns:
            current I/O (e.g. socket) error code, if available, or 0 otherwise.

     **************************************************************************/

    override public int error_code ( ) { return this.error_code_dg(); }

    /***************************************************************************

        Called if `EPOLLERR` was reported for the I/O device.

        Future direction: This class will handle `EPOLLERR` through `handle()`
        when error reporting and finalizing are removed from `ISelectClient`.

        Params:
            exception = not the issue here
            event     = the reported events including `EPOLLERR`

    ***************************************************************************/

    override protected void error_ ( Exception exception, Event events )
    {
        this.events_reported = events;
    }

    /**************************************************************************

        Called after this instance was unregistered from epoll because either
         - `handle()` returned `false` (`status.Success`) or
         - the I/O device timed out (`status.Timeout`) or
         - `EPOLLERR` has been reported for the I/O device (`status.Error`).

        Note that for `status` other than `Success` `handle()` is not called.

        Future direction: When error reporting and finalizing are removed from
        `ISelectClient`,
         - timeouts can be handled by overriding `void timeout()`,
         - this class will handle `EPOLLERR` through `handle()`,
         - finalization with `status.Success` doesn't need to be handled.

        Params:
            event     = the events reported including `EPOLLERR`

     **************************************************************************/

    override public void finalize ( FinalizeStatus status )
    {
        if (Task task = this.task)
        {
            this.task = null;
            this.events_expected = events_expected.init;

            /* D2: final */ switch (status)
            {
                case status.Success:
                    break;

                case status.Timeout:
                    this.timeout_reported = true;
                    task.resume();
                    break;

                case status.Error:
                    // error_() has been called before so ioWait() will simply
                    // return the reported events which include EPOLLERR.
                    task.resume();
                    break;

                default: assert(false);
            }
        }
    }

    /***************************************************************************

        Returns the file descriptor of the I/O device as `int`, for logging.

        Returns:
            the file descriptor of the I/O device.

    ***************************************************************************/

    private int fd ( )
    {
        auto handle = this.iodev.fileHandle;
        version (D_Version2)
        {
            static if (!is(typeof(handle) == int))
            {
                static assert(is(handle.IsTypedef));
                static assert(is(typeof(handle.value) == int));
            }
        }
        else mixin(`
            static if (is(typeof(handle) FD == typedef))
                static assert(is(FD == int));
            else
                static assert(is(typeof(handle) == int));
        `);

        return cast(int)handle;
    }
}
