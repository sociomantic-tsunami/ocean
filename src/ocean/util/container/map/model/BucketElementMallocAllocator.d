/*******************************************************************************

    Base class for a bucket element allocator using malloc function bypassing
    the GC.

    By default the class constructor checks the type of the Bucket elements
    (i.e, the values stored in the Map). If the element contains reference
    items (e.g class or an array) then on malloc allocations the class adds the
    elements to the GC scan range and removes them from the GC scan range on
    recycling.

    This tracking of the objects can be explicitly disabled through passing
    the appropriate flag to the class constructor.

    Warning :

        Do not disable the tracking of the allocated elements except if the
        element if there is another reference to the GC allocated items
        elsewhere.

    The following is a more detailed explanation about what's safe to store
    without GC tracking and what's unsafe.

        If the elements stored in the map (i.e the struct or class you are
        storing) contains a GC managed memory item and the single reference to
        this memory is only in this malloc-based map then the GC will collect
        this data as no other GC object is referencing it. Once collected you
        will end up with segmentation fault when you to access this non-used
        memory address.

        For example, consider that what you are storing in the map is the
        following :

        ---
            struct S
            {
                statuc class C
                {
                }

                statuc struct S2
                {
                    float x, y;
                }

                int a; // Not a problem
                S2 s2; // Not a problem, S2 doesn't contain GC allocated memory.

                int[] arr; // Problem: Arrays memory are managed by the GC
                Class c; // Problem: class C is tracked by the GC.

                static S opCall()
                {
                    S s;
                    s.c = new C();
                    return s;
                }
             }
        ---

        This reference items doesn't have to be added to the GC scan list if
        it has another reference in the GC (e.g when another reference exists
        in a pool).

        For example:

        ---
            struct GCTrackedObject
            {
                int[] arr;
            }

            static StructPool!(GCTrackedObject) arr_pool; // Tracked by GC

            struct S
            {
                        .
                // Same code as above
                        .

                ObjectPool!(C) c_pool; // Tracked by GC
                static S opCall()
                {
                    S s;
                    s.c = c_pool.get();
                    auto gc_tracked_object = arr_pool.get();
                    s.arr = gc_tracked_object.arr;
                    return s;
                }

                // TODO: Recycle the struct and object again to their pools
                // again when this S struct item is removed from malloc map.
            }
        ---

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.map.model.BucketElementMallocAllocator;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.map.model.IAllocator;

import core.memory;
import ocean.transition;

/*******************************************************************************

    Implements a malloc based BucketElement Allactor.

    By default the class constructor checks the type of the Bucket elements
    (i.e, the values stored in the Map). If the element contains reference
    items (e.g class or an array) then on malloc allocations the class adds the
    elements to the GC scan range and removes them from the GC scan range on
    recycling.

    This tracking of the objects can be explicitly disabled through passing
    the appropriate flag to the class constructor.

    Template_Params:
        Bucket = the bucket-element type

*******************************************************************************/

public class BucketElementMallocAllocator (Bucket) : IAllocator
{
    import core.stdc.stdio : fputs, stderr;
    import core.stdc.stdlib : malloc, free, abort;

    /***************************************************************************

        Make sure we don't try to allocate 0 sized elements, otherwise
        get() can return null.

    ***************************************************************************/

    static assert(Bucket.Element.sizeof);

    /***************************************************************************

        Flags whether the malloced items should be tracked by the GC.

    ***************************************************************************/

    private bool add_to_gc;


    /***************************************************************************

        Constructor.

        Params:
            attempt_gc_track = if set to true and if the Bucket element contains
                reference items (e.g class or arrays) then the allocated values
                are added to the GC scan range.
                If set to false or if set to true but the Bucket element doesn't
                contain reference type then the item won't be tracked by
                the GC.

    ***************************************************************************/

