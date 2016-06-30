/*******************************************************************************

    Cache class, caches raw data of either fixed or dynamic length

    Cache of raw data (ubyte[] / void[]) items of either fixed or variable
    length. The cache is initialised with a fixed capacity (the number of items
    that can be stored). When the cache reaches its full capacity, any newly
    added items will replace older items in the cache. The cache keeps track of
    the last time each item was written or read, and will replace the oldest
    items first.

    The basic Cache template is used to store raw data. A second template exists
    which takes a type as its parameter. This implements a thin wrapper around
    the basic Cache, allowing the transparent storage of (no-op) serialized
    values of the specified type.


    Note that with variable value length anything stored in the cache is
    invisible to the garbage collector because the internal value data type of
    the cache is ubyte[]. So if you store references (objects, pointers, slices
    to dynamic arrays) in the cache with variable value length, make sure your
    application keeps a reference to it. Otherwise the object referenced to may
    be garbage collected and attempting to use it after getting it from the
    cache will make your program go to HELL.


    When a cache element is removed explicitly (by calling remove()), the value
    of the removed element is kept in the cache in a spare location. If required
    it is possible to erase the value by overriding Cache.replaceRemovedItem(),
    see the description of this method for an example.

    When a cache element is removed automatically if the cache is full and a new
    element is added, Cache.whenCacheItemDropped(size_t index) will be called. If
    required it is possible to be notified of this occurrence by overriding
    Cache.whenCacheItemDropped method.

    Cache.createRaw() and Cache.getOrCreateRaw() return a reference to a record
    value in the cache. Cache.getRaw() behaves like Cache.getOrCreateRaw() if
    the record was found in the cache or returns null otherwise.
    For fixed length values the record value reference is a slice to the record
    value.
    Usage example:

    ---

        import ocean.util.container.Cache;

        // Create a fixed-size cache which can store 2 items, each of length 3.
        auto cache = new Cache!(3)(2);

        // Add an item using createRaw(). createRaw() returns a void[] array
        // with length 3 which references the value in the cache.

        hash_t key = 0x12345678;

        char[3] val = "abc";

        cache.createRaw(key)[] = val[];

        // Obtain an item using getRaw(). If found, getRaw() returns a value
        // slice just like createRaw() or null if not found.

        char[] val_got = cache.getRaw(key);

        if (val_got !is null)
        {
            // val_got contains the value that corresponds to key.
            // The value in the cache can be modified in-place by setting array
            // elements or copying to the whole array:

            (cast(char[])val_got)[2] = '!'; // Set the third value byte to '!'.

            (cast(char[])val_got)[] = "def"; // Set the value to "def".
        }
        else
        {
            // not found
        }

    ---

    For variable length arrays it is a pointer to the Cache.Value struct which
    encapsulates the value, which is void[], providing access to the value via
    operator overloading:

        - opAssign sets the value array instance to an input array slice
          (overwriting the previous array instance),
        - opSliceAssign treats the value array as an allocated buffer and copies
          the content of the an input array slice into the value array,
        - opSlice returns the value array.

    opSliceAssign reuses an existing buffer and is therefore memory-friendly as
    long as opAssign is not used with the same value instance.

    Rule of thumb: For each cache instance with variable value size use either
    opAssign or opSliceAssign with the values, never both.

    Usage Example 1: Store string slices in a cache using Value.opAssign.

    ---

        auto cache = new Cache!()(100);

        char[] str1 = "Hello World",
               str2 = "Eggs and Spam";

        {
            auto val = cache.createRaw(4711);

            // Store a slice to str1 in the array using (*val).opAssign.

            *val = str1;
        }

        {
            auto val = cache.getRaw(4711);

            // (*val)[] ((*val).opSlice) now returns a slice to str1.

            // Replace this value with a slice to str2 using (*val).opAssign.

            *val = str2;
        }

    ---

    Usage Example 2: Store copies of strings in a cache using
                     Value.opSliceAssign.

    ---

        auto cache = new Cache!()(100);

        char[] str1 = "Hello World",
               str2 = "Eggs and Spam";

        {
            auto val = cache.createRaw(4711);

            // Allocate a value array buffer with str1.length and copy the
            // content of str1 into that value buffer.

            (*val)[] = str1;
        }

        {
            auto val = cache.getRaw(4711);

            // (*val)[] ((*val).opSlice) now returns the value array buffer
            // which contains a copy of the content of str1.

            // Use (*val)[] = str2 ((*val).opSliceAssign(x)) to resize the value
            // array buffer to str2.length and copy the content of str2 into it.

            (*val)[] = str2;
        }

    ---

    For special situations it is possible to obtain a pointer to the value
    array. One such situation is when the value array needs to be modified by
    an external function which doesn't know about the cache.

    ---

        void setValue ( ref void[] value )
        {
            value = "Hello World!";
        }

        auto cache = new Cache!()(100);

        auto val = cache.createRaw(4711);

        void[]* val_array = cast (void[]*) (*s);

        setValue(*val_array);

    ---

    Link with:
        -Llibebtree.a

    TODO:
        Extend the cache by making values visible to the GC by default and
        provide GC hiding as an option.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.cache.Cache;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.cache.model.ICache;
import ocean.util.container.cache.model.ITrackCreateTimesCache;
import ocean.util.container.cache.model.Value;
import ocean.stdc.time: time_t;
import ocean.core.Test;

import core.memory;

debug import ocean.io.Stdout;

debug (CacheTimes)
{
    import ocean.core.Array: concat;
    import ocean.stdc.stdio: FILE, fopen, fclose, fprintf, perror;
    import ocean.stdc.posix.time: ctime_r;
}


/*******************************************************************************

    Evaluates to either ICache or ITrackCreateTimesCache, depending on
    TrackCreateTimes.

*******************************************************************************/

