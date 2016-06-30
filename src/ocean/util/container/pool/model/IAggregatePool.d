/*******************************************************************************

    Pool of structs or classes. Adds the following features to the base class:
        * Iteration over all items in the pool, or all busy or idle items. (See
          further notes below.)
        * get() and fill() methods which accept a lazy parameter for a new item
          to be added to the pool, if needed.
        * For structs, and classes with a default (paramaterless) constructor,
          get() and fill() methods which automatically create new pool items,
          without requiring them to be passed via a lazy argument.
        * Implementation of the item index (required by IPool) as a size_t member
          of the item type, called 'object_pool_index'. It is required that the
          item type has this member.

    Iteration can either be 'safe' or 'unsafe' (read-only). R/W (safe) iteration
    operates on an internal copy of the real pool data, thus making it safe to
    modify the pool during an iteration, but obviously entailing additional work
    due to needing to copy the data. Read-only (unsafe) iteration iterates over
    the actual items in the pool, meaning that it is not safe to modify the pool
    while iterating.

    Both types of iteration are handled by scope classes which must be newed to
    get access to an iterator. The R/W (safe) iterator scope classes perform the
    required copy of the set of items to be iterated over upon construction. As
    the IAggregatePool instance contains a single buffer which is used to store
    the iteration set for safe iterators, it is only possible for a single safe
    iterator to be newed at a time. There are asserts in the code to enforce
    this. (The advantage of having the safe iterator as a scope class is that it
    can be newed, performing the required copy once, then used multiple times,
    rather then doing the copy upon every iteration, as might be the case if a
    simple opApply method existed.)

    Iteration usage example (with ObjectPool):

    ---

        import ocean.util.container.pool.ObjectPool;

        void main ( )
        {
            class MyClass { size_t object_pool_index; }

            auto pool = new ObjectPool!(MyClass);

            // use pool

            scope busy_items = pool.new BusyItemsIterator;

            foreach ( busy_item; busy_items )
            {
                // busy_item now iterates over the items in the pool that
                // were busy when busy_items was created.
            }
        }

    ---

    Important note about newing pool iterators:

    Pool iterators must be newed as shown in the example above, *not* like this:

        foreach ( busy_item; pool.new BusyItemsIterator )

    This is because the iterators are declared as scope classes, meaning that
    the compiler should enforce that they can *only* be newed as scope (i.e. on
    the stack). Unfortunately the compiler doesn't always enforce this
    requirement, and will allow a scope class to be allocated on the heap in
    certain situations, one of these being the foreach situation shown above.

    Note about ref iteration over pools:

    If the pool items are structs, 'ref' iteration is required to make the
    modification of the items iterated over permanent. For objects 'ref' should
    not be used.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.pool.model.IAggregatePool;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.util.container.pool.model.IPool;
import ocean.util.container.pool.model.IFreeList;

import ocean.core.Array: copyExtend;



/*******************************************************************************

    Template to determine the internal item type of a free list.

    Template_Params:
        T = item type to be stored in free list

*******************************************************************************/

private template ItemType_ ( T )
{
    static if (is(T == class))
    {
        alias T ItemType_;
    }
    else
    {
        alias T* ItemType_;
    }
}


/*******************************************************************************

    Base class for pools of aggregate types (classes or structs). The items'
    index (required by the IPool base class) is implemented as a size_t member
    named 'object_pool_index', which is expected to exist in the type stored in
    the pool.

    Note: certain methods are overridden and have asserts added to them to
    support the iteration. These asserts are deliberately not placed in an in
    contract, due to the way in contracts work -- in a class hierarchy only
    *one* of the class' in contracts must pass, *not* all. In this case, as the
    base class has no in contract, it would always pass, making any in contracts
    added here irrelevant.

    Template_Params:
        T = type stored in pool (must be a struct or a class)

*******************************************************************************/

public abstract class IAggregatePool ( T ) : IPool, IFreeList!(ItemType_!(T))
{
    /***************************************************************************

        Asserts that T is either a struct or a class.

    ***************************************************************************/

