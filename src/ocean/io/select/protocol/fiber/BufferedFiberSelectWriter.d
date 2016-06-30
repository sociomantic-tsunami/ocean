/******************************************************************************

    Fiber/coroutine based buffered non-blocking output select client

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.io.select.protocol.fiber.BufferedFiberSelectWriter;

import ocean.transition;

import ocean.io.select.protocol.fiber.FiberSelectWriter;

import ocean.io.select.protocol.fiber.model.IFiberSelectProtocol;

import ocean.util.container.AppendBuffer;

/******************************************************************************/

class BufferedFiberSelectWriter : FiberSelectWriter
{
    /**************************************************************************

        Default output buffer size (64 kB)

     **************************************************************************/

    public const default_buffer_size = 64 * 1024;

    /**************************************************************************

        AppendBuffer instance

     **************************************************************************/

    private AppendBuffer!(void) buffer;

    /**************************************************************************

        Constructor

        Params:
            output = output device
            fiber = output reading fiber
            warning_e = exception to throw on end-of-flow condition or if the
                remote hung up
            error_e = exception to throw on I/O error
            size = buffer size

        In:
            The buffer size must not be 0.

     **************************************************************************/

    public this ( IOutputDevice output, SelectFiber fiber,
                  IOWarning warning_e, IOError error_e,
                  size_t size = default_buffer_size )
    in
    {
        assert (size, "zero input buffer size specified");
    }
    body
    {
        super(output, fiber, warning_e, error_e);
        this.buffer = new AppendBuffer!(void)(size, true);
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
            size        = output buffer size

        In:
            buffer_size must not be 0.

     **************************************************************************/

    public this ( IFiberSelectProtocol other, size_t size = default_buffer_size )
    in
    {
        assert (size, "zero input buffer size specified");
    }
    body
    {
        super(other);
        this.buffer = new AppendBuffer!(void)(size, true);
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

            delete this.buffer;
        }
    }


    /**************************************************************************

        Returns:
            current buffer size

     **************************************************************************/

    public size_t buffer_size ( )
    {
        return this.buffer.capacity;
    }

    /**************************************************************************

        Flushes the buffer and sends all pending data.

        Returns:
            this instance.

     **************************************************************************/

    public override typeof (this) flush ( )
    {
        this.flushBuffer();
        super.flush();

        return this;
    }

    /**************************************************************************

        Clears any pending data in the buffer.

        Returns:
            this instance

     **************************************************************************/

    public override typeof (this) reset ( )
    {
        this.buffer.clear();
        super.reset();

        return this;
    }

    /**************************************************************************

        Sets the buffer size to s. If there are currently more than s bytes of
        data in the buffer, flush() is called before setting the size.

        Params:
            s = new buffer size

        Returns:
            new buffer size

        In:
            The new buffer size must not be 0.

     **************************************************************************/

    public size_t buffer_size ( size_t s )
    in
    {
        assert (s, typeof (this).stringof ~ ".buffer_size: 0 specified");
    }
    out (n)
    {
        assert (n == s);
    }
    body
    {
        if (s < this.buffer.length)
        {
            this.flushBuffer();
        }

        return this.buffer.capacity = s;
    }

    /**************************************************************************

        Sends data_.

        Params:
            data = data to send

        Returns:
            this instance.

     **************************************************************************/

    public override typeof (this) send ( Const!(void)[] data )
    {
        if (data.length < this.buffer.capacity)
        {
            auto dst = this.buffer.extend(data.length);

            dst[] = data[0 .. dst.length];

            auto left = data[dst.length .. $];

            if (left.length || this.buffer.length == this.buffer.capacity)
            {
                this.flushBuffer();
            }

            if (left.length)
            {
                this.buffer ~= left;
            }
        }
        else
        {
            this.flushBuffer();
            super.send(data);
        }

        return this;
    }

    /**************************************************************************

        Flushes the buffer. Pending data may not be sent immediately, for
        example, if the TCP_CORK feature is enabled in the super class.

     **************************************************************************/

    private void flushBuffer ( )
    {
        super.send(this.buffer.dump());
    }
}
