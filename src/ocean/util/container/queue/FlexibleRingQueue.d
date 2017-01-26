/*******************************************************************************

    Fixed size memory-based ring queue for elements of flexible size.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.queue.FlexibleRingQueue;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.util.container.queue.model.IRingQueue;

import ocean.util.container.queue.model.IByteQueue;

import ocean.util.container.mem.MemManager;

import ocean.io.model.IConduit: InputStream, OutputStream;

import ocean.io.serialize.SimpleStreamSerializer;

import ocean.text.util.ClassName;

debug import ocean.io.Stdout;



/*******************************************************************************

    Simple ubyte-based ring queue.

    TODO: usage example

*******************************************************************************/

class FlexibleByteRingQueue : IRingQueue!(IByteQueue)
{
    import ocean.core.Enforce: enforce;

    import Integer = ocean.text.convert.Integer_tango: toString;
    private alias Integer.toString itoa;

    /***************************************************************************

        Location of the gap at the rear end of the data array where the unused
        space starts.

    ***************************************************************************/

    private size_t gap;


    /***************************************************************************

        Metadata header for saving/loading the queue state

    ***************************************************************************/

    public struct ExportMetadata
    {
        uint items;
    }


    /***************************************************************************

        Header for queue items

    ***************************************************************************/

    private struct Header
    {
        size_t length;
    }


    /***************************************************************************

        Invariant to assert queue position consistency: When the queue is empty,
        read_from and write_to must both be 0.

    ***************************************************************************/

    invariant ( )
    {
        debug scope ( failure ) Stderr.formatln
        (
            "{} invariant failed with items = {}, read_from = {}, " ~
            "write_to = {}, gap = {}, data.length = {}",
            classname(this), this.items, this.read_from, this.write_to,
            this.gap, this.data.length
        );

        if (this.items)
        {
            assert(this.gap       <= this.data.length, "gap out of range");
            assert(this.read_from <= this.data.length, "read_from out of range");
            assert(this.write_to  <= this.data.length, "write_to out of range");
            assert(this.write_to,                      "write_to 0 with non-empty queue");
            assert(this.read_from < this.gap,          "read_from within gap");
            assert((this.gap == this.write_to) ||
                   !(this.read_from < this.write_to),
                   "read_from < write_to but gap not write position");
        }
        else
        {
            assert(!this.gap, "gap expected to be 0 for empty queue");
            assert(!this.read_from, "read_from expected to be 0 for empty queue");
            assert(!this.write_to, "write_to expected to be 0 for empty queue");
        }
    }


    /***************************************************************************

        Constructor. The queue's memory buffer is allocated by the GC.

        Params:
            dimension = size of queue in bytes

    ***************************************************************************/

    public this ( size_t dimension )
    in
    {
        assert(dimension > 0, typeof(this).stringof ~ ": cannot construct a 0-length queue");
    }
    body
    {
        super(dimension);
    }


    /***************************************************************************

        Constructor. Allocates the queue's memory buffer with the provided
        memory manager.

        Params:
            mem_manager = memory manager to use to allocate queue's buffer
            dimension = size of queue in bytes

    ***************************************************************************/

    public this ( IMemManager mem_manager, size_t dimension )
    {
        super(mem_manager, dimension);
    }


    /***************************************************************************

        Pushes an item into the queue.

        item.length = 0 is allowed.

        Params:
            item = data item to push

        Returns:
            true if the item was pushed successfully, false if it didn't fit

    ***************************************************************************/

    public bool push ( ubyte[] item )
    {
        auto data = this.push(item.length);

        if ( data is null )
        {
            return false;
        }

        data[] = item[];

        return true;
    }

    /***************************************************************************

        Reserves space for an item of <size> bytes on the queue but doesn't
        fill the content. The caller is expected to fill in the content using
        the returned slice.

        size = 0 is allowed.

        Params:
            size = size of the space of the item that should be reserved

        Returns:
            slice to the reserved space if it was successfully reserved, else
            null. Returns non-null empty string if size = 0 and the item was
            successfully pushed.

        Out:
            The length of the returned array slice is size unless the slice is
            null.

    ***************************************************************************/

