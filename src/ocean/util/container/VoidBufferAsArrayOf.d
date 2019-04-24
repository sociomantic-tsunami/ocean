/*******************************************************************************

    Struct template which wraps a void[] with an API allowing it to be safely
    used as an array of another type.

    It is, of course, possible to simply cast a void[] to another type of array
    and use it directly. However, care must be taken when casting to an array
    type with a different element size. Experience has shown that this is likely
    to hit undefined behaviour. For example, casting the array then sizing it
    has been observed to cause segfaults, e.g.:

    ---
        void[]* void_array; // acquired from somewhere

        struct S { int i; hash_t h; }
        auto s_array = cast(S[]*)void_array;
        s_array.length = 23;
    ---

    The exact reason for the segfaults is not known, but this usage appears to
    lead to corruption of internal GC data (possibly type metadata associated
    with the array's pointer).

    Sizing the array first, then casting is fine, e.g.:

    ---
        void[]* void_array; // acquired from somewhere

        struct S { int i; hash_t h; }
        (*void_array).length = 23 * S.sizeof;
        auto s_array = cast(S[])*void_array;
    ---

    The helper VoidBufferAsArrayOf simplifies this procedure and removes the
    risk of undefined behaviour by always handling the void[] as a void[]
    internally.

    Copyright:
        Copyright (c) 2017-2018 dunnhumby Germany GmbH.
        All rights reserved

    License:
        Boost Software License Version 1.0. See LICENSE.txt for details.

*******************************************************************************/

module ocean.util.container.VoidBufferAsArrayOf;

import ocean.transition;

/*******************************************************************************

    Struct template which wraps a void[] with an API allowing it to be safely
    used as an array of another type.

    Params:
        T = element type of array which the API mimics

*******************************************************************************/

public struct VoidBufferAsArrayOf ( T )
{
    // T == void is not only pointless but is also invalid: it's illegal to pass
    // a void argument to a function (e.g. opCatAssign).
    static assert(!is(T == void));

    /// Pointer to the underlying void buffer. Must be set before use by struct
    /// construction.
    private void[]* buffer;

    // The length of the buffer must always be an even multiple of T.sizeof.
    invariant ( )
    {
        assert((&this).buffer.length % T.sizeof == 0);
    }

    /***************************************************************************

        Returns:
            a slice of this array

    ***************************************************************************/

    public T[] array ( )
    {
        return cast(T[])(*(&this).buffer);
    }

    /***************************************************************************

        Returns:
            the number of T elements in the array

    ***************************************************************************/

    public size_t length ( )
    {
        return (&this).buffer.length / T.sizeof;
    }

    /***************************************************************************

        Sets the length of the array.

        Params:
            len = new length of the array, in terms of the number of T elements

    ***************************************************************************/

    public void length ( size_t len )
    {
        (&this).buffer.length = len * T.sizeof;
        enableStomping(*(&this).buffer);
    }

    /***************************************************************************

        Appends an array of elements.

        Note that mutable copies of appended elements are made internally, but
        to access them from the outside, the constness of T applies.

        but
        are inaccessible from the outside.

        Params:
            arr = elements to append

        Returns:
            a slice of this array, now with the specified elements appended

    ***************************************************************************/

    public T[] opCatAssign ( in T[] arr )
    {
        return cast(T[])((*(&this).buffer) ~= cast(void[])arr);
    }

    /***************************************************************************

        Appends an element.

        Note that a mutable copy of the appended element is made internally, but
        to access it from the outside, the constness of T applies.

        Params:
            element = element to append

        Returns:
            a slice of this array, now with the specified element appended

    ***************************************************************************/

    public T[] opCatAssign ( in T element )
    {
        return (&this).opCatAssign((&element)[0 .. 1]);
    }
}

///
unittest
{
    // Backing array.
    void[] backing;

    // Wrap the backing array for use as an S[].
    struct S
    {
        ubyte b;
        hash_t h;
    }

    auto s_array = VoidBufferAsArrayOf!(S)(&backing);

    // Append some elements.
    s_array ~= S();
    s_array ~= [S(), S(), S()];

    // Resize the array.
    s_array.length = 2;

    // Iterate over the elements.
    foreach ( e; s_array.array() ) { }
}

version ( UnitTest )
{
    import ocean.core.Test;

    align ( 1 ) struct S
    {
        ubyte b;
        hash_t h;
    }
}

unittest
{
    void[] backing;

    auto s_array = VoidBufferAsArrayOf!(S)(&backing);

    test!("==")(s_array.length, 0);
    test!("==")(s_array.buffer.length, 0);

    s_array ~= S(0, 0);
    test!("==")(s_array.array(), [S(0, 0)]);
    test(s_array.length == 1);
    test(s_array.buffer.length == S.sizeof);

    s_array ~= [S(1, 1), S(2, 2), S(3, 3)];
    test!("==")(s_array.array(), [S(0, 0), S(1, 1), S(2, 2), S(3, 3)]);
    test(s_array.length == 4);
    test(s_array.buffer.length == S.sizeof * 4);

    s_array.length = 2;
    test!("==")(s_array.array(), [S(0, 0), S(1, 1)]);
    test(s_array.length == 2);
    test(s_array.buffer.length == S.sizeof * 2);
}
