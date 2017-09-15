/*******************************************************************************

    Template for a class implementing a mapping from hashes to a user-specified
    type.

    The interface of the class has been kept deliberately simple, purely
    handling the management of the mapping. The handling of the mapping values
    is left entirely up to the user -- all methods simply return a pointer to
    the mapping value which the user can do what they like with. (This is an
    intentional design decision, in order to reduce the complexity of the
    template.)

    The HashMap is designed as a replacement for ocean.core.ArrayMap. It has
    several advantages:
        1. Memory safety. As the ArrayMap's buckets are implemented as dynamic
           arrays, each bucket will theoretically grow continually in size over
           extended periods of use. Even when clear()ed, the buffers allocated
           for the buckets will not reduce in size. The HashMap, on the other
           hand, uses a pool of elements, meaning that the memory allocated for
           each bucket is truly variable.
        2. Code simplicity via removing optional advanced features such as
           thread safety and value array copying.
        3. Extensibility. Functionality is split into several modules, including
           a base class for easier reuse of components.

    A usage example with various types stored in mappings is below in the
    unit tests.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.map.HashMap;

import ocean.util.container.map.Map;

version (UnitTestVerbose) import ocean.io.Stdout;



/*******************************************************************************

    HashMap class template. Manages a mapping from hash_t to the specified type.

    Template_Params:
        V = type to store in values of map

*******************************************************************************/

public class HashMap ( V ) : Map!(V, hash_t)
{
    /***************************************************************************

        Constructor.

        Params:
            n = expected number of elements in mapping
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

    /***************************************************************************

        HashMap unittest.

    ***************************************************************************/

    version ( UnitTest )
    {
        import ocean.core.Test;
        import ocean.core.Traits : isFloatingPointType;
        import ocean.math.IEEE : isNaN;
    }

