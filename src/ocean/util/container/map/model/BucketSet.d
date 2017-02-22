/*******************************************************************************

    Template for a class implementing a set of buckets containing elements
    indexed by unique keys. The bucket set contains both a set of buckets and a
    pool of bucket elements. The bucket elements are structured as linked lists,
    thus each bucket simply contains a pointer to its first element.

    The number of buckets in the set is always a power of 2. In this way the
    getBucket() method, which determines which bucket is responsible for a key,
    can use a simple bit mask instead of a modulo operation, leading to greater
    efficiency.

    The method of bucket element allocation and pool management can be
    customised by passing a custom IAllocator implementation to the constructor.
    The default implementation--the BucketSet.FreeBuckets class--uses
    'new Bucket.Element' for allocation and manages the pool as a linked list of
    bucket elements. Possible alternative implementations include leaving the
    pool management up to an external memory manager such as the D or C runtime
    library using 'new'/'delete' or malloc()/free(), respectively. Also, if the
    maximum number of elements in the map is known in advance, all elements can
    be preallocated in a row.

    Usage:
        See ocean.util.container.map.HashMap & ocean.util.container.map.HashSet

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.map.model.BucketSet;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.map.model.Bucket,
       ocean.util.container.map.model.BucketInfo,
       ocean.util.container.map.model.IAllocator;

import ocean.core.Array: clear, isClearable;

import ocean.core.BitManip: bsr;

import ocean.util.container.map.model.BucketElementGCAllocator;

/******************************************************************************

    Generic BucketSet base class

 ******************************************************************************/

public abstract class IBucketSet
{
    /**************************************************************************

        Convenience type alias for subclasses.

     **************************************************************************/

    alias .IAllocator IAllocator;

    /**************************************************************************

        Map and and bucket statistics like the map length or the number of
        buckets.

     **************************************************************************/

    public BucketInfo bucket_info;

    /**************************************************************************

        Bucket element allocator.

     **************************************************************************/

    protected IAllocator bucket_element_allocator;

    /**************************************************************************

        Bit mask used by the getBucket() method to determine which bucket is
        responsible for a key.

     **************************************************************************/

    private size_t bucket_mask;

    /**************************************************************************

        Constructor.

        Params:
            bucket_element_allocator = bucket element allocator
            n = expected number of elements in mapping
            load_factor = ratio of n to the number of internal buckets. The
                desired (approximate) number of elements per bucket. For
                example, 0.5 sets the number of buckets to double n; for 2 the
                number of buckets is the half of n. load_factor must be greater
                than 0. The load factor is basically a trade-off between memory
                usage (number of buckets) and search time (number of elements
                per bucket).

     **************************************************************************/

    protected this ( IAllocator bucket_element_allocator, size_t n, float load_factor = 0.75 )
    {
        size_t num_buckets = 1 << this.calcNumBucketsExp2(n, load_factor);

        this.bucket_mask = num_buckets - 1;

        this.bucket_info          = new BucketInfo(num_buckets);
        this.bucket_element_allocator = bucket_element_allocator;
    }


    version (D_Version2) {}
    else
    {
        /***********************************************************************

            Disposer.

        ***********************************************************************/

        protected override void dispose ( )
        {
            delete this.bucket_info;
        }
    }


    /**************************************************************************

        Get the length of the buckets.

        Note: In the D2 port we should use subtyping via 'alias this' and
        avoid these forwarding functions.

        Returns:
            the length of the buckets.

     **************************************************************************/

    public final size_t length ( )
    {
        return this.bucket_info.length;
    }

    /***************************************************************************

        Removes all elements from all buckets.

        Note:
            Beware that calling this method is known to sometimes cause
            unexpected behaviour when the bucket-set is reused afterwards (where
            cyclic links are introduced).
            If you are using one of the of the children *Map classes then
            call clearErase() instead as it has been reported to properly clear
            the map.

        Returns:
            this instance

     **************************************************************************/

    public typeof(this) clear ( )
    {
        this.clear_();

        return this;
    }

