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

        Authors: Kris Bell

*******************************************************************************/

module ocean.io.stream.Buffered;

import core.stdc.string;

import ocean.transition;
version (UnitTest)  import ocean.core.Test;
import ocean.core.Verify;

public import ocean.io.model.IConduit;

import ocean.io.device.Conduit;
version (UnitTest) import ocean.io.device.MemoryDevice;


/// Shorthand aliases
public alias BufferedInput  Bin;
/// ditto
public alias BufferedOutput Bout;


/*******************************************************************************

    Buffers the flow of data from a upstream input

    A downstream neighbour can locate and use this buffer instead of creating
    another instance of their own.

    Note:
        upstream is closer to the source, and downstream is further away

*******************************************************************************/

public class BufferedInput : InputFilter, InputBuffer
{
    /// Clear/flush are the same
    public alias flush             clear;
    /// Access the source.
    public alias InputFilter.input input;

    private void[]        data;             // The raw data buffer.
    private size_t        index;            // Current read position.
    private size_t        extent;           // Limit of valid content.

    invariant ()
    {
        assert(this.index <= this.extent);
        assert(this.extent <= this.data.length);
    }

    /***************************************************************************

        Construct a buffer.

        Construct a Buffer upon the provided input stream.

        Params:
            stream = An input stream.

    ***************************************************************************/

    public this (InputStream stream)
    {
        verify(stream !is null);
        this(stream, stream.conduit.bufferSize);
    }

    /***************************************************************************

        Construct a buffer.

        Construct a Buffer upon the provided input stream.

        Params:
            stream = An input stream.
            capacity = Desired buffer capacity.

    ***************************************************************************/

    public this (InputStream stream, size_t capacity)
    {
        this.set(new ubyte[capacity], 0);
        super(this.source = stream);
    }

    /***************************************************************************

        Attempt to share an upstream Buffer, and create an instance
        where there's not one available.

        If an upstream Buffer instances is visible, it will be shared.
        Otherwise, a new instance is created based upon the bufferSize
        exposed by the stream endpoint (conduit).

        Params:
            stream = An input stream.

    ***************************************************************************/

    public static InputBuffer create (InputStream stream)
    {
        auto source = stream;
        auto conduit = source.conduit;
        while (cast(Mutator) source is null)
        {
            auto b = cast(InputBuffer) source;
            if (b)
                return b;
            if (source is conduit)
                break;
            source = source.input;
            verify(source !is null);
        }

        return new BufferedInput(stream, conduit.bufferSize);
    }

    /***************************************************************************

        Place more data from the source stream into this buffer, and returns
        the number of bytes added.

        This does not compress the current buffer content, so consider doing
        that explicitly.

        Returns:
            Number of bytes added, which will be Eof when there is no further
            input available.
            Zero is also a valid response, meaning no data was actually added.

    ***************************************************************************/

    public final size_t populate ()
    {
        return this.writer(&this.input.read);
    }

    /***************************************************************************

        Returns:
            a void[] slice of the buffer from start to end,
            where end is exclusive.

    ***************************************************************************/

    public final void[] opSlice (size_t start, size_t end)
    {
        verify(start <= this.extent && end <= this.extent && start <= end);
        return this.data[start .. end];
    }

    /***************************************************************************

        Retrieve the valid content.

        Returns:
            A void[] slice of the buffer, from the current position up to
            the limit of valid content.
            The content remains in the buffer for future extraction.

    ***************************************************************************/

    public final void[] slice ()
    {
        return  this.data[this.index .. this.extent];
    }

    /***************************************************************************

        Access buffer content.

        Read a slice of data from the buffer, loading from the
        conduit as necessary. The specified number of bytes is
        sliced from the buffer, and marked as having been read
        when the 'eat' parameter is set true. When 'eat' is set
        false, the read position is not adjusted.

        The slice cannot be larger than the size of the buffer: use method
        `fill(void[])` instead where you simply want the content copied,
        or use `conduit.read()` to extract directly from an attached conduit
        Also if you need to retain the slice, then it should be `.dup`'d
        before the buffer is compressed or repopulated.

        Params:
            size =  Number of bytes to access.
            eat =   Whether to consume the content or not.

        Returns:
            The corresponding buffer slice when successful, or
            null if there's not enough data available (Eof; Eob).

        Examples:
        ---
            // create a buffer with some content
            auto buffer = new Buffer("hello world");

            // consume everything unread
            auto slice = buffer.slice(buffer.this.readable());
        ---

    ***************************************************************************/