    unittest
    {
        version ( UnitTestVerbose )
        {
            Stdout.formatln("{} unittest ---------------",
                typeof(this).stringof);
            scope ( success ) Stdout.formatln("{} unittest ---------------",
               typeof(this).stringof);
        }

        scope map = new typeof(this)(10);

        version ( UnitTestVerbose ) void printState ( )
        {
            Stdout.formatln("  ::  len={}, load={}, max_load={}",
                map.length, map.bucket_info.load, map.bucket_info.max_load);
        }

        bool lengthIs ( size_t expected )
        {
            test!("==")(map.length, expected);

            int c;
            foreach ( k, v; map )
            {
                c++;
            }
            return c == expected;
        }

        void put ( hash_t key, bool should_exist )
        {
            auto len = map.length;

            test!("==")(((key in map) !is null), should_exist);

            auto e = map.put(key);

            *e = V.init;

            version ( UnitTestVerbose )
            {
                Stdout.format("put {}: {}", key, e);
                printState();
            }

            test!("!is")((key in map), null);

            static if (is (V U : U[]) && !is (V == V[]))
            {
                // work around DMD bug 7752

                V v_init;

                test!("==")(*map.get(key), v_init);
            }
            else static if ( is ( V == class ) )
            {
                test!("is")(*map.get(key), V.init);
            }
            else static if ( isFloatingPointType!(V) )
            {
                // Specialised test for floating point types, where
                // V.init != V.init
                test(isNaN(*map.get(key))); // Value does not equal previously set value
            }
            else
            {
                test!("is")(*map.get(key), V.init); // Value does not equal previously set value
            }

            test(lengthIs(len + (should_exist ? 0 : 1)),
                   "Length different from foreach-counted elements!");
        }

        void remove ( hash_t key, bool should_exist )
        {
            auto len = map.length;
            auto pool_len = map.bucket_info.num_buckets;

            test!("==")(((key in map) !is null), should_exist);

            auto e = map.remove(key);
            version ( UnitTestVerbose )
            {
                Stdout.format("remove {}: {}", key, e);
                printState();
            }

            test(!(key in map));
            test(lengthIs(len - (should_exist ? 1 : 0)));
            test!("==")(pool_len, map.bucket_info.num_buckets);
        }

        void clear ( )
        {
            auto pool_len = map.bucket_info.num_buckets;

            map.clear();
            version ( UnitTestVerbose )
            {
                Stdout.format("clear");
                printState();
            }

            test(lengthIs(0));

            test!("==")(pool_len, map.bucket_info.num_buckets);
        }

        uint[hash_t] expected_keys;

        void checkContent ( )
        {
            foreach (key, val; map)
            {
                uint* n = key in expected_keys;

                test!("!is")(n, null);

                test(!*n, "duplicate key");

                (*n)++;
            }

            foreach (n; expected_keys)
            {
                test!("==")(n, 1);
            }
        }

        put(4711, false);   // put
        put(4711, true);    // double put
        put(23, false);     // put
        put(12, false);     // put

        expected_keys[4711] = 0;
        expected_keys[23]   = 0;
        expected_keys[12]   = 0;

        checkContent();

        remove(23, true);   // remove
        remove(23, false);  // double remove

        expected_keys[4711] = 0;
        expected_keys[12]   = 0;

        expected_keys.remove(23);

        checkContent();

        put(23, false);     // put
        put(23, true);      // double put

        expected_keys[4711] = 0;
        expected_keys[12]   = 0;
        expected_keys[23]   = 0;

        checkContent();

        clear();
        foreach (key, val; map)
        {
            test(false);
        }

        put(4711, false);   // put
        put(11, false);     // put
        put(11, true);      // double put
        put(12, false);     // put

        expected_keys[4711] = 0;
        expected_keys[12]   = 0;
        expected_keys[11]   = 0;
        expected_keys.remove(23);

        checkContent();

        remove(23, false);  // remove
        put(23, false);     // put
        put(23, true);      // double put

        expected_keys[4711] = 0;
        expected_keys[12]   = 0;
        expected_keys[11]   = 0;
        expected_keys[23]   = 0;

        checkContent();

        clear();
        foreach (key, val; map)
        {
            test(false);
        }

        map.put(1);
        map.put(2);
        map.put(3);
        map.put(4);
        map.put(5);
        map.put(6);
        map.put(7);
        map.put(8);
        map.put(9);


        void testPartial ( typeof(this).Iterator it )
        {
            foreach (i, ref k, ref v; it )
            {
                test!("==")( i, 0); // Didn't interrupt when expected 1
                if ( i % 3 == 0 ) break;
            }

            foreach (i, ref k, ref v; it )
            {
                test( i >= 1 && i <= 3, "Didn't interrupt when expected 2" );
                if ( i % 3 == 0 ) break;
            }

            foreach (i, ref k, ref v; it )
            {
                test( i >= 4 && i <= 6, "Didn't interrupt when expected 3" );
                if ( i % 3 == 0 ) break;
            }

            foreach (i, ref k, ref v; it )
            {
                test( i >= 7 && i <= 9, "Didn't interrupt when expected 4" );
                if ( i % 3 == 0 ) break;
            }
        }

        auto not_looping_it = map.new InterruptibleIterator;

        testPartial(not_looping_it);

        // Should be finished
        test( not_looping_it.finished() );

        // Should not run again
        foreach (i, ref k, ref v; not_looping_it )
        {
            test(false, "Ran iteration even though it should be finished");
        }

        not_looping_it.reset();

        test( !not_looping_it.finished() );

        // After manual reset, should loop again
        testPartial(not_looping_it);
        test( not_looping_it.finished() );

//            foreach (i, bucket; map.buckets)
//            {
//                Stdout.formatln("Bucket {,2}: {,2} elements:", i, bucket.length);
//                foreach ( element; bucket )
//                {
//                    Stdout.formatln("  {,2}->{,2}", element.key,
//                        *(cast(V*)element.val.ptr));
//                }
//            }
    }

}

unittest
{
    // Instantiate a couple of hashmaps to actually run the unittests in the
    // class
    HashMap!(int) hi;
    HashMap!(char[]) hs;
    HashMap!(float) hf;
    HashMap!(Object) ho;
}

///
unittest
{
    // Unittest that serves as a usage example
    const expected_number_of_elements = 1_000;

    // Mapping from hash_t -> int
    auto map = new HashMap!(int)(expected_number_of_elements);

    hash_t hash = 232323;

    // Add a mapping
    *(map.put(hash)) = 12;

    // Look up a mapping and obtain a pointer to the value if found or null
    // if not found;
    int* val = hash in map;

    bool exists = val !is null;

    // Remove a mapping
    map.remove(hash);

    // Clear the map
    map.clear();

    // Mapping from hash_t -> char[]
    auto map2 = new HashMap!(char[])(expected_number_of_elements);

    // Add a mapping
    char[]* val2 = map2.put(hash);

    (*val2).length = "hello".length;
    (*val2)[]      = "hello";

    // Mapping from hash_t -> struct
    struct MyStruct
    {
        int x;
        float y;
    }

    auto map3 = new HashMap!(MyStruct)(expected_number_of_elements);

    // Add a mapping, put() never returns null
    with (*map3.put(hash))
    {
        x = 12;
        y = 23.23;
    }
}
