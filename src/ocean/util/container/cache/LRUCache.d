/*******************************************************************************

    (L)east (R)ecently (U)sed Cache class, Caches data items according to their
    access time and discards item that were least recently accessed.

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

    Cache.getOrCreate() return a reference to a record in the cache.
    Cache.getAndRefresh() return a reference to a record in the cache or
    returns null otherwise.
    For fixed length values the record value reference is a slice to the record
    value.
    Usage example:

    ---

        import ocean.util.container.LRUCache;

        // Create a fixed-size cache which can store 2 items, each of length 3.
        auto cache = new LRUCache!(char[3])(2);

        // Add an item using getOrCreate(). getOrCreate() returns a pointer to
        // void[] array with length 3 which references the value in the cache.

        hash_t key = 0x12345678;

        char[3] val = "abc";

        *cache.getOrCreate(key) = val[];

        // Obtain an item using getAndRefresh(). If found, getAndRefresh()
        // returns a pointer to a value slice just like getOrCreate() or null
        // if not found.

        char[] val_got = cache.getAndRefresh(key);

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

        auto cache = new LRUCache!(char[])(100);

        char[] str1 = "Hello World",
               str2 = "Eggs and Spam";

        {
            auto val = cache.getRefreshOrCreate(4711);

            // Store a slice to str1 in the array using (*val).opAssign.

            *val = str1;
        }

        {
            auto val = cache.getAndRefresh(4711);

            // (*val)[] ((*val).opSlice) now returns a slice to str1.

            // Replace this value with a slice to str2 using (*val).opAssign.

            *val = str2;
        }

    ---

    Usage Example 2: Store copies of strings in a cache using
                     Value.opSliceAssign.

    ---

        auto cache = new LRUCache!(char[])(100);

        char[] str1 = "Hello World",
               str2 = "Eggs and Spam";

        {
            auto val = cache.getRefreshOrCreate(4711);

            // Allocate a value array buffer with str1.length and copy the
            // content of str1 into that value buffer.

            (*val)[] = str1;
        }

        {
            auto val = cache.getAndRefresh(4711);

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

        auto cache = new LRUCache!(char[])(100);

        auto val = cache.getRefreshOrCreate(4711);

        void[]* val_array = cast (void[]*) (*val);

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

module ocean.util.container.cache.LRUCache;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.cache.PriorityCache;
import ocean.stdc.time: time_t, time;

import core.memory;
import Traits = ocean.core.Traits;

/*******************************************************************************

    Creates an extra create_time field depending on the template parameter.

    Template_Params:
        T = the type of value to store
        TrackCreateTimes = flags whether a create_time field should be created

*******************************************************************************/

private struct ValueT(T,  bool TrackCreateTimes)
{
    T value;
    static if (TrackCreateTimes)
    {
        time_t create_time;
    }
}

/*******************************************************************************

    Data cache class template. Stores items of raw data, either of fixed or
    dynamic size.

    Template_Params:
        T = type of item to store in cache
        TrackCreateTimes = if true, each cache item is stored with its create
            time, in addition to its last access time

*******************************************************************************/

class LRUCache(T, bool TrackCreateTimes = false) : PriorityCache!(ValueT!(T, TrackCreateTimes))
{
    /***************************************************************************

        An alias for the type stored in PriorityCache.

        The stored type is a wrapper around T which might (or might not) add
        extra fields in addition to T be stored (depending on the
        TrackCreateTimes template parameters).

    ***************************************************************************/

    protected alias ValueT!(T, TrackCreateTimes) Value;

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

        T* dst = this.getRefreshOrCreate(key, existed);

        if (dst)
        {
            // This check is not needed in D2
            static if ( Traits.isStaticArrayType!(T) )
            {
                // TODO: Add support in PriorityCache.opApply for arrays
                (*dst)[] = value[];
            }
            else
            {
                (*dst) = value;
            }
        }