    /***************************************************************************

        Changes the number of buckets to 2 ^ exp2.

        Params:
            exp2 = exponent of 2 of the new number of buckets

        Returns:
            this instance.

        In:
            2 ^ exp2 must fit into size_t.

    ***************************************************************************/

    abstract typeof (this) setNumBuckets ( uint exp2 );

    /***************************************************************************

        Changes the number of buckets to the lowest power of 2 that results in a
        load factor of at least load_factor with the current number of elements.

        Params:
            load_factor = factor of n / number of buckets

        Returns:
            this instance.

        In:
            load_factor must be greater than 0.

    ***************************************************************************/

    public typeof (this) redistribute ( float load_factor = 0.75 )
    in
    {
        assert (load_factor > 0);
    }
    body
    {
        return this.setNumBuckets(this.calcNumBucketsExp2(this.bucket_info.length, load_factor));
    }

    /***************************************************************************

        Removes all elements from all buckets and sets the values to val_init if
        val_init is not empty.

        Params:
            val_init = initial element value

        Returns:
            this instance

     **************************************************************************/

    protected typeof(this) clear_ ( void[] val_init = null )
    {
        this.clearBuckets(val_init);

        this.bucket_info.clear();

        return this;
    }

    /***************************************************************************

        Removes all elements from all buckets.

        Returns:
            this instance

     **************************************************************************/

    abstract protected void clearBuckets ( void[] val_init );

    /***************************************************************************

        Calculates the lowest exponent of 2 so that a power of 2 with this
        exponent is at least n / load_factor.

        Params:
            n           = number of expected elements in the set
            load_factor = desired maximum load factor

        Returns:
            exponent of 2.

        In:
            load_factor must be greater than 0.

    ***************************************************************************/

    public static uint calcNumBucketsExp2 ( size_t n, float load_factor = 0.75 )
    in
    {
        assert (load_factor > 0);
    }
    body
    {
        return n? bsr(cast(size_t)(n / load_factor)) + 1 : 0;
    }
}

/******************************************************************************

    Bucket set class template.

    Template_Params:
        V = value size (.sizeof of the value type), may be 0 to store no value
        K = key type

 ******************************************************************************/

public abstract class BucketSet ( size_t V, K = hash_t ) : IBucketSet
{
    /**************************************************************************

        Bucket type

    **************************************************************************/

    public alias .Bucket!(V, K) Bucket;


    /***************************************************************************

        List of buckets

    ***************************************************************************/

    private Bucket[] buckets;

    /***************************************************************************

        Constructor, uses the default implementation for the bucket element
        allocator: Elements are allocated by 'new' and stored in a free list.

        Sets the number of buckets to n / load_factor, rounded up to the nearest
        power or 2.

        Params:
            n = expected number of elements in bucket set
            load_factor = ratio of n to the number of buckets. The desired
                (approximate) number of elements per bucket. For example, 0.5
                sets the number of buckets to double n; for 2 the number of
                buckets is the half of n. load_factor must be greater than 0
                (this is asserted in IBucketSet.calcNumBucketsExp2()). The load
                factor is basically a trade-off between memory usage (number of
                buckets) and search time (number of elements per bucket).

    ***************************************************************************/

    protected this ( size_t n, float load_factor = 0.75 )
    {
        auto allocator = new BucketElementGCAllocator!(Bucket)();
        this(allocator, n, load_factor);
    }

    /***************************************************************************

        Constructor.

        Sets the number of buckets to n / load_factor, rounded up to the nearest
        power or 2.

        Params:
            allocator = allocator to use to allocate with
            n = expected number of elements in bucket set
            load_factor = ratio of n to the number of buckets. The desired
                (approximate) number of elements per bucket. For example, 0.5
                sets the number of buckets to double n; for 2 the number of
                buckets is the half of n. load_factor must be greater than 0
                (this is asserted in IBucketSet.calcNumBucketsExp2()). The load
                factor is basically a trade-off between memory usage (number of
                buckets) and search time (number of elements per bucket).

    ***************************************************************************/

