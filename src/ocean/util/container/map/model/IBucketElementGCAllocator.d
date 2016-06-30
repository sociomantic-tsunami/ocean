/*******************************************************************************

    Base class for a bucket element allocator using the D runtime memory
    manager. Even though this memory manager is called "GC-managed" this class
    in fact doesn't rely on garbage collection but explicitly deletes unused
    bucket elements.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.map.model.IBucketElementGCAllocator;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.map.model.IAllocator;

/******************************************************************************/

class IBucketElementGCAllocator: IAllocator
{
    /***************************************************************************

        Constructor.

        Params:
            bucket_element_sizeof = the amount of memory used by each allocated
                element.

    ***************************************************************************/

    public this ( size_t bucket_element_sizeof )
    {
        super(bucket_element_sizeof);
    }

    /***************************************************************************

        Deletes a bucket element that is no longer used.

        Params:
            element = old bucket element

    ***************************************************************************/

    protected override void deallocate ( void* element )
    {
        delete element;
    }

    /***************************************************************************

        Helper class to temprarily park a certain number of bucket elements.

    ***************************************************************************/

    static scope class ParkingStack: IParkingStack
    {
        /***********************************************************************

            List of parked object.

        ***********************************************************************/

        private void*[] elements;

        /***********************************************************************

            Constructor.

            Params:
                n = number of objects that will be parked

        ***********************************************************************/

        public this ( size_t n )
        {
            super(n);
            this.elements = new void*[n];
        }


        version (D_Version2) {}
        else
        {
            /*******************************************************************

                Disposer.

            *******************************************************************/

            protected override void dispose ( )
            {
                delete this.elements;
            }
        }

        /**********************************************************************

            Pushes an object on the stack.

            Params:
                element = object to push
                n      = number of parked objects before object is pushed
                         (guaranteed to be less than max_length)

         **********************************************************************/

        protected override void push_ ( void* element, size_t n )
        {
            this.elements[n] = element;
        }

        /**********************************************************************

            Pops an object from the stack. This method is never called if the
            stack is empty.

            Params:
                n = number of parked objects after object is popped (guaranteed
                    to be less than max_length)

            Returns:
                object popped from the stack or null if the stack is empty.

         **********************************************************************/

        protected override void* pop_ ( size_t n )
        {
            return this.elements[n];
        }
    }

    /***************************************************************************

        Calls dg with an IParkingStack instance that is set up to keep n
        elements.

        Params:
            n  = number of elements to park
            dg = delegate to call with the IParkingStack instance

    ***************************************************************************/

    public override void parkElements (size_t n,
                                       void delegate ( IParkingStack park ) dg)
    {
        scope park = new ParkingStack(n);
        dg(park);
    }
}