template CacheBase ( bool TrackCreateTimes = false )
{
    static if (TrackCreateTimes)
    {
        alias ITrackCreateTimesCache CacheBase;
    }
    else
    {
        alias ICache CacheBase;
    }
}

/*******************************************************************************

    Data cache class template. Stores items of raw data, either of fixed or
    dynamic size.

    Template_Params:
        ValueSize = size of a data item. If 0 is specified (the default), the
            items stored in the cache are of variable (dynamic) size
        TrackCreateTimes = if true, each cache item is stored with its create
            time, in addition to its last access time

*******************************************************************************/

class Cache ( size_t ValueSize = 0, bool TrackCreateTimes = false ) : CacheBase!(TrackCreateTimes)
{
    /***************************************************************************

        Mixin the type definition for the values.

    ***************************************************************************/

    mixin Value!(ValueSize);

    /***************************************************************************

        Cached item struct, storing a key and value.

    ***************************************************************************/

    struct CacheItem
    {
        hash_t key;
        Value value;

        static if ( TrackCreateTimes )
        {
            time_t create_time;
        }

        /***********************************************************************

            Copies value to this.value.

            Params:
                value = value to copy

            Returns:
                this.value

        ***********************************************************************/

        ValueRef setValue ( Value value )
        {
            static if ( is_dynamic )
            {
                this.value = value;
                return &this.value;
            }
            else
            {
                return this.value[] = value[];
            }
        }

        static if ( is_dynamic )
        {
            ValueRef value_ref ( )
            {
                return &this.value;
            }
        }
        else
        {
            ValueRef value_ref ( )
            {
                return this.value[];
            }
        }
    }


    /***************************************************************************

        Array of cached items.

    ***************************************************************************/

    private CacheItem[] items;


    /***************************************************************************

        Constructor.

        Params:
            max_items = maximum number of items in the cache, set once, cannot
                be changed

    ***************************************************************************/

    public this ( size_t max_items )
    {
        super(max_items);

        this.items = new CacheItem[max_items];
    }


    version (D_Version2) {}
    else
    {
        /***********************************************************************

            Disposer.

        ***********************************************************************/

        protected override void dispose ( )
        {
            super.dispose();

            delete this.items;
        }
    }

    /***************************************************************************

        Creates an item in the cache and sets its create time. If the cache is
        full, the oldest item is replaced with the new item. (In the case where
        several items are equally old, the choice of which one to be replaced is
        made arbitrarily.)

        Params:
            key = item key

        Returns:
            a reference to the value of the created item. If an existing item
            was replaced, this reference refers to its current value, otherwise
            it may refer to the value of a previously removed element.

        Out:
            The returned reference is never null; for values of fixed size the
            slice length is ValueSize.

    ***************************************************************************/