    public final void[] slice (size_t size, bool eat = true)
    {
        if (size > this.readable())
        {
            // make some space? This will try to leave as much content
            // in the buffer as possible, such that entire records may
            // be aliased directly from within.
            if (size > (this.data.length - this.index))
            {
                if (size <= this.data.length)
                    this.compress();
                else
                    this.conduit.error("input buffer is empty");
            }

            // populate tail of buffer with new content
            do {
                if (this.writer(&this.source.read) is Eof)
                    this.conduit.error("end-of-flow whilst reading");
            } while (size > this.readable());
        }

        auto i = this.index;
        if (eat)
            this.index += size;
        return this.data[i .. i + size];
    }

    /***************************************************************************

        Read directly from this buffer.

        Exposes the raw data buffer at the current _read position.
        The delegate is provided with a void[] representing the available
        data, and should return zero to leave the current _read position
        intact.

        If the delegate consumes data, it should return the number of
        bytes consumed; or IConduit.Eof to indicate an error.

        Params:
            dg = Callback to provide buffer access to.

        Returns:
            the delegate's return value

    ***************************************************************************/

    public final size_t reader (scope size_t delegate (Const!(void)[]) dg)
    {
        auto count = dg(this.data[this.index .. this.extent]);

        if (count != Eof)
        {
            this.index += count;
            verify(this.index <= this.extent);
        }
        return count;
    }

    /***************************************************************************

        Write into this buffer.

        Exposes the raw data buffer at the current _write position,
        The delegate is provided with a void[] representing space
        available within the buffer at the current _write position.

        The delegate should return the appropriate number of bytes
        if it writes valid content, or IConduit.Eof on error.

        Params:
            dg = The callback to provide buffer access to.

        Returns:
            the delegate return's value.

    ***************************************************************************/

    public size_t writer (scope size_t delegate (void[]) dg)
    {
        auto count = dg(this.data[this.extent .. $]);

        if (count != Eof)
        {
            this.extent += count;
            verify(this.extent <= this.data.length);
        }
        return count;
    }

    /***************************************************************************

        Transfer content into the provided dst.

        Populates the provided array with content. We try to
        satisfy the request from the buffer content, and read
        directly from an attached conduit when the buffer is empty.

        Params:
            dst = Destination of the content.

        Returns:
            the number of bytes read, which may be less than `dst.length`.
            Eof is returned when no further content is available.

    ***************************************************************************/

    public final override size_t read (void[] dst)
    {
        size_t content = this.readable;
        if (content)
        {
            if (content >= dst.length)
                content = dst.length;

            // transfer buffer content
            dst[0 .. content] = this.data[this.index .. this.index + content];
            this.index += content;
        }
        // pathological cases read directly from conduit
        else if (dst.length > this.data.length)
            content = this.source.read(dst);
        else
        {
            if (this.writable is 0)
                this.index = this.extent = 0;  // same as clear, without call-chain

            // keep buffer partially populated
            if ((content = this.writer(&this.source.read)) != Eof && content > 0)
                content = this.read(dst);
        }
        return content;
    }

    /**************************************************************************

        Fill the provided buffer

        Returns:
            the number of bytes actually read, which will be less than
            `dst.length` when Eof has been reached and Eof thereafter.

        Params:
            dst = Where data should be placed.
            exact = Whether to throw an exception when dst is not
                    filled (an Eof occurs first). Defaults to false.

    **************************************************************************/

    public final size_t fill (void[] dst, bool exact = false)
    {
        size_t len = 0;

        while (len < dst.length)
        {
            size_t i = this.read(dst[len .. $]);
            if (i is Eof)
            {
                if (exact && len < dst.length)
                    this.conduit.error("end-of-flow whilst reading");
                return (len > 0) ? len : Eof;
            }
            len += i;
        }
        return len;
    }

