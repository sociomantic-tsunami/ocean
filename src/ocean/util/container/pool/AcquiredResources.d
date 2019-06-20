/*******************************************************************************

    Helper structs for a specific execution context to acquire and relinquish
    resources from a shared pool.

    (Examples of an "execution context" include `Task`s or connection handlers.)

    Several utilities are provided in this module, all of which build on top of
    `FreeList`:
        * `Acquired`: Tracks instances of a specific type acquired from the
          shared resources and automatically relinquishes them when the
          execution context exits.
        * `AcquiredArraysOf`: Tracks arrays of a specific type acquired from the
          shared resources and automatically relinquishes them when the
          execution context exits.
        * `AcquiredSingleton`: Tracks a singleton instance acquired from the
          shared resources and automatically relinquishes it when the execution
          context exits.

    The normal approach to using these utilities is as follows:
        1. Create a class to store the shared resources pools. Let's call it
           `SharedResources`.
        2. Add your resource pools to `SharedResources`. A `FreeList!(ubyte[])`
           is required, but you should add pools of other types you need as
           well.
        3. New the resource pools in the constructor.
        4. Create a nested class inside `SharedResources`. An instance of this
           class will be newed at scope inside each execution context, and will
           track the shared resources that the execution context has acquired.
           Let's call it `AcquiredResources`.
        5. Add `Acquired*` private members to `AcquiredResources`, as required.
           There should be one member per type of resource that the execution
           context might need to acquire.
        6. Initialise the acquired members in the constructor, and relinquish
           them in the destructor.
        7. Add public getters for each type of resource that can be acquired.
           These should call the `acquire` method of the appropriate acquired
           member, and return the newly acquired instance to the user.

    Usage examples:
        See documented unittests of `Acquired`, `AcquiredArraysOf`, and
        `AcquiredSingleton`.

    Copyright:
        Copyright (c) 2016-2018 dunnhumby Germany GmbH.
        All rights reserved

    License:
        Boost Software License Version 1.0. See LICENSE.txt for details.

*******************************************************************************/

module ocean.util.container.pool.AcquiredResources;

import ocean.transition;
import ocean.core.Verify;
import ocean.util.container.pool.FreeList;

/*******************************************************************************

    Set of resources of the templated type acquired by an execution context. An
    external source of elements of this type -- a FreeList!(T) -- as well as a
    source of untyped buffers -- a FreeList!(ubyte[]) -- is required. When
    resources are acquired (via the acquire() method), they are requested from
    the free list and stored internally in an array. When the resources are no
    longer required, the relinquishAll() method will return them to the free
    list. Note that the array used to store the acquired resources is itself
    acquired from the free list of untyped buffers and relinquished by
    relinquishAll().

    Params:
        T = type of resource

*******************************************************************************/

public struct Acquired ( T )
{
    import ocean.util.container.VoidBufferAsArrayOf;

    /// Type of a new resource. (Differs for reference / value types.)
    static if ( is(typeof({T* t = new T;})) )
    {
        alias T* Elem;
    }
    else
    {
        alias T Elem;
    }

    /// Externally owned pool of untyped buffers, passed in via initialise().
    private FreeList!(ubyte[]) buffer_pool;

    /// Externally owned pool of T, passed in via initialise().
    private FreeList!(T) t_pool;

    /// List of acquired resources.
    private VoidBufferAsArrayOf!(Elem) acquired;

    /// Backing buffer for this.acquired.
    private void[] buffer;

    /***************************************************************************

        Initialises this instance. (No other methods may be called before
        calling this method.)

        Params:
            buffer_pool = shared pool of untyped arrays
            t_pool = shared pool of T

    ***************************************************************************/

    public void initialise ( FreeList!(ubyte[]) buffer_pool, FreeList!(T) t_pool )
    {
        (&this).buffer_pool = buffer_pool;
        (&this).t_pool = t_pool;
    }