    static assert(is(T == class) || is(T == struct));

    /***************************************************************************

        Asserts that T has dynamic "object_pool_index" member of type size_t.

    ***************************************************************************/

    static if (is (typeof (T.init.object_pool_index) I))
    {
        static assert (!is (typeof (&(T.object_pool_index))), T.stringof ~ ".object_pool_index must be a dynamic member");

        static assert (
            is(I == size_t) || is(I == uint),
            T.stringof ~ ".object_pool_index must be size_t, not " ~ I.stringof
        );

        static if (is(I == uint))
        {
            pragma (msg, "Consider changing the type of " ~ T.stringof
                ~ ".object_pool_index from uint to size_t for improved 64-bit "
                ~ "correctness and easier D2 migration");
        }

        // WORKAROUND: because of DMD1 bug placing this condition in static assert
        // directly causes it to fail even if condition is in fact true. Using
        // intermediate constant fixes that
        const _assignable = is(typeof({ T t; t.object_pool_index = 4711; }));
        static assert (
            _assignable,
            T.stringof ~ ".object_pool_index must be assignable"
        );
    }
    else static assert (false, "need dynamic \"size_t " ~ T.stringof ~ ".object_pool_index\"");

    /***************************************************************************

        Pool item instance type alias.

    ***************************************************************************/

    public alias ItemType_!(T) ItemType;

    /***************************************************************************

        D2 compiler refuses to resolve `Item` type from IPool implicitly which
        may be a bug but is easily fixed by introducing explicit alias.

    ***************************************************************************/

    public alias IPool.Item Item;

    /**************************************************************************

        List of items (objects) in pool for safe iteration. items is copied into
        this array on safe iterator instantiation.

     **************************************************************************/

    protected Item[] iteration_items;

    /**************************************************************************

        true if a safe iterator instance exists currently, used for assertions
        to ensure that only a single safe iterator can exist at a time (as it
        uses the single buffer, iteration_items, above).

     **************************************************************************/

    protected bool safe_iterator_open = false;

    /**************************************************************************

        Count of unsafe iterator instances which exist currently, used for
        assertions to ensure that while an unsafe iterator exists the object
        pool may not be modified.

     **************************************************************************/

    protected size_t unsafe_iterators_open = 0;

    /***************************************************************************

        Takes an idle item from the pool or creates a new one if all item
        are busy or the pool is empty.

        Params:
            new_item = expression that creates a new instance of T

        Returns:
            pool item

        Throws:
            LimitExceededException if limitation is enabled and all pool
            items are busy.

    ***************************************************************************/

    public ItemType get ( lazy ItemType new_item )
    out (item)
    {
        assert (item !is null);
    }
    body
    {
        return this.fromItem(super.get_(Item.from(new_item)));
    }

    /***************************************************************************

        Ensures that the pool contains at least the specified number of items.
        Useful to pre-allocate a pool of a certain size.

        Params:
            num = minimum number of items desired in pool
            new_item = expression that creates a new instance of T

        Returns:
            this

        Throws:
            LimitExceededException if the requested number of items exceeds
            the previously specified limit.

    ***************************************************************************/

    public typeof(this) fill ( size_t num, lazy ItemType new_item )
    {
        super.fill_(num, this.toItem(new_item));
        return this;
    }

    /***************************************************************************

        get() and fill() requests without an expression which returns "new T"
        exist in the class if type T can be newed without requiring any
        constructor arguments. This is always the case when T is a struct, and
        is also the case when T is a class with a constructor with no arguments.

    ***************************************************************************/

    static if (is (typeof (new T)))
    {
        /***********************************************************************

            Takes an idle item from the pool or creates a new one if all item
            are busy or the pool is empty.

            Returns:
                pool item

            Throws:
                LimitExceededException if limitation is enabled and all pool
                items are busy.

        ***********************************************************************/

        public ItemType get ( )
        out (item)
        {
            assert (item !is null);
        }
        body
        {
            return this.get(new T);
        }

        /**********************************************************************

            Ensures that the pool contains at least the specified number of
            items. Useful to pre-allocate a pool of a certain size.

            Params:
                num = minimum number of items desired in pool

            Returns:
                this

         **********************************************************************/

        public typeof(this) fill ( size_t num )
        {
            return this.fill(num, new T);
        }
    }