    /***************************************************************************

        Move the current read location.

        Skips ahead by the specified number of bytes, streaming from
        the associated conduit as necessary.

        Can also reverse the read position by 'size' bytes, when size
        is negative. This may be used to support lookahead operations.
        Note that a negative size will fail where there is not sufficient
        content available in the buffer (can't _skip beyond the beginning).

        Params:
            size = The number of bytes to move.

        Returns:
            `true` if successful, `false` otherwise.

    ***************************************************************************/

    public final bool skip (int size)
    {
        if (size < 0)
        {
            size = -size;
            if (this.index >= size)
            {
                this.index -= size;
                return true;
            }
            return false;
        }
        return this.slice(size) !is null;
    }

    /***************************************************************************

        Move the current read location.

    ***************************************************************************/

    public final override long seek (long offset, Anchor start = Anchor.Begin)
    {
        if (start is Anchor.Current)
        {
            // handle this specially because we know this is
            // buffered - we should take into account the buffer
            // position when seeking
            offset -= this.readable;
            auto bpos = offset + this.limit;

            if (bpos >= 0 && bpos < this.limit)
            {
                // the new position is within the current
                // buffer, skip to that position.
                this.skip(cast(int) bpos - cast(int) position);

                // see if we can return a valid offset
                auto pos = this.source.seek(0, Anchor.Current);
                if (pos != Eof)
                    return pos - this.readable();
                return Eof;
            }
            // else, position is outside the buffer. Do a real
            // seek using the adjusted position.
        }

        this.clear();
        return this.source.seek(offset, start);
    }

    /***************************************************************************

        Iterator support.

        Upon success, the delegate should return the byte-based index of
        the consumed pattern (tail end of it).
        Failure to match a pattern should be indicated by returning an Eof

        Each pattern is expected to be stripped of the delimiter.
        An end-of-file condition causes trailing content to be
        placed into the token. Requests made beyond Eof result
        in empty matches (length is zero).

        Additional iterator and/or reader instances
        will operate in lockstep when bound to a common buffer.

        Params:
            scan = The delegate to invoke with the current content.

        Returns:
            `true` if a token was isolated, `false` otherwise.

    ***************************************************************************/

    public final bool next (scope size_t delegate (Const!(void)[]) scan)
    {
        while (this.reader(scan) is Eof)
        {
            // did we start at the beginning?
            if (this.position)
                // yep - move partial token to start of buffer
                this.compress();
            // no more space in the buffer?
            else if (this.writable is 0)
                this.extend();

            verify(this.writable() > 0);

            // read another chunk of data
            if (this.writer(&this.source.read) is Eof)
                return false;
        }
        return true;
    }

    /***************************************************************************

        Reserve the specified space within the buffer, compressing
        existing content as necessary to make room.

        Returns:
            the current read point, after compression if that was required.

    ***************************************************************************/

    public final size_t reserve (size_t space)
    {
        verify(space < this.data.length);

        if ((this.data.length - this.index) < space)
            this.compress();
        return this.index;
    }

    /***************************************************************************

        Compress buffer space.

        Limit is set to the amount of data remaining.
        Position is always reset to zero.

        If we have some data left after an export, move it to the front of
        the buffer and set position to be just after the remains.
        This is for supporting certain conduits which choose to write just
        the initial portion of a request.

        Returns:
            The buffer instance.

    ***************************************************************************/

    public final BufferedInput compress ()
    {
        auto r = this.readable();

        if (this.index > 0 && r > 0)
            // content may overlap ...
            memmove(&data[0], &data[this.index], r);

        this.index = 0;
        this.extent = r;
        return this;
    }

    /***************************************************************************

        Drain buffer content to the specific conduit.

        Returns:
            the number of bytes written, or Eof.

        Note:
            Write as much of the buffer that the associated conduit can consume.
            The conduit is not obliged to consume all content,
            so some may remain within the buffer.

    ***************************************************************************/

    public final size_t drain (OutputStream dst)
    {
        verify(dst !is null);

        size_t ret = this.reader(&dst.write);
        this.compress();
        return ret;
    }

