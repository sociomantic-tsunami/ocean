/*******************************************************************************

        Copyright:
            Copyright (c) 2004 Kris Bell.
            Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version:
            Mar 2004: Initial release$(BR)
            Dec 2006: Outback release

        Authors: Kris

*******************************************************************************/

module ocean.io.device.Array;

import ocean.meta.types.Qualifiers;

import ocean.core.Verify;

import ocean.core.ExceptionDefinitions;

import ocean.io.device.Conduit;

/******************************************************************************

******************************************************************************/

extern (C)
{
        protected void * memcpy (void *dst, const(void)* src, size_t);
}

/*******************************************************************************

        Array manipulation typically involves appending, as in the
        following example:
        ---
        // create a small buffer
        auto buf = new Array (256);

        auto foo = "to write some D";

        // append some text directly to it
        buf.append ("now is the time for all good men ").append(foo);
        ---

        Alternatively, one might use a formatter to append content:
        ---
        auto output = new TextOutput (new Array(256));
        output.format ("now is the time for {} good men {}", 3, foo);
        ---

        A slice() method returns all valid content within the array.

*******************************************************************************/

class Array : Conduit, InputBuffer, OutputBuffer, Conduit.Seek
{
        private void[]  data;                   // the raw data buffer
        private size_t  index;                  // current read position
        private size_t  extent;                 // limit of valid content
        private size_t  dimension;              // maximum extent of content
        private size_t  expansion;              // for growing instances

        private static string overflow  = "output buffer is full";
        private static string underflow = "input buffer is empty";
        private static string eofRead   = "end-of-flow while reading";
        private static string eofWrite  = "end-of-flow while writing";

        /***********************************************************************

                Ensure the buffer remains valid between method calls.

        ***********************************************************************/

        invariant()
        {
                assert (index <= extent);
                assert (extent <= dimension);
        }

        /***********************************************************************

                Construct a buffer.

                Params:
                capacity = The number of bytes to make available.
                growing  = Chunk size of a growable instance, or zero
                           to prohibit expansion.

                Remarks:
                Construct a Buffer with the specified number of bytes
                and expansion policy.

        ***********************************************************************/

        this (size_t capacity, size_t growing = 0)
        {
                assign (new ubyte[capacity], 0);
                expansion = growing;
        }

        /***********************************************************************

                Construct a buffer.

                Params:
                data = The backing array to buffer within.

                Remarks:
                Prime a buffer with an application-supplied array. All content
                is considered valid for reading, and thus there is no writable
                space initially available.

        ***********************************************************************/

        this (void[] data)
        {
                assign (data, data.length);
        }

        /***********************************************************************

                Construct a buffer.

                Params:
                data =     The backing array to buffer within.
                readable = The number of bytes initially made
                           readable.

                Remarks:
                Prime buffer with an application-supplied array, and
                indicate how much readable data is already there. A
                write operation will begin writing immediately after
                the existing readable content.

                This is commonly used to attach a Buffer instance to
                a local array.

        ***********************************************************************/

        this (void[] data, size_t readable)
        {
                assign (data, readable);
        }

        /***********************************************************************

                Return the name of this conduit.

        ***********************************************************************/

        final override string toString ()
        {
                return "<array>";
        }

        /***********************************************************************

                Transfer content into the provided dst.

                Params:
                dst = Destination of the content.

                Returns:
                Return the number of bytes read, which may be less than
                dst.length. Eof is returned when no further content is
                available.

                Remarks:
                Populates the provided array with content. We try to
                satisfy the request from the buffer content, and read
                directly from an attached conduit when the buffer is
                empty.

        ***********************************************************************/

        final override size_t read (void[] dst)
        {
                auto content = readable;
                if (content)
                   {
                   if (content >= dst.length)
                       content = dst.length;

                   // transfer buffer content
                   dst [0 .. content] = data [index .. index + content];
                   index += content;
                   }
                else
                   content = IConduit.Eof;
                return content;
        }

        /***********************************************************************

                Emulate OutputStream.write().

                Params:
                src = The content to write.

                Returns:
                Return the number of bytes written, which may be less than
                provided (conceptually). Returns Eof when the buffer becomes
                full.

                Remarks:
                Appends src content to the buffer, expanding as required if
                configured to do so (via the ctor).

        ***********************************************************************/

        final override size_t write (const(void)[] src)
        {
                auto len = src.length;
                if (len)
                   {
                   if (len > writable)
                       if (expand(len) < len)
                           return Eof;

                   // content may overlap ...
                   memcpy (&data[extent], src.ptr, len);
                   extent += len;
                   }
                return len;
        }

        /***********************************************************************

                Return a preferred size for buffering conduit I/O.

        ***********************************************************************/