    /***************************************************************************

        Puts item back to the pool.

        Params:
            item = item to put back

        Returns:
            this instance

    ***************************************************************************/

    public void recycle ( ItemType item )
    {
        super.recycle_(Item.from(item));
    }

    /***************************************************************************

        Minimizes the number of items in the pool, removing idle items in excess
        of the specified number. Only idle items will be removed, busy items are
        not affected. The reset() method (if existing) of any removed items is
        called before they are deleted.

        Params:
            num = maximum number of items desired in pool

        Returns:
            this

    ***************************************************************************/

    public typeof(this) minimize ( size_t num = 0 )
    {
        assert (!this.unsafe_iterators_open, "cannot minimize pool while iterating over items");

        if ( this.num_idle > num )
        {
            this.truncate(this.num_idle - num);
        }

        return this;
    }

    /**************************************************************************

        Recycles all items in the pool.

        This method is overridden simply in order to add an iteration assert.

        Returns:
            this instance

     **************************************************************************/

    override public typeof(this) clear ( )
    {
        assert (!this.unsafe_iterators_open, "cannot clear pool while iterating over items");

        super.clear();
        return this;
    }

    /**************************************************************************

        Sets the limit of number of items in pool or disables limitation for
        limit = unlimited.

        This method is overridden simply in order to add iteration asserts.

        Params:
            limit = new limit of number of items in pool; unlimited disables
                limitation

        Returns:
            limit

        Throws:
            LimitExceededException if the number of busy pool items exceeds
            the desired limit.

     **************************************************************************/

    override public size_t setLimit ( size_t limit )
    {
        assert (!this.safe_iterator_open, "cannot set the limit while iterating over items");
        assert (!this.unsafe_iterators_open, "cannot set the limit while iterating over items");

        return super.setLimit(limit);
    }

    /**************************************************************************

        Obtains the n-th pool item. n must be less than the value returned by
        length().
        Caution: The item must not be recycled; while the item is in use, only
        opIndex(), opApply(), length() and limit() may be called.

        TODO: is this ever used? Seems rather obscure.

        Params:
            n = item index

        Returns:
            n-th pool item

    **************************************************************************/

    public ItemType opIndex ( size_t n )
    /+out (obj)
    {
        assert (obj !is null);
    }
    body+/
    {
        return this.fromItem(super.opIndex_(n));
    }

    /**************************************************************************

        Takes an idle item from the pool or creates a new one if all item are
        busy or the pool is empty.

        This method is overridden simply in order to add an iteration assert.

        Params:
            new_item = expression that creates a new Item instance

        Returns:
            pool item

        Throws:
            LimitExceededException if limitation is enabled and all pool items
            are busy

    **************************************************************************/

    override protected Item get_ ( lazy Item new_item )
    {
        assert (!this.unsafe_iterators_open, "cannot get from pool while iterating over items");

        return super.get_(new_item);
    }

    /***************************************************************************

        Puts item back to the pool.

        This method is overridden simply in order to add an iteration assert.

        Params:
            item_in = item to put back

    ***************************************************************************/

    override protected void recycle_ ( Item item_in )
    {
        assert (!this.unsafe_iterators_open, "cannot recycle while iterating over items");

        super.recycle_(item_in);
    }

    /**************************************************************************

        Returns the member of the item union that is used by this instance.

        Params:
            item = item union instance

        Returns:
            the member of the item union that is used by this instance.

     **************************************************************************/

    protected static ItemType fromItem ( Item item )
    {
        static if (is (ItemType == class))
        {
            return cast (ItemType) item.obj;
        }
        else
        {
            return cast (ItemType) item.ptr;
        }
    }