    /***************************************************************************

        Access buffer limit.

        Each buffer has a capacity, a limit, and a position.
        The capacity is the maximum content a buffer can contain,
        limit represents the extent of valid content, and position marks
        the current read location.

        Returns:
            the limit of readable content within this buffer.

    ***************************************************************************/

    public final size_t limit ()
    {
        return this.extent;
    }

   /***************************************************************************

        Access buffer capacity.

        Each buffer has a capacity, a limit, and a position.
        The capacity is the maximum content a buffer can contain, limit
        represents the extent of valid content, and position marks
        the current read location.

        Returns:
            the maximum capacity of this buffer.

   ***************************************************************************/

    public final size_t capacity ()
    {
        return this.data.length;
    }

    /***************************************************************************

        Access buffer read position.

        Each buffer has a capacity, a limit, and a position.
        The capacity is the maximum content a buffer can contain, limit
        represents the extent of valid content, and position marks
        the current read location.

        Returns:
            the current read-position within this buffer.

    ***************************************************************************/

    final size_t position ()
    {
        return this.index;
    }

    /***************************************************************************

        Available content.

        Returns:
            count of _readable bytes remaining in buffer.
            This is calculated simply as `this.limit() - this.position()`.

    ***************************************************************************/

    public final size_t readable ()
    {
        return this.extent - this.index;
    }

    /***************************************************************************

        Cast to a target type without invoking the wrath of the
        runtime checks for misalignment. Instead, we truncate the
        array length.

    ***************************************************************************/

    static Inout!(T)[] convert (T) (Inout!(void)[] x)
    {
        return (cast(Inout!(T)*) x.ptr) [0 .. (x.length / T.sizeof)];
    }

    /***************************************************************************

        Clear buffer content.

        Note:
            Reset 'position' and 'limit' to zero. This effectively
            clears all content from the buffer.

    ***************************************************************************/

    public final override BufferedInput flush ()
    {
        this.index = this.extent = 0;

        // clear the filter chain also
        if (this.source)
            super.flush();
        return this;
    }

    /***************************************************************************

        Set the input stream.

    ***************************************************************************/

    public final void input (InputStream source)
    {
        this.source = source;
    }

    /***************************************************************************

        Load the bits from a stream, up to an indicated length, and
        return them all in an array.

        The function may consume more than the indicated size where additional
        data is available during a block read operation, but will not wait for
        more than specified.
        An Eof terminates the operation.

        Returns:
            an array representing the content

        Throws:
            `IOException` on error.

    ***************************************************************************/

    public final override void[] load (size_t max = size_t.max)
    {
        this.load(super.input, super.conduit.bufferSize, max);
        return this.slice;
    }

    /***************************************************************************

        Import content from the specified conduit, expanding as necessary
        up to the indicated maximum or until an Eof occurs.

        Returns:
            the number of bytes contained.

    ***************************************************************************/

    private size_t load (InputStream src, size_t increment, size_t max)
    {
        size_t len, count;

        // make some room
        this.compress();

        // explicitly resize?
        if (max != max.max)
            if ((len = this.writable()) < max)
                increment = max - len;

        while (count < max)
        {
            if (!this.writable())
                this.data.length = (this.data.length + increment);
            if ((len = this.writer(&src.read)) is Eof)
                break;
            else
                count += len;
        }
        return count;
    }

    /***************************************************************************

        Reset the buffer content.

        Set the backing array with some content readable.
        Writing to this will either flush it to an associated conduit,
        or raise an Eof condition.
        Use clear() to reset the content (make it all writable).

        Params:
            data =     The backing array to buffer within.
            readable = The number of bytes within data considered valid.

        Returns:
            The buffer instance.

    ***************************************************************************/

    private final BufferedInput set (void[] data, size_t readable)
    {
        this.data = data;
        this.extent = readable;

        // reset to start of input
        this.index = 0;

        return this;
    }

    /***************************************************************************

        Available space.

        Returns:
            count of _writable bytes available in buffer.
            This is calculated simply as `this.capacity() - this.limit()`.

    ***************************************************************************/

    private final size_t writable ()
    {
        return this.data.length - this.extent;
    }

    /***************************************************************************

        Extend the buffer by half of its size

    ***************************************************************************/