    /***************************************************************************

        Gets a new T.

        Params:
            new_t = lazily initialised new resource

        Returns:
            a new T

    ***************************************************************************/

    public Elem acquire ( lazy Elem new_t )
    {
        verify((&this).buffer_pool !is null);

        // Acquire container buffer, if not already done.
        if ( (&this).buffer is null )
        {
            (&this).buffer = acquireBuffer((&this).buffer_pool, Elem.sizeof * 4);
            (&this).acquired = VoidBufferAsArrayOf!(Elem)(&(&this).buffer);
        }

        // Acquire new element.
        (&this).acquired ~= (&this).t_pool.get(new_t);

        return (&this).acquired.array()[$-1];
    }

    /***************************************************************************

        Relinquishes all shared resources acquired by this instance.

    ***************************************************************************/

    public void relinquishAll ( )
    {
        verify((&this).buffer_pool !is null);

        if ( (&this).buffer !is null )
        {
            // Relinquish acquired Ts.
            foreach ( ref inst; (&this).acquired.array() )
                (&this).t_pool.recycle(inst);

            // Relinquish container buffer.
            (&this).buffer_pool.recycle(cast(ubyte[])(&this).buffer);
        }
    }
}

///
unittest
{
    // Type of a specialised resource which may be required by an execution
    // context.
    struct MyResource
    {
    }

    // Demonstrates how a typical global shared resources container should look.
    // A single instance of this would be owned at the top level of the app.
    class SharedResources
    {
        import ocean.util.container.pool.FreeList;

        // The pool of untyped buffers required by Acquired.
        private FreeList!(ubyte[]) buffers;

        // The pool of specialised resources required by Acquired.
        private FreeList!(MyResource) myresources;

        this ( )
        {
            this.buffers = new FreeList!(ubyte[]);
            this.myresources = new FreeList!(MyResource);
        }

        // Objects of this class will be newed at scope and passed to execution
        // contexts. This allows the context to acquire various shared resources
        // and have them automatically relinquished when it exits.
        class ContextResources
        {
            // Tracker of resources acquired by the context.
            private Acquired!(MyResource) acquired_myresources;

            // Initialise the tracker in the ctor.
            this ( )
            {
                this.acquired_myresources.initialise(this.outer.buffers,
                    this.outer.myresources);
            }

            // ...and be sure to relinquish all the acquired resources in the
            // dtor.
            ~this ( )
            {
                this.acquired_myresources.relinquishAll();
            }

            // Public method to get a new resource, managed by the tracker.
            public MyResource* getMyResource ( )
            {
                return this.acquired_myresources.acquire(new MyResource);
            }
        }
    }

    // Demonstrates the usage of the shared resources and the context resources.
    class Context
    {
        SharedResources resources;

        void entryPoint ( )
        {
            // New a ContextResources as scope, so that its dtor will be called
            // at scope exit and all acquired resources relinquished.
            scope acquired = this.resources.new ContextResources;

            // Acquire some resources.
            auto r1 = acquired.getMyResource();
            auto r2 = acquired.getMyResource();
            auto r3 = acquired.getMyResource();
        }
    }
}

/*******************************************************************************

    Set of acquired arrays of the templated type acquired by an execution
    context. An external source of untyped arrays -- a FreeList!(ubyte[]) -- is
    required. When arrays are acquired (via the acquire() method), they are
    requested from the free list and stored internally in a container array.
    When the arrays are no longer required, the relinquishAll() method will
    return them to the free list. Note that the container array used to store
    the acquired arrays is also itself acquired from the free list and
    relinquished by relinquishAll().

    Params:
        T = element type of the arrays

*******************************************************************************/

public struct AcquiredArraysOf ( T )
{
    import ocean.util.container.VoidBufferAsArrayOf;

    /// Externally owned pool of untyped buffers, passed in via initialise().
    private FreeList!(ubyte[]) buffer_pool;

