/*******************************************************************************

    A bucket element allocator using the D runtime memory manager. Bucket
    elements are newed by get() and deleted by recycle().

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.map.model.BucketElementGCAllocator;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.map.model.IBucketElementGCAllocator;


/*******************************************************************************

    A bucket element allocator using the D runtime memory manager. Even though
    this memory manager is called "GC-managed" this class
    in fact doesn't rely on garbage collection but explicitly deletes unused
    bucket elements.

*******************************************************************************/

public class BucketElementGCAllocator(Bucket) : IBucketElementGCAllocator
{
    /***************************************************************************

        Constructor.

    ***************************************************************************/

    public this ( )
    {
        super(Bucket.Element.sizeof);
    }

    /***************************************************************************

        Gets or allocates an object

        Returns:
            an object that is ready to use.

    ***************************************************************************/

    protected override void* allocate ( )
    {
        return new Bucket.Element;
    }
}


/*******************************************************************************

    Creates an instance of BucketElementGCAllocator which is suitable for usage
    with the Map type passed as a template parameter.

    Template_Params:
        Map = the type to create the allocator according to

    Returns:
        an instance of type BucketElementGCAllocator class

*******************************************************************************/

public BucketElementGCAllocator!(Map.Bucket) instantiateAllocator ( Map ) ( )
{
    return new BucketElementGCAllocator!(Map.Bucket);
}