    private void extend ()
    {
        this.data.length = this.data.length + (this.data.length / 2);
    }
}


/*******************************************************************************

    Buffers the flow of data from a upstream output.

    A downstream neighbour can locate and use this buffer instead of creating
    another instance of their own.

    Don't forget to flush() buffered content before closing.

    Note:
        upstream is closer to the source, and downstream is further away

*******************************************************************************/

public class BufferedOutput : OutputFilter, OutputBuffer
{
    /// access the sink
    alias OutputFilter.output output;

    private void[]        data;             // the raw data buffer
    private size_t        index;            // current read position
    private size_t        extent;           // limit of valid content
    private size_t        dimension;        // maximum extent of content

    /// Notifier that will be called on flush.
    private void delegate() flush_notifier;

    invariant ()
    {
        assert (this.index <= this.extent);
        assert (this.extent <= this.dimension);
    }

    /***************************************************************************

        Construct a Buffer upon the provided input stream.

        Params:
            stream = An input stream.
            flush_notifier = user specified delegate called after the content
                             of the buffer has been flushed to upstream output.

    ***************************************************************************/

    public this (OutputStream stream, scope void delegate() flush_notifier = null)
    {
        verify(stream !is null);
        this(stream, stream.conduit.bufferSize, flush_notifier);
    }

    /***************************************************************************

        Construct a Buffer upon the provided input stream.

        Params:
            stream = An input stream.
            capacity = Desired buffer capacity.
            flush_notifier = user specified delegate called after the content
                             of the buffer has been flushed to upstream output.

    ***************************************************************************/

    public this (OutputStream stream, size_t capacity,
                 scope void delegate() flush_notifier = null)
    {
        this.set(new ubyte[capacity], 0);
        this.flush_notifier = flush_notifier;
        super(this.sink = stream);
    }

    /***************************************************************************

        Attempts to share an upstream BufferedOutput, and creates a new
        instance where there's not a shared one available.

        Where an upstream instance is visible it will be returned.
        Otherwise, a new instance is created based upon the bufferSize
        exposed by the associated conduit

        Params:
            stream = An output stream.

    ***************************************************************************/

    public static OutputBuffer create (OutputStream stream)
    {
        auto sink = stream;
        auto conduit = sink.conduit;
        while (cast(Mutator) sink is null)
        {
            auto b = cast(OutputBuffer) sink;
            if (b)
                return b;
            if (sink is conduit)
                break;
            sink = sink.output;
            verify(sink !is null);
        }

        return new BufferedOutput(stream, conduit.bufferSize);
    }

    /***************************************************************************

        Retrieve the valid content.

        Returns:
            A void[] slice of the buffer.

        Returns:
            a slice of the buffer, from the current position up to the limit
            of valid content.
            The content remains in the buffer for future extraction.

    ***************************************************************************/

    public final void[] slice ()
    {
        return this.data[this.index .. this.extent];
    }

    /***************************************************************************

        Emulate OutputStream.write().

        Appends src content to the buffer, flushing to an attached conduit
        as necessary. An IOException is thrown upon write failure.

        Params:
            src = The content to write.

        Returns:
            the number of bytes written, which may be less than provided
            (conceptually).

    ***************************************************************************/

    public final override size_t write (Const!(void)[] src)
    {
        this.append(src.ptr, src.length);
        return src.length;
    }

    /***************************************************************************

        Append content.

        Append an array to this buffer, flush to the conduit as necessary.
        This is often used in lieu of a Writer.

        Params:
            src = The content to _append.

        Returns:
            a chaining reference if all content was written.

        Throws:
            an IOException indicating Eof or Eob if not.

    ***************************************************************************/

    public final BufferedOutput append (Const!(void)[] src)
    {
        return this.append(src.ptr, src.length);
    }

    /***************************************************************************

        Append content.

        Append an array to this buffer, flush to the conduit as necessary.
        This is often used in lieu of a Writer.

        Params:
            src = The content to _append.
            length = The number of bytes in src.

        Returns:
            a chaining reference if all content was written.

        Throws:
            an IOException indicating Eof or Eob if not.

    ***************************************************************************/

