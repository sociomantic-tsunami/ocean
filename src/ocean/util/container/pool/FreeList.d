/*******************************************************************************

    Simple pool class template with the following features:
        * Get and recycle items. Recycled items will be re-used before creating
          new items.
        * Fill the free list with a specific number of idle items.
        * The number of idle items in the free list can be queried.

    A free list does not manage busy items, it only stores a reference to any
    idle / free items, making them available for re-use.

    TODO:
        - Free lists could support limiting, simply by counting the number of
          allocated (i.e. busy) items. A count of allocated items would also allow a
          length() method (with the same meaning as the method in IPool) to be
          implemented.
        - Add idle items iterators (safe & unsafe). These could probably share
          code with the aggregate pool.

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.pool.FreeList;



import ocean.util.container.pool.model.IFreeList;

import ocean.core.Array : pop;

import ocean.meta.traits.Basic;
import ocean.meta.types.Typedef;

import ocean.core.Buffer;
import ocean.core.TypeConvert;

version (unittest)
    import ocean.core.Test;

/*******************************************************************************

    Template to determine the internal item type of a free list.

    Params:
        T = item type to be stored in free list

*******************************************************************************/

private template ItemType_ ( T )
{
    static if (isTypedef!(T))
    {
        alias ItemType_!(TypedefBaseType!(T)) ItemType_;
    }
    else static if (
           isReferenceType!(T)
        || isArrayType!(T) == ArrayKind.Dynamic
        || isArrayType!(T) == ArrayKind.Associative)
    {
        alias T ItemType_;
    }
    else
    {
        alias T* ItemType_;
    }
}


/*******************************************************************************

    Free list class template.

    Params:
        T = item type to be stored in free list

*******************************************************************************/

public class FreeList ( T ) : IFreeList!(ItemType_!(T))
{
    import ocean.core.Verify;

    /***************************************************************************

        Free lists of static arrays are not allowed. Likewise a free list of an
        atomic type (int, float, etc) is not allowed -- this would be rather
        pointless.

    ***************************************************************************/

    static assert(
        isArrayType!(T) != ArrayKind.Static,
        "Cannot use static array type '"
            ~ T.stringof ~ "' as base type for FreeList"
    );

    static assert(
        !isPrimitiveType!(T),
        "Cannot use primitive type '" ~ T.stringof ~
            "' as base type for FreeList"
    );


    /***************************************************************************

        Alias for item type to be stored in free list and accepted by public
        methods.

        Reference types (including dynamic and associative arrays) can be stored
        directly in the free list. Pointers are stored for other types.

    ***************************************************************************/

    public alias ItemType_!(T) ItemType;


    /***************************************************************************

        List of free items.

    ***************************************************************************/

    private ItemType[] free_list;


    /***************************************************************************

        Gets an item from the free list.

        Params:
            new_item = new item, will only be evaluated in the case when no
                items are available in the free list

        Returns:
            new item

    ***************************************************************************/

    public ItemType get ( lazy ItemType new_item )
    {
        if ( this.free_list.length )
        {
            ItemType item;
            auto popped = this.free_list.pop(item);
            verify(popped, "Item failed to be popped from non-empty free list");
            return item;
        }
        else
        {
            return new_item;
        }
    }


    /***************************************************************************

        Recycles an item into the free list.

        Params:
            item = item to be put into the free list

    ***************************************************************************/

    public void recycle ( ItemType item )
    {
        this.free_list ~= item;
    }


    /***************************************************************************

        Ensures that the free list contains at least the specified number of
        (idle) items. Useful to pre-allocate a free list of a certain size.

        Params:
            num = minimum number of items desired in pool
            new_item = expression that creates a new instance of T

        Returns:
            this

    ***************************************************************************/

    public typeof(this) fill ( size_t num, lazy ItemType new_item )
    out
    {
        assert(this.free_list.length >= num);
    }
    body
    {
        if ( this.free_list.length < num )
        {
            auto extra = num - this.free_list.length;
            for ( size_t i; i < extra; i++ )
            {
                this.free_list ~= new_item;
            }
        }

        return this;
    }


    /***************************************************************************

        Ensures that the free list contains at most the specified number of
        (idle) items.

        Params:
            num = maximum number of idle items desired in free list

        Returns:
            this

    ***************************************************************************/

