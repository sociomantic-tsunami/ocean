/******************************************************************************

  Defines base exception class thrown by test checks and set of helper
  functions to define actual test cases. These helpers are supposed to be
  used in unittest blocks instead of asserts.

  There were three reasons why dedicated function got introduced:

  1) Bultin `assert` throws an `Error`, which makes implementing test runner
     that doesn't stop on first failure illegal by language specification.
  2) These `test` functions can provide more informational formatting compared
     to plain `assert`, for example `test!("==")(a, b)` will print `a` and `b`
     values on failure.
  3) Having dedicated exception type for test failures makes possible to
     distinguish in test runners between contract failures and test failures.

  Copyright:
      Copyright (c) 2009-2016 dunnhumby Germany GmbH.
      All rights reserved.

  License:
      Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
      Alternatively, this file may be distributed under the terms of the Tango
      3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.core.Test;


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

    public this ( string msg, string file = __FILE__, int line = __LINE__ )
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
    string file = __FILE__, int line = __LINE__ )
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

public void test ( string op, T1, T2 ) ( T1 a,
    T2 b, string file = __FILE__, int line = __LINE__ )
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
        assert(e.message() == "unit test has failed");
        assert(e.line == __LINE__ - 6);
    }

    try
    {
        test!("==")(2, 3);
        assert(false);
    }
    catch (TestException e)
    {
        assert(e.message() == "expression '2 == 3' evaluates to false");
        assert(e.line == __LINE__ - 6);
    }
}

/******************************************************************************

    Verifies that given expression throws exception instance of expected type.

    Params:
        E = exception type to expect, Exception by default
        expr = expression that is expected to throw during evaluation
        strict = if 'true', accepts only exact exception type, disallowing
            polymorphic conversion
        file = file of origin
        line = line of origin

    Throws:
        `TestException` if nothing has been thrown from `expr`
        Propagates any thrown exception which is not `E`
        In strict mode (default) also propagates any children of E (disables
        polymorphic catching)

******************************************************************************/

public void testThrown ( E : Exception = Exception ) ( lazy void expr,
    bool strict = true, string file = __FILE__, int line = __LINE__ )
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

    private string name;

    /**************************************************************************

        Constructor

    ***************************************************************************/

    this(string name)
    {
        super(null);
        this.name = name;
    }

    /***************************************************************************

      message that also uses this.name if present

    ****************************************************************************/

    static if (is(typeof(Throwable.message)))
    {
        public override cstring message () const @trusted nothrow
        {
            // The Formatter currently has no annotation, as it would require
            // extensive work on it (and a new language feature),
            // but we know it's neither throwing (it doesn't on its own),
            // nor does it present a non-safe interface.
            scope (failure) assert(0);

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

    public void test ( T ) ( T ok, cstring msg = "", string file = __FILE__,
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

    public void test ( string op, T1, T2 ) ( T1 a, T2 b,
        string file = __FILE__, int line = __LINE__ )
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
        assert(e.message() == "[name] unit test has failed");
    }

    try
    {
        t.test!(">")(2, 3);
        assert(false);
    }
    catch (TestException e)
    {
        assert(e.message() == "[name] expression '2 > 3' evaluates to false");
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

public void testNoAlloc ( lazy void expr, string file = __FILE__,
    int line = __LINE__ )
{
    auto before = GC.stats();
    expr();
    auto after = GC.stats();

    enforceImpl!(TestException, bool)(
        before.usedSize == after.usedSize && before.freeSize == after.freeSize,
        format("Expression expected to not allocate but GC usage stats have " ~
               "changed from {} (used) / {} (free) to {} / {}",
               before.usedSize, before.freeSize, after.usedSize, after.freeSize),
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
        assert(e.message() == `[struct] expression '{ a: 1, arr: "ab" } == { a: 2, arr: "cd" }' evaluates to false`);
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
        assert(e.message() == `[typedef] expression '10 == 20' evaluates to false`);
    }
}