    public ubyte[] push ( size_t size )
    out (slice)
    {
        assert(slice is null || slice.length == size,
               classname(this) ~ "push: length of returned buffer not as requested");
    }
    body
    {
        return this.willFit(size) ? this.push_(size) : null;
    }


    /***************************************************************************

        Pops an item from the queue.

        Returns:
            item popped from queue, may be null if queue is empty

    ***************************************************************************/

    public ubyte[] pop ( )
    {
        return this.items ? this.pop_() : null;
    }


    /***************************************************************************

        Peeks at the item that would be popped next.

        Returns:
            item that would be popped from queue,
            may be null if queue is empty

    ***************************************************************************/

    public ubyte[] peek ( )
    {
        if (this.items)
        {
            auto h = this.read_from;
            auto d = h + Header.sizeof;
            auto header = cast(Header*) this.data[h .. d].ptr;
            return this.data[d .. d + header.length];
        }
        else
        {
            return null;
        }
    }


    /***************************************************************************

        Returns:
            number of bytes stored in queue

    ***************************************************************************/

    public override ulong used_space ( )
    {
        if (this.items == 0)
        {
            return 0;
        }

        if (this.write_to > this.read_from)
        {
            return this.write_to - this.read_from;
        }

        return this.gap - this.read_from + this.write_to;
    }


    /***************************************************************************

        Removes all items from the queue.

    ***************************************************************************/

    public override void clear ( )
    {
        super.clear();
        this.items = 0;
        this.gap = 0;
    }


    /***************************************************************************

        Tells how much space an item would take up when written into the queue.
        (Including the size of the required item header.)

        Params:
            item = item to calculate push size of

        Returns:
            number of bytes the item would take up if pushed to the queue

    ***************************************************************************/

    static public size_t pushSize ( ubyte[] item )
    {
        return pushSize(item.length);
    }


    /***************************************************************************

        Tells how much space an item of the specified size would take up when
        written into the queue. (Including the size of the required item
        header.)

        Params:
            bytes = number of bytes to calculate push size of

        Returns:
            number of bytes the item would take up if pushed to the queue

    ***************************************************************************/

    static public size_t pushSize ( size_t bytes )
    {
        return Header.sizeof + bytes;
    }


    /***************************************************************************

        Finds out whether the provided item will fit in the queue. Also
        considers the need of wrapping.

        Params:
            item = item to check

        Returns:
            true if the item fits, else false

    ***************************************************************************/

    bool willFit ( ubyte[] item )
    {
        return this.willFit(item.length);
    }


    /***************************************************************************

        Finds out whether the provided number of bytes will fit in the queue.
        Also considers the need of wrapping.

        Note that this method internally adds on the extra bytes required for
        the item header, so it is *not* necessary for the end-user to first
        calculate the item's push size.

        Params:
            bytes = size of item to check

        Returns:
            true if the bytes fits, else false

    ***************************************************************************/

    public bool willFit ( size_t bytes )
    {
        size_t push_size = this.pushSize(bytes);

        if (this.read_from < this.write_to)
        {
            /*
             *  Free space at either
             *  - data[write_to .. $], the end, or
             *  - data[0 .. read_from], the beginning, wrapping around.
             */
            return ((this.data.length - this.write_to) >= push_size) // Fits at the end.
                   || (this.read_from >= push_size); // Fits at the start wrapping around.

        }
        else if (this.items)
        {
            // Free space at data[write_to .. read_from].
            return (this.read_from - this.write_to) >= push_size;
        }
        else
        {
            // Queue empty: data is the free space.
            return push_size <= this.data.length;
        }
    }

    /***************************************************************************

        Writes the queue's state and contents to the given output stream in the
        following format:

        - First ExportMetadata.sizeof bytes: Metadata header
        - Next size_t.sizeof bytes: Number n of bytes of queue data (possibly 0)
        - Next n bytes: Queue data

        Params:
            output = output stream to write to

        Returns:
            number of bytes written to output.

    ***************************************************************************/