    public ValueRef createRaw ( hash_t key )
    out (val)
    {
        static if (is_dynamic)
        {
            assert (val !is null);
        }
        else
        {
            assert (val.length == ValueSize);
        }
    }
    body
    {
        bool existed;

        time_t access_time;

        with (*this.getOrAdd(key, existed, access_time))
        {
            static if ( TrackCreateTimes )
            {
                create_time = access_time;
            }

            return value_ref;
        }
    }

    /***************************************************************************

        Gets an item from the cache. If the item was found in the cache, its
        access time is updated.

        Note that, if you change the value referenced by the returned reference,
        the create time will not be updated.

        Params:
            key = key to lookup

        Returns:
            a reference to item value or null if no such item was found.

        Out:
            For values of fixed size the slice length is ValueSize unless the
            returned reference is null.

    ***************************************************************************/

    public ValueRef getRaw ( hash_t key )
    out (val)
    {
        static if (!is_dynamic)
        {
            if (val !is null)
            {
                assert (val.length == ValueSize);
            }
        }
    }
    body
    {
        time_t access_time;

        CacheItem* item = this.get__(key, access_time);

        return (item !is null)? item.value_ref : null;
    }

    /***************************************************************************

        Gets an item from the cache or creates it if not already existing. If
        the item was found in the cache, its access time is updated, otherwise
        its create time is set.

        Note that the create time is set only if an item is created, not if it
        already existed and you change the value referenced by the returned
        reference.

        Params:
            key         = key to lookup
            existed     = true:  the item already existed,
                          false: the item was created

        Returns:
            a reference to the value of the obtained or created item. If an item
            was created, the returned reference may refer to the value of a
            previously removed element.

        Out:
            The returned reference is never null; for values of fixed size the
            slice length is ValueSize.

    ***************************************************************************/

    public ValueRef getOrCreateRaw ( hash_t key, out bool existed )
    out (val)
    {
        static if (is_dynamic)
        {
            assert (val !is null);
        }
        else
        {
            assert (val.length == ValueSize);
        }
    }
    body
    {
        time_t access_time;

        with (*this.getOrAdd(key, existed, access_time))
        {
            static if ( TrackCreateTimes ) if (!existed)
            {
                create_time = access_time;
            }

            return value_ref;
        }
    }

    /***************************************************************************

        Checks whether an item exists in the cache and returns its create time.

        Params:
            key = key to lookup

        Returns:
            item's create time, or 0 if the item doesn't exist

    ***************************************************************************/

    static if ( TrackCreateTimes )
    {
        public override time_t createTime ( hash_t key )
        {
            TimeToIndex.Node** node = key in this;

            return node? this.items[(*node).key.lo].create_time : 0;
        }
    }

    /***************************************************************************

        Obtains the key of the cache item corresponding to index.

        Params:
            index = cache item index, guaranteed to be below length

        Returns:
            cache item key

    ***************************************************************************/

    protected override hash_t keyByIndex ( size_t index )
    in
    {
        assert (index <= this.length);
    }
    body
    {
        return this.items[index].key;
    }

    /***************************************************************************

        Called when a cache element is removed, replaces the cache items at
        index "replaced" with the one at index "replace" by swapping the items.

        Unlike all other situations where indices and are used, "replaced" and
        "replace" must be always valid, i.e. less than length.

        Note: A subclass may erase removed elements by overriding this method as
              follows:

        ---
        protected override hash_t replaceRemovedItem ( size_t replaced,
                                                       size_t replace )
        {
            scope (success) this.items[replace] = this.items[replace].init;

            return (this.items[replaced] = this.items[replace]).key;
        }
        ---

        Params:
            replaced = index of the cache item that is to be replaced
            replace  = index of the cache item that will replace the replaced
                       item

        Returns:
            the key of the cache item that was at index "replace" before and is
            at index "replaced" now.

        In:
            "replaced" and "replace" must be different and be valid cache item
            indices, i.e. less than this.length.

        Out:
            The returned key must be the key of this.items[replaced].

    ***************************************************************************/