        final override size_t bufferSize ()
        {
                return data.length;
        }

        /***********************************************************************

                Release external resources.

        ***********************************************************************/

        override void detach ()
        {
        }

        /***********************************************************************

                Seek within the constraints of assigned content.

        ***********************************************************************/

        override long seek (long offset, Anchor anchor = Anchor.Begin)
        {
                if (offset > cast(long) limit)
                    offset = limit;

                switch (anchor)
                       {
                       case Anchor.End:
                            index = cast(size_t) (limit - offset);
                            break;

                       case Anchor.Begin:
                            index = cast(size_t) offset;
                            break;

                       case Anchor.Current:
                            long o = cast(size_t) (index + offset);
                            if (o < 0)
                                o = 0;
                            if (o > cast(long) limit)
                                o = limit;
                            index = cast(size_t) o;
                            goto default;
                       default:
                            break;
                       }
                return index;
        }

        /***********************************************************************

                Reset the buffer content.

                Params:
                data =  The backing array to buffer within. All content
                        is considered valid.

                Returns:
                The buffer instance.

                Remarks:
                Set the backing array with all content readable.

        ***********************************************************************/

        Array assign (void[] data)
        {
                return assign (data, data.length);
        }

        /***********************************************************************

                Reset the buffer content

                Params:
                data     = The backing array to buffer within.
                readable = The number of bytes within data considered
                           valid.

                Returns:
                The buffer instance.

                Remarks:
                Set the backing array with some content readable. Use clear()
                to reset the content (make it all writable).

        ***********************************************************************/

        Array assign (void[] data, size_t readable)
        {
                this.data = data;
                this.extent = readable;
                this.dimension = data.length;

                // reset to start of input
                this.expansion = 0;
                this.index = 0;
                return this;
        }

        /***********************************************************************

                Access buffer content.

                Remarks:
                Return the entire backing array.

        ***********************************************************************/

        final void[] assign ()
        {
                return data;
        }

        /***********************************************************************

                Return a void[] read of the buffer from start to end, where
                end is exclusive.

        ***********************************************************************/

        final void[] opSlice (size_t start, size_t end)
        {
                verify(start <= extent && end <= extent && start <= end);
                return data [start .. end];
        }

        /***********************************************************************

                Retrieve all readable content.

                Returns:
                A void[] read of the buffer.

                Remarks:
                Return a void[] read of the buffer, from the current position
                up to the limit of valid content. The content remains in the
                buffer for future extraction.

        ***********************************************************************/

        final void[] slice ()
        {
                return data [index .. extent];
        }

        /***********************************************************************

                Access buffer content.

                Params:
                size = Number of bytes to access.
                eat =  Whether to consume the content or not.

                Returns:
                The corresponding buffer slice when successful, or
                null if there's not enough data available (Eof; Eob).

                Remarks:
                Slices readable data. The specified number of bytes is
                readd from the buffer, and marked as having been read
                when the 'eat' parameter is set true. When 'eat' is set
                false, the read position is not adjusted.

                Note that the slice cannot be larger than the size of
                the buffer ~ use method read(void[]) instead where you
                simply want the content copied.

                Note also that the slice should be .dup'd if you wish to
                retain it.

                Examples:
                ---
                // create a buffer with some content
                auto buffer = new Buffer ("hello world");

                // consume everything unread
                auto slice = buffer.slice (buffer.readable);
                ---

        ***********************************************************************/

        final void[] slice (size_t size, bool eat = true)
        {
                if (size > readable)
                    error (underflow);

                auto i = index;
                if (eat)
                    index += size;
                return data [i .. i + size];
        }

        /***********************************************************************

                Append content.

                Params:
                src = The content to _append.

                Returns:
                A chaining reference if all content was written.
                Throws an IOException indicating eof or eob if not.

                Remarks:
                Append an array to this buffer.

        ***********************************************************************/

        final Array append (const(void)[] src)
        {
                if (write(src) is Eof)
                    error (overflow);
                return this;
        }

        /***********************************************************************

                Iterator support.

                Params:
                scan = The delagate to invoke with the current content

                Returns:
                Returns true if a token was isolated, false otherwise.

                Remarks:
                Upon success, the delegate should return the byte-based
                index of the consumed pattern (tail end of it). Failure
                to match a pattern should be indicated by returning an
                IConduit.Eof.

                Note that additional iterator and/or reader instances
                will operate in lockstep when bound to a common buffer.

        ***********************************************************************/

        final bool next (scope size_t delegate (const(void)[]) scan)
        {
                return reader (scan) != IConduit.Eof;
        }