    /// List of void[] backing buffers for acquired arrays of T. This array is
    /// stored as a VoidBufferAsArrayOf!(void[]) in order to be able to handle
    /// it as if it's a void[][], where it's actually a simple void[] under the
    /// hood.
    private VoidBufferAsArrayOf!(void[]) acquired;

    /// Backing buffer for this.acquired.
    private void[] buffer;

    /***************************************************************************

        Initialises this instance. (No other methods may be called before
        calling this method.)

        Params:
            buffer_pool = shared pool of untyped arrays

    ***************************************************************************/

    public void initialise ( FreeList!(ubyte[]) buffer_pool )
    {
        (&this).buffer_pool = buffer_pool;
    }

    /***************************************************************************

        Figure out the return type of this.acquire. It's pointless (and not
        possible) to have a VoidBufferAsArrayOf!(void), so if T is void, we only
        need a method to return a void[]* directly. If T is not void, we need a
        method to return a VoidBufferAsArrayOf!(T).

    ***************************************************************************/

    static if (is(T == void) )
    {
        /***********************************************************************

            Gets a pointer to a new array, acquired from the shared resources
            pool.

            Returns:
                pointer to a new void[]

        ***********************************************************************/

        public void[]* acquire ( )
        {
            return (&this).acquireNewBuffer();
        }
    }
    else
    {
        /***********************************************************************

            Gets a new void[] wrapped with an API allowing it to be used as a
            T[], acquired from the shared resources pool.

            Returns:
                a void[] wrapped with an API allowing it to be used as a T[]

        ***********************************************************************/

        public VoidBufferAsArrayOf!(T) acquire ( )
        {
            auto new_buf = (&this).acquireNewBuffer();
            return VoidBufferAsArrayOf!(T)(new_buf);
        }
    }

    /***************************************************************************

        Relinquishes all shared resources acquired by this instance.

    ***************************************************************************/

    public void relinquishAll ( )
    {
        verify((&this).buffer_pool !is null);

        if ( (&this).buffer !is null )
        {
            // Relinquish acquired buffers.
            foreach ( ref inst; (&this).acquired.array() )
                (&this).buffer_pool.recycle(cast(ubyte[])inst);

            // Relinquish container buffer.
            (&this).buffer_pool.recycle(cast(ubyte[])(&this).buffer);
        }
    }

    /***************************************************************************

        Gets a void[] from the pool of buffers, appends it to the list of
        acquired buffers, then returns a pointer to element in the list.

        Returns:
            a pointer to a new void[] in the list of acquired buffers

    ***************************************************************************/

    private void[]* acquireNewBuffer ( )
    {
        verify((&this).buffer_pool !is null);

        enum initial_array_capacity = 4;

        // Acquire container buffer, if not already done.
        if ( (&this).buffer is null )
        {
            (&this).buffer = acquireBuffer((&this).buffer_pool,
                (void[]).sizeof * initial_array_capacity);
            (&this).acquired = VoidBufferAsArrayOf!(void[])(&(&this).buffer);
        }

        // Acquire and re-initialise new buffer to return to the user. Store
        // it in the container buffer.
        (&this).acquired ~= acquireBuffer((&this).buffer_pool,
            T.sizeof * initial_array_capacity);

        return &((&this).acquired.array()[$-1]);
    }
}