    public size_t save ( OutputStream output )
    {
        size_t bytes = 0;

        this.save((void[] meta, void[] head, void[] tail = null)
        {
            bytes += SimpleStreamSerializer.writeData(output, meta);
            bytes += SimpleStreamSerializer.write(output, head.length + tail.length);
            if (head.length) bytes += SimpleStreamSerializer.writeData(output, head);
            if (tail.length) bytes += SimpleStreamSerializer.writeData(output, tail);
        });

        return bytes;
    }

    /***************************************************************************

        Calls the provided delegate, store(), to store the queue state and
        contents.

        The caller may concatenate the contents of the three buffers because
          - it is safe to assume that load() will use the same meta.length and
          - load() expects to receive the head ~ tail data.

        Example:

        ---

            auto queue = new FlexibleRingQueue(/+ ... +/);

            // Populate the queue...

            void[] queue_save_data;

            // Save the populated queue in queue_save_data.

            queue.save(void[] meta, void[] head, void[] tail)
            {
                queue_save_data = meta ~ head ~ tail;
            }

            // Restore queue from queue_save_data.

            queue.load(void[] meta, void[] data)
            {
                // It is safe to assume meta.length is the same as in the
                // queue.save() callback delegate.
                meta[] = queue_save_data[0 .. meta.length];

                void[] queue_load_data = queue_save_data[meta.length .. $];
                data[] = queue_load_data[];
                return queue_load_data.length;
            }

        ---

        This method can also be called to poll the amount of space required for
        storing the current queue content, which is
        meta.length + head.length + tail.length.

        The data produced by this method is accepted by the load() method of any
        queue where queue.length >= head.length + tail.length.

        Params:
            store = output delegate

    ***************************************************************************/

    public void save ( void delegate ( void[] meta, void[] head, void[] tail = null ) store )
    {
        auto meta = ExportMetadata(this.items);

        if (this.read_from < this.write_to)
        {
            store((&meta)[0 .. 1], this.data[this.read_from .. this.write_to]);
        }
        else
        {
            store((&meta)[0 .. 1],
                  this.data[this.read_from .. this.gap],
                  this.data[0 .. this.write_to]);
        }
    }

    /***************************************************************************

        Restores the queue state and contents, reading from input and expecting
        data previously written by save() to an output stream.

        Assumes that the input data do not exceed the queue capacity and throws
        if they do. If this is possible and you want to handle this gracefully
        (rather than getting an exception thrown), use the other overload of
        this method.

        Params:
            input = input stream

        Returns:
            the number of bytes read from input.

        Throws:
            ValidationError if the input data are inconsistent or exceed the
            queue capacity. When throwing, the queue remains empty.

    ***************************************************************************/

    public size_t load ( InputStream input )
    {
        size_t bytes = 0;

        this.load((void[] meta, void[] data)
        {
            bytes += SimpleStreamSerializer.readData(input, meta);

            size_t data_length;
            bytes += SimpleStreamSerializer.read(input, data_length);
            enforce!(ValidationError)(data_length <= data.length,
                "Size of loaded data exceeds queue capacity");
            bytes += SimpleStreamSerializer.readData(input, data[0 .. data_length]);
            return data_length;
        });

        return bytes;
    }

    /***************************************************************************

        Restores the queue state and contents.

        Clears the queue, then calls the provided delegate, restore(), to
        restore the queue state and contents and validates it.

        restore() should populate the meta and data buffer it receives with data
        previously obtained from save():
         - meta should be populated with the data from the store() meta
           parameter,
         - data[0 .. head.length + tail.length] should be populated with the
           head ~ tail data as received by the store() delegate during save(),
         - restore() should return head.length + tail.length.

        See the example in the documentation of save().

        Params:
            restore = input delegate

        Throws:
            ValidationError if the input data are inconsistent. When throwing,
            the queue remains empty.

    ***************************************************************************/

