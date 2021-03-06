/*******************************************************************************

    Cache with an element expiration facility.

    Extends the Cache by providing a settable lifetime and automatically
    removing  elements where the difference between the current time and the
    createtime is greater than that lifetime value.

    The cache can be configured to apply different lifetimes to empty and
    non-empty values (where a cached record with array length 0 is considered
    "empty"). See constructor arguments.

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.cache.ExpiringCache;

import ocean.meta.types.Qualifiers;

import ocean.util.container.cache.model.IExpiringCacheInfo;

import ocean.util.container.cache.Cache;

import core.stdc.time: time_t;

version (unittest)
{
    import ocean.core.Test;
}


/*******************************************************************************

    Data cache class template with element life time limitation. Stores items of
    raw data, either of fixed or dynamic size. When the life time of an item,
    which is the difference between its creation time and the current wall clock
    time, has expired, it is removed automatically on the next getRaw()/exists()
    access.

    Params:
        ValueSize = size of a data item. If 0 is specified (the default), the
            items stored in the cache are of variable (dynamic) size

*******************************************************************************/

class ExpiringCache ( size_t ValueSize = 0 ) : Cache!(ValueSize, true),
                                               IExpiringCacheInfo
{
    import ocean.core.Verify;

    /***************************************************************************

        Life time for non-empty items in seconds; may be changed at any time.
        This value must be at least 1.

    ***************************************************************************/

    public time_t lifetime;

    /***************************************************************************

        Life time for empty items in seconds; may be changed at any time.
        This value must be at least 1. Can be same as `lifetime`.

        ExpiringCache considers a cached record with array length 0 as being
        "empty".

    ***************************************************************************/

    public time_t empty_lifetime;

    /***************************************************************************

        Counts the number of lookups where an existing element was expired.

    ***************************************************************************/

    protected uint n_expired = 0;

    /***************************************************************************

        Constructor.

        Params:
            max_items = maximum number of items in the cache, set once, cannot
                be changed
            lifetime = lifetime for non-empty items in seconds; may be changed
                at any time. This value must be at least 1.
            empty_lifetime = lifetime for empty items in seconds. If set to 0
                (default), will be same as regular `lifetime`

    ***************************************************************************/

    public this ( size_t max_items, time_t lifetime, time_t empty_lifetime = 0 )
    {
        verify (lifetime > 0,
                "cache element lifetime is expected to be at least 1");

        super(max_items);

        this.lifetime = lifetime;
        this.empty_lifetime = empty_lifetime ? empty_lifetime : lifetime;
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

        Out:
            See super class.

    ***************************************************************************/

    public override ValueRef getRaw ( hash_t key )
    {
        bool existed;

        return this.getExpiringOrCreate(key, existed);
    }

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
            - See super class.

    ***************************************************************************/

    public ValueRef getRaw ( hash_t key, out bool expired )
    out (val)
    {
        if (expired) assert (val is null);
    }
    do
    {
        bool existed;

        ValueRef val = this.getExpiringOrCreate(key, existed);

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

    public override ValueRef getOrCreateRaw ( hash_t key, out bool existed )
    {
        return this.getExpiringOrCreate(key, existed, true);
    }

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
    do
    {
        return this.getRaw(key, expired) !is null;
    }

    /***************************************************************************

        Checks whether an item exists in the cache and updates its access time.
        If the life time of the item has expired, it is removed.

        Params:
            key = key to lookup

        Returns:
            true if item exists in cache and its life time is not yet expired.

    ***************************************************************************/

    public override bool exists ( hash_t key )
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

    private ValueRef getExpiringOrCreate ( hash_t key, out bool existed,
                                           bool create = false )
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
    do
    {
        TimeToIndex.Node** node = key in this;

        // opIn_r may return null but never a pointer to null.

        CacheItem* cache_item = null;

        existed = node !is null;

        if (existed)
        {
            time_t access_time;

            cache_item = this.access(**node, access_time);
            // XXX: This was previously an assert() but it was changed to
            // verify() due to a compiler bug when using -release -inline -O.
            // In that case the null check is removed by -release and it seems
            // that due to compiler optimizations and inlining, the compiler
            // ends up thinking that cache_item is null when used afterwards
            // (in the following if statement for example). By using verify()
            // instead of assert() we make sure the compiler can see there is a
            // null check even when -release is used.
            verify(cache_item !is null,
                    "cache item existed, so it shouldn't be null");
            bool empty = cache_item.value_ref.length == 0;

            time_t used_lifetime = empty ? this.empty_lifetime : this.lifetime;
            verify (used_lifetime > 0,
                "cache element lifetime is expected to be at least 1");

            if (access_time >= cache_item.create_time)
            {
                /*
                 * We silently tolerate the case the element was created after
                 * its last access because with the system time as external
                 * data source this is theoretically possible and at least no
                 * program bug.
                 */

                existed = (access_time - cache_item.create_time) < used_lifetime;
            }

            if (!existed)
            {
                if (create)
                {
                    cache_item.create_time = access_time;
                }
                else
                {
                    this.remove_(key, **node);
                    cache_item = null;
                }

                this.n_expired++;
                this.n_misses++;
            }
        }
        else if (create)
        {
            time_t access_time;

            cache_item = this.add(key, access_time);

            cache_item.create_time = access_time;
        }

        return cache_item? cache_item.value_ref : null;
    }
}

/******************************************************************************/

import core.sys.posix.stdlib: srand48, mrand48, drand48;
import core.stdc.time: time;

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

        scope expiring_cache = new class ExpiringCache!()
        {
            this ( ) {super(4, 10, 5);}

            override time_t now ( ) {return ++t;}
        };

        with (expiring_cache)
        {
            test!("==")(length, 0);

            *createRaw(1) = data1;
            test!("==")(length, 1);
            test(exists(1));
            {
                Value* data = getRaw(1);
                test!("!is")(data, null);
                test!("==")((*data)[], data1);
            }

            test!("<=")(t, 5);
            t = 5;

            *createRaw(2) = data2;
            test!("==")(length, 2);
            test(exists(2));
            {
                Value* data = getRaw(2);
                test!("!is")(data, null);
                test!("==")((*data)[], data2);
            }

            test!("<=")(t, 10);
            t = 10;

            test(!exists(1));

            test!("<=")(t, 17);
            t = 17;

            {
                Value* data = getRaw(2);
                test!("is")(data, null);
            }
        }

        // Test clear().
        with (expiring_cache)
        {
            t = 5;

            test!("==")(length, 0);

            *createRaw(1) = data1;
            test!("==")(length, 1);
            test(exists(1));

            *createRaw(2) = data2;
            test!("==")(length, 2);
            test(exists(2));

            clear();
            test!("==")(length, 0);
            test(!exists(1));
            test(!exists(2));
        }

        // Test empty records
        with (expiring_cache)
        {
            t = 0;
            test!("==")(length, 0);

            *createRaw(1) = data1;
            test!("==")(length, 1);
            test(exists(1));

            *getRaw(1) = null;
            test!("==")(length, 1);
            test(exists(1));

            t = 6; // less than 10, more than 5
            {
                Value* data = getRaw(1);
                test!("is")(data, null);
            }
        }
    }

}