    public final BufferedOutput append (Const!(void)* src, size_t length)
    {
        if (length > this.writable)
        {
            this.flush();

            // check for pathological case
            if (length > this.dimension)
                do {
                    auto written = this.sink.write(src [0 .. length]);
                    if (written is Eof)
                        this.conduit.error("end-of-flow whilst writing");
                    length -= written;
                    src += written;
                } while (length > this.dimension);
        }

        // avoid "out of bounds" test on zero length
        if (length)
        {
            // content may overlap ...
            memmove(&this.data[this.extent], src, length);
            this.extent += length;
        }
        return this;
    }

    /***************************************************************************

        Available space.

        Returns:
            count of _writable bytes available in buffer.
            This is calculated as `capacity() - limit()`.

    ***************************************************************************/

    public final size_t writable ()
    {
        return this.dimension - this.extent;
    }

    /***************************************************************************

        Access buffer limit.

        Each buffer has a capacity, a limit, and a position.
        The capacity is the maximum content a buffer can contain,
        limit represents the extent of valid content, and position marks
        the current read location.

        Returns:
            the limit of readable content within this buffer.

    ***************************************************************************/

    public final size_t limit ()
    {
        return this.extent;
    }

    /***************************************************************************

        Access buffer capacity.

        Each buffer has a capacity, a limit, and a position.
        The capacity is the maximum content a buffer can contain,
        limit represents the extent of valid content, and position marks
        the current read location.

        Returns:
            the maximum capacity of this buffer.

    ***************************************************************************/

    public final size_t capacity ()
    {
        return this.dimension;
    }

    /***************************************************************************

       Truncate the buffer within its extent.

        Returns:
            `true` if the new length is valid, `false` otherwise.

    ***************************************************************************/

    public final bool truncate (size_t length)
    {
        if (length <= this.data.length)
        {
            this.extent = length;
            return true;
        }
        return false;
    }

    /***************************************************************************

        Cast to a target type without invoking the wrath of the
        runtime checks for misalignment. Instead, we truncate the
        array length.

    ***************************************************************************/

    static T[] convert(T)(void[] x)
    {
        return (cast(T*) x.ptr) [0 .. (x.length / T.sizeof)];
    }

    /***************************************************************************

        Flush all buffer content to the specific conduit.

        Flush the contents of this buffer.
        This will block until all content is actually flushed via the associated
        conduit, whereas `drain()` will not.

       Throws:
            an IOException on premature Eof.

    ***************************************************************************/

    final override BufferedOutput flush ()
    {
        while (this.readable() > 0)
        {
            auto ret = this.reader(&this.sink.write);
            if (ret is Eof)
                this.conduit.error("end-of-flow whilst writing");
        }

        // flush the filter chain also
        this.clear();
        super.flush;

        if (this.flush_notifier)
        {
            this.flush_notifier();
        }

        return this;
    }

    /***************************************************************************

        Copy content via this buffer from the provided src conduit.

        The src conduit has its content transferred through this buffer via
        a series of fill & drain operations,
        until there is no more content available.
        The buffer content should be explicitly flushed by the caller.

       Throws:
            an IOException on premature Eof.

    ***************************************************************************/

    final override BufferedOutput copy (InputStream src, size_t max = -1)
    {
        size_t chunk, copied;

        while (copied < max && (chunk = this.writer(&src.read)) != Eof)
        {
            copied += chunk;

            // don't drain until we actually need to
            if (this.writable is 0)
                if (this.drain(this.sink) is Eof)
                    this.conduit.error("end-of-flow whilst writing");
        }
        return this;
    }

    /***************************************************************************

        Flushes the buffer and closes the stream.

    ***************************************************************************/

    final override void close ( )
    {
        this.flush();
        super.close();
    }

    /***************************************************************************

        Drain buffer content to the specific conduit.

        Write as much of the buffer that the associated conduit can consume.
        The conduit is not obliged to consume all content,
        so some may remain within the buffer.

        Returns:
            the number of bytes written, or Eof.

   ***************************************************************************/

    final size_t drain (OutputStream dst)
    {
        verify(dst !is null);

        size_t ret = this.reader(&dst.write);
        this.compress();
        return ret;
    }