    public void load ( size_t delegate ( void[] meta, void[] data ) restore )
    {
        this.clear();

        /*
         * Pass this.data as the destination buffer to restore() and validate
         * its content after restore() populated it. Should the validation fail,
         * items, read_from, write_to and gap will remain 0 so the queue is
         * empty and the invalid data in this.data are not harmful.
         */

        ExportMetadata meta;
        size_t end = restore((&meta)[0 .. 1], this.data);

        assert(end <= this.data.length,
               classname(this) ~ ".save(): restore callback expected to " ~
               "return at most " ~ itoa(this.data.length) ~ ", not" ~ itoa(end));


        this.validate(meta, this.data[0 .. end]);

        this.items    = meta.items;
        this.write_to = end;
        this.gap      = end;
    }

    /***************************************************************************

        Pushes an item into the queue.

        Params:
            item = data item to push

    ***************************************************************************/

    private ubyte[] push_ ( size_t size )
    in
    {
        assert(this); // invariant
        assert(this.willFit(size), classname(this) ~ ".push_: item will not fit");
    }
    out (slice)
    {
        assert(slice !is null,
               classname(this) ~ "push_: returned a null slice");
        assert(slice.length == size,
               classname(this) ~ "push_: length of returned slice not as requested");
        assert(this); // invariant
    }
    body
    {
        auto push_size = this.pushSize(size);

        /*
         * read_from and write_to can have three different relationships:
         *
         * 1. write_to == read_from: The queue is empty, both are 0, the
         *    record goes to data[write_to .. $].
         *
         * 2. write_to < read_from: The record goes in
         *    data[write_to .. read_from].
         *
         * 3. read_from < write_to: The record goes either in
         *   a) data[write_to .. $] if there is enough space or
         *   b) data[0 .. read_from], wrapping around by setting
         *      write_to = 0.
         *
         * The destination slice of data in case 3a is equivalent to case 1
         * and in case 3b to case 2.
         */

        if (this.read_from < this.write_to)
        {
            assert(this.gap == this.write_to);

            // Case 3: Check if the record fits in data[write_to .. $] ...
            if (this.data.length - this.write_to < push_size)
            {
                /*
                 * ... no, we have to wrap around. The precondition claims
                 * the record does fit so there must be enough space in
                 * data[0 .. read_from].
                 */
                assert(push_size <= this.read_from);
                this.write_to = 0;
            }
        }

        auto start = this.write_to;
        this.write_to += push_size;

        if (this.write_to > this.read_from) // Case 1 or 3a.
        {
            this.gap = this.write_to;
        }

        this.items++;

        void[] dst = this.data[start .. this.write_to];
        *cast(Header*)dst[0 .. Header.sizeof].ptr = Header(size);
        return cast(ubyte[])dst[Header.sizeof .. $];
    }


    /***************************************************************************

        Pops an item from the queue.

        Returns:
            item popped from queue

    ***************************************************************************/

    private ubyte[] pop_ ( )
    in
    {
        assert(this); // invariant
        assert(this.items, classname(this) ~ ".pop_: no items in the queue");
    }
    out (buffer)
    {
        assert(buffer, classname(this) ~ ".pop_: returned a null buffer");
        assert(this); // invariant
    }
    body
    {

        auto position = this.read_from;
        this.read_from += Header.sizeof;

        // TODO: Error if this.data.length < this.read_from.

        auto header = cast(Header*)this.data[position .. this.read_from].ptr;

        // TODO: Error if this.data.length - this.read_from < header.length

        position = this.read_from;
        this.read_from += header.length;
        assert(this.read_from <= this.gap); // The invariant ensures that
                                            // this.gap is not 0.

        this.items--; // The precondition prevents decrementing 0.

        scope (exit)
        {
            if (this.items)
            {
                if (this.read_from == this.gap)
                {
                    /*
                     *  End of data, wrap around:
                     *  1. Set the read position to the start of this.data.
                     */
                    this.read_from = 0;
                    /*
                     *  2. The write position is now the end of the data.
                     *     If the queue is now empty, i.e. this.items == 0,
                     *     write_to must be 0.
                     */

                    assert(this.items || !this.write_to);
                    this.gap = this.write_to;
                }
            }
            else // Popped the last record.
            {
                assert(this.read_from == this.write_to);
                this.read_from = 0;
                this.write_to  = 0;
                this.gap       = 0;
            }

        }

        return this.data[position .. this.read_from];
    }

