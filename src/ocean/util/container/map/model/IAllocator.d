/*******************************************************************************

    Interface for an object allocator.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.map.model.IAllocator;

/******************************************************************************/



abstract class IAllocator
{
    /***************************************************************************

        Tracks amount of memory used by this allocator.

    ***************************************************************************/

    private size_t used_memory;

    /***************************************************************************

        Stores the size of a single allocated element.

    ***************************************************************************/

    protected size_t bucket_element_size;


    /***************************************************************************

        Constructor.

        Params:
            bucket_element_sizeof = the amount of memory used by each allocated
                element.

    ***************************************************************************/

    public this ( size_t bucket_element_sizeof )
    {
        this.bucket_element_size = bucket_element_sizeof;
    }

    /***************************************************************************

        Gets or allocates an object

        Returns:
            an object that is ready to use.

    ***************************************************************************/

    public void* get ( )
    {
        this.used_memory += this.bucket_element_size;
        return this.allocate();
    }

    /***************************************************************************

        Performs the actual allocation of an object

        Returns:
            an object that is ready to use.

    ***************************************************************************/

    protected abstract void* allocate ();

    /***************************************************************************

        Recycles or deletes an object that is no longer used.

        Note: Strictly specking old should be a ref to satisfy D's delete
        expression which wants the pointer as an lvalue in order to set it to
        null after deletion. However, would make code more complex and isn't
        actually necessary in the particular use case of this interface (see
        BucketSet.remove()/clear()).

        Params:
            old = old object

    ***************************************************************************/

    public void recycle ( void* old )
    {
        this.used_memory -= this.bucket_element_size;
        return this.deallocate(old);
    }

    /***************************************************************************

        Performs the actual recycling of an object. See recycle() documentation.

        Params:
            old = old object

    ***************************************************************************/

    protected abstract void deallocate ( void* old );

    /***************************************************************************

        Return the amount of memory currently used.

        Returns:
            the size of the memory allocated by this allocator

    ***************************************************************************/

    public size_t memoryUsed ()
    {
        return this.used_memory;
    }

    /***************************************************************************

        Helper class to temprarily park a certain number of objects.

    ***************************************************************************/

    static abstract /* scope */ class IParkingStack
    {
        /**********************************************************************

            Maximum number of objects as passed to the constructor.

         **********************************************************************/

        public size_t max_length ( )
        {
            return this._max_length;
        }

        private size_t _max_length;

        /**********************************************************************

            Number of elements currently on the stack. This value is always
            at most max_length.

         **********************************************************************/

        private size_t n = 0;

        invariant ( )
        {
            assert(this.n <= this._max_length);
        }

        /**********************************************************************

            Constructor.

            Params:
                max_length = maximum number of objects that will be stored

         **********************************************************************/

        protected this ( size_t max_length )
        {
            this._max_length = max_length;
        }

        /**********************************************************************

            Pushes an object on the stack.

            Params:
                object = object to push

            Returns:
                object

            In:
                Less than max_length objects may be parked.

         **********************************************************************/

        public void* push ( void* object )
        in
        {
            assert(this.n < this._max_length);
        }
        body
        {
            this.push_(object, this.n++);

            return object;
        }

        /**********************************************************************

            Pops an object from the stack.

            Returns:
                object popped from the stack or null if the stack is empty.

            Out:
                If an element is returned, less than max_length elements must be
                on the stack, otherwise the stack must be empty.

         **********************************************************************/

        public void* pop ( )
        out (element)
        {
            if (element)
            {
                assert(this.n < this._max_length);
            }
            else
            {
                assert(!this.n);
            }
        }
        body
        {
            if (this.n)
            {
                return this.pop_(--this.n);
            }
            else
            {
                return null;
            }
        }

        /**********************************************************************

            'foreach' iteration, each cycle pops an element from the stack and
            iterates over it.

         **********************************************************************/

        public int opApply ( int delegate ( ref void* object ) dg )
        {
            int r = 0;

            for (void* object = this.pop(); object && !r; object = this.pop())
            {
                r = dg(object);
            }

            return r;
        }

        /**********************************************************************

            Pushes an object on the stack.

            Params:
                object = object to push
                n      = number of parked objects before object is pushed
                         (guaranteed to be less than max_length)

         **********************************************************************/

        abstract protected void push_ ( void* object, size_t n );

        /**********************************************************************

            Pops an object from the stack. This method is never called if the
            stack is empty.

            Params:
                n = number of parked objects after object is popped (guaranteed
                    to be less than max_length)

            Returns:
                object popped from the stack or null if the stack is empty.

         **********************************************************************/

        abstract protected void* pop_ ( size_t n );
    }

    /***************************************************************************

        Calls dg with an IParkingStack instance that is set up to keep n
        elements.

        Params:
            n  = number of elements to park
            dg = delegate to call with the IParkingStack instance

    ***************************************************************************/

    void parkElements ( size_t n, void delegate ( IParkingStack park ) dg );
}