    /**************************************************************************

        Sets the member of the item union that is used by this instance.

        Params:
            item = item to set to an item union instance

        Returns:
            item union instance with the member set that is used by this
            instance.

     **************************************************************************/

    protected static Item toItem ( ItemType item )
    {
        Item item_out;

        static if (is (ItemType == class))
        {
            item_out.obj = item;
        }
        else
        {
            item_out.ptr = item;
        }

        return item_out;
    }

    /**************************************************************************

        Sets the object pool index to item.

        Params:
            item = item to set index
            n    = index to set item to

     **************************************************************************/

    protected override void setItemIndex ( Item item, size_t n )
    {
        // For slower and smoother transition initially assumes index still
        // contains at most uint.max value while using size_t in API. Later
        // `uint object_pool_index` will become deprecated and this cast removed
        assert (n < uint.max);
        this.fromItem(item).object_pool_index = cast(uint) n;
    }

    /**************************************************************************

        Gets the object pool index of item.

        Params:
            item = item to get index from

        Returns:
            object pool index of item.

     **************************************************************************/

    protected override size_t getItemIndex ( Item item )
    {
        return this.fromItem(item).object_pool_index;
    }

    /**************************************************************************

        Resets item.

        Params:
            item = item to reset

     **************************************************************************/

    abstract protected override void resetItem ( Item item );

    /**************************************************************************

        Deletes item and sets it to null.

        Params:
            item = item to delete

     **************************************************************************/

    protected override void deleteItem ( ref Item item )
    out
    {
        assert (this.isNull(item));
    }
    body
    {
        static if (is (ItemType == class))
        {
            delete item.obj;
            item.obj = null;
        }
        else
        {
            delete item.ptr;
            item.ptr = null;
        }
    }

    /**************************************************************************

        Checks a and b for identity.

        Params:
            a = item to check for being identical to b
            b = item to check for being identical to a

        Returs:
            true if a and b are identical or false otherwise.

     **************************************************************************/

    protected override bool isSame ( Item a, Item b )
    {
        return this.fromItem(a) is this.fromItem(b);
    }

    /**************************************************************************

        Checks if item is null.

        Params:
            item = item to check for being null

        Returs:
            true if item is null or false otherwise.

     **************************************************************************/

    protected override bool isNull ( Item item )
    {
        return this.fromItem(item) is null;
    }

    /***************************************************************************

        Base class for pool 'foreach' iterators. The constructor receives a
        slice of the items to be iterated over.

        Note that the iterators pass the pool items as type T to the foreach
        delegate, not as type ItemType. This is because, when ref iterating over
        a pool of structs, we want the references to be to the structs in the
        pool themselves, not the pointer to the structs in the pool.

    ***************************************************************************/

    protected abstract scope class IItemsIterator
    {
        protected Item[] iteration_items;

        /***********************************************************************

            Constructor

            Params:
                iteration_items = items to be iterated over (sliced)

        ***********************************************************************/

        protected this ( Item[] iteration_items )
        {
            this.iteration_items = iteration_items;
        }

        /***********************************************************************

            'foreach' iteration over items[start .. end]

        ***********************************************************************/

        public int opApply ( int delegate ( ref T item ) dg )
        {
            int ret = 0;

            foreach ( ref item; this.iteration_items )
            {
                static if (is (T == class))
                {
                    assert (item.obj !is null);

                    T item_out = cast (T) item.obj;

                    ret = dg(item_out);
                }
                else
                {
                    assert (item.ptr !is null);

                    ret = dg(*cast (T*) item.ptr);
                }

                if ( ret )
                {
                    break;
                }
            }

            return ret;
        }

        /***********************************************************************

            'foreach' iteration over items[start .. end], with index (0-based)

        ***********************************************************************/

        public int opApply ( int delegate ( ref size_t i, ref T item ) dg )
        {
            int ret = 0;
            size_t i = 0;

            foreach ( ref item; this )
            {
                ret = dg(i, item);
                if ( ret )
                {
                    break;
                }
                i++;
            }

            return ret;
        }
    }

