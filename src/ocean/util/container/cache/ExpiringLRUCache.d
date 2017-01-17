/*******************************************************************************

    Expiring (L)east (R)ecently (U)sed Cache.

    Extends the Cache by providing a settable lifetime and automatically
    removing  elements where the difference between the current time and the
    createtime is greater than that lifetime value.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.cache.ExpiringLRUCache;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.util.container.cache.model.IExpiringCacheInfo;

import ocean.util.container.cache.LRUCache;

import ocean.stdc.time: time_t;

/*******************************************************************************

    Data cache class template with element life time limitation. Stores items of
    raw data, either of fixed or dynamic size. When the life time of an item,
    which is the difference between its creation time and the current wall clock
    time, has expired, it is removed automatically on the next
    getAndRefreshValue()/exists() access.

    Template_Params:
        T = the type of data that will be stored

*******************************************************************************/

class ExpiringLRUCache(T = void[]) : LRUCache!(T, true), IExpiringCacheInfo
{
    /***************************************************************************

        Life time for all items in seconds; may be changed at any time.
        This value must be at least 1.

    ***************************************************************************/

    public time_t lifetime;

    /***************************************************************************

        Counts the number of lookups where an existing element was expired.

    ***************************************************************************/

    protected uint n_expired = 0;

    /***************************************************************************

        Constructor.

        Params:
            max_items = maximum number of items in the cache, set once, cannot
                        be changed
            lifetime  = life time for all items in seconds; may be changed at
                        any time. This value must be at least 1.

    ***************************************************************************/

    public this ( size_t max_items, time_t lifetime )
    in
    {
        assert (lifetime > 0,
                "cache element lifetime is expected to be at least 1");
    }
    body
    {
        super(max_items);

        this.lifetime = lifetime;
    }

    /***************************************************************************

        Gets an item from the cache. If the item was found in the cache, its
        access time is updated. If the item life time has expired, it is
        automatically removed.

        Note that, if you change the value referenced by the returned reference,
        the create time will not be updated.

        Params:
            key = key to lookup

        Returns:
            a reference to the item value or null if no such item was found or
            it has expired so it was removed.

    ***************************************************************************/

    public override T* getAndRefresh ( hash_t key )
    {
        bool existed;

        return this.getAndRefresh(key, existed);
    }

    /// ditto
    public alias LRUCache!(T, true).getAndRefresh getAndRefresh;

    /***************************************************************************

        Gets an item from the cache. If the item was found in the cache, its
        access time is updated. If the item life time has expired, it is
        automatically removed.

        Note that, if you change the value referenced by the returned reference,
        the create time will not be updated.

        Params:
            key     = key to lookup
            expired = true:  the item was found but expired so it was removed,
                      false: the item was not found

        Returns:
            a reference to the item value or null if no such item was found or
            it has expired so it was removed.

        Out:
            - If expired, the returned reference is null.

    ***************************************************************************/

    public T* getAndRefresh ( hash_t key, out bool expired )
    out (val)
    {
        if (expired) assert (val is null);
    }
    body
    {
        bool existed;

        T* val = this.getExpiringOrCreate(key, existed);

        expired = !val && existed;

        return val;
    }

    /***************************************************************************

        Gets an item from the cache or creates it if not already existing. If
        the item was found in the cache, its access time is updated, otherwise
        its create time is set. If the item was found but was expired, the
        effect is the same as if the item was not found.

        Note that the create time is set only if an item is created, not if it
        already existed and you change the value referenced by the returned
        reference.

        Params:
            key     = key to lookup
            existed = true:  the item already existed,
                      false: the item was created either because it did not
                             exist or was expired

        Returns:
            a reference to the value of the obtained or created item. If an old
            item was replaced, this reference refers to the old value.

        Out:
            See super class.

    ***************************************************************************/

    public override T* getRefreshOrCreate ( hash_t key, out bool existed )
    {
        return this.getExpiringOrCreate(key, existed, true);
    }

    /***************************************************************************

        Imports the super class overloaded methods which were hidden by the
        getOrCreate() override implementation.

    ***************************************************************************/

    alias LRUCache!(T, true).getRefreshOrCreate getRefreshOrCreate;

    /***************************************************************************

        Checks whether an item exists in the cache and updates its access time.
        If the life time of the item has expired, it is removed.

        Params:
            key     = key to lookup
            expired = true: an item was found but removed because it was expired

        Returns:
            true if item exists in cache and its life time is not yet expired.

        Out:
            If expired is false, the return value is false.

    ***************************************************************************/