    public typeof(this) minimize ( size_t num = 0 )
    {
        if ( this.free_list.length > num )
        {
            this.free_list.length = num;
            assumeSafeAppend(this.free_list);
        }

        return this;
    }


    /***************************************************************************

        Returns:
            the number of idle (available) items in the free list

    ***************************************************************************/

    public size_t num_idle ( )
    {
        return this.free_list.length;
    }
}


/*******************************************************************************

    Unit test.

    Tests:
        * All methods of IFreeList.
        * FreeList of strings, structs and classes.

*******************************************************************************/

version (unittest)
{
    import ocean.core.Test;

    /***************************************************************************

        String free list tester.

    ***************************************************************************/

    private alias FreeList!(char[]) StringFreeList;
    private class StringFreeListTester : FreeListTester!(StringFreeList.ItemType)
    {
        public this ( ) { super(new StringFreeList); }

        protected override Item newItem ( )
        {
            return new char[10];
        }

        protected override void setItem ( ref Item item, size_t i )
        {
            item.length = 1;
            item[0] = cast(char)(i + 32);
        }

        protected override void checkItem ( ref Item item, size_t i )
        {
            .test!("==")(item.length, 1, "item length wrong");
            .test!("==")(item[0], cast(char)(i + 32), "item content wrong");
        }
    }


    /***************************************************************************

        Struct free list tester.

    ***************************************************************************/

    private struct Struct
    {
        size_t i;
        char[] s;
    }

    private alias FreeList!(Struct) StructFreeList;
    private class StructFreeListTester : FreeListTester!(StructFreeList.ItemType)
    {
        public this ( ) { super(new StructFreeList); }

        protected override Item newItem ( )
        {
            return new Struct;
        }

        protected override void setItem ( ref Item item, size_t i )
        {
            item.i = i;
            item.s.length = 1;
            item.s[0] = cast(char)(i + 32);
        }

        protected override void checkItem ( ref Item item, size_t i )
        {
            .test!("==")(item.i, i, "item integer wrong");
            .test!("==")(item.s.length, 1, "item string length wrong");
            .test!("==")(item.s[0], cast(char)(i + 32), "item string content wrong");
        }
    }

    /***************************************************************************

        Buffer free list tester.

    ***************************************************************************/

    private alias FreeList!(Buffer!(void)) BufferFreeList;
    private class BufferFreeListTester : FreeListTester!(BufferFreeList.ItemType)
    {
        public this ( ) { super(new BufferFreeList); }

        protected override Item newItem ( )
        {
            return new Buffer!(void);
        }

        protected override void setItem ( ref Item item, size_t i )
        {
            *item ~= 40;
            *item ~= 41;
            *item ~= 42;
        }

        protected override void checkItem ( ref Item item, size_t i )
        {
            void[] a = (*item)[];
            void[] b = arrayOf!(ubyte)(40, 41, 42);
            .test!("==")(a, b);
        }
    }

    /***************************************************************************

        Class free list tester.

    ***************************************************************************/

    private class Class
    {
        override equals_t opEquals(Object rhs)
        {
            auto crhs = cast(typeof(this)) rhs;
            return this.i == crhs.i && this.s == crhs.s;
        }

        size_t i;
        char[] s;
    }

    private alias FreeList!(Class) ClassFreeList;
    private class ClassFreeListTester : FreeListTester!(ClassFreeList.ItemType)
    {
        public this ( ) { super(new ClassFreeList); }

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
            .test!("==")(item.i, i, "item integer wrong");
            .test!("==")(item.s.length, 1, "item string length wrong");
            .test!("==")(item.s[0], cast(char)(i + 32), "item string content wrong");
        }
    }
}

unittest
{
    // String (arrays) free list test
    {
        scope fl = new StringFreeListTester;
        fl.test();
    }

    // Struct free list test
    {
        scope fl = new StructFreeListTester;
        fl.test();
    }

    // Buffer free list test
    {
        scope fl = new BufferFreeListTester;
        fl.test();
    }

    // Class free list test
    {
        scope fl = new ClassFreeListTester;
        fl.test();
    }
}

