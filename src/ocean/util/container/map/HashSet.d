/*******************************************************************************

    Class implementing a set of hashes. The set is built on top of an efficient
    bucket algorithm, allowing for fast look up of hashes in the set.

    Usage example:

    ---

        import ocean.util.container.map.HashSet;

        // A set of hash_t's
        auto set = new HashSet;

        hash_t hash = 232323;

        // Add a hash
        set.put(hash);

        // Check if a hash exists in the set (null if not found)
        auto exists = hash in set;

        // Remove a hash from the set
        set.remove(hash);

        // Clear the set
        set.clear();

    ---

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.map.HashSet;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.map.Set;

version (UnitTestVerbose) import ocean.io.Stdout;



/*******************************************************************************

    Debug switch for verbose unittest output (uncomment if desired)

*******************************************************************************/

//version = UnitTestVerbose;

version ( UnitTestVerbose )
{
    import ocean.io.Stdout_tango;
}

/*******************************************************************************

    HashSet class. Manages a set of hash_t's with fast lookup.

*******************************************************************************/

public class HashSet : Set!(hash_t)
{
    /***************************************************************************

        Constructor, sets the number of buckets to n * load_factor

        Params:
            n = expected number of elements
            load_factor = ratio of n to the number of internal buckets. The
                desired (approximate) number of elements per bucket. For
                example, 0.5 sets the number of buckets to double n; for 2 the
                number of buckets is the half of n. load_factor must be greater
                than 0. The load factor is basically a trade-off between memory
                usage (number of buckets) and search time (number of elements
                per bucket).

    ***************************************************************************/

    public this ( size_t n, float load_factor = 0.75 )
    {
        super(n, load_factor);
    }

    /***************************************************************************

        Constructor.

        Params:
            allocator = custom bucket elements allocator
            n = expected number of elements in mapping
            load_factor = ratio of n to the number of internal buckets. The
                desired (approximate) number of elements per bucket. For
                example, 0.5 sets the number of buckets to double n; for 2 the
                number of buckets is the half of n. load_factor must be greater
                than 0. The load factor is basically a trade-off between memory
                usage (number of buckets) and search time (number of elements
                per bucket).

    ***************************************************************************/

    public this ( IAllocator allocator, size_t n, float load_factor = 0.75 )
    {
        super(allocator, n, load_factor);
    }

    /***************************************************************************

        Calculates the hash value from key. Uses the identity since key is
        expected to be a suitable hash value.

        Params:
            key = key to hash

        Returns:
            the hash value that corresponds to key, which is key itself.

    ***************************************************************************/

    public override hash_t toHash ( hash_t key )
    {
        return key;
    }
}

/***************************************************************************

    HashSet unittest.

***************************************************************************/

unittest
{
    version ( UnitTestVerbose )
    {
        Stdout.formatln("{} unittest ---------------",
            typeof(this).stringof);
        scope ( exit ) Stdout.formatln("{} unittest ---------------",
           typeof(this).stringof);
    }

    scope set = new HashSet(10);

    version ( UnitTestVerbose ) void printState ( )
    {
        Stdout.formatln("  ::  len={}, load={}, max_load={}, pool={} ({} busy)",
            set.length, set.load, set.max_load,
            set.bucket_elements.length, set.bucket_elements.num_busy);
    }

    bool lengthIs ( size_t expected )
    {
        assert(set.length == expected);

        int c;
        foreach ( k; set )
        {
            c++;
        }
        return c == expected;
    }

    void put ( hash_t key, bool should_exist )
    {
        auto len = set.length;

        assert(!!(key in set) == should_exist);

        auto e = set.put(key);
        version ( UnitTestVerbose )
        {
            Stdout.format("put {}: {}", key, e);
            printState();
        }

        assert(key in set);
        assert(lengthIs(len + (should_exist ? 0 : 1)));
    }

    void remove ( hash_t key, bool should_exist )
    {
        auto len = set.length;
        auto pool_len = set.bucket_info.num_buckets;

        assert(!!(key in set) == should_exist);

        auto e = set.remove(key);
        version ( UnitTestVerbose )
        {
            Stdout.format("remove {}: {}", key, e);
            printState();
        }

        assert(!(key in set));
        assert(lengthIs(len - (should_exist ? 1 : 0)));
        assert(pool_len == set.bucket_info.num_buckets);
    }

    void clear ( )
    {
        auto pool_len = set.bucket_info.num_buckets;

        set.clear();
        version ( UnitTestVerbose )
        {
            Stdout.format("clear");
            printState();
        }

        assert(lengthIs(0));

        assert(pool_len == set.bucket_info.num_buckets);
    }

    put(4711, false);   // put
    put(4711, true);    // double put
    put(23, false);     // put
    put(12, false);     // put
    remove(23, true);   // remove
    remove(23, false);  // double remove
    put(23, false);     // put
    put(23, true);      // double put

    clear();

    put(4711, false);   // put
    put(11, false);     // put
    put(11, true);      // double put
    put(12, false);     // put
    remove(23, false);  // remove
    put(23, false);     // put
    put(23, true);      // double put

    clear();
}
