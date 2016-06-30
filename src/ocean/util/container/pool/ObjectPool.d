/*******************************************************************************

    Pool class template which stores class instances, has the
    following features:
        * Get and recycle items. Recycled items will be re-used before creating
          new items.
        * The total number of items, as well as the number of idle or busy items
          in the pool can be queried.
        * A limit can be applied to the pool, which prevents more than the
          specified number of items from being created.
        * A specified number of items can be pre-allocated in the pool using the
          fill() method.
        * The entire pool can be emptied, returning all items to the idle state,
          with clear().
        * Iteration over all items in the pool, or all busy or idle items. (See
          further notes in the super class.)
        * For classes with a default (parameterless) constructor, get() and
          fill() methods exist which automatically create new pool items,
          without requiring them to be passed via a lazy argument.

    An additional class template exists, the AutoCtorPool, which automatically
    creates new instances of the specified class by calling the constructor
    with a fixed set of parameters.

    Also see: ocean.util.container.pool.model.IAggregatePool, for more detailed
    documentation and usage examples.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.pool.ObjectPool;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.pool.model.IAggregatePool;
import ocean.util.container.pool.model.IResettable;

import ocean.transition;

/*******************************************************************************

    Manages a pool of class instances of type T.

    Does not create the items ("new T") internally but receives them as lazy
    arguments in get().

    Template_Params:
        T = type stored in pool

*******************************************************************************/

public class ObjectPool ( T ) : IAggregatePool!(T)
{
    /***************************************************************************

        Asserts that T is a class.

    ***************************************************************************/

    static assert(is(T == class));

    /***************************************************************************

        Resets item.

        Params:
            item = item to reset

    ***************************************************************************/

    protected override void resetItem ( Item item )
    {
        static if (is(T : Resettable))
        {
            this.fromItem(item).reset();
        }
    }
}



/*******************************************************************************

    Extends ObjectPool by creating items (instances of T) automatically with
    "new T(Args)".

    Template_Params:
        T = type stored in pool
        Args = tuple of T constructor argument types.

*******************************************************************************/

public class AutoCtorPool ( T, Args ... ) : ObjectPool!(T)
{
    /***************************************************************************

        Asserts that at least one constructor argument is specified in the Args
        tuple.

    ***************************************************************************/

    static assert(Args.length > 0, "if you want to use a constructor with no arguments, just use ObjectPool");

    /***************************************************************************

        Arguments used to construct pool items. These items are set in the
        class' constructor and are then used to construct all requested pool
        items.

    ***************************************************************************/

    private Args args;

    /***************************************************************************

        Constructor

        Params:
            args = T constructor arguments to be used each time an
                   object is created

    ***************************************************************************/

    public this ( Args args )
    {
        this.args = args;
    }

    /**************************************************************************

        Gets an object from the object pool.

        Returns:
            object from the object pool

     **************************************************************************/

    public ItemType get ( )
    {
        return super.get(new T(args));
    }

    /**************************************************************************

        Ensures that the pool contains at least the specified number of items.
        Useful to pre-allocate a pool of a certain size.

        Params:
            num = minimum number of items desired in pool

        Returns:
            this

        Throws:
            LimitExceededException if the requested number of items exceeds
            the previously specified limit.

     **************************************************************************/

    public typeof(this) fill ( size_t num )
    {
        super.fill_(num, this.toItem(new T(args)));
        return this;
    }

    /**************************************************************************

        Creates a new instance.

        Params:
            args = T constructor arguments to be used each time an object is
                   created

     **************************************************************************/

    static typeof (this) newPool ( Args args )
    {
        return new typeof (this)(args);
    }
}



version ( UnitTest )
{
    class Class
    {
        size_t object_pool_index;

        mixin(genOpEquals(`
        {
            auto crhs = cast(typeof(this)) rhs;
            return this.i == crhs.i && this.s == crhs.s;
        }`));

        size_t i;
        char[] s;
    }

    alias ObjectPool!(Class) MyPool;
    class ObjectPoolTester : IAggregatePoolTester!(Class)
    {
        public this ( )
        {
            super(new MyPool);
        }

        protected override Item newItem ( )
        {
            return new Class;
        }

        protected override void setItem ( ref Item item, size_t i )
        {
            item.i = i;
            item.s.length = 1;
            item.s[0] = cast(char)(i + 32);
        }

        protected override void checkItem ( ref Item item, size_t i )
        {
            assert(item.i == i, "item integer wrong");
            assert(item.s.length == 1, "item string length wrong");
            assert(item.s[0] == cast(char)(i + 32), "item string content wrong");
        }
    }
}

unittest
{
    scope op = new ObjectPoolTester;
    op.test();
}