    protected override hash_t replaceRemovedItem ( size_t replaced, size_t replace )
    in
    {
        assert(replaced != replace);

        size_t length = this.length;

        assert(replaced < length);
        assert(replace < length);
    }
    out (key)
    {
        assert(key == this.items[replaced].key);
    }
    body
    {
        CacheItem tmp       = this.items[replace];
        this.items[replace] = this.items[replaced];

        return (this.items[replaced] = tmp).key;
    }

    /***************************************************************************

        Obtains the cache item that corresponds to node and updates the access
        time.
        If realtime is enabled, time is expected to be equal to or
        greater than the time stored in node. If disabled and the access time is
        less, the node will not be updated and null returned.


        Params:
            node = time-to-index tree node
            access_time = access time

        Returns:
            the cache item or a null if realtime is disabled and the access time
            is less than the access time in the node.

        Out:
            If realtime is enabled, the returned pointer is never null.

    ***************************************************************************/

    protected CacheItem* access ( ref TimeToIndex.Node node, out time_t access_time )
    out (item)
    {
        assert (item !is null);
    }
    body
    {
        return this.getItem(this.accessIndex(node, access_time));
    }

    /***************************************************************************

        Obtains the cache item that corresponds to node and updates the access
        time.
        If realtime is enabled and key could be found, time is expected to be at
        least the time value stored in node. If disabled and access_time is
        less, the result is the same as if key could not be found.


        Params:
            key = time-to-index tree node key
            access_time = access time

        Returns:
            the corresponding cache item or null if key could not be found or
            realtime is disabled and the access time is less than the access
            time in the cache element.

    ***************************************************************************/

    protected CacheItem* get__ ( hash_t key, out time_t access_time )
    {
        return this.getItem(this.get_(key, access_time));
    }

    /***************************************************************************

        Obtains the cache item that corresponds to index. Returns null if index
        is length or greater.

        Params:
            index = cache item index

        Returns:
            the corresponding cache item or null if index is length or greater.

    ***************************************************************************/

    protected CacheItem* getItem ( size_t index )
    {
        return (index < this.length)? &this.items[index] : null;
    }

    /***************************************************************************

        Gets an item from the cache or creates it if not already existing. If
        the item was found in the cache, its access time is updated.

        Params:
            key         = key to lookup
            existed     = true:  the item already existed,
                          false: the item was created

        Returns:
            a pointer to the obtained or created item.

        Out:
            The returned pointer is never null.

    ***************************************************************************/

    private CacheItem* getOrAdd ( hash_t key, out bool existed, out time_t access_time )
    out (item)
    {
        assert (item !is null);
    }
    body
    {
        CacheItem* item = this.get__(key, access_time);

        existed = item !is null;

        return existed? item : this.add(key, access_time);
    }

    /***************************************************************************

        Adds an item to the cache. If the cache is full, the oldest item will be
        removed and replaced with the new item.

        Params:
            key         = key of item
            access_time = access time (also the create time)

        Returns:
            the added cache item.

        Out:
            The returned pointer is never null.

    ***************************************************************************/

    protected CacheItem* add ( hash_t key, out time_t access_time )
    out (cache_item)
    {
        assert (cache_item !is null);
    }
    body
    {
        // Add key->item mapping

        CacheItem* cache_item = &this.items[this.register(key, access_time)];

        // Set the key in chosen element of items array.

        cache_item.key = key;

        return cache_item;
    }

    /***************************************************************************

        Makes the GC scan the cache items. Should be called by the subclass
        constructor if it stores values that contain GC references.
        This method should be called after the constructor of this class has
        returned.

    ***************************************************************************/

