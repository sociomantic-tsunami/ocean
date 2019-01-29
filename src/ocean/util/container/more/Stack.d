/*******************************************************************************

    Copyright:
        Copyright (c) 2008 Kris Bell.
        Some parts copyright (c) 2009-2017 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

*******************************************************************************/

module ocean.util.container.more.Stack;

import ocean.core.Enforce;

version (UnitTest)
{
    import ocean.core.Test;
}

/*******************************************************************************

    A stack of the given value-type V, with maximum depth Size. Note
    that this does no memory allocation of its own when Size != 0, and
    does heap allocation when Size == 0. Thus you can have a fixed-size
    low-overhead instance, or a heap oriented instance.

*******************************************************************************/

public struct Stack ( V, int Size = 0 )
{
    public alias nth         opIndex;
    public alias slice       opSlice;
    public alias rotateRight opShrAssign;
    public alias rotateLeft  opShlAssign;
    public alias push        opCatAssign;

    static if (Size == 0)
    {
        private uint depth;
        private V[]  stack;
    }
    else
    {
        private uint     depth;
        private V[Size]  stack;
    }

    /***************************************************************************

        Clear the stack

        Returns: pointer to itself for chaining calls

    ***************************************************************************/

    Stack* clear ( )
    {
        depth = 0;
        return (&this);
    }

    /***************************************************************************

        Returns: depth of the stack

    ***************************************************************************/

    size_t size ( )
    {
        return depth;
    }

    /***************************************************************************

        Returns: remaining unused slots

    ***************************************************************************/

    size_t unused  ( )
    {
        enforce(.e_bounds, stack.length >= depth);
        return stack.length - depth;
    }

    /***************************************************************************

        Returns: a (shallow) clone of this stack, on the stack

    ***************************************************************************/

    Stack clone ( )
    {
        Stack s;
        static if (Size == 0)
            s.stack.length = stack.length;
        s.stack[] = stack;
        s.depth = depth;
        return s;
    }

    /***************************************************************************

        Pushes shallow copy of topmost element

        Returns: pushed copy

    ***************************************************************************/

    V dup ( )
    {
        auto v = top;
        push (v);
        return v;
    }

    /***************************************************************************

        Params:
            value = valush to push on top of the stack

        Returns: pointer to itself for call chaining

        Throws: StackBoundsException when the stack is full

    ***************************************************************************/

    Stack* push ( V value )
    {
        static if (Size == 0)
        {
            if (depth >= stack.length)
                stack.length = stack.length + 64;
            stack[depth++] = value;
        }
        else
        {
            enforce(.e_bounds, depth < stack.length);
            stack[depth++] = value;
        }
        return (&this);
    }

    /***************************************************************************

        Params:
            value = array of values to push onto the stack

        Returns: pointer to itself for call chaining

        Throws: StackBoundsException when the stack is full

    ***************************************************************************/

    Stack* append ( V[] value... )
    {
        foreach (v; value)
            push (v);
        return (&this);
    }

    /***************************************************************************

        Removes most recent stack element

        Return: most recent stack element before popping

        Throws: StackBoundsException when the stack is full

    ***************************************************************************/

    V pop ( )
    {
        enforce(.e_bounds, depth > 0);
        return stack[--depth];
    }

    /***************************************************************************

        Returns: most recent stack element

        Throws: StackBoundsException when the stack is full

    ***************************************************************************/

    V top ( )
    {
        enforce(.e_bounds, depth > 0);
        return stack[depth-1];
    }

    /***************************************************************************

        Swaps the top two entries

        Returns: the top element after swapping

        Throws: StackBoundsException when the stack has insufficient entries

    ***************************************************************************/

    V swap ( )
    {
        auto p = stack.ptr + depth;
        enforce(.e_bounds, p - 2 >= stack.ptr);

        p -= 2;
        auto v = p[0];
        p[0] = p[1];
        return p[1] = v;
    }

    /***************************************************************************

        Params:
            i = entry index

        Returns:
            stack entry with index `i`, where a zero index represents the
            newest stack entry (the top).

        Throws: StackBoundsException when the given index is out of range

    ***************************************************************************/

    V nth ( uint i )
    {
        enforce(.e_bounds, i < depth);
        return stack [depth-i-1];
    }

    /***************************************************************************

        Rotate the given number of stack entries

        Params:
            d = number of entries

        Returns: pointer to itself for call chaining

        Throws: StackBoundsException when the number is out of range

    ***************************************************************************/