    /***************************************************************************

        Validates queue state and content data.

        Params:
            meta = queue state data as imported by load()
            data = queue content data

        Throws:
            ValidationError if meta and/or data are inconsistent.

    ***************************************************************************/

    private static void validate ( ExportMetadata meta, void[] data )
    {
        if (meta.items)
        {
            enforce!(ValidationError)(
                data.length,
                cast(istring) ("Expected data for a non-empty queue ("
                    ~ itoa(meta.items) ~ " records)")
            );

            enforce!(ValidationError)(
                data.length >= cast(size_t)meta.items * Header.sizeof,
                cast(istring) ("Queue data shorter than required minimum for " ~
                    itoa(meta.items) ~ " records (got " ~ itoa(data.length) ~
                    " bytes)")
            );

            size_t pos = 0;

            for (typeof(meta.items) i = 0; i < meta.items; i++)
            {
                assert(pos <= data.length);

                try
                {
                    enforce!(ValidationError)(pos != data.length,
                                              "Unexpected end of input data");

                    auto start = pos;
                    pos += Header.sizeof;

                    enforce!(ValidationError)(
                        pos <= data.length,
                        cast(istring) ("End of queue data in the middle of" ~
                            " the record header which starts at byte " ~
                            itoa(start))
                    );

                    auto header = cast(Header*)data[start .. pos].ptr;

                    enforce!(ValidationError)(
                        (data.length - pos) >= header.length,
                        cast(istring) ("End of queue data in the middle of the" ~
                            " queue record, record length = " ~
                            itoa(header.length))
                    );

                    pos += header.length;
                }
                catch (ValidationError e)
                {
                    auto msg = "Error reading record " ~ itoa(i + i) ~ "/" ~
                        itoa(meta.items) ~ ": " ~ getMsg(e);
                    e.msg = assumeUnique(msg);
                    throw e;
                }
            }

            assert(pos <= data.length);

            enforce!(ValidationError)(
                pos >= data.length,
                cast(istring) ("Queue data  too long (" ~ itoa(meta.items) ~
                    " records, " ~ itoa(pos) ~ "/" ~ itoa(data.length) ~
                    " bytes used)")
            );
        }
        else
        {
            enforce!(ValidationError)(
                !data.length,
                cast(istring) ("Expected no data for an empty queue, not " ~
                    itoa(data.length) ~ " bytes")
            );
        }
    }

    /**************************************************************************/

    static class ValidationError: Exception
    {
        import ocean.core.Exception : DefaultExceptionCtor;
        mixin DefaultExceptionCtor!();
    }
}
/*******************************************************************************

    UnitTest

*******************************************************************************/

version ( UnitTest )
{
    import ocean.io.model.IConduit: IConduit;
}

