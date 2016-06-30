/*******************************************************************************

    Interfaces to manage and get information about a free list.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.pool.model.IFreeList;

import ocean.transition;

/*******************************************************************************

    Informational interface to a free list.

*******************************************************************************/

public interface IFreeListInfo
{
    /***************************************************************************

        Returns the number of idle items in pool.

        Returns:
            the number of idle items in pool

    ***************************************************************************/

    size_t num_idle ( );
}


/*******************************************************************************

    Management interface to a free list.

*******************************************************************************/

public interface IFreeList ( T ) : IFreeListInfo
{
    /***************************************************************************

        Gets an item from the free list.

        Params:
            new_item = new item, will only be evaluated in the case when no
                items are available in the free list

        Returns:
            new item (either popped from free list or new_item)

    ***************************************************************************/

    T get ( lazy T new_item );


    /***************************************************************************

        Ensures that the free list contains at least the specified number of
        (idle) items. Useful to pre-allocate a free list of a certain size.

        Params:
            num = minimum number of idle items desired in free list
            new_item = expression that creates a new instance of T

        Returns:
            this

    ***************************************************************************/

    typeof(this) fill ( size_t num, lazy T new_item );


    /***************************************************************************

        Recycles an item into the free list.

        Params:
            item = item to be put into the free list

    ***************************************************************************/

    void recycle ( T item );


    /***************************************************************************

        Ensures that the free list contains at most the specified number of
        items.

        Params:
            num = maximum number of items desired in free list

        Returns:
            this

    ***************************************************************************/

    typeof(this) minimize ( size_t num = 0 );
}



version ( UnitTest )
{
    import ocean.core.Array : pop;


    /***************************************************************************

        Free list tester base class. Tests all methods of IFreeList.

        Template_Params:
            I = type of item stored in free list

    ***************************************************************************/

    abstract class FreeListTester ( I )
    {
        /***********************************************************************

            Free list being tested.

        ***********************************************************************/

        private alias IFreeList!(I) FL;

        private FL fl;


        /***********************************************************************

            Alias for type of item stored in free list.

        ***********************************************************************/

        protected alias I Item;


        /***********************************************************************

            Number of items to use in tests.

        ***********************************************************************/

        protected const num_items = 10;


        /***********************************************************************

            Constructor.

            Params:
                fl = free list to test

        ***********************************************************************/

        public this ( FL fl )
        {
            this.fl = fl;
        }


        /***********************************************************************

            Unittest for internal free list.

        ***********************************************************************/

        public void test ( )
        {
            Item[] busy_items;
            size_t idle_count;

            // Get some items (initial creation)
            for ( int i; i < this.num_items; i++ )
            {
                busy_items ~= this.fl.get(this.newItem());
                this.lengthCheck(busy_items.length, idle_count);
            }
            assert(idle_count == 0, "idle count mismatch");

            // Recycle them
            this.recycle(busy_items, idle_count);
            assert(idle_count == this.num_items);

            // Get some items and store something in them
            for ( int i; i < this.num_items; i++ )
            {
                auto item = this.fl.get(this.newItem());

                this.setItem(item, i);
                busy_items ~= item;

                this.lengthCheck(busy_items.length, --idle_count);
            }
            assert(idle_count == 0, "idle count mismatch");

            // Recycle them
            this.recycle(busy_items, idle_count);
            assert(idle_count == this.num_items, "idle count mismatch");

            // Get them again and check the contents are as expected
            for ( int i; i < this.num_items; i++ )
            {
                auto item = this.fl.get(this.newItem());

                this.checkItem(item, i);
                busy_items ~= item;

                this.lengthCheck(busy_items.length, --idle_count);
            }
            assert(idle_count == 0, "idle count mismatch");

            // Recycle them
            this.recycle(busy_items, idle_count);
            assert(idle_count == this.num_items, "idle count mismatch");

            // Fill
            this.fl.fill(this.num_items * 2, this.newItem());
            this.lengthCheck(busy_items.length, this.num_items * 2);

            // Minimize
            this.fl.minimize(this.num_items);
            this.lengthCheck(busy_items.length, this.num_items);

            this.fl.minimize();
            this.lengthCheck(busy_items.length, 0);
        }


        /***********************************************************************

            Checks that the contents of the free list match the expected values.
            Derived classes can add additional checks by overriding.

            Params:
                expected_busy = expected number of busy items
                expected_idle = expected number of idle items

        ***********************************************************************/

        protected void lengthCheck ( size_t expected_busy, size_t expected_idle )
        {
            assert(this.fl.num_idle == expected_idle, "FreeList idle items wrong");
        }


        /***********************************************************************

            Returns:
                a new item of the type stored in the free list.

        ***********************************************************************/

        protected abstract Item newItem ( );


        /***********************************************************************

            Sets the value of the passed item, using the passed integer to
            deterministically decide its contents.

            Params:
                item = item to set value of
                i = integer to determine contents of item

        ***********************************************************************/

        protected abstract void setItem ( ref Item item, size_t i );


        /***********************************************************************

            Checks the value of the passed item against the value which can be
            deterministically derived from the passed integer. The method should
            assert on failure.

            Params:
                item = item to check value of
                i = integer to determine contents of item

        ***********************************************************************/

        protected abstract void checkItem ( ref Item item, size_t i );


        /***********************************************************************

            Recycles all of the passed items into the free list, checking
            consistency along the way.

            Params:
                busy_items = items to recycle
                idle_count = count of idle items

        ***********************************************************************/

        private void recycle ( ref Item[] busy_items, ref size_t idle_count )
        {
            while ( busy_items.length )
            {
                Item item;
                auto popped = busy_items.pop(item);
                assert(popped, "pop from list of busy items failed");

                this.fl.recycle(item);
                this.lengthCheck(busy_items.length, ++idle_count);
            }

            enableStomping(busy_items);
        }
    }
}
