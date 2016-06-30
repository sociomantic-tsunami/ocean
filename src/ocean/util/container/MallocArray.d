/*******************************************************************************

    A utility for allocating and managing malloc allocated arrays.

    The module contains functions which aids in creating arrays whose buffer
    is allocated by malloc().

    Note:
    - Don't manually modify the length of the arrays returned by this module or
      pass it to any method which modifies the length of the array.

      To resize an array, call the resize() method. To deallocate an array, call
      the deallocate() method.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.MallocArray;

/*******************************************************************************

    Imports.

*******************************************************************************/

import ocean.core.Exception_tango; // onOutOfMemoryError;
import ocean.stdc.stdlib; // malloc, free, realloc;
import ocean.stdc.string; // memmove;


/*******************************************************************************

    Allocate an array of the given type and length whose buffer is allocated by
    malloc().

    Template_Params:
        Item = the type of items making up the array

    Params:
        num_elements = the number of array elements to allocate

    Returns:
        the malloc allocated array

*******************************************************************************/

public Item[] allocate (Item) (size_t num_elements)
{
    if (num_elements is 0)
        return null;

    auto allocated_mem = malloc(num_elements * Item.sizeof);
    if (allocated_mem is null)
        onOutOfMemoryError();

    auto arr = (cast(Item*)allocated_mem)[0 .. num_elements];
    arr[] = Item.init;
    return arr;
}

/*******************************************************************************

    Resize an array whose buffer was allocated by malloc().

    It's safe to pass an array whose current length is 0, the array would
    be allocated.

    It's also safe to specify the new_length of an array to be 0, the array
    would be deallocated.

    Template_Params:
        Item = the type of items making up the array

    Params:
        arr_to_resize = the array that should be resized
        new_length = the new length that the item should be resize to

*******************************************************************************/

public void resize (Item) (ref Item[] arr_to_resize, size_t new_length)
{
    if (new_length is 0)
    {
        deallocate(arr_to_resize);
        return;
    }

    auto old_length = arr_to_resize.length;
    if (old_length == new_length)
        return;

    auto allocated_mem = realloc(arr_to_resize.ptr, Item.sizeof * new_length);
    if (allocated_mem is null)
        onOutOfMemoryError();

    arr_to_resize = (cast(Item*)allocated_mem)[0 .. new_length];
    if (old_length < new_length)
    {
        // Init newly allocated items
        arr_to_resize[old_length..new_length] = Item.init;
    }
}

/*******************************************************************************

    Deallocate an array whose buffer was allocated by malloc().

    Template_Params:
        Item = the type of items making up the array

    Params:
        arr_to_deallocate = the array to deallocate

*******************************************************************************/

public void deallocate (Item) (ref Item[] arr_to_deallocate)
{
    free(arr_to_deallocate.ptr);
    arr_to_deallocate = null;
}


/*******************************************************************************

    Basic functionalities tests

*******************************************************************************/

version (UnitTest)
{
    import ocean.core.Test;
    void testFunctions (T) ()
    {
        auto t = allocate!(T)(1);
        test!("==")(t.length, 1);
        // Test whether the allocated array was inited.
        test!("==")(t[0], T.init);

        t.resize(2);
        test!("!=")(t, (T[]).init);
        test!("==")(t.length, 2);
        // Test whether the expanded array part was inited.
        test!("==")(t[1], T.init);

        t.resize(0);
        test!("==")(t, (T[]).init);

        t = allocate!(T)(100);
        test!("!=")(t, (T[]).init);
        test!("==")(t.length, 100);

        t.deallocate();
        test!("==")(t, (T[]).init);

        t.resize(1);
        test!("==")(t.length, 1);
    }
}

unittest
{
    testFunctions!(int)();

    // Test initiating the template with an empty struct
    struct TestEmptyStruct
    {
    }
    testFunctions!(TestEmptyStruct)();

    // Test initiating the template with a populated struct with non-default
    // init values
    struct TestStruct
    {
        float num = 5;
    }
    testFunctions!(TestStruct)();
}