unittest
{
    const queue_size_1 = (9+FlexibleByteRingQueue.Header.sizeof)*10;

    scope queue = new FlexibleByteRingQueue(queue_size_1);
    assert(queue.free_space >= queue_size_1);
    assert(queue.is_empty);

    assert(queue.free_space >= queue_size_1);
    assert(queue.is_empty);

    assert(queue.push(cast(ubyte[])"Element 1"));
    assert(queue.pop() == cast(ubyte[])"Element 1");
    assert(queue.items == 0);
    assert(!queue.free_space == 0);
    assert(queue.is_empty);
    assert(queue.used_space() == 0);

    assert(queue.push(cast(ubyte[])"Element 1"));
    assert(queue.push(cast(ubyte[])"Element 2"));
    assert(queue.push(cast(ubyte[])"Element 3"));
    assert(queue.push(cast(ubyte[])"Element 4"));
    assert(queue.push(cast(ubyte[])"Element 5"));
    assert(queue.push(cast(ubyte[])"Element 6"));
    assert(queue.push(cast(ubyte[])"Element 7"));
    assert(queue.push(cast(ubyte[])"Element 8"));
    assert(queue.push(cast(ubyte[])"Element 9"));
    assert(queue.push(cast(ubyte[])"Element10"));

    assert(queue.length == 10);
    assert(queue.free_space == 0);
    assert(!queue.is_empty);

    assert(!queue.push(cast(ubyte[])"more"));
    assert(queue.length == 10);

    scope middle = new FlexibleByteRingQueue((1+FlexibleByteRingQueue.Header.sizeof)*5);
    middle.push(cast(ubyte[])"1");
    middle.push(cast(ubyte[])"2");
    middle.push(cast(ubyte[])"3");
    middle.push(cast(ubyte[])"4");
    assert(middle.pop == cast(ubyte[])"1");
    assert(middle.read_from == 1 + FlexibleByteRingQueue.Header.sizeof);
    assert(middle.write_to == (1+FlexibleByteRingQueue.Header.sizeof)*4);
    assert(middle.free_space() == (1+FlexibleByteRingQueue.Header.sizeof)*2);

    assert(middle.push(cast(ubyte[])"5"));
    assert(middle.push(cast(ubyte[])"6"));
    assert(middle.free_space() == 0);
}

/*******************************************************************************

    Save/load test. Uses the unittest above, adding save/load sequences in the
    middle. This test is separate to allow for changing the above push/pop test
    without breaking the save/load test.

*******************************************************************************/

version ( UnitTest )
{
    import ocean.io.device.MemoryDevice;
}

unittest
{
    // Buffers and callback functions for the delegate based save() & load().

    void[] saved_meta, saved_data;

    void store ( void[] meta, void[] head, void[] tail )
    {
        saved_meta = meta.dup;
        saved_data = head.dup ~ tail;
    }

    size_t restore ( void[] meta, void[] data )
    {
        meta[] = saved_meta;
        data[0 .. saved_data.length] = saved_data;
        return saved_data.length;
    }

    // Memory I/O stream device for the stream based save() & load().

    scope backup = new MemoryDevice;

    const queue_size_1 = (9+FlexibleByteRingQueue.Header.sizeof)*10;

    scope queue = new FlexibleByteRingQueue(queue_size_1);
    assert(queue.free_space >= queue_size_1);
    assert(queue.is_empty);

    queue.save(&store);
    queue.load(&restore);

    assert(queue.free_space >= queue_size_1);
    assert(queue.is_empty);

    assert(queue.push(cast(ubyte[])"Element 1"));
    assert(queue.pop() == cast(ubyte[])"Element 1");
    assert(queue.items == 0);
    assert(!queue.free_space == 0);
    assert(queue.is_empty);
    assert(queue.used_space() == 0);

    assert(queue.push(cast(ubyte[])"Element 1"));
    assert(queue.push(cast(ubyte[])"Element 2"));
    assert(queue.push(cast(ubyte[])"Element 3"));
    assert(queue.push(cast(ubyte[])"Element 4"));
    assert(queue.push(cast(ubyte[])"Element 5"));
    assert(queue.push(cast(ubyte[])"Element 6"));
    assert(queue.push(cast(ubyte[])"Element 7"));
    assert(queue.push(cast(ubyte[])"Element 8"));
    assert(queue.push(cast(ubyte[])"Element 9"));
    assert(queue.push(cast(ubyte[])"Element10"));

    // Save and restore the queue status in the middle of a test.

    queue.save(&store);
    queue.clear();
    queue.load(&restore);

    assert(queue.length == 10);
    assert(queue.free_space == 0);
    assert(!queue.is_empty);

    assert(!queue.push(cast(ubyte[])"more"));
    assert(queue.length == 10);

    scope middle = new FlexibleByteRingQueue((1+FlexibleByteRingQueue.Header.sizeof)*5);
    middle.push(cast(ubyte[])"1");
    middle.push(cast(ubyte[])"2");
    middle.push(cast(ubyte[])"3");
    middle.push(cast(ubyte[])"4");
    assert(middle.pop == cast(ubyte[])"1");
    assert(middle.read_from == 1 + FlexibleByteRingQueue.Header.sizeof);
    assert(middle.write_to == (1+FlexibleByteRingQueue.Header.sizeof)*4);
    assert(middle.free_space() == (1+FlexibleByteRingQueue.Header.sizeof)*2);

    // Save and restore the queue status in the middle of a test.

    middle.save(backup);
    middle.clear();
    backup.seek(0);
    middle.load(backup);
    assert(backup.read(null) == backup.Eof);
    backup.close();

    assert(middle.push(cast(ubyte[])"5"));
    assert(middle.push(cast(ubyte[])"6"));
    assert(middle.free_space() == 0);
}

