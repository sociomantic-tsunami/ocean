/*******************************************************************************

    Free list of dynamically allocated objects.
    Implemented as a linked list; a subclass must get and set the next one of
    a given object.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.map.model.BucketElementFreeList;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.util.container.map.model.IAllocator;

import ocean.core.Array: clear;

/*******************************************************************************

    Free list of currently unused bucket elements.

*******************************************************************************/

class BucketElementFreeList ( BucketElement ) : IBucketElementFreeList
{
    static assert(is(BucketElement == struct),
                  "BucketElement type needs to be a struct, which " ~
                  BucketElement.stringof ~ " is not");

    static if(is(typeof(BucketElement.next) Next))
    {
        static assert(is(Next == BucketElement*),
                      BucketElement.stringof ~ ".next needs to be of type " ~
                      (BucketElement*).stringof ~ ", not " ~ Next.stringof);
    }
    else
    {
        static assert(false, "need " ~ (BucketElement*).stringof ~ " " ~
                             BucketElement.stringof ~ ".next");
    }

    /***************************************************************************

        Constructor.

    ***************************************************************************/

    public this ( )
    {
        super(BucketElement.sizeof);
    }

    /**************************************************************************

        Obtains the next element of element.

        Params:
            element = bucket element of which to obtain the next one

        Returns:
            the next bucket element (which may be null).

     **************************************************************************/

    protected override void* getNext ( void* element )
    {
        return (cast(BucketElement*)element).next;
    }

    /**************************************************************************

        Sets the next element of element.

        Params:
            element = bucket element to which to set the next one
            next    = next bucket element for element (nay be null)

     **************************************************************************/

    protected override void setNext ( void* element, void* next )
    {
        (cast(BucketElement*)element).next = cast(BucketElement*)next;
    }

    /**************************************************************************

        Allocates a bucket element.

        Returns:
            a new bucket element.

     **************************************************************************/

    protected override void* newElement ( )
    {
        return new BucketElement;
    }
}

/*******************************************************************************

    Creates an instance of BucketElementFreeList which is suitable for usage
    with the Map type passed as a template parameter.

    Template_Params:
        Map = the type to create the allocator according to

    Returns:
        an instance of type BucketElementFreeList class

*******************************************************************************/

public BucketElementFreeList!(Map.Bucket.Element) instantiateAllocator ( Map ) ( )
{
    return new BucketElementFreeList!(Map.Bucket.Element);
}


/*******************************************************************************

    Type generic BucketElementFreeList base class.

*******************************************************************************/

abstract class IBucketElementFreeList: IAllocator
{
    /**************************************************************************

        First free element.

     **************************************************************************/

    private void* first = null;

    /**************************************************************************

        Free list length.

     **************************************************************************/

    private size_t n_free = 0;

    /**************************************************************************

        True while a ParkingStack instance for this instance exists.

     **************************************************************************/

    private bool parking_stack_open = false;

    /**************************************************************************

        Consistency check and assertion that at most one ParkingStack instance
        for this instance exists at a time.

     **************************************************************************/

    invariant ( )
    {
        if (this.first)
        {
            assert (this.n_free);
        }
        else
        {
            assert (!this.n_free);
        }

        assert (!this.parking_stack_open, "attempted to use the outer " ~
                typeof (this).stringof ~ " instance of an existing " ~
                ParkingStack.stringof ~ " instance");
    }


    version (D_Version2) {}
    else
    {
        /***********************************************************************

            Disposer.

        ***********************************************************************/

        protected override void dispose ( )
        {
            this.first = null;
            this.n_free = 0;
        }
    }


    /***************************************************************************

        Constructor.

        Params:
            bucket_element_sizeof = the amount of memory used by each allocated
                element.

    ***************************************************************************/

    public this( size_t bucket_element_sizeof )
    {
        super(bucket_element_sizeof);
    }

    /**************************************************************************

        Obtains an object either from the free list, if available, or from
        new_object if the free list is empty.

        Returns:
            new object

        Out:
            The returned object cannot be null.

     **************************************************************************/

    protected override void* allocate ( )
    out (object)
    {
        assert (object !is null);
    }
    body
    {
        if (this.first)
        {
            return this.get_();
        }
        else
        {
            return this.newElement();
        }
    }

    /**************************************************************************

        Allocates a new object. Called by get() if the list is empty.

        Returns:
            a new object.

     **************************************************************************/

    abstract protected void* newElement ( );

    /**************************************************************************

        Appends old_object to the free list.

        Params:
            old_object = object to recycle

        In:
            old_object must not be null.

     **************************************************************************/

    protected override void deallocate ( void* old_object )
    in
    {
        assert (old_object !is null);
    }
    body
    {
        scope (success) this.n_free++;

        this.recycle_(old_object);
    }

    /**************************************************************************

        Returns:
            the number of objects in the free list.

     **************************************************************************/

    public size_t length ( )
    {
        return this.n_free;
    }

    /**************************************************************************

        Obtains the next object of object. object is never null but the next
        object may be.

        Params:
            object = object of which to obtain the next object (is never null)

        Returns:
            the next object (which may be null).

     **************************************************************************/

    abstract protected void* getNext ( void* object );

    /**************************************************************************

        Sets the next object of object. object is never null but next may be.

        Params:
            object = object to which to set the next object (is never null)
            next   = next object for object (nay be null)

     **************************************************************************/

    abstract protected void setNext ( void* object, void* next );

    /**************************************************************************

        Obtains free_list[n] and sets free_list[n] to null.

        Params:
            n = free list index

        Returns:
            free_list[n]

     **************************************************************************/

    private void* get_ ( )
    in
    {
        assert (this.first !is null);
    }
    body
    {
        void* element = this.first;

        this.first = this.getNext(element);
        this.n_free--;
        this.setNext(element, null);

        return element;
    }

    /**************************************************************************

        Appends object to the free list using n as insertion index. n is
        expected to refer to the position immediately after the last object in
        the free list, which may be free_list.length.

        Params:
            n = free list insertion index

        Returns:
            free_list[n]

     **************************************************************************/

    private void* recycle_ ( void* object )
    {
        this.setNext(object, this.first);

        return this.first = object;
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
        scope parking_stack = this.new ParkingStack(n);

        dg(parking_stack);
    }

    /**************************************************************************

        Allows using the free list as a stack to park objects without marking
        them as free. The parked object are appended to the free list after the
        free objects currently in the list.
        At most one ParkingStack instance may exist at a time. While a
        ParkingStack instance exists, no public FreeList method may be used.

     **************************************************************************/

    scope class ParkingStack: IParkingStack
    {
        /**********************************************************************

            Constructor.

            Params:
                max_length = maximum number of objects that will be stored

         **********************************************************************/

        private this ( size_t max_length )
        in
        {
            assert (!this.outer.parking_stack_open);
            this.outer.parking_stack_open = true;
        }
        body
        {
            super(max_length);
        }

        /**********************************************************************

            Destructor; removes the remaining stack elements, if any.

         **********************************************************************/

        ~this ( )
        out
        {
            this.outer.parking_stack_open = false;
        }
        body
        {
            while (this.pop()) { }
        }

        /**********************************************************************

            Pushes an object on the stack.

            Params:
                object = object to push
                n      = number of parked objects before object is pushed
                         (guaranteed to be less than max_length)

         **********************************************************************/

        protected override void push_ ( void* object, size_t n )
        {
            this.outer.recycle_(object);
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
            return this.outer.get_();
        }
    }
}
