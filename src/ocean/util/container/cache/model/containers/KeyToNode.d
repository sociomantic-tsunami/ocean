/*******************************************************************************

    Mapping from key to the time-to-index mapping of an item in the cache.
    Limits the number of available mappings to a fixed value and preallocates
    all bucket elements in an array buffer.

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.cache.model.containers.KeyToNode;


import ocean.util.container.map.HashMap;
import ocean.util.container.map.model.BucketElementFreeList;
import ocean.util.container.cache.model.containers.ArrayPool;
import ocean.util.container.cache.model.containers.TimeToIndex;

/******************************************************************************/

class KeyToNode: HashMap!(TimeToIndex.Node*)
{
    static class ArrayAllocatedFreeBucketElements: BucketElementFreeList!(Bucket.Element)
    {
        /***********************************************************************

            Preallocated pool of bucket elements.

        ***********************************************************************/

        private GenericArrayPool pool;

        /***********************************************************************

            Constructor.

            Params:
                n = number of elements in the pool

        ***********************************************************************/

        private this ( size_t n )
        {
            this.pool = new GenericArrayPool(n, Bucket.Element.sizeof);
        }

        /***********************************************************************

            Obtains a new element from the pool.

            Returns:
                A new pool element.

        ***********************************************************************/

        protected override Bucket.Element* newElement ( )
        {
            return cast(Bucket.Element*)this.pool.next;
        }
    }

    /***************************************************************************

        Bucket elements allocator.
        The elements are allocated only during container construction,
        and never freed.

    ***************************************************************************/

    private ArrayAllocatedFreeBucketElements allocator;

    /***********************************************************************

        Constructor.

        Params:
            n = maximum number of elements in mapping

    ***********************************************************************/

    public this ( size_t n )
    {
        this.allocator = new ArrayAllocatedFreeBucketElements(n);
        super(this.allocator, n);
    }
}

unittest
{
    KeyToNode map = new KeyToNode(5);
    (*map.put(1)) = new TimeToIndex.Node();
    (*map.put(2)) = new TimeToIndex.Node();
    (*map.put(3)) = new TimeToIndex.Node();
    (*map.put(4)) = new TimeToIndex.Node();
    (*map.put(5)) = new TimeToIndex.Node();
    map.clear();
    map.clear();
    map.clear();
}

unittest
{
    KeyToNode map = new KeyToNode(100000);
    map.clear();
    map.put(9207674216414740734);
    map.put(8595442437537477107);
    map.clear();
    map.put(8595442437537477107);
    map.clear();
    map.put(9207674216414740734);
    map.put(8595442437537477106);
    map.put(8595442437537477108);
    map.put(8595442437537477110);
    map.put(8595442437537477112);
    map.clear();
}