/*******************************************************************************

    Test for the corner case of saving the queue state after wrapping around.

*******************************************************************************/

unittest
{
    enum Save {Dont = 0, Dg, Stream}

    // Buffers and callback functions for the delegate based save() & load().

    void[] saved_meta, saved_data;

    void store ( void[] meta, void[] head, void[] tail )
    {
        saved_meta = meta.dup;
        saved_data = head.dup ~ tail;
    }

    size_t restore ( void[] meta, void[] data )
    {
        meta[] = saved_meta;
        data[0 .. saved_data.length] = saved_data;
        return saved_data.length;
    }

    // Memory I/O stream device for the stream based save() & load().

    scope backup = new MemoryDevice;

    void save_wraparound ( Save save )
    {
        const Q_SIZE = 20;
        FlexibleByteRingQueue q = new FlexibleByteRingQueue(Q_SIZE);

        void push(uint n)
        in
        {
            assert(n <= ubyte.max);
        }
        body
        {
            for (ubyte i = 0; i < n; i++)
            {
                if (ubyte[] push_slice = q.push(1))
                {
                    push_slice[0] = i;
                }
                else
                {
                    break;
                }

                // Save and restore the queue status after wrapping around.

                if (q.write_to <= q.read_from) switch (save)
                {
                    case save.Dont: break;

                    case save.Dg:
                        q.save(&store);
                        q.clear();
                        q.load(&restore);
                        break;

                    case save.Stream:
                        q.save(backup);
                        q.clear();
                        backup.seek(0);
                        q.load(backup);
                        assert(backup.read(null) == backup.Eof);
                        backup.close();
                        break;

                    default: assert(false);
                }
            }
        }

        void pop(uint n)
        {
            for (uint i = 0; i < n; i++)
            {
                if (ubyte[] popped = q.pop())
                {
                    assert (popped.length == 1);
                    assert (popped[0] != Q_SIZE+1);
                    popped[0] = Q_SIZE+1;
                }
                else
                {
                    break;
                }
            }
        }

        push(2);
        pop(1);
        push(2);
        pop(1);
        push(3);
        pop(4);
        pop(1);
    }
    save_wraparound(Save.Dont);
    save_wraparound(Save.Dg);
    save_wraparound(Save.Stream);
}

/*******************************************************************************

    Performance test

*******************************************************************************/

version ( UnitTest )
{
    // Uncomment the next line to see UnitTest output
    // version = UnitTestVerbose;

    import ocean.core.Test;

    import ocean.math.random.Random;
    import ocean.time.StopWatch;
    import core.memory;
    import ocean.io.FilePath_tango;
}