        /***********************************************************************

                Available content.

                Remarks:
                Return count of _readable bytes remaining in buffer. This is
                calculated simply as limit() - position().

        ***********************************************************************/

        final size_t readable ()
        {
                return extent - index;
        }

        /***********************************************************************

                Available space.

                Remarks:
                Return count of _writable bytes available in buffer. This is
                calculated simply as capacity() - limit().

        ***********************************************************************/

        final size_t writable ()
        {
                return dimension - extent;
        }

        /***********************************************************************

                Access buffer limit.

                Returns:
                Returns the limit of readable content within this buffer.

                Remarks:
                Each buffer has a capacity, a limit, and a position. The
                capacity is the maximum content a buffer can contain, limit
                represents the extent of valid content, and position marks
                the current read location.

        ***********************************************************************/

        final size_t limit ()
        {
                return extent;
        }

        /***********************************************************************

                Access buffer capacity.

                Returns:
                Returns the maximum capacity of this buffer.

                Remarks:
                Each buffer has a capacity, a limit, and a position. The
                capacity is the maximum content a buffer can contain, limit
                represents the extent of valid content, and position marks
                the current read location.

        ***********************************************************************/

        final size_t capacity ()
        {
                return dimension;
        }

        /***********************************************************************

                Access buffer read position.

                Returns:
                Returns the current read-position within this buffer

                Remarks:
                Each buffer has a capacity, a limit, and a position. The
                capacity is the maximum content a buffer can contain, limit
                represents the extent of valid content, and position marks
                the current read location.

        ***********************************************************************/

        final size_t position ()
        {
                return index;
        }

        /***********************************************************************

                Clear array content.

                Remarks:
                Reset 'position' and 'limit' to zero. This effectively
                clears all content from the array.

        ***********************************************************************/

        final Array clear ()
        {
                index = extent = 0;
                return this;
        }

        /***********************************************************************

                Emit/purge buffered content.

        ***********************************************************************/

        final override Array flush ()
        {
                return this;
        }

        /***********************************************************************

                Write into this buffer.

                Params:
                dg = The callback to provide buffer access to.

                Returns:
                Returns whatever the delegate returns.

                Remarks:
                Exposes the raw data buffer at the current _write position,
                The delegate is provided with a void[] representing space
                available within the buffer at the current _write position.

                The delegate should return the appropriate number of bytes
                if it writes valid content, or IConduit.Eof on error.

        ***********************************************************************/

        final size_t writer (scope size_t delegate (void[]) dg)
        {
                auto count = dg (data [extent..dimension]);

                if (count != IConduit.Eof)
                   {
                   extent += count;
                   verify(extent <= dimension);
                   }
                return count;
        }

        /***********************************************************************

                Read directly from this buffer.

                Params:
                dg = Callback to provide buffer access to.

                Returns:
                Returns whatever the delegate returns.

                Remarks:
                Exposes the raw data buffer at the current _read position. The
                delegate is provided with a void[] representing the available
                data, and should return zero to leave the current _read position
                intact.

                If the delegate consumes data, it should return the number of
                bytes consumed; or IConduit.Eof to indicate an error.

        ***********************************************************************/

        final size_t reader (scope size_t delegate (const(void)[]) dg)
        {
                auto count = dg (data [index..extent]);

                if (count != IConduit.Eof)
                   {
                   index += count;
                   verify(index <= extent);
                   }
                return count;
        }

        /***********************************************************************

                Expand existing buffer space.

                Returns:
                Available space, without any expansion.

                Remarks:
                Make some additional room in the buffer, of at least the
                given size. Should not be public in order to avoid issues
                with non-growable subclasses.

        ***********************************************************************/

        private final size_t expand (size_t size)
        {
                if (expansion)
                   {
                   if (size < expansion)
                       size = expansion;
                   dimension += size;
                   data.length = dimension;
                   }
                return writable;
        }

        /***********************************************************************

                Cast to a target type without invoking the wrath of the
                runtime checks for misalignment. Instead, we truncate the
                array length.

        ***********************************************************************/

        private static T[] convert(T)(void[] x)
        {
                return (cast(T*) x.ptr) [0 .. (x.length / T.sizeof)];
        }
}


/******************************************************************************

******************************************************************************/

debug (Array)
{
        import ocean.io.Stdout;

        void main()
        {
                auto b = new Array(6, 10);
                b.seek (0);
                b.write ("fubar");

                Stdout.formatln ("extent {}, pos {}, read {}, bufsize {}",
                                  b.limit, b.position, cast(char[]) b.slice, b.bufferSize);

                b.write ("fubar");
                Stdout.formatln ("extent {}, pos {}, read {}, bufsize {}",
                                  b.limit, b.position, cast(char[]) b.slice, b.bufferSize);
        }
}