    static if (!is_dynamic)
    {
        protected void enableGcValueScanning ( )
        in
        {
            assert(this.items,
                   "please call enableGcValueScanning() *after* the super
                    constructor");
        }
        body
        {
            GC.clrAttr(this.items.ptr, GC.BlkAttr.NO_SCAN);
        }
    }

    debug (CacheTimes)
    {
        /**********************************************************************

            String nul-termination buffer

        ***********************************************************************/

        private char[] nt_buffer;

        /**********************************************************************

            Writes the access times and the number of records with that time to
            a file, appending to that file.

        ***********************************************************************/

        void dumpTimes ( char[] filename, time_t now )
        {
            FILE* f = fopen(this.nt_buffer.concat(filename, "\0").ptr, "a");

            if (f)
            {
                scope (exit) fclose(f);

                char[26] buf;

                fprintf(f, "> %10u %s", now, ctime_r(&now, buf.ptr));

                TimeToIndex.Mapping mapping = this.time_to_index.firstMapping;

                if (mapping)
                {
                    time_t t = mapping.key;

                    uint n = 0;

                    foreach (time_t u; this.time_to_index)
                    {
                        if (t == u)
                        {
                            n++;
                        }
                        else
                        {
                            fprintf(f, "%10u %10u\n", t, n);
                            t = u;
                            n = 0;
                        }
                    }
                }
            }
            else
            {
                perror(this.nt_buffer.concat("unable to open \"", filename, "\"\0").ptr);
            }
        }
    }
}

/*******************************************************************************

    Typed cache class template. Stores items of a particular type.

    Template_Params:
        T = type of item to store in cache
        TrackCreateTimes = if true, each cache item is stored with its create
            time, in addition to its last access time

*******************************************************************************/

class Cache ( T, bool TrackCreateTimes = false ) : Cache!(T.sizeof, TrackCreateTimes)
{
    /***************************************************************************

        Constructor.

        Params:
            max_items = maximum number of items in the cache, set once, cannot
                be changed

    ***************************************************************************/

    public this ( size_t max_items )
    {
        super(max_items);
    }

    /***************************************************************************

        Puts an item into the cache. If the cache is full, the oldest item is
        replaced with the new item. (In the case where several items are equally
        old, the choice of which one to be replaced is made arbitrarily.)

        Params:
            key   = item key
            value = item to store in cache

        Returns:
            true if a record was updated / overwritten, false if a new record
            was added

    ***************************************************************************/

    public bool put ( hash_t key, T value )
    {
        bool existed;

        T* dst = this.getOrCreate(key, existed);

        if (dst)
        {
            *dst = value;
        }

        return existed;
    }

    /***************************************************************************

        Creates a cache item and sets the create time. If the cache is full, the
        oldest item is replaced with the new item. (In the case where several
        items are equally old, the choice of which one to be replaced is made
        arbitrarily.)

        Params:
            key   = item key

        Returns:
            true if a record was updated / overwritten, false if a new record
            was added

    ***************************************************************************/

    public T* create ( hash_t key )
    out (val)
    {
        assert (val !is null);
    }
    body
    {
        return cast (T*) this.createRaw(key)[0 .. T.sizeof].ptr;
    }

    /***************************************************************************

        Gets an item from the cache. A pointer to the item is returned, if
        found. If the item exists in the cache, its update time is updated.

        Note that, if the item already existed and you change the value pointed
        to by the returned pointer, the create time will not be updated.

        Params:
            key = key to lookup

        Returns:
            pointer to item value, may be null if key not found

     ***************************************************************************/

    public T* get ( hash_t key )
    {
        return cast (T*) this.getRaw(key);
    }


    /***************************************************************************

        Gets an item from the cache or creates it if not already existing. If
        the item exists in the cache, its update time is updated, otherwise its
        create time is set.

        Note that the create time is set only if an item is created, not if it
        already existed and you change the value referenced by the returned
        pointer.

        Params:
            key         = key to lookup
            existed     = true:  the item already existed,
                          false: the item was created

        Returns:
            pointer to item value

    ***************************************************************************/