///
unittest
{
    // Demonstrates how a typical global shared resources container should look.
    // A single instance of this would be owned at the top level of the app.
    class SharedResources
    {
        import ocean.util.container.pool.FreeList;

        // The pool of untyped buffers required by AcquiredArraysOf.
        private FreeList!(ubyte[]) buffers;

        this ( )
        {
            this.buffers = new FreeList!(ubyte[]);
        }

        // Objects of this class will be newed at scope and passed to execution
        // contexts. This allows the context to acquire various shared resources
        // and have them automatically relinquished when it exits.
        class ContextResources
        {
            // Tracker of buffers acquired by the context.
            private AcquiredArraysOf!(void) acquired_void_buffers;

            // Initialise the tracker in the ctor.
            this ( )
            {
                this.acquired_void_buffers.initialise(this.outer.buffers);
            }

            // ...and be sure to relinquish all the acquired resources in the
            // dtor.
            ~this ( )
            {
                this.acquired_void_buffers.relinquishAll();
            }

            // Public method to get a new resource, managed by the tracker.
            public void[]* getVoidBuffer ( )
            {
                return this.acquired_void_buffers.acquire();
            }
        }
    }

    // Demonstrates the usage of the shared resources and the context resources.
    class Context
    {
        SharedResources resources;

        void entryPoint ( )
        {
            // New a ContextResources as scope, so that its dtor will be called
            // at scope exit and all acquired resources relinquished.
            scope acquired = this.resources.new ContextResources;

            // Acquire some buffers.
            auto buf1 = acquired.getVoidBuffer();
            auto buf2 = acquired.getVoidBuffer();
            auto buf3 = acquired.getVoidBuffer();
        }
    }
}

/*******************************************************************************

    Singleton (per-execution context) acquired resource of the templated type.
    An external source of elements of this type -- a FreeList!(T) -- is
    required. When the singleton resource is acquired (via the acquire()
    method), it is requested from the free list and stored internally. All
    subsequent calls to acquire() return the same instance. When the resource is
    no longer required, the relinquish() method will return it to the free list.

    Params:
        T = type of resource

*******************************************************************************/

public struct AcquiredSingleton ( T )
{
    import ocean.util.container.pool.FreeList;

    /// Type of a new resource. (Differs for reference / value types.)
    static if ( is(typeof({T* t = new T;})) )
    {
        alias T* Elem;
    }
    else
    {
        alias T Elem;
    }

    /// Externally owned pool of T, passed in via initialise().
    private FreeList!(T) t_pool;

    /// Acquired resource.
    private Elem acquired;

    /***************************************************************************

        Initialises this instance. (No other methods may be called before
        calling this method.)

        Params:
            t_pool = shared pool of T

    ***************************************************************************/

    public void initialise ( FreeList!(T) t_pool )
    {
        (&this).t_pool = t_pool;
    }

    /***************************************************************************

        Gets the singleton T instance.

        Params:
            new_t = lazily initialised new resource

        Returns:
            singleton T instance

    ***************************************************************************/

    public Elem acquire ( lazy Elem new_t )
    {
        verify((&this).t_pool !is null);

        if ( (&this).acquired is null )
            (&this).acquired = (&this).t_pool.get(new_t);

        verify((&this).acquired !is null);

        return (&this).acquired;
    }

    /***************************************************************************

        Gets the singleton T instance.

        Params:
            new_t = lazily initialised new resource
            reset = delegate to call on the singleton instance when it is first
                acquired by this execution context from the pool. Should perform
                any logic required to reset the instance to its initial state

        Returns:
            singleton T instance

    ***************************************************************************/

    public Elem acquire ( lazy Elem new_t, scope void delegate ( Elem ) reset )
    {
        verify((&this).t_pool !is null);

        if ( (&this).acquired is null )
        {
            (&this).acquired = (&this).t_pool.get(new_t);
            reset((&this).acquired);
        }

        verify((&this).acquired !is null);

        return (&this).acquired;
    }

    /***************************************************************************

        Relinquishes singleton shared resources acquired by this instance.

    ***************************************************************************/

    public void relinquish ( )
    {
        verify((&this).t_pool !is null);

        if ( (&this).acquired !is null )
            (&this).t_pool.recycle((&this).acquired);
    }
}

