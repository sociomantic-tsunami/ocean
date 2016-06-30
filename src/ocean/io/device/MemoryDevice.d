/*******************************************************************************

    Simulates a device that you can write to and read from, behaves pretty much
    like a file

    This was created as an alternative to ocean.io.device.Array, whose write()
    function has the unreasonable limitation of always appending instead of
    respecting the current seek position and thus not properly simulating a file

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.device.MemoryDevice;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;
import ocean.io.model.IConduit;
import ocean.stdc.string : memmove;

/*******************************************************************************

    Simulates a device that you can write to and read from, behaves pretty much
    like a file

*******************************************************************************/

class MemoryDevice : IConduit
{
    /***************************************************************************

        Buffer to keep the data

    ***************************************************************************/

    private ubyte[] data;

    /***************************************************************************

        Current read/write position

    ***************************************************************************/

    private size_t position;

    /***************************************************************************

        Returns:
            Return the current size of the buffer

    ***************************************************************************/

    override size_t bufferSize ( )
    {
        return data.length;
    }

    /***************************************************************************

        Returns:
            Current buffer as string

    ***************************************************************************/

    public Const!(void)[] peek ()
    {
        return data;
    }

    /***************************************************************************

        Returns:
            Name of this IConduit

    ***************************************************************************/

    override istring toString ( )
    {
        return MemoryDevice.stringof;
    }

    /***************************************************************************

        Implemented because interfaces demand it, returns always true

    ***************************************************************************/

    override bool isAlive ( )
    {
        return true;
    }

    /***************************************************************************

        Implemented because interfaces demand it, does nothing

    ***************************************************************************/

    override void detach ( ) {}

    /***************************************************************************

        Throws an exception

        Params:
            msg = message to use in the exception

    ***************************************************************************/

    override void error ( istring msg )
    {
        throw new Exception ( msg );
    }

    /***************************************************************************

        Write into this device, starting at the current seek position

        Params:
            src = data to write

        Returns:
            amount of written data, always src.length

    ***************************************************************************/

    override size_t write ( Const!(void)[] src )
    {
        if ( this.position + src.length > this.data.length )
        {
            this.data.length = this.position + src.length;
        }

        memmove(&this.data[this.position], src.ptr, src.length);

        this.position += src.length;

        return src.length;
    }

    /***************************************************************************

        Copies src into this stream, overwriting any existing data

        Params:
            src = stream to copy from
            max = amount of bytes to copy, -1 means infinite

        Returns:
            this class for chaining

    ***************************************************************************/

    override OutputStream copy ( InputStream src, size_t max = -1 )
    {
        size_t len;

        if ( max == -1 )
        {
            len = max > this.data.length ? this.data.length : max;
        }
        else
        {
            len = this.data.length;
        }

        this.position = 0;

        auto new_data = src.load();

        this.data.length = new_data.length;
        this.data[] = cast(ubyte[])new_data[];

        return this;
    }

    /***************************************************************************

        Returns:
            the stream this stream writes to, which is none, so always null

    ***************************************************************************/

    override OutputStream output ( )
    {
        return null;
    }

    /***************************************************************************

        Reads into dst, starting to read from the current seek position

        Params:
            dst = array to read into

        Returns:
            Eof (and no action) if current seek position is at the end of the
            buffer,
            Else the amount of bytes read.

    ***************************************************************************/

    override size_t read ( void[] dst )
    {
        if ( this.position < this.data.length )
        {
            auto end_pos = this.position + dst.length > this.data.length ?
                                this.data.length : this.position + dst.length;

            dst[0..end_pos-this.position] = this.data[this.position .. end_pos];

            scope(exit) this.position = end_pos;

            return end_pos - this.position;
        }
        else
        {
            return IConduit.Eof;
        }
    }

    /***************************************************************************

        Params:
            max = maximum amount of bytes to return

        Returns:
            slice to the internal buffer up to max bytes (-1 means infinite,
            thus the whole buffer)

    ***************************************************************************/

    override void[] load ( size_t max = -1 )
    {
        size_t len;

        if ( max == -1 )
        {
            len = max > this.data.length ? this.data.length : max;
        }
        else
        {
            len = this.data.length;
        }

        return this.data[0..len];
    }

    /***************************************************************************

        Returns:
            This streams input stream, alas this stream has no input stream,
            so null

    ***************************************************************************/

    override InputStream input ( )
    {
        return null;
    }

    /***************************************************************************

        Change the internal seeker position

        Params:
            offset = amount of bytes to add to the anchor to seek the new
                     position
            anchor = specifies which point should be used as basis for the
                     offset

        Returns:
            the new seeker position

    ***************************************************************************/

    override long seek ( long offset, Anchor anchor = Anchor.Begin )
    {
        with ( Anchor ) switch ( anchor )
        {
            case Begin:
                break;
            case Current:
                offset = this.position + offset;
                break;
            case End:
                offset = this.data.length + offset;
                break;
            default:
                assert(false);
        }

        if ( offset > this.data.length )
        {
            return this.position = this.data.length;
        }

        return this.position = offset;
    }

    /***************************************************************************

        Used by FormatOutput and other streams.

    ***************************************************************************/

    override IConduit conduit ()
    {
        return this;
    }

    /***************************************************************************

        Does nothing

    ***************************************************************************/

    override IOStream flush ( )
    {
        return this;
    }

    /***************************************************************************

        Deletes the buffer and resets position

    ***************************************************************************/

    override void close ( )
    {
        delete this.data;
        this.data = null;
        this.position = 0;
    }
}

version ( UnitTest )
{
    import ocean.core.Test;
}

unittest
{
    auto m = new MemoryDevice;

    auto data = "This is a string";

    auto dst = new void[data.length];

    test!("==")(m.position, 0);
    m.write(data);
    test(m.data == cast(ubyte[])data);
    test!("==")(m.position, data.length);

    m.seek(0);
    m.read(dst);
    test(dst == data);
    test!("==")(m.position, data.length);

    m.seek(0);
    m.write(data);
    test(m.data == cast(ubyte[])data);
    test!("==")(m.position, data.length);
}