    public T* getOrCreate ( hash_t key, out bool existed )
    out (val)
    {
        assert (val !is null);
    }
    body
    {
        return cast (T*) this.getOrCreateRaw(key, existed)[0 .. T.sizeof].ptr;
    }
}

/*******************************************************************************

    Unit test

*******************************************************************************/

version (UnitTest)
{
    import ocean.stdc.posix.stdlib: srand48, mrand48, drand48;
    import ocean.stdc.posix.unistd: getpid;
    import ocean.stdc.time: time;
    import ocean.io.Stdout_tango;
    import ocean.core.Array: shuffle;
}

unittest
{
    srand48(time(null)+getpid());

    static ulong ulrand ( )
    {
        return (cast (ulong) mrand48() << 0x20) | cast (uint) mrand48();
    }

    time_t time = 234567;

    // ---------------------------------------------------------------------
    // Test of static sized cache

    version (all)
    {{
        const n_records  = 33,
              capacity   = 22,
              n_overflow = 7;

        static assert (n_records >= capacity,
                       "Number of records smaller than capacity!");

        struct Record
        {
            hash_t  key; // random number
            size_t  val; // counter
        }

        // Initialise the list of records.

        Record[n_records] records;

        foreach (i, ref record; records)
        {
            record = Record(ulrand(), i);
        }

        // Populate the cache to the limit.

        time_t t = 0;

        scope cache = new class Cache!(size_t)
        {
            this ( ) {super(capacity);}

            override time_t now ( ) {return ++t;}
        };

        assert (capacity == cache.max_length,
                "Max length of cache does not equal configured capacity!");

        foreach (record; records[0 .. cache.max_length])
        {
            cache.put(record.key, record.val);
        }

        // Shuffle records and count how many of the first n_overflow of the
        // shuffled records are in the cache. If either all or none of these are
        // in the cache, shuffle and try again.

        uint n_existing;

        do
        {
            n_existing = 0;
            foreach (i, record; records.shuffle(drand48)[0 .. n_overflow])
            {
                n_existing += cache.exists(record.key);
            }
        }
        while (!n_existing || n_existing == n_overflow);

        assert (n_existing > 0 && n_existing < n_overflow, "n_existing has unexpected value");

        // Get the shuffled records from the cache and verify them. Record the
        // keys of the first n_overflow existing records which will get the
        // least (oldest) access time by cache.getItem() and therefore be the
        // first records to be removed on a cache overflow.

        hash_t[n_overflow] oldest_keys;

        {
            uint i = 0;

            foreach (record; records)
            {
                auto v = cache.get(record.key);

                if (record.val < cache.max_length)
                {
                    assert (v !is null);
                    assert (*v == record.val);

                    if (i < n_overflow)
                    {
                        oldest_keys[i++] = record.key;
                    }
                }
                else
                {
                    assert (v is null);
                }
            }

            assert (i == n_overflow);
        }

        assert (t == cache.max_length * 2);

        // Put the first n_overflow shuffled records so that the cache will
        // overflow.
        // Existing records should be updated to a new value. To enable
        // verification of the update, change the values to 4711 + i.

        foreach (i, ref record; records[0 .. n_overflow])
        {
            record.val = 4711 + i;

            cache.put(record.key, record.val);
        }

        assert (t == cache.max_length * 2 + n_overflow);

        // Verify the records.

        foreach (i, record; records[0 .. n_overflow])
        {
            auto v = cache.get(record.key);

            assert (v !is null);
            assert (*v == 4711 + i);
        }

        assert (t == cache.max_length * 2 + n_overflow * 2);

        // oldest_keys[n_existing .. $] should have been removed from the
        // cache due to cache overflow.

        foreach (key; oldest_keys[n_existing .. $])
        {
            auto v = cache.get(key);

            assert (v is null);
        }

        // cache.get should not have evaluated the lazy ++t.

        assert (t == cache.max_length * 2 + n_overflow * 2);

        // Verify that all other records still exist in the cache.

        {
            uint n = 0;

            foreach (record; records[n_overflow .. $])
            {
                auto v = cache.get(record.key);

                if (v !is null)
                {
                    assert (*v == record.val);

                    n++;
                }
            }

            assert (n == cache.max_length - n_overflow);
        }

        assert (t == cache.max_length * 3 + n_overflow);
    }}
    else
    {
        struct Data
        {
            int x;
        }

        scope static_cache = new Cache!(Data)(2);

        with (static_cache)
        {
            assert(length == 0);

            {
                bool replaced = put(1, time, Data(23));

                assert(!replaced);

                assert(length == 1);
                assert(exists(1));

                Data* item = get(1, time);
                assert(item);
                assert(item.x == 23);
            }

            {
                bool replaced = put(2, time + 1, Data(24));

                assert(!replaced);

                assert(length == 2);
                assert(exists(2));

                Data* item = get(2, time + 1);
                assert(item);
                assert(item.x == 24);
            }

            {
                bool replaced = put(2, time + 1, Data(25));

                assert(replaced);

                assert(length == 2);
                assert(exists(2));

                Data* item = get(2, time + 1);
                assert(item);
                assert(item.x == 25);
            }

            {
                bool replaced = put(3, time + 2, Data(26));

                assert(!replaced);

                assert(length == 2);
                assert(!exists(1));
                assert(exists(2));
                assert(exists(3));

                Data* item = get(3, time + 2);
                assert(item);
                assert(item.x == 26);
            }

            {
                bool replaced = put(4, time + 3, Data(27));

                assert(!replaced);

                assert(length == 2);
                assert(!exists(1));
                assert(!exists(2));
                assert(exists(3));
                assert(exists(4));

                Data* item = get(4, time + 3);
                assert(item);
                assert(item.x == 27);
            }

            clear();
            assert(length == 0);

            {
                bool replaced = put(1, time, Data(23));

                assert(!replaced);

                assert(length == 1);
                assert(exists(1));

                Data* item = get(1, time);
                assert(item);
                assert(item.x == 23);
            }

            {
                bool replaced = put(2, time + 1, Data(24));

                assert(!replaced);

                assert(length == 2);
                assert(exists(2));

                Data* item = get(2, time + 1);
                assert(item);
                assert(item.x == 24);
            }

            remove(1);
            assert(length == 1);
            assert(!exists(1));
            assert(exists(2));
        }
    }

    // ---------------------------------------------------------------------
    // Test of dynamic sized cache

    {
        ubyte[] data1 = cast(ubyte[])"hello world";
        ubyte[] data2 = cast(ubyte[])"goodbye world";
        ubyte[] data3 = cast(ubyte[])"hallo welt";

        scope dynamic_cache = new class Cache!()
        {
            this ( ) {super(2);}

            time_t now_sec ( ) {return ++time;}
        };

        assert(dynamic_cache.length == 0);

        version (all)
        {
            *dynamic_cache.createRaw(1) = data1;
            {
                auto val = dynamic_cache.getRaw(1);
                assert(val !is null);
                assert((*val)[] == data1);
            }

            *dynamic_cache.createRaw(2) = data2;
            {
                auto val = dynamic_cache.getRaw(1);
                assert(val !is null);
                assert((*val)[] == data1);
            }
            {
                auto val = dynamic_cache.getRaw(2);
                assert(val !is null);
                assert((*val)[] == data2);
            }

            *dynamic_cache.createRaw(3) = data3;
            assert(dynamic_cache.getRaw(1) is null);
            {
                auto val = dynamic_cache.getRaw(2);
                assert(val !is null);
                assert((*val)[] == data2);
            }
            {
                auto val = dynamic_cache.getRaw(3);
                assert(val !is null);
                assert((*val)[] == data3);
            }

            dynamic_cache.clear;
            assert(dynamic_cache.length == 0);

            *dynamic_cache.createRaw(1) = data1;
            assert(dynamic_cache.length == 1);
            {
                auto val = dynamic_cache.getRaw(1);
                assert(val !is null);
                assert((*val)[] == data1);
            }

            *dynamic_cache.createRaw(2) = data2;
            assert(dynamic_cache.length == 2);
            {
                auto val = dynamic_cache.getRaw(2);
                assert(val !is null);
                assert((*val)[] == data2);
            }

            dynamic_cache.remove(1);
            assert(dynamic_cache.length == 1);
            assert(dynamic_cache.getRaw(1) is null);
            {
                auto val = dynamic_cache.getRaw(2);
                assert(val !is null);
                assert((*val)[] == data2);
            }
        }
        else
        {
            dynamic_cache.putRaw(1, data1);
            assert(dynamic_cache.exists(1));
            assert((*dynamic_cache.getRaw(1))[] == data1);

            dynamic_cache.putRaw(2, data2);
            assert(dynamic_cache.exists(1));
            assert(dynamic_cache.exists(2));
            assert((*dynamic_cache.getRaw(1))[] == data1);
            assert((*dynamic_cache.getRaw(2))[] == data2);

            dynamic_cache.putRaw(3, data3);
            assert(!dynamic_cache.exists(1));
            assert(dynamic_cache.exists(2));
            assert(dynamic_cache.exists(3));
            assert((*dynamic_cache.getRaw(2))[] == data2);
            assert((*dynamic_cache.getRaw(3))[] == data3);

            dynamic_cache.clear;
            assert(dynamic_cache.length == 0);

            dynamic_cache.putRaw(1, data1);
            assert(dynamic_cache.length == 1);
            assert(dynamic_cache.exists(1));
            assert((*dynamic_cache.getRaw(1))[] == data1);

            dynamic_cache.putRaw(2, data2);
            assert(dynamic_cache.length == 2);
            assert(dynamic_cache.exists(2));
            assert((*dynamic_cache.getRaw(2))[] == data2);

            dynamic_cache.remove(1);
            assert(dynamic_cache.length == 1);
            assert(!dynamic_cache.exists(1));
            assert(dynamic_cache.exists(2));
        }
    }
}




/*******************************************************************************

    Performance test

*******************************************************************************/

debug ( OceanPerformanceTest )
{
    import ocean.core.Memory;

    import ocean.math.random.Random;

    import ocean.time.StopWatch;

    import ocean.io.Stdout : Stderr;

    unittest
    {
        GC.disable;

        Stderr.formatln("Starting Cache performance test");

        auto random = new Random;

        const cache_size = 100_000;

        const max_item_size = 1024 * 4;

        StopWatch sw;

        auto cache = new Cache!()(cache_size);

        ubyte[] value;
        value.length = max_item_size;

        time_t time = 1;

        // Fill cache
        Stderr.formatln("Filling cache:");
        sw.start;
        for ( uint i; i < cache_size; i++ )
        {
            cache.put(i, time, value);
            ubyte d_time;
            random(d_time);
            time += d_time % 16;
        }
        Stderr.formatln("{} puts, {} puts/s", cache_size, cast(float)cache_size / (cast(float)sw.microsec / 1_000_000));

        // Put values into full cache
        const puts = 1_000_000;
        Stderr.formatln("Writing to cache:   ");
        sw.start;
        for ( uint i; i < puts; i++ )
        {
            cache.put(i % cache_size, time, value);
            ubyte d_time;
            random(d_time);
            time += d_time % 16;
        }
        Stderr.formatln("{} puts, {} puts/s", puts, cast(float)puts / (cast(float)sw.microsec / 1_000_000));

        // Get values from cache
        const gets = 1_000_000;
        Stderr.formatln("Reading from cache: {} gets, {} gets/s", gets, cast(float)gets / (cast(float)sw.microsec / 1_000_000));
        sw.start;
        for ( uint i; i < gets; i++ )
        {
            cache.get(i % cache_size, time);
            ubyte d_time;
            random(d_time);
            time += d_time % 16;
        }
        Stderr.formatln("Writing to cache: {} gets, {} gets/s", gets, cast(float)gets / (cast(float)sw.microsec / 1_000_000));

        Stderr.formatln("Cache performance test finished");
    }
}

version (CacheTest) void main ( ) { }


unittest
{
    class CacheImpl: Cache!()
    {
        private bool* item_dropped;
        private size_t* index;

        public this (size_t max_items, bool* item_dropped)
        {
            super(max_items);
            this.item_dropped = item_dropped;
        }

        protected override void whenCacheItemDropped ( size_t index )
        {
            *item_dropped = true;
        }
    }


   // Test if the whenCacheItemDropped is being called
    const max_items = 10;
    auto item_dropped = false;
    size_t index = 0;

    auto cache = new CacheImpl( max_items, &item_dropped );

    for(int i = 0; i < max_items * 2; i++)
    {
        auto data = cache.createRaw(i);

        if(i > max_items - 1)
        {
            // Test if it is being called
            test(item_dropped);

            // Test the next case
            item_dropped = false;
        }
        else
        {
            test(!item_dropped);
        }
    }
}

