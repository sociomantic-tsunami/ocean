/*******************************************************************************

    Mapping from key to the time-to-index mapping of an item in the cache.
    Limits the number of available mappings to a fixed value and preallocates
    all bucket elements in an array buffer.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.cache.model.containers.KeyToNode;

/*******************************************************************************

    Imports

*******************************************************************************/

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

    ***************************************************************************/

    private ArrayAllocatedFreeBucketElements allocator;

    /***********************************************************************

        Constructor.

        Params:
            n = maximum number of elements in mapping

    ***********************************************************************/

    public this ( size_t n )
    {
        super(this.allocator = new ArrayAllocatedFreeBucketElements(n), n);
    }

    /***************************************************************************

        Removes all elements from all buckets.

        Returns:
            this instance

     **************************************************************************/

    public override typeof(this) clear ( )
    {
        super.clear();
        this.allocator.pool.clear();
        return this;
    }
}