    public bool exists ( hash_t key, out bool expired )
    out (does_exist)
    {
        if (expired) assert (!does_exist);
    }
    body
    {
        return this.getAndRefresh(key, expired) !is null;
    }

    /***************************************************************************

        Checks whether an item exists in the cache and updates its access time.
        If the life time of the item has expired, it is removed.

        Params:
            key = key to lookup

        Returns:
            true if item exists in cache and its life time is not yet expired.

    ***************************************************************************/

    override public bool exists ( hash_t key )
    {
        bool expired;

        return this.exists(key, expired);
    }

    /***************************************************************************

        Returns:
            the number of cache lookups  since instantiation or the last call of
            resetStats() where the element could be found but was expired.

    ***************************************************************************/

    public uint num_expired ( )
    {
        return this.n_expired;
    }

    /***************************************************************************

        Resets the statistics counter values.

    ***************************************************************************/

    public override void resetStats ( )
    {
        super.resetStats();
        this.n_expired = 0;
    }

    /***************************************************************************

        Gets an item from the cache or optionally creates it if not already
        existing. If the item was found in the cache, its access time is
        updated, otherwise its create time is set. If the item was found but was
        expired, the effect is the same as if the item was not found.

        Note that the create time is set only if an item is created, not if it
        already existed and you change the value referenced by the returned
        reference.

        Params:
            key     = key to lookup
            existed = true:  the item already existed,
                      false: the item did not exist or was expired
            create  = true: create the item if it doesn't exist or is expired

        Returns:
            a reference to the value of the obtained or created item. If an old
            item was replaced, this reference refers to the old value.

        Out:
            - If create is true, the returned reference is not null.
            - If create and existed are false, the returned reference is null.

    ***************************************************************************/

    private T* getExpiringOrCreate ( hash_t key, out bool existed,
                                     bool create = false )
    in
    {
        assert (this.lifetime > 0,
                "cache element lifetime is expected to be at least 1");
    }
    out (val)
    {
        if (create)
        {
            assert (val !is null);
        }
        else if (!existed)
        {
            assert (val is null);
        }
    }
    body
    {
        Value* item;

        time_t new_access_time;
        if (create)
        {
            item = this.getRefreshOrCreateRaw(key, new_access_time, existed);
        }
        else
        {
            item = this.getAndRefreshRaw(key, new_access_time);
            existed = item !is null;
        }

        if (item)
        {
            // If we reached that point, then it must be an old item which
            // existed before. We should check if it has expired
            if (new_access_time >= item.create_time &&
                this.lifetime <= (new_access_time - item.create_time))
            {
                existed = false;
                this.remove(key);
                item = null;

                this.n_expired++;
                // TODO: increase these ones
                // this.n_misses++;
            }

            return &item.value;
        }
        else
        {
            // The misses was already increased, no need to do it again
            return null;
        }
    }
}

/******************************************************************************/

import ocean.stdc.posix.stdlib: srand48, mrand48, drand48;
import ocean.stdc.time: time;


extern (C) int getpid();


unittest
{
    srand48(time(null)+getpid());

    static ulong ulrand ( )
    {
        return (cast (ulong) mrand48() << 0x20) | cast (uint) mrand48();
    }

    time_t time = 234567;

    // ---------------------------------------------------------------------
    // Test of expiring cache

    {
        mstring data1 = "hello world".dup,
                data2 = "goodbye world".dup,
                data3 = "hallo welt".dup;

        time_t t = 0;

        scope expiring_cache = new class ExpiringLRUCache!()
        {
            this ( ) {super(4, 10);}

            override time_t now ( ) {return ++t;}
        };

        with (expiring_cache)
        {
            assert(length == 0);

            *getRefreshOrCreate(1) = data1;
            assert(length == 1);
            assert(exists(1));
            {
                auto data = getAndRefresh(1);
                assert(data !is null);
                assert((*data)[] == data1);
            }

            assert(t <= 5);
            t = 5;

            *getRefreshOrCreate(2) = data2;
            assert(length == 2);
            assert(exists(2));
            {
                auto data = getAndRefresh(2);
                assert(data !is null);
                assert((*data)[] == data2);
            }

            assert(t <= 10);
            t = 10;

            assert(!exists(1));

            assert(t <= 17);
            t = 17;
            {
                auto data = getAndRefresh(2);
                assert(data is null);
            }
        }
    }

}

unittest
{
    // check cache with const elements
    scope expiring_cache = new ExpiringLRUCache!(cstring)(1, 1);
    *expiring_cache.getRefreshOrCreate(1) = "abc"[];
}
