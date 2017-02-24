/*******************************************************************************

    Fiberless SelectReader

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.select.protocol.SelectReader;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.io.select.client.model.ISelectClient;
import ocean.io.device.IODevice;
import ocean.io.select.protocol.generic.ErrnoIOException;

import core.stdc.errno;

debug (Raw)         import ocean.io.Stdout : Stderr;
debug (SelectFiber) import ocean.io.Stdout : Stderr;

/*******************************************************************************

    SelectReader without Fiber

    This is useful for when you want to read when there is something to read but
    you don't want to block/wait/suspend your fiber when there is nothing.

*******************************************************************************/

class SelectReader : IAdvancedSelectClient
{
    /***************************************************************************

        Reader device

    ***************************************************************************/

    private IInputDevice input;

    /***************************************************************************

        Reader buffer

    ***************************************************************************/

    private ubyte[] buffer;

    /***************************************************************************

        Reader delegate, will be called with new data

    ***************************************************************************/

    private void delegate ( void[] data ) reader;

    /**************************************************************************

        IOWarning exception instance

     **************************************************************************/

    protected IOWarning warning_e;

    /**************************************************************************

        IOError exception instance

     **************************************************************************/

    protected IOError error_e;

    /***************************************************************************

        Events to we are interested in

    ***************************************************************************/

    private Event events_ = Event.EPOLLIN | Event.EPOLLRDHUP;

    /***************************************************************************

        Constructor

        Params:
            input       = input device to use
            buffer_size = buffer size to use
            warning_e   = instance of a reusable exception to use, will be
                          allocated if null
            error_e     = instance of a reusable exception to use, will be
                          allocated if null

    ***************************************************************************/

    public this ( IInputDevice input, size_t buffer_size, IOWarning warning_e =
                  null , IOError error_e = null)
    {
        this.input = input;
        this.buffer = new ubyte[buffer_size];

        this.warning_e =  warning_e is null ? new IOWarning(input) : warning_e;
        this.error_e   =  error_e   is null ? new IOError(input)   : error_e;
    }


    /**************************************************************************

        Returns:
            the events to register the I/O device for.

     **************************************************************************/

    public override Event events ( )
    {
        return this.events_;
    }


    /**************************************************************************

        Returns:
            the I/O device file handle.

     **************************************************************************/

    public override Handle fileHandle ( )
    {
        return this.input.fileHandle();
    }


    /***************************************************************************

        Feed delegate with data that was read.

        Params:
            dg = delegate to call with new data

    ***************************************************************************/

    public void read ( void delegate ( void[] data ) dg )
    {
        this.reader = dg;

        this.read(Event.None);
    }


    /***************************************************************************

        Read data if events don't indicate end of connection

        Params:
            events = events

    ***************************************************************************/

    private void read ( Event events )
    {
        .errno = 0;

        input.ssize_t n = this.input.read(this.buffer);

        if (n <= 0)
        {
             // EOF or error: Check for socket error and hung-up event first.

            this.error_e.checkDeviceError(n? "read error" : "end of flow whilst reading", __FILE__, __LINE__);

            this.warning_e.enforce(!(events & events.EPOLLRDHUP), "connection hung up on read");
            this.warning_e.enforce(!(events & events.EPOLLHUP), "connection hung up");

            if (n)
            {
                // read() error and no socket error or hung-up event: Check
                // errno. Carry on if there are just currently no data available
                // (EAGAIN/EWOULDBLOCK/EINTR) or throw error otherwise.

                int errnum = .errno;

                switch (errnum)
                {
                    default:
                        throw this.error_e.set(errnum, "read error");

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

                this.warning_e.enforce(false, "end of flow whilst reading");
            }
        }
        else
        {
            debug (Raw) Stderr.formatln("[{}] Read  {:X2} ({} bytes)",
                this.fileHandle,
                this.buffer[0 .. n], n);
        }

        assert (n >= 0);

        if ( n > 0 )
        {
            this.reader(this.buffer[0 .. n]);
        }
    }


    /***************************************************************************

        Handle socket events

        Params:
            events = events to handle

        Returns:
            true, so it stays registered

    ***************************************************************************/

    final override protected bool handle ( Event events )
    {
        this.read(events);
        debug ( SelectFiber ) Stderr.formatln("{}.handle: fd {} read() called",
                typeof(this).stringof, this.fileHandle);

        return true;
    }
}