        return existed;
    }

    /***************************************************************************

        Gets an item from the cache or creates it if not already existing. If
        the item exists in the cache, its update time is updated, otherwise its
        create time is set.

        Note that the create time is set only if an item is created, not if it
        already existed and you change the value referenced by the returned
        pointer.

        Params:
            key         = key to lookup or create

        Returns:
            The returned reference is never null.

    ***************************************************************************/

    public T* getRefreshOrCreate ( hash_t key )
    out (val)
    {
        assert (val !is null);
    }
    body
    {
        bool existed_ignore;

        return this.getRefreshOrCreate(key, existed_ignore);
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
            The returned reference is never null.

    ***************************************************************************/

    public T* getRefreshOrCreate ( hash_t key, out bool existed )
    out (val)
    {
        assert (val !is null);
    }
    body
    {
        time_t access_time;

        return this.getRefreshOrCreate(key, access_time, existed);
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
            access_time = access time of the element
            existed     = true:  the item already existed,
                          false: the item was created

        Returns:
            a reference to the value of the obtained or created item. If an item
            was created, the returned reference may refer to the value of a
            previously removed element.

        Out:
            The returned reference is never null.

    ***************************************************************************/

    public T* getRefreshOrCreate ( hash_t key, out time_t access_time, out bool existed )
    out (val)
    {
        assert (val !is null);
    }
    body
    {
        if ( Value* val = this.getRefreshOrCreateRaw(key, access_time, existed) )
        {
            return &val.value;
        }
        else
        {
            return null;
        }
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
            access_time = access time of the element
            existed     = true:  the item already existed,
                          false: the item was created

        Returns:
            a reference to the value of the obtained or created item. If an item
            was created, the returned reference may refer to the value of a
            previously removed element.

        Out:
            The returned reference is never null.

    ***************************************************************************/

    protected Value* getRefreshOrCreateRaw ( hash_t key, out time_t access_time, out bool existed )
    out (val)
    {
        assert (val !is null);
    }
    body
    {
        access_time = this.now();

        Value* value = this.getUpdateOrCreate(key, access_time, existed);
        static if ( TrackCreateTimes )
        {
            if (!existed)
            {
                value.create_time = access_time;
            }
        }

        return value;
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

    public T* getAndRefresh ( hash_t key )
    {
        time_t access_time;
        return this.getAndRefresh(key, access_time);
    }

    /***************************************************************************

        Gets an item from the cache. A pointer to the item is returned, if
        found. If the item exists in the cache, its update time is updated.

        Note that, if the item already existed and you change the value pointed
        to by the returned pointer, the create time will not be updated.

        Params:
            key = key to lookup
            access_time = access time of the element

        Returns:
            pointer to item value, may be null if key not found

    ***************************************************************************/

    public T* getAndRefresh (hash_t key, out time_t access_time)
    {
        if ( Value* val = this.getAndRefreshRaw(key, access_time) )
        {
            return  &val.value;
        }
        else
        {
            return null;
        }
    }

    /***************************************************************************

        Gets an item from the cache. A pointer to the item is returned, if
        found. If the item exists in the cache, its update time is updated.

        Note that, if the item already existed and you change the value pointed
        to by the returned pointer, the create time will not be updated.

        Params:
            key = key to lookup
            access_time = access time of the element

        Returns:
            pointer to item value, may be null if key not found

    ***************************************************************************/

    protected Value* getAndRefreshRaw(hash_t key, out time_t access_time)
    {
        return this.updatePriority(key, access_time = this.now());
    }

    /***************************************************************************

        Obtains the current time. By default this is the wall clock time in
        seconds.
        This time value is used to find the least recently updated cache item
        and stored as create time. A subclass may override this method to use a
        different time unit or clock.


        Returns:
            the current time in seconds.

    ***************************************************************************/

    protected time_t now ( )
    {
        return .time(null);
    }
}
