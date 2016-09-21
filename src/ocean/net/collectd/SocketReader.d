/*******************************************************************************

    Input range that will read data from a socket and return token-separated
    values. The token will be excluded.

    This struct is an implementation detail of the Collectd socket and not
    intended to be used outside of it.

    Copyright:
        Copyright (c) 2015-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.net.collectd.SocketReader;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;
import ocean.stdc.posix.sys.types; // ssize_t
import ocean.sys.ErrnoException;
import ocean.sys.socket.model.ISocket;
import ocean.text.util.StringSearch; // locateChar


/*******************************************************************************

    Input range that will read data from a socket and return token-separated
    values. The token will be excluded.

    This struct is allocation-free as it acts as a (specialized) circular buffer.

    Params:
        MAX_FIELD_SIZE  = Maximum length a line can have.
                          As lines can be non-contiguous (if a line starts at
                          the end of the circular buffer and ends at the
                          beginning of it), but we need to provide them
                          contiguous to the reader, a buffer is used and
                          written to in this situation.
        FIELDS          = The maximum number of maximum length fields that
                          the buffer can store.
                          In other words, MAX_FIELD_SIZE * FIELDS == capacity.

*******************************************************************************/

package struct SocketReader (size_t MAX_FIELD_SIZE = 512, size_t FIELDS = 16)
{
    /***************************************************************************

        Get the current element

        The returned data is transient, which means it might get invalidated
        by the next call to popFront or when the range is finalized. Make sure
        to `.dup` it if you need a longer lifetime.

        Returns:
            A transient string to the current item. This will be `null` if
            this range is `empty`.

    ***************************************************************************/

    public cstring front ()
    {
        return this.current_field;
    }


    /***************************************************************************

        Discard the current item (`front`) and process the next field

        This will change the current front. If not enough data is available,
        and a non-null socket is provided, it will attempt to read as much as
        possible data from this socket.

        Params:
            socket = If non null, instead of becoming empty, popFront will
                        attempt to read data from the socket
            flags  = Flags to pass to recv in the event of a read from socket

        Returns:
            The amount of data read from the network, if any (recv return value)

        Throws:
            `ErrnoException` if `recv` returned a negative value

    ***************************************************************************/

    public ssize_t popFront (ISocket socket = null, int flags = 0)
    {
        auto off = this.locateChar('\n');

        if (off != this.length)
        {
            // Worst case scenario: the field starts at the end of the buffer
            // and continues at the beginning. In this case, we have no choice
            // but to copy data to our field_buffer to get something sane.
            if (this.start_idx + off > this.buffer.length)
            {
                auto p1len = this.buffer.length - this.start_idx;
                assert(p1len < off);

                this.field_buffer[0 .. p1len]
                    = this.buffer[this.start_idx .. this.buffer.length];

                this.field_buffer[p1len .. off] = this.buffer[0 .. off - p1len];

                this.current_field = this.field_buffer[0 .. off];
            }
            else
            {
                // Usual case: We just return a slice to our buffer
                this.current_field = this.buffer[this.start_idx .. this.start_idx + off];
            }
            this.length -= (off + 1);
            this.start_idx = !this.length ? 0 : this.calc(this.start_idx, off + 1);
        }
        else if (socket !is null)
        {
            auto r = this.recv(socket, flags);
            if (r <= 0)
            {
                this.current_field = null;
                throw this.e.useGlobalErrno("recv");
            }
            this.popFront(socket, flags);
        }
        else
        {
            this.current_field = null;
        }
        return 0;
    }


    /***************************************************************************

        Tells whenever the range is empty (i.e. no more fields can be read)

        Note that empty doesn't mean that no more data is stored in the buffer,
        but rather mean no more delimiter (or token) could be found in the data

    ***************************************************************************/

    public bool empty ()
    {
        return this.current_field is null;
    }


    /***************************************************************************

        Read data from the socket

        This function is only called from popFront when a socket is provided.

        Params:
            socket = An ISocket to read from
            flags  = flags to pass to `ISocket.recv`

        Returns:
            The return value of `ISocket.recv`, which is the quantity of bytes
            read.

    ***************************************************************************/

    private ssize_t recv (ISocket socket, int flags)
    in
    {
        assert(socket !is null, "Cannot recv with a null socket");
    }
    body
    {
        auto start = this.calc(this.start_idx, this.length);
        auto end   = start < this.start_idx ? this.start_idx : this.buffer.length;

        ssize_t ret = socket.recv(this.buffer[start .. end], flags);

        // Errors are handled from popFront
        if (ret <= 0)
            return ret;

        this.length += ret;
        assert(this.length <= this.buffer.length);

        return ret;
    }


    /***************************************************************************

        Tell whenever the current data in the buffer are linear, or extend
        past the end of the buffer and circle to the beginning

    ***************************************************************************/

    private bool isLinear ()
    {
        return !(this.start_idx + this.length > this.buffer.length);
    }


    /***************************************************************************

        Helper function for locateChar

        Returns:
            An end suitable for 'linear' reading of the buffer, that is,
            an end which is always > this.start_idx

    ***************************************************************************/

    private size_t linearEnd ()
    {
        return this.isLinear()
            ? (this.start_idx + this.length)
            : (this.buffer.length);
    }


    /**************************************************************************
*
        Returns: the maximum amount of data we can read

    ***************************************************************************/

    private size_t linearSpace ()
    {
        return this.isLinear()
            ? (this.buffer.length - this.calc(this.start_idx, this.length))
            : (this.start_idx - this.calc(this.start_idx, this.length));
    }


    /***************************************************************************

        Find the next occurence of 'tok' in the string in a non-linear way

        Params:
            tok = a token (character) to search from, starting from start_idx

        Returns:
            The offset to `start_idx` (linear offset) at which the token is,
            or `this.length` if it wasn't found

    ***************************************************************************/

    private size_t locateChar (char tok)
    {
        auto after = StringSearch!(false).locateChar(
            this.buffer[this.start_idx .. this.linearEnd()], tok);
        if (this.isLinear() || this.start_idx  + after < this.buffer.length)
        {
            return after;
        }
        // In this case, after ==> buffer.length - start_idx
        return after + StringSearch!(false).locateChar(
            this.buffer[0 .. this.length - after],
            tok);
    }


    /***************************************************************************

        Helper function to calculate index in the buffer from offsets

        Params:
            idx = The index to start from
            val = The offset to add

        Returns:
            An index in `this.buffer`. It is always in-bound.

    ***************************************************************************/

    private size_t calc (size_t idx, size_t val)
    {
        return (idx + val) % this.buffer.length;
    }


    /***************************************************************************

        Buffer in which the data will be stored

    ***************************************************************************/

    private char[MAX_FIELD_SIZE * FIELDS] buffer;


    /***************************************************************************

        Internal buffer in which the current line will be copied in the event
        of a line being non-linear (starts at the end of the buffer and
        continue at the beggining).

    ***************************************************************************/

    private char[MAX_FIELD_SIZE] field_buffer;


    /***************************************************************************

        A slice to the data currently being the `front()`

    ***************************************************************************/

    private cstring current_field;


    /***************************************************************************

        Unprocessed data start

    ***************************************************************************/

    private size_t start_idx;


    /***************************************************************************

        Unprocessed data length

    ***************************************************************************/

    private size_t length;


    /***************************************************************************

        Exception to throw on error

        Note:
            It is set from outside, hence the package visibility.

    ***************************************************************************/

    package ErrnoException e;
}

unittest
{
    // Ensure it compiles
    SocketReader!() reader;
}
