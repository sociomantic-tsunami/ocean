/*******************************************************************************

        Copyright:
            Copyright (c) 2008 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: April 2008

        Authors: Kris

*******************************************************************************/

module ocean.util.container.more.Stack;

import ocean.core.Enforce;
version (UnitTest)
    import ocean.core.Test;

/******************************************************************************

        A stack of the given value-type V, with maximum depth Size. Note
        that this does no memory allocation of its own when Size != 0, and
        does heap allocation when Size == 0. Thus you can have a fixed-size
        low-overhead instance, or a heap oriented instance.

******************************************************************************/

struct Stack (V, int Size = 0)
{
        alias nth              opIndex;
        alias slice            opSlice;
        alias rotateRight      opShrAssign;
        alias rotateLeft       opShlAssign;
        alias push             opCatAssign;


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

        /***********************************************************************

                Clear the stack

        ***********************************************************************/

        Stack* clear ()
        {
                depth = 0;
                return (&this);
        }

        /***********************************************************************

                Return depth of the stack

        ***********************************************************************/

        size_t size ()
        {
                return depth;
        }

        /***********************************************************************

                Return remaining unused slots

        ***********************************************************************/

        size_t unused ()
        {
                assert (stack.length >= depth);
                return stack.length - depth;
        }

        /***********************************************************************

                Returns a (shallow) clone of this stack, on the stack

        ***********************************************************************/

        Stack clone ()
        {
                Stack s;
                static if (Size == 0)
                           s.stack.length = stack.length;
                s.stack[] = stack;
                s.depth = depth;
                return s;
        }

        /***********************************************************************

                Push and return a (shallow) copy of the topmost element

        ***********************************************************************/

        V dup ()
        {
                auto v = top;
                push (v);
                return v;
        }

        /**********************************************************************

                Push a value onto the stack.

                Throws an exception when the stack is full

        **********************************************************************/

        Stack* push (V value)
        {
                static if (Size == 0)
                          {
                          if (depth >= stack.length)
                              stack.length = stack.length + 64;
                          stack[depth++] = value;
                          }
                       else
                          {
                          if (depth < stack.length)
                              stack[depth++] = value;
                          else
                              enforce(.e_bounds, false);
                          }
                return (&this);
        }

        /**********************************************************************

                Push a series of values onto the stack.

                Throws an exception when the stack is full

        **********************************************************************/

        Stack* append (V[] value...)
        {
                foreach (v; value)
                         push (v);
                return (&this);
        }

        /**********************************************************************

                Remove and return the most recent addition to the stack.

                Throws an exception when the stack is empty

        **********************************************************************/

        V pop ()
        {
                if (depth)
                    return stack[--depth];

                enforce(.e_bounds, false);
                assert(false);
        }

        /**********************************************************************

                Return the most recent addition to the stack.

                Throws an exception when the stack is empty

        **********************************************************************/

        V top ()
        {
                if (depth)
                    return stack[depth-1];

                enforce(.e_bounds, false);
                assert(false);
        }

        /**********************************************************************

                Swaps the top two entries, and return the top

                Throws an exception when the stack has insufficient entries

        **********************************************************************/

        V swap ()
        {
                auto p = stack.ptr + depth;
                if ((p -= 2) >= stack.ptr)
                   {
                   auto v = p[0];
                   p[0] = p[1];
                   return p[1] = v;
                   }

                enforce(.e_bounds, false);
                assert(false);
        }

        /**********************************************************************

                Index stack entries, where a zero index represents the
                newest stack entry (the top).

                Throws an exception when the given index is out of range

        **********************************************************************/

        V nth (uint i)
        {
                if (i < depth)
                    return stack [depth-i-1];

                enforce(.e_bounds, false);
                assert(false);
        }

        /**********************************************************************

                Rotate the given number of stack entries

                Throws an exception when the number is out of range

        **********************************************************************/

        Stack* rotateLeft (uint d)
        {
                if (d <= depth)
                   {
                   auto p = &stack[depth-d];
                   auto t = *p;
                   while (--d)
                      {
                          *p = *(p+1);
                          p++;
                      }
                   *p = t;
                   }
                else
                   enforce(.e_bounds, false);
                return (&this);
        }

        /**********************************************************************

                Rotate the given number of stack entries

                Throws an exception when the number is out of range

        **********************************************************************/

        Stack* rotateRight (uint d)
        {
                if (d <= depth)
                   {
                   auto p = &stack[depth-1];
                   auto t = *p;
                   while (--d)
                      {
                          *p = *(p-1);
                          p--;
                      }
                   *p = t;
                   }
                else
                   enforce(.e_bounds, false);
                return (&this);
        }

        /**********************************************************************

                Return the stack as an array of values, where the first
                array entry represents the oldest value.

                Doing a foreach() on the returned array will traverse in
                the opposite direction of foreach() upon a stack

        **********************************************************************/

        V[] slice ()
        {
                return stack [0 .. depth];
        }

        /***********************************************************************

                Iterate from the most recent to the oldest stack entries

        ***********************************************************************/

        int opApply (scope int delegate(ref V value) dg)
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

/*******************************************************************************

*******************************************************************************/

debug (Stack)
{
        import ocean.io.Stdout;

        void main()
        {
                Stack!(int) v;
                v.push(1);

                Stack!(int, 10) s;

                Stdout.formatln ("push four");
                s.push (1);
                s.push (2);
                s.push (3);
                s.push (4);
                foreach (v; s)
                         Stdout.formatln ("{}", v);
                s <<= 4;
                s >>= 4;
                foreach (v; s)
                         Stdout.formatln ("{}", v);

                s = s.clone;
                Stdout.formatln ("pop one: {}", s.pop);
                foreach (v; s)
                         Stdout.formatln ("{}", v);
                Stdout.formatln ("top: {}", s.top);

                Stdout.formatln ("pop three");
                s.pop;
                s.pop;
                s.pop;
                foreach (v; s)
                         Stdout.formatln ("> {}", v);
        }
}