///
unittest
{
    // Type of a specialised resource which may be required by an execution
    // context.
    struct MyResource
    {
    }

    // Demonstrates how a typical global shared resources container should look.
    // A single instance of this would be owned at the top level of the app.
    class SharedResources
    {
        import ocean.util.container.pool.FreeList;

        // The pool of specialised resources required by AcquiredSingleton.
        private FreeList!(MyResource) myresources;

        this ( )
        {
            this.myresources = new FreeList!(MyResource);
        }

        // Objects of this class will be newed at scope and passed to execution
        // contexts. This allows the context to acquire various shared resources
        // and have them automatically relinquished when it exits.
        class ContextResources
        {
            // Tracker of the singleton resource acquired by the context.
            private AcquiredSingleton!(MyResource) myresource_singleton;

            // Initialise the tracker in the ctor.
            this ( )
            {
                this.myresource_singleton.initialise(this.outer.myresources);
            }

            // ...and be sure to relinquish all the acquired resources in the
            // dtor.
            ~this ( )
            {
                this.myresource_singleton.relinquish();
            }

            // Public method to get the resource singleton for this execution
            // context, managed by the tracker.
            public MyResource* myResource ( )
            {
                return this.myresource_singleton.acquire(new MyResource,
                    ( MyResource* resource )
                    {
                        // When the singleton is first acquired, perform any
                        // logic required to reset it to its initial state.
                        *resource = MyResource.init;
                    }
                );
            }
        }
    }

    // Demonstrates the usage of the shared resources and the context resources.
    class Context
    {
        SharedResources resources;

        void entryPoint ( )
        {
            // New a ContextResources as scope, so that its dtor will be called
            // at scope exit and all acquired resources relinquished.
            scope acquired = this.resources.new ContextResources;

            // Acquire a resource.
            acquired.myResource();

            // Acquire the same resource again.
            acquired.myResource();
        }
    }
}

/*******************************************************************************

    Helper function used by the structs in this module to acquire a void[]
    buffer from the specified free list.

    Params:
        buffer_pool = free list of void[]s to reuse, if one is available
        capacity = if a new buffer is allocated (i.e. the free list is empty),
            this argument specifies its initial dimension (in bytes)

    Returns:
        a buffer acquired from the free list or a newly allocated buffer

*******************************************************************************/

private void[] acquireBuffer ( FreeList!(ubyte[]) buffer_pool, size_t capacity )
{
    auto buffer = buffer_pool.get(cast(ubyte[])new void[capacity]);
    buffer.length = 0;
    enableStomping(buffer);

    return buffer;
}

/*******************************************************************************

    Test that shared resources are acquired and relinquished correctly using the
    helper structs above.

*******************************************************************************/

version ( UnitTest )
{
    import ocean.core.Test;
}