    public this(bool attempt_gc_track = true)
    {
        super(Bucket.Element.sizeof);
        if (attempt_gc_track)
        {
            // TypeInfo.flags & 2 is set if the type cannot have references to
            // GC allocated objects.
            // In D2 this can be checked at compile time.
            this.add_to_gc = !(typeid(Bucket).flags & 2);
        }
        else
            this.add_to_gc = false;
    }

    /***************************************************************************

        Get new element

        Returns:
            pointer to the allocated item

    ***************************************************************************/

    protected override void* allocate ( )
    {
        auto inited = cast(Bucket.Element*) malloc(Bucket.Element.sizeof);
        if (inited is null)
        {
            istring msg = "malloc failed to allocate @" ~ __FILE__ ~ ":" ~
                          __LINE__.stringof ~ "\n\0";
            fputs(msg.ptr, stderr);
            abort();
        }
        *inited = Bucket.Element.init;

        if (this.add_to_gc)
            GC.addRange(inited, Bucket.Element.sizeof);

        return inited;
    }

    /***************************************************************************

        delete element

        Params:
            element = pointer to the element to be deleted

    ***************************************************************************/

    protected override void deallocate ( void* element )
    {
        if (this.add_to_gc)
            GC.removeRange(element);
        free(element);
    }

    /***************************************************************************

        Class for parking elements

    ***************************************************************************/

    static /* scope */ class ParkingStack : IParkingStack
    {
        /***********************************************************************

            Parking stack

        ***********************************************************************/

        private void*[] elements;

        /***********************************************************************

            Create new instance of class with size n

            Params:
                n = the number of elements that will be parked

        ***********************************************************************/

        public this ( size_t n )
        {
            super(n);

            auto allocated_mem = malloc((void*).sizeof * n);
            if (allocated_mem is null)
            {
                istring msg = "malloc failed to allocate @" ~ __FILE__ ~ ":" ~
                              __LINE__.stringof ~ "\n\0";
                fputs(msg.ptr, stderr);
                abort();
            }
            this.elements = (cast(void**)allocated_mem)[0 .. n];
        }

        version (D_Version2) {}
        else
        {
            /*******************************************************************

                Dispose class.

            *******************************************************************/

            protected override void dispose ( )
            {
                free(this.elements.ptr);
            }
        }

        /***********************************************************************

            Park element.

            Params:
                element = the element to park
                n = the index of the element

        ***********************************************************************/

        protected override void push_ ( void* element, size_t n )
        {
            this.elements[n] = element;
        }

        /***********************************************************************

            Pop an element from parking.

            Params:
                n = the index of the element to retrieve

            Returns:
                the element parked at index n

        ***********************************************************************/

        protected override void* pop_ ( size_t n )
        {
            return this.elements[n];
        }
    }

    /***************************************************************************

        Park elements

        Params:
            n = the number of elements that will be parked
            dg = the delegate that will receive the IParkingStack implementation

    ***************************************************************************/

    public override void parkElements (size_t n,
                                       void delegate ( IParkingStack park ) dg)
    {
        scope park = new ParkingStack(n);
        dg(park);
    }
}


/*******************************************************************************

    Returns a new instance of type BucketElementMallocAllocator suitable to be
    used with the Map passed as template parameter.

    Template_Params:
        Map = the map to create the allocator according to

    Params:
        attempt_gc_track = if set to true and if the Bucket element contains
            reference items (e.g class or arrays) then the allocated values
            are added to the GC scan range.
            If set to false or if set to true but the Bucket element doesn't
            contain reference type then the item won't be tracked by
            the GC.

    Returns:
        an instance of type BucketElementMallocAllocator

*******************************************************************************/

public BucketElementMallocAllocator!(Map.Bucket)
       instantiateAllocator(Map)(bool attempt_gc_track = true)
{
    return new BucketElementMallocAllocator!(Map.Bucket)(attempt_gc_track);
}



version (UnitTest)
{
    import ocean.util.container.map.model.Bucket;
    unittest
    {
        // Test if creating a map with a bucket compiles.
        BucketElementMallocAllocator!(Bucket!(hash_t.sizeof, hash_t)) allocator;
    }
}
