/*******************************************************************************

    Template for a class implementing a set of hashed keys. The set is built on
    top of an efficient bucket algorithm, allowing for fast look up of keys in
    the set.

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

module ocean.util.container.map.Set;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.map.model.BucketSet;

import ocean.util.container.map.model.Bucket;

import ocean.util.container.map.model.MapIterator;

import ocean.util.container.map.model.StandardHash;

version (UnitTestVerbose) import ocean.io.Stdout;

/*******************************************************************************

    Debug switch for verbose unittest output (uncomment if desired)

*******************************************************************************/

//version = UnitTestVerbose;

version ( UnitTestVerbose )
{
    import ocean.io.Stdout;
}

/*******************************************************************************

    StandardKeyHashingSet class template. Manages a set of K's with fast lookup
    using a standard way of hash calculation:

    - If K is a primitive type (integer, floating point, character), the hash
      value is calculated from the raw key data using the FNV1a hash function.
    - If K is a dynamic or static array of a  primitive type, the hash value is
      calculated from the raw data of the key array content using the FNV1a hash
      function.
    - If K is a class, struct or union, it is expected to implement toHash(),
      which will be used.
    - Other key types (arrays of non-primitive types, classes/structs/unions
      which do not implement toHash(), pointers, function references, delegates,
      associative arrays) are not supported by this class template.

*******************************************************************************/

public class StandardHashingSet ( K ) : Set!(K)
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

        Mixin of the toHash() method which is declared abstract in BucketSet.

    ***************************************************************************/

    override:
        mixin StandardHash.toHash!(K);
}


/*******************************************************************************

    Set class. Manages a set of K's with fast lookup. The toHash() method must
    be implemented.

*******************************************************************************/

public abstract class Set ( K ) : BucketSet!(0, K)
{
    private alias .MapIterator!(void, K) SetIterator;

    /***************************************************************************

        Mixin of the specialized iterator classes which inherit from
        BucketSet.Iterator.

        This makes available three iterator classes that can be newed to allow
        certain iteration behaviors:

        * Iterator — just a normal iterator
        * InterruptibleIterator — an iterator that can be interrupted and
          resumed, but that has to be manually reset with reset() if the
          iteration is meant to be repeated

        If the map is modified between interrupted iterations, it can happen
        that new elements that were added in the mean time won't appear in the
        iteratation, depending on whether they end up in a bucket that was
        already iterated or not.

        Iterator usage example
        ---
        auto map = new HashMap!(size_t);

        auto it = map.new Iterator();

        // A normal iteration over the map
        foreach ( k, v; it )
        {
            ..
        }

        // Equal to
        foreach ( k, v; map )
        {
            ..
        }
        ---

        InterruptibleIterator
        ---
        auto map = new HashMap!(size_t);

        auto interruptible_it = map.new InterruptibleIterator();

        // Iterate over the first 100k elements
        foreach ( i, k, v; interruptible_it )
        {
            ..
            // Break after 100k elements
            if ( i % 100_000 == 0 ) break;
        }

        // Iterate over the next 100k elments
        foreach ( i, k, v; interruptible_it )
        {
            ..
            // Break after 100k elements
            if ( i % 100_000 == 0 ) break;
        }

        // Assuming the map had 150k elements, the iteration is done now,
        // so this won't do anything
        foreach ( i, k, v; interruptible_it )
        {
            ..
            // Break after 100k elements
            if ( i % 100_000 == 0 ) break;
        }

        assert ( interruptible_it.finished() == true );
        ---

        See also: BucketSet.Iterator, MapIterator.IteratorClass

    ***************************************************************************/

    mixin IteratorClass!(BucketSet!(0,K).Iterator, SetIterator);

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

    protected this ( size_t n, float load_factor = 0.75 )
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

    protected this ( IAllocator allocator, size_t n, float load_factor = 0.75 )
    {
        super(allocator, n, load_factor);
    }


    /***************************************************************************

        Looks up key in the set.

        Params:
            key = key to look up

        Returns:
            true if found or false if not.

    ***************************************************************************/

    public bool opIn_r ( K key )
    {
        return this.get_(key) !is null;
    }


    /***************************************************************************

        Puts key into the set.

        Params:
            key = key to put into set

        Returns:
            true if the key was already on the set, false otherwise

    ***************************************************************************/

    public bool put ( K key )
    {
        bool added;

        this.put_(key, added);

        return !added;
    }


    /***************************************************************************

        'foreach' iteration over set.

        Note: It is possible to have interruptible iterations, see documentation
        for mixin of IteratorClass

        See also: BucketSet.Iterator, MapIterator.IteratorClass

        Notes:
        - During iteration it is forbidden to call clear() or redistribute() or
          remove map elements. If elements are added, the iteration may or may
          not include these elements.
        - If K is a static array, the iteration variable is a dynamic array of
          the same base type and slices the key of the element in the map.
          (The reason is that static array 'ref' parameters are forbidden in D.)
          In this case DO NOT modify the key in any way!
        - It is not recommended to do a 'ref' iteration over the keys. If you do
          it anyway, DO NOT modify the key in-place!

    ***************************************************************************/

    public int opApply ( SetIterator.Dg dg )
    {
        scope it = this.new Iterator;

        return it.opApply(dg);
    }

    /***************************************************************************

        Same as above, but includes a counter

    ***************************************************************************/

    public int opApply ( SetIterator.Dgi dgi )
    {
        scope it = this.new Iterator;

        return it.opApply(dgi);
    }
}