    /***************************************************************************

        Provides 'foreach' iteration over items[start .. end]. During
        iteration all methods of PoolCore may be called except limit_().

        The iteration is actually over a copy of the items in the pool which
        are specified in the constructor. Thus the pool may be modified
        while iterating. However, the list of items iterated over is not
        updated to changes made by get(), clear() and recycle().

        During iteration all Pool methods may be called except the limit setter.
        However, as indicated, the list of items iterated over is not updated to
        changes made by get(), recycle() and clear().

    ***************************************************************************/

    protected abstract scope class SafeItemsIterator : IItemsIterator
    {
        /***********************************************************************

            Constructor

            Params:
                start = start item index
                end   = end item index (excluded like array slice end index)

            In:
                No instance of this class may exist.

        ***********************************************************************/

        protected this ( size_t start, size_t end )
        in
        {
            assert (!this.outer.safe_iterator_open);
        }
        body
        {
            this.outer.safe_iterator_open = true;
            auto slice = this.outer.items[start .. end];
            enableStomping(this.outer.iteration_items);
            this.outer.iteration_items.length = slice.length;
            slice = (this.outer.iteration_items[] = slice[]);
            super(slice);
        }

        /***********************************************************************

            Destructor

        ***********************************************************************/

        ~this ( )
        {
            this.outer.safe_iterator_open = false;
        }
    }

    /***************************************************************************

        Provides 'foreach' iteration over items[start .. end]. During
        iteration only read-only methods of PoolCore may be called.

        The unsafe iterator is more efficient as it does not require the
        copy of the items being iterated, which the safe iterator performs.

    ***************************************************************************/

    protected abstract scope class UnsafeItemsIterator : IItemsIterator
    {
        /***********************************************************************

            Constructor

            Params:
                start = start item index
                end   = end item index (excluded like array slice end index)

        ***********************************************************************/

        protected this ( size_t start, size_t end )
        {
            this.outer.unsafe_iterators_open++;
            super(this.outer.items[start .. end]);
        }

        /***********************************************************************

            Destructor

        ***********************************************************************/

        ~this ( )
        {
            this.outer.unsafe_iterators_open--;
        }
    }

    /***************************************************************************

        Iterator classes, each one provides 'foreach' iteration over a subset
        if the items in the pool:

         - AllItemsIterator iterates over all items in the pool,
         - BusyItemsIterator iterates over the items that are busy on
           instantiation,
         - IdleItemsIteratoriterates over the items that are idle on
           instantiation.

    ***************************************************************************/

    /***************************************************************************

        Provides safe 'foreach' iteration over all items in the pool.

    ***************************************************************************/

    public scope class AllItemsIterator : SafeItemsIterator
    {
        this ( )
        {
            super(0, this.outer.items.length);
        }
    }

    /***************************************************************************

        Provides unsafe 'foreach' iteration over all items in the pool.

    ***************************************************************************/

    public scope class ReadOnlyAllItemsIterator : UnsafeItemsIterator
    {
        this ( )
        {
            super(0, this.outer.items.length);
        }
    }

    /***************************************************************************

        Provides safe 'foreach' iteration over the busy items in the pool.

    ***************************************************************************/

    public scope class BusyItemsIterator : SafeItemsIterator
    {
        this ( )
        {
            super(0, this.outer.num_busy_);
        }
    }

    /***************************************************************************

        Provides unsafe 'foreach' iteration over the busy items in the pool.

    ***************************************************************************/

    public scope class ReadOnlyBusyItemsIterator : UnsafeItemsIterator
    {
        this ( )
        {
            super(0, this.outer.num_busy_);
        }
    }

    /***************************************************************************

        Provides safe 'foreach' iteration over the idle items in the pool.

    ***************************************************************************/

    public scope class IdleItemsIterator : SafeItemsIterator
    {
        this ( )
        {
            super(this.outer.num_busy_, this.outer.items.length);
        }
    }

    /***************************************************************************

        Provides unsafe 'foreach' iteration over the idle items in the pool.

    ***************************************************************************/

