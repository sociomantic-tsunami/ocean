/******************************************************************************

  Defines base exception class thrown by test checks and set of helper
  functions to define actual test cases. These helpers are supposed to be
  used in unittest blocks instead of asserts.

  Copyright:
      Copyright (c) 2009-2016 Sociomantic Labs GmbH.
      All rights reserved.

  License:
      Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
      Alternatively, this file may be distributed under the terms of the Tango
      3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.core.Test;

/*******************************************************************************

  Imports

********************************************************************************/

import ocean.transition;

import core.memory;
import ocean.core.Enforce;
import ocean.text.convert.Formatter;

/******************************************************************************

    Exception class to be thrown from unot tests blocks.

*******************************************************************************/

class TestException : Exception
{
    /***************************************************************************

      wraps parent constructor

     ***************************************************************************/

    public this ( istring msg, istring file = __FILE__, int line = __LINE__ )
    {
        super( msg, file, line );
    }
}

/******************************************************************************

    Effectively partial specialization alias:
        test = enforceImpl!(TestException)

    Same arguments as enforceImpl.

******************************************************************************/

public void test ( T ) ( T ok, cstring msg = "",
    istring file = __FILE__, int line = __LINE__ )
{
    if (!msg.length)
    {
        msg = "unit test has failed";
    }
    enforceImpl!(TestException, T)(ok, idup(msg), file, line);
}

/******************************************************************************

    ditto

******************************************************************************/

public void test ( istring op, T1, T2 ) ( T1 a,
    T2 b, istring file = __FILE__, int line = __LINE__ )
{
    enforceImpl!(op, TestException)(a, b, file, line);
}

unittest
{
    try
    {
        test(false);
        assert(false);
    }
    catch (TestException e)
    {
        assert(getMsg(e) == "unit test has failed");
        assert(e.line == __LINE__ - 6);
    }

    try
    {
        test!("==")(2, 3);
        assert(false);
    }
    catch (TestException e)
    {
        assert(getMsg(e) == "expression '2 == 3' evaluates to false");
        assert(e.line == __LINE__ - 6);
    }
}

/******************************************************************************

    Verifies that given expression throws exception instance of expected type.

    Params:
        expr = expression that is expected to throw during evaluation
        strict = if 'true', accepts only exact exception type, disallowing
            polymorphic conversion
        file = file of origin
        line = line of origin

    Template_Params:
        E = exception type to expect, Exception by default

    Throws:
        `TestException` if nothing has been thrown from `expr`
        Propagates any thrown exception which is not `E`
        In strict mode (default) also propagates any children of E (disables
        polymorphic catching)

******************************************************************************/

public void testThrown ( E : Exception = Exception ) ( lazy void expr,
    bool strict = true, istring file = __FILE__, int line = __LINE__ )
{
    bool was_thrown = false;
    try
    {
        expr;
    }
    catch (E e)
    {
        if (strict)
        {
            if (E.classinfo == e.classinfo)
            {
                was_thrown = true;
            }
            else
            {
                throw e;
            }
        }
        else
        {
            was_thrown = true;
        }
    }

    if (!was_thrown)
    {
        throw new TestException(
            "Expected '" ~ E.stringof ~ "' to be thrown, but it wasn't",
            file,
            line
        );
    }
}

unittest
{
    void foo() { throw new Exception(""); }
    testThrown(foo());

    void test_foo() { throw new TestException("", "", 0); }
    testThrown!(TestException)(test_foo());

    // make sure only exact exception type is caught
    testThrown!(TestException)(
        testThrown!(Exception)(test_foo())
    );

    // .. unless strict matching is disabled
    testThrown!(Exception)(test_foo(), false);
}

/******************************************************************************

    Utility class useful in scenarios where actual testing code is reused in
    different contexts and file+line information is not enough to uniquely
    identify failed case.

    NamedTest is also exception class on its own - when test condition fails
    it throws itself.

******************************************************************************/