    /***************************************************************************

        Clear buffer content.

        Reset 'position' and 'limit' to zero.
        This effectively clears all content from the buffer.

    ***************************************************************************/

    final BufferedOutput clear ()
    {
        this.index = this.extent = 0;
        return this;
    }

    /***************************************************************************

        Set the output stream.

    ***************************************************************************/

    final void output (OutputStream sink)
    {
        this.sink = sink;
    }

    /***************************************************************************

        Seek within this stream

        Any and all buffered output is disposed before the upstream is invoked.
        Use an explicit `flush()` to emit content prior to seeking.

    ***************************************************************************/

    final override long seek (long offset, Anchor start = Anchor.Begin)
    {
        this.clear();
        return super.seek(offset, start);
    }

    /***************************************************************************

        Write into this buffer.

        Exposes the raw data buffer at the current _write position,
        The delegate is provided with a void[] representing space
        available within the buffer at the current _write position.

        The delegate should return the appropriate number of bytes
        if it writes valid content, or Eof on error.

        Params:
            dg = The callback to provide buffer access to.

        Returns:
            the delegate return's value

   ***************************************************************************/

    final size_t writer (scope size_t delegate (void[]) dg)
    {
        auto count = dg (this.data[this.extent..this.dimension]);

        if (count != Eof)
        {
            this.extent += count;
            verify(this.extent <= this.dimension);
        }
        return count;
    }

    /***************************************************************************

        Read directly from this buffer.

        Exposes the raw data buffer at the current _read position.
        The delegate is provided with a void[] representing the available data,
        and should return zero to leave the current _read position intact.

        If the delegate consumes data, it should return the number of
        bytes consumed; or Eof to indicate an error.

        Params:
            dg = Callback to provide buffer access to.

        Returns:
            the delegate's return value.

   ***************************************************************************/

    private final size_t reader (scope size_t delegate (Const!(void)[]) dg)
    {
        auto count = dg (this.data[this.index..this.extent]);

        if (count != Eof)
        {
            this.index += count;
            verify(this.index <= this.extent);
        }
        return count;
    }

    /***************************************************************************

        Available content.

        Returns:
            count of _readable bytes remaining in buffer.
            This is calculated simply as `limit() - position()`.

    ***************************************************************************/

    private final size_t readable ()
    {
        return this.extent - this.index;
    }

    /***************************************************************************

        Reset the buffer content.

        Set the backing array with some content readable.
        Writing to this will either flush it to an associated conduit,
        or raise an Eof condition.
        Use clear() to reset the content (make it all writable).

        Params:
            data =     The backing array to buffer within.
            readable = The number of bytes within data considered valid.

        Returns:
            The buffer instance.

   ***************************************************************************/

    private final BufferedOutput set (void[] data, size_t readable)
    {
        this.data = data;
        this.extent = readable;
        this.dimension = data.length;

        // reset to start of input
        this.index = 0;

        return this;
    }

    /***************************************************************************

        Compress buffer space.

        Limit is set to the amount of data remaining.
        Position is always reset to zero.

        If we have some data left after an export, move it to front of the
        buffer and set position to be just after the remains.
        This is for supporting certain conduits which choose to write just
        the initial portion of a request.

        Returns:
            The buffer instance.

   ***************************************************************************/

    private final BufferedOutput compress ()
    {
        size_t r = this.readable();

        if (this.index > 0 && r > 0)
            // content may overlap ...
            memmove(&data[0], &data[this.index], r);

        this.index = 0;
        this.extent = r;
        return this;
    }
}


unittest
{
    scope device = new MemoryDevice;
    scope buffer = new BufferedInput(device, 16);

    device.write(
        "En 1815, M. Charles-François-Bienvenu Myriel était évêque de Digne. " ~
        "C’était un vieillard d’environ soixante-quinze ans; " ~
        "il occupait le siège de Digne depuis 1806.");
    device.seek(0);

    size_t finder (Const!(void)[] raw)
    {
        auto text = cast(cstring) raw;
        if (raw.length >= 5 && raw[$ - 5 .. $] == "1806.")
            return raw.length - 5;
        return BufferedInput.Eof;
    }

    test(buffer.next(&finder));
}