    public scope class ReadOnlyIdleItemsIterator : UnsafeItemsIterator
    {
        this ( )
        {
            super(this.outer.num_busy_, this.outer.items.length);
        }
    }
}



version ( UnitTest )
{
    /***************************************************************************

        Agrregate pool tester base class. Tests all methods of IAggregatePool.
        Derived from the free list tester (as an IAggregatePool is an
        IFreeList).

        Template_Params:
            T = type of item stored in pool

    ***************************************************************************/

    abstract class IAggregatePoolTester ( T ) : FreeListTester!(ItemType_!(T))
    {
        /***********************************************************************

            Pool being tested.

        ***********************************************************************/

        private alias IAggregatePool!(T) Pool;

        private Pool pool;


        /***********************************************************************

            Constructor.

            Params:
                pool = pool to test

        ***********************************************************************/

        public this ( Pool pool )
        {
            super(pool);
            this.pool = pool;
        }


        /***********************************************************************

            Unittest for internal pool. Runs the IFreeList test, then a series
            of additional tests to check the features of the IAggregatePool.

        ***********************************************************************/

        override public void test ( )
        {
            // Test IFreeList features
            super.test();

            this.pool.clear();
            this.pool.minimize();

            // Test ILimitable features
            this.limitTest();

            this.pool.clear();
            this.pool.minimize();

            // Test iterators
            this.iteratorTest();
        }


        /***********************************************************************

            Checks that the contents of the pool match the expected values.

            Params:
                expected_busy = expected number of busy items
                expected_idle = expected number of idle items

        ***********************************************************************/

        override protected void lengthCheck ( size_t expected_busy,
            size_t expected_idle )
        {
            assert(this.pool.num_busy == expected_busy, "AggregatePool busy items wrong");
            assert(this.pool.length == expected_busy + expected_idle, "AggregatePool length was wrong");

            super.lengthCheck(expected_busy, expected_idle);
        }


        /***********************************************************************

            Tests the limit features of IAggregatePool.

        ***********************************************************************/

        private void limitTest ( )
        {
            // Check that initially not limited
            this.limitCheck(false);

            // Set limit
            this.pool.setLimit(this.num_items);
            this.limitCheck(true, this.num_items);

            // Get items up to limit
            size_t busy_count, idle_count;
            for ( int i; i < this.num_items; i++ )
            {
                this.pool.get(this.newItem());
                this.lengthCheck(++busy_count, idle_count);
            }
            assert(idle_count == 0, "idle count mismatch");

            // Check that getting another item is prevented
            bool get_prevented;
            try
            {
                this.pool.get(this.newItem());
            }
            catch ( LimitExceededException e )
            {
                get_prevented = true;
            }
            assert(get_prevented, "AggregatePool limitation failed");
            this.lengthCheck(busy_count, idle_count);

            // Recycle all items (clear)
            this.pool.clear();
            idle_count = busy_count;
            busy_count = 0;
            this.lengthCheck(busy_count, idle_count);

            // Reduce limit
            this.pool.setLimit(this.num_items / 2);
            idle_count = this.num_items / 2;
            this.limitCheck(true, this.num_items / 2);
            this.lengthCheck(busy_count, idle_count);

            // Remove limit
            this.pool.setLimit(this.pool.unlimited);
            this.limitCheck(false);

            // Get items beyond old limit
            for ( int i; i < this.num_items * 2; i++ )
            {
                auto item = this.pool.get(this.newItem());
                this.setItem(item, i);
                if ( idle_count ) idle_count--;
                this.lengthCheck(++busy_count, idle_count);
            }
            assert(idle_count == 0, "idle count mismatch");
        }


        /***********************************************************************

            Tests the iteration features of IAggregatePool.

        ***********************************************************************/

        private void iteratorTest ( )
        {
            // Get some items
            size_t busy_count, idle_count;
            for ( int i; i < this.num_items; i++ )
            {
                auto item = this.pool.get(this.newItem());
                this.setItem(item, i);
                this.lengthCheck(++busy_count, idle_count);
            }
            assert(idle_count == 0, "idle count mismatch");

            // Check safe busy items iterator
            {
                size_t count;
                scope it = this.pool.new BusyItemsIterator;
                foreach ( i, ref item; it )
                {
                    this.checkIteratorItem(item, i);
                    count++;
                }
                assert(count == this.pool.num_busy, "iterator count wrong");
            }

            // Check read-only busy items iterator
            {
                size_t count;
                scope it = this.pool.new ReadOnlyBusyItemsIterator;
                foreach ( i, ref item; it )
                {
                    this.checkIteratorItem(item, i);
                    count++;
                }
                assert(count == this.pool.num_busy, "iterator count wrong");
            }

            {
                // Recycle the second half of the items
                // Note that after recycling, the order of the items in the
                // second half of the pool are expected to be reversed.
                size_t count;
                scope it = this.pool.new BusyItemsIterator;
                foreach ( i, ref item; it )
                {
                    if ( i >= this.num_items / 2 )
                    {
                        static if ( is(T == class) )
                        {
                            this.pool.recycle(item);
                        }
                        else
                        {
                            static assert(is(T == struct));
                            auto item_p = &item;
                            this.pool.recycle(item_p);
                        }
                    }
                    count++;
                }
                assert(count == this.pool.length, "iterator count wrong");
            }

            // Check safe idle items iterator
            {
                size_t count;
                scope it = this.pool.new IdleItemsIterator;
                foreach ( i, ref item; it )
                {
                    this.checkIteratorItem(item, this.num_items - (i + 1));
                    count++;
                }
                assert(count == this.pool.num_idle, "iterator count wrong");
            }

            // Check read-only idle items iterator
            {
                size_t count;
                scope it = this.pool.new ReadOnlyIdleItemsIterator;
                foreach ( i, ref item; it )
                {
                    this.checkIteratorItem(item, this.num_items - (i + 1));
                    count++;
                }
                assert(count == this.pool.num_idle, "iterator count wrong");
            }

            // Check safe all items iterator
            {
                size_t count;
                scope it = this.pool.new AllItemsIterator;
                foreach ( i, ref item; it )
                {
                    auto num = i >= this.num_items / 2
                        ? this.num_items - ((i - this.num_items / 2) + 1)
                        : i;
                    this.checkIteratorItem(item, num);
                    count++;
                }
                assert(count == this.pool.length, "iterator count wrong");
            }

            // Check read-only all items iterator
            {
                size_t count;
                scope it = this.pool.new ReadOnlyAllItemsIterator;
                foreach ( i, ref item; it )
                {
                    auto num = i >= this.num_items / 2
                        ? this.num_items - ((i - this.num_items / 2) + 1)
                        : i;
                    this.checkIteratorItem(item, num);
                    count++;
                }
                assert(count == this.pool.length, "iterator count wrong");
            }

            // TODO: the iterator checks could be expanded to also check that
            // it's not possible to write while performing a read-only iteration
        }


        /***********************************************************************

            Checks the limitation state of the pool is as expected.

            Params:
                limited = whether the pool is expected to be limited or not
                limit = expected limit (if limited is false, this value is
                    ignored)

        ***********************************************************************/

        private void limitCheck ( bool limited, size_t limit = 0 )
        {
            assert(this.pool.is_limited == limited, "AggregatePool limit flag wrong");
            assert(this.pool.limit == (limited ? limit : this.pool.unlimited),
                "AggregatePool limit wrong");
        }


        /***********************************************************************

            Checks the value of the passed item (from an iterator) against the
            value which can be deterministically derived from the passed
            integer. The method should assert on failure.

            Params:
                item = iterated item to check value of
                i = integer to determine contents of item

        ***********************************************************************/

        private void checkIteratorItem ( ref T item, size_t i )
        {
            static if ( is(T == class) )
            {
                this.checkItem(item, i);
            }
            else
            {
                static assert(is(T == struct));
                auto item_p = &item;
                this.checkItem(item_p, i);
            }
        }
    }
}