class NamedTest : TestException
{
    /***************************************************************************

      Field to store test name this check belongs to. Useful
      when you have a common verification code reused by different test cases
      and file+line is not enough for identification.

     ***************************************************************************/

    private istring name;

    /**************************************************************************

        Constructor

    ***************************************************************************/

    this(istring name)
    {
        super(null);
        this.name = name;
    }

    /***************************************************************************

      message that also uses this.name if present

    ****************************************************************************/

    static if (is(typeof(Throwable.message)))
    {
        public override cstring message ( ) /* d1to2fix_inject: const */
        {
            if (this.name.length)
            {
                return format("[{}] {}", this.name, this.msg);
            }
            else
            {
                return format("{}", this.msg);
            }
        }
    }

    /**************************************************************************

        Same as enforceImpl!(TestException) but uses this.name for error message
        formatting.

    ***************************************************************************/

    public void test ( T ) ( T ok, cstring msg = "", istring file = __FILE__,
        int line = __LINE__ )
    {
        // uses `enforceImpl` instead of `test` so that pre-constructed
        // exception instance can be used.
        if (!msg.length)
        {
            msg = "unit test has failed";
        }
        enforceImpl(this, ok, idup(msg), file, line);
    }

    /**************************************************************************

        Same as enforceImpl!(op, TestException) but uses this.name for error message
        formatting.

    ***************************************************************************/

    public void test ( istring op, T1, T2 ) ( T1 a, T2 b,
        istring file = __FILE__, int line = __LINE__ )
    {
        // uses `enforceImpl` instead of `test` so that pre-constructed
        // exception instance can be used.
        enforceImpl!(op)(this, a, b, file, line);
    }
}

unittest
{
    auto t = new NamedTest("name");

    t.test(true);

    try
    {
        t.test(false);
        assert(false);
    }
    catch (TestException e)
    {
        assert(getMsg(e) == "[name] unit test has failed");
    }

    try
    {
        t.test!(">")(2, 3);
        assert(false);
    }
    catch (TestException e)
    {
        assert(getMsg(e) == "[name] expression '2 > 3' evaluates to false");
    }
}

/******************************************************************************

    Verifies that call to `expr` does not allocate GC memory

    This is achieved by checking GC usage stats before and after the call.

    Params:
        expr = any expression, wrapped in void-returning delegate if necessary
        file = file where test is invoked
        line = line where test is invoked

    Throws:
        TestException if unexpected allocation happens

******************************************************************************/

public void testNoAlloc ( lazy void expr, istring file = __FILE__,
    int line = __LINE__ )
{
    size_t used1, free1;
    ocean.transition.gc_usage(used1, free1);

    expr();

    size_t used2, free2;
    ocean.transition.gc_usage(used2, free2);

    enforceImpl!(TestException, bool)(
        used1 == used2 && free1 == free2,
        "Expression expected to not allocate but GC usage stats have changed",
        file,
        line
    );
}

///
unittest
{
    testNoAlloc({} ());

    testThrown!(TestException)(
        testNoAlloc({ auto x = new int; } ())
    );
}

unittest
{
    auto t = new NamedTest("struct");

    struct S { int a; char[2] arr; }

    try
    {
        t.test!("==")(S(1, ['a', 'b']), S(2, ['c', 'd']));
        assert(false);
    }
    catch (TestException e)
    {
        assert(getMsg(e) == `[struct] expression '{ a: 1, arr: "ab" } == { a: 2, arr: "cd" }' evaluates to false`);
    }
}

unittest
{
    auto t = new NamedTest("typedef");

    mixin(Typedef!(int, "MyInt"));

    try
    {
        t.test!("==")(cast(MyInt)10, cast(MyInt)20);
        assert(false);
    }
    catch (TestException e)
    {
        assert(getMsg(e) == `[typedef] expression '10 == 20' evaluates to false`);
    }
}