unittest
{
     scope random = new Random();

    /***********************************************************************

        Test wrapping

    ***********************************************************************/

    {
        scope queue = new FlexibleByteRingQueue((1+FlexibleByteRingQueue.Header.sizeof)*3);

        assert(queue.read_from == 0);
        assert(queue.write_to == 0);
        // [___] r=0 w=0
        assert(queue.push(cast(ubyte[])"1"));

        assert(queue.read_from == 0);
        assert(queue.write_to == 1+FlexibleByteRingQueue.Header.sizeof);
        assert(queue.items == 1);
        assert((cast(FlexibleByteRingQueue.Header*) queue.data.ptr).length == 1);

        assert(queue.data[FlexibleByteRingQueue.Header.sizeof ..
                          1+FlexibleByteRingQueue.Header.sizeof] ==
                              cast(ubyte[]) "1");

        // [#__] r=0 w=5
        assert(queue.push(cast(ubyte[])"2"));

        // [##_] r=0 w=10
        assert(queue.push(cast(ubyte[])"3"));

        // [###] r=0 w=15
        assert(!queue.push(cast(ubyte[])"4"));
        assert(queue.free_space == 0);
        assert(queue.pop() == cast(ubyte[])"1");

        // [_##] r=5 w=15
        assert(queue.free_space() == 1+FlexibleByteRingQueue.Header.sizeof);
        assert(queue.pop() == cast(ubyte[])"2");

        // [__#] r=10 w=15
        assert(queue.free_space() == (1+FlexibleByteRingQueue.Header.sizeof)*2);
        assert(queue.write_to == queue.data.length);
        assert(queue.push(cast(ubyte[])"1"));

        // [#_#] r=10 w=5
        assert(queue.free_space() == 1+FlexibleByteRingQueue.Header.sizeof);
        assert(queue.write_to == queue.pushSize("2".length));
        assert(queue.push(cast(ubyte[])"2"));
       // Stdout.formatln("gap is {}, free is {}, write is {}", queue.gap, queue.free_space(),queue.write_to);


        // [###] r=10 w=10
        assert(queue.free_space == 0);
        assert(queue.pop() == cast(ubyte[])"3");

        // [##_] r=15/0 w=10
        assert(queue.free_space() == (1+FlexibleByteRingQueue.Header.sizeof)*1);
        assert(queue.pop() == cast(ubyte[])"1");

        // [_#_] r=5 w=10
        assert(queue.pop() == cast(ubyte[])"2");

        // [__] r=0 w=0
        assert(queue.is_empty);
        assert(queue.push(cast(ubyte[])"1"));

        // [#__] r=0 w=5
        assert(queue.push(cast(ubyte[])"2#"));

        // [#$_] r=0 w=11 ($ = 2 bytes)
        assert(queue.pop() == cast(ubyte[])"1");

        // [_$_] r=5 w=11
        assert(queue.push(cast(ubyte[])"1"));

        // [#$_] r=5 w=5
        assert(!queue.push(cast(ubyte[])"2"));
        assert(queue.pop() == cast(ubyte[])"2#");

        // [#__] r=11 w=5
        assert(queue.push(cast(ubyte[])"2")); // this needs to be wrapped now

        // [##_] r=11 w=10
    }
}


// Test for a specific bug that caused garbled loglines due to an old wrong
// willFit() function
unittest
{
    auto q = new FlexibleByteRingQueue(45);

    // Setup conditions
    test(q.push(cast(ubyte[])"123456")); // w = 14
    test(q.push(cast(ubyte[])"12345678")); // w = 30
    test(q.push(cast(ubyte[])"123456")); // w = 44
    test(q.pop() == cast(ubyte[])"123456");
    test(q.pop() == cast(ubyte[])"12345678"); // r == 30
    test(q.push(cast(ubyte[])"12345678123456781234")); // r = 30, gap = 44

    auto test_push = cast(ubyte[])"123456789.....16";

    // Make sure the bugs conditions are present
    test!(">")(q.read_from, q.write_to);
    test!("<")(q.read_from, q.gap);
    test!(">")(q.pushSize(test_push.length) + q.write_to, q.data.length);

    // Do the actual test
    test(!q.push(test_push));

    test!("==")(q.pop(), cast(ubyte[])"123456");
    test!("==")(q.pop(), cast(ubyte[])"12345678123456781234");
}