unittest
{
    // Resource types that may be acquired.
    struct MyStruct { }
    class MyClass { }

    class SharedResources
    {
        import ocean.util.container.pool.FreeList;

        private FreeList!(MyStruct) mystructs;
        private FreeList!(MyClass) myclasses;
        private FreeList!(ubyte[]) buffers;

        this ( )
        {
            this.mystructs = new FreeList!(MyStruct);
            this.myclasses = new FreeList!(MyClass);
            this.buffers = new FreeList!(ubyte[]);
        }

        class ContextResources
        {
            private Acquired!(MyStruct) acquired_mystructs;
            private AcquiredSingleton!(MyStruct) mystruct_singleton;
            private Acquired!(MyClass) acquired_myclasses;
            private AcquiredArraysOf!(void) acquired_void_arrays;

            this ( )
            {
                this.acquired_mystructs.initialise(this.outer.buffers,
                    this.outer.mystructs);
                this.mystruct_singleton.initialise(this.outer.mystructs);
                this.acquired_myclasses.initialise(this.outer.buffers,
                    this.outer.myclasses);
                this.acquired_void_arrays.initialise(this.outer.buffers);
            }

            ~this ( )
            {
                this.acquired_mystructs.relinquishAll();
                this.mystruct_singleton.relinquish();
                this.acquired_myclasses.relinquishAll();
                this.acquired_void_arrays.relinquishAll();
            }

            public MyStruct* getMyStruct ( )
            {
                return this.acquired_mystructs.acquire(new MyStruct);
            }

            public MyStruct* myStructSingleton ( )
            {
                return this.mystruct_singleton.acquire(new MyStruct);
            }

            public MyClass getMyClass ( )
            {
                return this.acquired_myclasses.acquire(new MyClass);
            }

            public void[]* getVoidArray ( )
            {
                return this.acquired_void_arrays.acquire();
            }
        }
    }

    auto resources = new SharedResources;

    // Test acquiring some resources.
    {
        scope acquired = resources.new ContextResources;
        test!("==")(resources.buffers.num_idle, 0);
        test!("==")(resources.mystructs.num_idle, 0);
        test!("==")(resources.myclasses.num_idle, 0);

        // Acquire a struct.
        acquired.getMyStruct();
        test!("==")(resources.buffers.num_idle, 0);
        test!("==")(resources.mystructs.num_idle, 0);
        test!("==")(resources.myclasses.num_idle, 0);
        test!("==")(acquired.acquired_mystructs.acquired.length, 1);

        // Acquire a struct singleton twice.
        acquired.myStructSingleton();
        acquired.myStructSingleton();
        test!("==")(resources.buffers.num_idle, 0);
        test!("==")(resources.mystructs.num_idle, 0);
        test!("==")(resources.myclasses.num_idle, 0);
        test!("==")(acquired.acquired_mystructs.acquired.length, 1);

        // Acquire a class.
        acquired.getMyClass();
        test!("==")(resources.buffers.num_idle, 0);
        test!("==")(resources.mystructs.num_idle, 0);
        test!("==")(resources.myclasses.num_idle, 0);
        test!("==")(acquired.acquired_myclasses.acquired.length, 1);

        // Acquire an array.
        acquired.getVoidArray();
        test!("==")(resources.buffers.num_idle, 0);
        test!("==")(resources.mystructs.num_idle, 0);
        test!("==")(resources.myclasses.num_idle, 0);
        test!("==")(acquired.acquired_void_arrays.acquired.length, 1);
    }

    // Test that the acquired resources appear in the free-lists, once the
    // acquired tracker goes out of scope.
    test!("==")(resources.buffers.num_idle, 4); // 3 container arrays + 1
    test!("==")(resources.mystructs.num_idle, 2);
    test!("==")(resources.myclasses.num_idle, 1);

    // Now do it again and test that the resources in the free-lists are reused.
    {
        scope acquired = resources.new ContextResources;
        test!("==")(resources.buffers.num_idle, 4);
        test!("==")(resources.mystructs.num_idle, 2);
        test!("==")(resources.myclasses.num_idle, 1);

        // Acquire a struct.
        acquired.getMyStruct();
        test!("==")(resources.buffers.num_idle, 3);
        test!("==")(resources.mystructs.num_idle, 1);
        test!("==")(resources.myclasses.num_idle, 1);
        test!("==")(acquired.acquired_mystructs.acquired.length, 1);

        // Acquire a class.
        acquired.getMyClass();
        test!("==")(resources.buffers.num_idle, 2);
        test!("==")(resources.mystructs.num_idle, 1);
        test!("==")(resources.myclasses.num_idle, 0);
        test!("==")(acquired.acquired_myclasses.acquired.length, 1);

        // Acquire an array.
        acquired.getVoidArray();
        test!("==")(resources.buffers.num_idle, 0);
        test!("==")(resources.mystructs.num_idle, 1);
        test!("==")(resources.myclasses.num_idle, 0);
        test!("==")(acquired.acquired_void_arrays.acquired.length, 1);
    }

    // No more resources should have been allocated.
    test!("==")(resources.buffers.num_idle, 4); // 3 container arrays + 1
    test!("==")(resources.mystructs.num_idle, 2);
    test!("==")(resources.myclasses.num_idle, 1);
}