    protected this ( IAllocator allocator, size_t n, float load_factor = 0.75 )
    {
        super(allocator, n, load_factor);

        this.buckets = new Bucket[this.bucket_info.num_buckets];
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

            delete this.buckets;
        }
    }

    /**************************************************************************

        Ensures that Bucket.init consists only of zero bytes so that the
        memset() method in clear() will work.

     **************************************************************************/

    unittest
    {
        assert(isClearable!(Bucket),
               Bucket.stringof ~ ".init contains non-zero byte: " ~
               typeof (this).stringof ~ ".clear_() will not work");
    }

    /***************************************************************************

        Looks up a mapping from the specified key.

        Params:
            key        = key to look up mapping for
            must_exist = true: assert that the mapping exists, false: the
                         mapping may or may not exist

        Returns:
            a pointer to the element mapped to by the specified key or null if
            not found and must_exist is false.
            The caller should make sure that the key is not changed.

        Out:
            - The returned array can only be null if must_exist is false.
            - The length of the returned array is V unless the array is null.

     ***************************************************************************/

    final protected Bucket.Element* get_ ( K key, bool must_exist = false )
    out (element)
    {
        // FIXME: Disabled due to DMD bug 6417, the method parameter argument
        // values are junk inside this contract.

        version (none)
        {
            if (element)
            {
                assert (element.key == key, "key mismatch");
            }
            else
            {
                assert (!must_exist, "element not found");
            }
        }
    }
    body
    {
        auto element = this.buckets[this.toHash(key) & this.bucket_mask].find(key);

        if (element)
        {
            assert (element.key == key, "key mismatch");
        }
        else
        {
            assert (!must_exist, "element not found");
        }

        return element;
    }

    /***************************************************************************

        Adds or updates a mapping from the specified key.

        Params:
            key   = key to add/update mapping for
            added = set to true if the record did not exist but was added

        Returns:
            a pointer to the element mapped to by the specified key. The caller
            should set the value as desired and make sure that the key is not
            changed.

     ***************************************************************************/

    final protected Bucket.Element* put_ ( K key, out bool added )
    out (element)
    {
        // FIXME: Disabled due to DMD bug 6417, the method parameter argument
        // values are junk inside this contract.

        version (none)
        {
            assert (element !is null);

            assert (element.key == key, "key mismatch");
        }
    }
    body
    {
        size_t bucket_index = this.toHash(key) & this.bucket_mask;

        with (this.buckets[bucket_index])
        {
            auto element = add(key,
            {
                added = true;

                if (has_element)
                {
                    this.bucket_info.put(bucket_index);
                }
                else
                {
                    this.bucket_info.create(bucket_index);
                }

                return cast (Bucket.Element*) this.bucket_element_allocator.get();
            }());

            assert (element !is null);

            assert (element.key == key, "key mismatch");

            return element;
        }
    }

    /***************************************************************************

        Adds or updates a mapping from the specified key.

        Params:
            key = key to add/update mapping for

        Returns:
            the element mapped to by the specified key. The caller should set
            the value as desired and make sure that the key is not changed.

    ***************************************************************************/

    final protected Bucket.Element* put_ ( K key )
    {
        bool added;

        return this.put_(key, added);
    }

    /***************************************************************************

        Removes the mapping for the specified key and optionally invokes dg with
        the value that is about to be removed.

        Note that, if references to GC-allocated objects (objects or dynamic
        arrays), it is a good idea to set the value of the element referenced
        by the element parameter of the callback delegate to null to avoid these
        objects from being prevented from garbage collection. In general
        pointers should be set to null for the same reason and to avoid dangling
        pointers.

        If the default allocator is used (that is, no allocator instance was
        passed to the constructor), the value of the element referenced
        by the element parameter of the callback delegate dg is accessible and
        remains unchanged after dg returned until the next call to put() or
        clear().

        Params:
            key = key to remove mapping for
            dg  = optional delegate to call with the removed element value (not
                  called if key was not found)

        Returns:
            true if key was found in the map or false if not. In case of false
            dg was not called.

    ***************************************************************************/

    final protected bool remove_ ( K key, void delegate ( ref Bucket.Element element ) dg = null )
    {
        size_t bucket_index = this.toHash(key) & this.bucket_mask;

        Bucket.Element* element = this.buckets[bucket_index].remove(key);

        scope (exit) if ( element )
        {
            this.bucket_info.remove(bucket_index);

            if (dg)
            {
                dg(*element);
            }

            this.bucket_element_allocator.recycle(element);
        }

        return !!element;
    }

    /***************************************************************************

        Removes the mapping for the specified key.

        Params:
            key = key to remove mapping for

        Returns:
            true if key was found and the mapping removed or false otherwise.

    ***************************************************************************/

    public bool remove ( K key )
    {
        return this.remove_(key);
    }

    /***************************************************************************

        Calculates the hash value from key.

        Params:
            key = key to hash

        Returns:
            the hash value that corresponds to key.

    ***************************************************************************/

    abstract public hash_t toHash ( K key );

    /***************************************************************************

        Changes the number of buckets to 2 ^ exp2.

        Params:
            exp2 = exponent of 2 of the new number of buckets

        Returns:
            this instance.

        In:
            2 ^ exp2 must fit into size_t.

    ***************************************************************************/

    public override typeof (this) setNumBuckets ( uint exp2 )
    in
    {
        assert (exp2 < size_t.sizeof * 8);
    }
    body
    {
        size_t n_prev = this.buckets.length,
        n_new  = 1 << exp2;

        if (n_prev != n_new)
        {
            // Park the bucket elements that are currently in the set.

            this.bucket_element_allocator.parkElements(this.bucket_info.length,
            (IAllocator.IParkingStack parked_elements)
            {
                scope Iterator it = this.new Iterator(true);

                foreach (ref element; it)
                {
                    parked_elements.push(&element);
                }

                // Resize the array of buckets and the bucket_info and calculate
                // the new bucket_mask.

                this.buckets.length = n_new;

                .clear(this.buckets[0 .. (n_prev < $)? n_prev : $]);

                this.bucket_info.clearResize(n_new);

                this.bucket_mask = n_new - 1;

                // Put the parked elements back into the buckets.

                foreach (element_; parked_elements)
                {
                    auto element = cast (Bucket.Element*) element_,
                    bucket_index = this.toHash(element.key) & this.bucket_mask;

                    if (this.bucket_info[bucket_index])
                    {
                        assert (this.buckets[bucket_index].has_element,
                                "bucket with non-zero length has no element");
                    }
                    else
                    {
                        assert (!this.bucket_info[bucket_index],
                                "bucket with zero length has an element");
                    }

                    this.bucket_info.put(bucket_index);

                    this.buckets[bucket_index].add(element);
                }
            });
        }

        return this;
    }

    /***************************************************************************

        Removes all elements from all buckets and sets the values to val_init if
        val_init is not empty.

        Params:
            val_init = initial element value, the length must be V or 0

        In:
            val_init.length must be V.

        Out:
            all the buckets.first are set to null

    ***************************************************************************/

    protected override void clearBuckets ( void[] val_init = null )
    in
    {
        assert (!val_init.length || val_init.length == V);
    }
    out
    {
        foreach(bucket; this.buckets)
        {
            assert(bucket.first == null, "non-Null first bucket element found");
        }
    }
    body
    {
        // Recycle all bucket elements.

        scope Iterator it = this.new Iterator(true);

        foreach (ref element; it)
        {
            static if (V) if (val_init.length)
            {
                element.val[] = cast (ubyte[]) val_init[];
            }

            this.bucket_element_allocator.recycle(&element);
        }

        // Clear bucket contents.
        .clear(this.buckets);
    }

    /***************************************************************************

        'foreach' iteration over elements in the set.
        DO NOT change the element keys during iteration because this will
        corrupt the map (unless it is guaranteed that the element will go to the
        same bucket).

    ***************************************************************************/

    protected class Iterator
    {
        /***********************************************************************

            Whether to reset the counter after each foreach

        ***********************************************************************/

        protected bool reset_after_foreach = true;

        /***********************************************************************

            Index of the last bucket that was iterated in the last call to
            foreach

        ***********************************************************************/

        protected size_t last_bucket_index;

        /***********************************************************************

            Last element within the last bucket that was iterated

        ***********************************************************************/

        protected size_t last_bucket_element;

        /***********************************************************************

            Total count of the elements currently iterated

        ***********************************************************************/

        protected size_t counter;

        /***********************************************************************

            Ctor

            Params:
                reset_after_foreach = whether to reset iteration counters
                                      after a foreach (true) or not (false)

        ***********************************************************************/

        public this ( bool reset_after_foreach = false )
        {
            this.reset_after_foreach = reset_after_foreach;
        }

        /***********************************************************************

            Reset the counters, effectively forcing any interrupted iteration to
            start from the beginning.

        ***********************************************************************/

        public void reset ( )
        {
            this.last_bucket_index = 0;
            this.last_bucket_element = 0;
            this.counter = 0;
        }

        /***********************************************************************

            if reset_after_foreach is true:
                resets the counters after each foreach so the next iteration
                starts from the beginning

            if reset_after_foreach is false:
                resets the counters only when the whole map was iterated

            Params:
                interrupted = whether the last foreach call was interrupted
                using break (true) or not (false)

        ***********************************************************************/

        protected void resetIterator ( bool interrupted )
        {
            if ( reset_after_foreach || !interrupted )
            {
                this.reset();
            }
        }

        /***********************************************************************

            Foreach support

        ***********************************************************************/

        final protected int opApply ( int delegate ( ref Bucket.Element element ) dg )
        {
            int tmpDg ( ref size_t i, ref Bucket.Element e )
            {
                return dg(e);
            }

            return this.opApply(&tmpDg);
        }

        /***********************************************************************

            Foreach support with counter

            Instead of remembering the exact pointer we last iterated upon a
            break, we remember the index within the linked list and re-iterate
            to that index next time we're called. Using a pointer for this
            problem would be problematic, probably (alliteration!), because the
            linked list could change drastically in the mean time. Elements
            could be removed, especially the one we were remembering. adding
            checks to make that safe is a lot of hassle and not worth it.

            As buckets are supposed to be very small anyway, we just remember
            the index and if the list finished before we reach that index, so be
            it, we just use the next bucket then.

        ***********************************************************************/

        final protected int opApply ( int delegate ( ref size_t i,
                                                     ref Bucket.Element element ) dg )
        {
            int result = 0;

            scope (exit)
            {
                this.resetIterator(result != 0);
            }

            if ( this.outer.bucket_info.num_filled_buckets < this.last_bucket_index )
            {
                this.last_bucket_index = this.outer
                                            .bucket_info
                                            .num_filled_buckets;
            }

            auto remaining_buckets = this.outer
                                      .bucket_info
                                      .filled_buckets[this.last_bucket_index .. $];

            top: foreach (info; remaining_buckets)
            {
                with (this.outer.buckets[info.index])
                {
                    size_t bucket_element_counter = 0;
                    assert (has_element);

                    for ( auto element = first; element !is null; )
                    {
                        /* element.next needs to be stored before calling dg
                         * because now dg will modifiy element.next if it
                         * returns the element to the free list.  */
                        auto next = element.next;

                        if ( bucket_element_counter == this.last_bucket_element )
                        {
                            result = dg(this.counter, *element);

                            this.counter++;
                            this.last_bucket_element++;
                        }

                        bucket_element_counter++;

                        element = next;

                        if (result) break top;
                    }
                }

                this.last_bucket_index++;
                this.last_bucket_element = 0;
            }

            return result;
        }
    }
}
