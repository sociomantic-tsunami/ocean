/*******************************************************************************

    Contains unit-tests for LRUCache class.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.cache.LRUCache_test;

/*******************************************************************************

    Imports

*******************************************************************************/

version (UnitTest)
{
    import ocean.util.container.cache.LRUCache;
    import ocean.core.Array: shuffle;
    import ocean.core.Test;

    import core.memory;
    import ocean.math.random.Random;
    import ocean.io.Stdout_tango;
    import ocean.stdc.posix.stdlib: srand48, mrand48, drand48;
    import ocean.stdc.posix.unistd: getpid;
    import core.stdc.stdio : printf;
    import core.stdc.time: time_t, time;
    import ocean.time.StopWatch;
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

    {
        const n_records  = 33,
              capacity   = 22,
              n_overflow = 7;

        static assert (n_records >= capacity,
                       "Number of records smaller than capacity!");

        struct Record
        {
            hash_t    key; // random number
            size_t    val; // counter
        }

        // Initialise the list of records.

        Record[n_records] records;

        foreach (i, ref record; records)
        {
            record = Record(ulrand(), i);
        }

        // Populate the cache to the limit.

        time_t t = 0;

        scope cache = new class LRUCache!(size_t)
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
                auto v = cache.getAndRefresh(record.key);

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

        foreach (int i, ref record; records[0 .. n_overflow])
        {
            record.val = 4711 + i;

            cache.put(record.key, record.val);
        }

        assert (t == cache.max_length * 2 + n_overflow);

        // Verify the records.

        foreach (i, record; records[0 .. n_overflow])
        {
            auto v = cache.getAndRefresh(record.key);

            assert (v !is null);
            assert (*v == 4711 + i);
        }

        assert (t == cache.max_length * 2 + n_overflow * 2);

        // oldest_keys[n_existing .. $] should have been removed from the
        // cache due to cache overflow.

        foreach (key; oldest_keys[n_existing .. $])
        {
            auto v = cache.getAndRefresh(key);

            assert (v is null);
        }

        // cache.get should not have evaluated the lazy ++t.

        assert (t == cache.max_length * 2 + n_overflow * 2);

        // Verify that all other records still exist in the cache.

        {
            uint n = 0;

            foreach (record; records[n_overflow .. $])
            {
                auto v = cache.getAndRefresh(record.key);

                if (v !is null)
                {
                    assert (*v == record.val);

                    n++;
                }
            }

            assert (n == cache.max_length - n_overflow);
        }

        assert (t == cache.max_length * 3 + n_overflow);
    }

    // More tests to the LRUCache
    {
        struct Data
        {
            int x;
        }

        time_t t = 500;

        scope static_cache = new class LRUCache!(Data)
        {
            this ( ) {super(2);}

            override time_t now ( ) {return t;}
        };

        with (static_cache)
        {
            assert(length == 0);

            {
                bool replaced = put(1, Data(23));

                assert(!replaced);

                assert(length == 1);
                assert(exists(1));

                Data* item = getAndRefresh(1);
                assert(item);
                assert(item.x == 23);
            }

            {
                t += 1;
                bool replaced = put(2, Data(24));

                assert(!replaced);

                assert(length == 2);
                assert(exists(2));

                Data* item = getAndRefresh(2);
                assert(item);
                assert(item.x == 24);
            }

            {
                t += 1;
                bool replaced = put(2, Data(25));

                assert(replaced);

                assert(length == 2);
                assert(exists(2));

                Data* item = getAndRefresh(2);
                assert(item);
                assert(item.x == 25);
            }

            {
                t += 1;
                bool replaced = put(3, Data(26));

                assert(!replaced);

                assert(length == 2);
                assert(!exists(1));
                assert(exists(2));
                assert(exists(3));

                Data* item = getAndRefresh(3);
                assert(item);
                assert(item.x == 26);
            }

            {
                t += 1;
                bool replaced = put(4, Data(27));

                assert(!replaced);

                assert(length == 2);
                assert(!exists(1));
                assert(!exists(2));
                assert(exists(3));
                assert(exists(4));

                Data* item = getAndRefresh(4);
                assert(item);
                assert(item.x == 27);
            }

            clear();
            assert(length == 0);

            {
                bool replaced = put(1, Data(23));

                assert(!replaced);

                assert(length == 1);
                assert(exists(1));

                Data* item = getAndRefresh(1);
                assert(item);
                assert(item.x == 23);
            }

            {
                bool replaced = put(2, Data(24));

                assert(!replaced);

                assert(length == 2);
                assert(exists(2));

                Data* item = getAndRefresh(2);
                assert(item);
                assert(item.x == 24);
            }

            remove(1);
            assert(length == 1);
            assert(!exists(1));
            assert(exists(2));
        }
    }

    // Test notifier for removing items from Cache
    {
        class CacheImpl: LRUCache!(void[])
        {
            private bool* item_dropped;
            private size_t* index;

            public this (size_t max_items, bool* item_dropped)
            {
                super(max_items);
                this.item_dropped = item_dropped;
            }

            protected override void itemDropped (hash_t key, ref CacheImpl.Value value)
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

            auto data = cache.getRefreshOrCreate(i);

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

    // ---------------------------------------------------------------------
    // Test of dynamic sized cache

    {
        ubyte[] data1 = cast(ubyte[])"hello world";
        ubyte[] data2 = cast(ubyte[])"goodbye world";
        ubyte[] data3 = cast(ubyte[])"hallo welt";

        scope dynamic_cache = new class LRUCache!(ubyte[])
        {
            this ( ) {super(2);}

            time_t now_sec ( ) {return ++time;}
        };

        assert(dynamic_cache.length == 0);

        {
            *dynamic_cache.getRefreshOrCreate(1) = data1;
            {
                auto val = dynamic_cache.getAndRefresh(1);
                assert(val !is null);
                assert((*val)[] == data1);
            }

            *dynamic_cache.getRefreshOrCreate(2) = data2;
            {
                auto val = dynamic_cache.getAndRefresh(1);
                assert(val !is null);
                assert((*val)[] == data1);
            }
            {
                auto val = dynamic_cache.getAndRefresh(2);
                assert(val !is null);
                assert((*val)[] == data2);
            }

            *dynamic_cache.getRefreshOrCreate(3) = data3;
            assert(dynamic_cache.getAndRefresh(1) is null);
            {
                auto val = dynamic_cache.getAndRefresh(2);
                assert(val !is null);
                assert((*val)[] == data2);
            }
            {
                auto val = dynamic_cache.getAndRefresh(3);
                assert(val !is null);
                assert((*val)[] == data3);
            }

            dynamic_cache.clear;
            assert(dynamic_cache.length == 0);

            *dynamic_cache.getRefreshOrCreate(1) = data1;
            assert(dynamic_cache.length == 1);
            {
                auto val = dynamic_cache.getAndRefresh(1);
                assert(val !is null);
                assert((*val)[] == data1);
            }

            *dynamic_cache.getRefreshOrCreate(2) = data2;
            assert(dynamic_cache.length == 2);
            {
                auto val = dynamic_cache.getAndRefresh(2);
                assert(val !is null);
                assert((*val)[] == data2);
            }

            dynamic_cache.remove(1);
            assert(dynamic_cache.length == 1);
            assert(dynamic_cache.getAndRefresh(1) is null);
            {
                auto val = dynamic_cache.getAndRefresh(2);
                assert(val !is null);
                assert((*val)[] == data2);
            }
        }

        // More tests for dynamic cache
        {
            dynamic_cache.clear();
            dynamic_cache.put(1, data1);
            assert(dynamic_cache.exists(1));
            assert((*dynamic_cache.getAndRefresh(1))[] == data1);

            dynamic_cache.put(2, data2);
            assert(dynamic_cache.exists(1));
            assert(dynamic_cache.exists(2));
            assert((*dynamic_cache.getAndRefresh(1))[] == data1);
            assert((*dynamic_cache.getAndRefresh(2))[] == data2);

            dynamic_cache.put(3, data3);
            assert(!dynamic_cache.exists(1));
            assert(dynamic_cache.exists(2));
            assert(dynamic_cache.exists(3));
            assert((*dynamic_cache.getAndRefresh(2))[] == data2);
            assert((*dynamic_cache.getAndRefresh(3))[] == data3);

            dynamic_cache.clear;
            assert(dynamic_cache.length == 0);

            dynamic_cache.put(1, data1);
            assert(dynamic_cache.length == 1);
            assert(dynamic_cache.exists(1));
            assert((*dynamic_cache.getAndRefresh(1))[] == data1);

            dynamic_cache.put(2, data2);
            assert(dynamic_cache.length == 2);
            assert(dynamic_cache.exists(2));
            assert((*dynamic_cache.getAndRefresh(2))[] == data2);

            dynamic_cache.remove(1);
            assert(dynamic_cache.length == 1);
            assert(!dynamic_cache.exists(1));
            assert(dynamic_cache.exists(2));
        }
    }

    void performanceTest()
    {
        GC.disable;

        printf("Starting Cache performance test\n".ptr);

        auto random = new Random;

        const cache_size = 100_000;

        const max_item_size = 1024 * 4;

        StopWatch sw;

        time_t time = 1;

        auto cache = new class LRUCache!(ubyte[])
        {
            this ( ) {super(cache_size);}

            override time_t now ( ) {return time;}
        };

        ubyte[] value;
        value.length = max_item_size;

        // Fill cache
        printf("Filling cache\n".ptr);
        sw.start;
        for ( uint i; i < cache_size; i++ )
        {
            cache.put(i, value);
            ubyte d_time;
            random(d_time);
            time += d_time % 16;
        }
        printf("%d puts, %f puts/s\n".ptr, cache_size, cast(float)cache_size / (cast(float)sw.microsec / 1_000_000));

        // Put values into full cache
        const puts = 1_000_000;
        printf("Writing to cache:\n".ptr);
        sw.start;
        for ( uint i; i < puts; i++ )
        {
            cache.put(i % cache_size, value);
            ubyte d_time;
            random(d_time);
            time += d_time % 16;
        }
        printf("%d puts, %f puts/s\n".ptr, puts, cast(float)puts / (cast(float)sw.microsec / 1_000_000));

        // Get values from cache
        const gets = 1_000_000;
        printf("Reading from cache: %d gets, %f gets/s\n".ptr, gets, cast(float)gets / (cast(float)sw.microsec / 1_000_000));
        sw.start;
        for ( uint i; i < gets; i++ )
        {
            cache.getAndRefresh(i % cache_size);
            ubyte d_time;
            random(d_time);
            time += d_time % 16;
        }
        printf("Writing to cache: %d gets, %f gets/s\n".ptr, gets, cast(float)gets / (cast(float)sw.microsec / 1_000_000));

        printf("Cache performance test finished\n".ptr);
    }

    debug ( OceanPerformanceTest ) performanceTest();
}