    Stack* rotateLeft ( uint d )
    {
        enforce(.e_bounds, d <= depth);
        auto p = &stack[depth-d];
        auto t = *p;
        while (--d)
        {
            *p = *(p+1);
            p++;
        }
        *p = t;
        return (&this);
    }

    /***************************************************************************

        Rotate the given number of stack entries

        Params:
            d = number of entries

        Returns: pointer to itself for call chaining

        Throws: StackBoundsException when the number is out of range

    ***************************************************************************/

    Stack* rotateRight ( uint d )
    {
        enforce(.e_bounds, d <= depth);
        auto p = &stack[depth-1];
        auto t = *p;
        while (--d)
        {
            *p = *(p-1);
            p--;
        }
        *p = t;
        return (&this);
    }

    /***************************************************************************

        Returns:
            The stack as an array of values, where the first
            array entry represents the oldest value.

            Doing a foreach() on the returned array will traverse in
            the opposite direction of foreach() upon a stack.


    ***************************************************************************/

    V[] slice ( )
    {
        return stack[0 .. depth];
    }

    /***************************************************************************

        Iterate from the most recent to the oldest stack entries

    ***************************************************************************/

    int opApply ( scope int delegate(ref V value) dg )
    {
        int result;

        for (int i=depth; i-- && result is 0;)
            result = dg (stack[i]);

        return result;
    }
}

///
unittest
{
    Stack!(int) stack;
    stack.push(42);
    test!("==")(stack.pop(), 42);
    testThrown!(StackBoundsException)(stack.pop());
}

version(UnitTest)
{
    static void runTests ( T ) ( NamedTest t, T stack )
    {
        t.test!("==")(stack.size(), 0);
        testThrown!(StackBoundsException)(stack.pop());
        stack.push(42);
        t.test!("==")(stack.size(), 1);
        stack.clear();
        t.test!("==")(stack.size(), 0);

        stack.push(100);
        t.test!("==")(stack.dup(), 100);
        t.test!("==")(stack[], [ 100, 100 ]);

        auto clone = stack.clone();
        foreach (idx, ref field; clone.tupleof)
            t.test!("==")(field, stack.tupleof[idx]);

        stack.clear();
        stack.append(1, 2, 3, 4);
        t.test!("==")(stack[], [ 1, 2, 3, 4 ]);

        t.test!("==")(stack.top(), 4);
        t.test!("==")(stack.pop(), 4);
        t.test!("==")(stack.top(), 3);
        t.test!("==")(stack[0], 3);
        t.test!("==")(stack[2], 1);
        testThrown!(StackBoundsException)(stack[10]);

        stack.swap();
        t.test!("==")(stack[], [ 1, 3, 2 ]);
        stack.clear();
        testThrown!(StackBoundsException)(stack.swap());

        stack.append(1, 2, 3);
        stack.rotateLeft(2);
        t.test!("==")(stack[], [ 1, 3, 2 ]);
        stack.rotateRight(2);
        t.test!("==")(stack[], [ 1, 2, 3 ]);
        testThrown!(StackBoundsException)(stack.rotateLeft(40));
        testThrown!(StackBoundsException)(stack.rotateRight(40));
    }
}

unittest
{
    // common tests
    runTests(new NamedTest("Dynamic size"), Stack!(int).init);
    runTests(new NamedTest("Static size"),  Stack!(int, 10).init);
}

unittest
{
    // fixed size specific tests
    Stack!(int, 3) stack;
    test!("==")(stack.unused(), 3);

    stack.push(1);
    stack.push(1);
    stack.push(1);
    testThrown!(StackBoundsException)(stack.push(1));
}

unittest
{
    // dynamic size specific tests
    Stack!(int) stack;
    test!("==")(stack.unused(), 0);
}

/*******************************************************************************

    Exception that indicates any kind of out of bound access in stack, for
    example, trying to pop from empty one.

*******************************************************************************/

public class StackBoundsException : ExceptionBase
{
    this ( )
    {
        version (D_Version2)
            super("Out of bounds access attempt to stack struct");
        else
            super("", 0);
    }
}

// HACK: some D1 code may be trying to catch ArrayBoundsException specifically
// so different bases are used for smoother migration.
version (D_Version2)
    private alias Exception ExceptionBase;
    else
{
    import ocean.core.ExceptionDefinitions : ArrayBoundsException;
    private alias ArrayBoundsException ExceptionBase;
}

private StackBoundsException e_bounds;

static this ( )
{
    e_bounds = new StackBoundsException;
}
