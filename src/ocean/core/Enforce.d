/******************************************************************************

    Exception utilities to write enforcements/

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.core.Enforce;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;
import ocean.text.convert.Format;


/******************************************************************************

    Enforces that given expression evaluates to boolean `true` after
    implicit conversion.

    Template_Params:
        E = exception type to create and throw
        T = type of expression to test

    Params:
        ok = result of expression
        msg = optional custom message for exception
        file = file of origin
        line = line of origin

    Throws:
        E if expression evaluates to false

******************************************************************************/

public void enforceImpl ( E : Exception = Exception, T ) (
    T ok, lazy istring msg, istring file, int line )
{
    // duplicate msg/file/line mention to both conform Exception cnstructor
    // signature and fit our reusable exceptions.

    E exception = null;

    if (!ok)
    {
        static if (is(typeof(new E((char[]).init, file, line))))
        {
            exception = new E(null, file, line);
        }
        else static if (is(typeof(new E(file, line))))
        {
            exception = new E(file, line);
        }
        else static if (is(typeof(new E((char[]).init))))
        {
            exception = new E(null);
        }
        else static if (is(typeof(new E())))
        {
            exception = new E();
        }
        else
        {
            static assert (false, "Unsupported constructor signature");
        }
    }

    enforceImpl!(T)(exception, ok, msg, file, line);
}

/******************************************************************************

    Thin wrapper for enforceImpl that deduces file/line as template arguments
    to avoid ambiguity between overloads.

******************************************************************************/

public void enforce ( E : Exception = Exception, T,
    istring file = __FILE__, int line = __LINE__ ) ( T ok, lazy istring msg = "" )
{
    enforceImpl!(E, T)(ok, msg, file, line);
}

unittest
{
    // uses 'assert' to avoid dependency on itself

    enforce(true);

    try
    {
        enforce(false);
        assert(false);
    }
    catch (Exception e)
    {
        assert(getMsg(e) == "enforcement has failed");
        assert(e.line == __LINE__ - 6);
    }

    try
    {
        enforce(3 > 4, "custom message");
        assert(false);
    }
    catch (Exception e)
    {
        assert(getMsg(e) == "custom message");
        assert(e.line == __LINE__ - 6);
    }
}

/******************************************************************************

    Enforces that given expression evaluates to boolean `true` after
    implicit conversion.

    NB! When present 'msg' is used instead of existing 'getMsg(e)'

    In D2 we will be able to call this via UFCS:
        exception.enforce(1 == 1);

    Template_Params:
        E = exception type to create and throw
        T = type of expression to test

    Params:
        e = exception instance to throw in case of an error (evaluated once in
            case of an error, not evaluated otherwise)
        ok = result of expression
        msg = optional custom message for exception
        file = file of origin
        line = line of origin

    Throws:
        e if expression evaluates to false

******************************************************************************/

public void enforceImpl ( T ) ( lazy Exception e, T ok, lazy istring msg,
    istring file, int line)
{
    if (!ok)
    {
        auto exception = e;

        if (msg.length)
        {
            exception.msg = msg;
        }
        else
        {
            if (!exception.msg.length)
            {
                exception.msg = "enforcement has failed";
            }
        }

        exception.file = file;
        exception.line = line;

        throw exception;
    }
}

/******************************************************************************

    Thin wrapper for enforceImpl that deduces file/line as template arguments
    to avoid ambiguity between overloads.

******************************************************************************/

public void enforce ( T, E : Exception, istring file = __FILE__,
    int line = __LINE__ ) ( lazy E e, T ok, lazy istring msg = "" )
{
    enforceImpl!(T)(e, ok, msg, file, line);
}

unittest
{
    class MyException : Exception
    {
        this ( istring msg, istring file = __FILE__, int line = __LINE__ )
        {
            super ( msg, file, line );
        }
    }

    auto reusable = new MyException(null);

    enforce(reusable, true);

    try
    {
        enforce(reusable, false);
        assert(false);
    }
    catch (MyException e)
    {
        assert(getMsg(e) == "enforcement has failed");
        assert(e.line == __LINE__ - 6);
    }

    try
    {
        enforce(reusable, false, "custom message");
        assert(false);
    }
    catch (MyException e)
    {
        assert(getMsg(e) == "custom message");
        assert(e.line == __LINE__ - 6);
    }

    try
    {
        enforce(reusable, false);
        assert(false);
    }
    catch (MyException e)
    {
        // preserved from previous enforcement
        assert(getMsg(e) == "custom message");
        assert(e.line == __LINE__ - 7);
    }

    // Check that enforce won't try to modify the exception reference
    static assert(is(typeof(enforce(new Exception("test"), true))));

    // Check that enforce() with doesn't evaluate its lazy exception parameter
    // if the sanity condition is true.

    enforce(
        delegate MyException()
        {
            assert(false,
                   "enforce() evaluated its exception parameter without error");
        }(),
        true
    );

    // call enforce() with condition "2 != 2" and verify it does evaluate its
    // lazy exception parameter exactly once

    bool returned_reusable = false;

    try
    {
        enforce(
            {
                assert(!returned_reusable,
                       "enforce() evaluated its exception pararmeter more " ~
                       "than once");
                returned_reusable = true;
                return reusable;
            }(),
            false
        );
    }
    catch (Exception e)
    {
        assert(e is reusable, "expected enforce() to throw reusable");
    }

    assert(returned_reusable,
           "enforce() didn't evaluate its exception parameter");
}

/******************************************************************************

    enforcement that builds error message string automatically based on value
    of operands and supplied "comparison" operation.

    'op' can be any binary operation.

    Template_Params:
        op = binary operator string
        E = exception type to create and throw
        T1 = type of left operand
        T2 = type of right operand

    Params:
        a = left operand
        b = right operand
        file = file of origin
        line = line of origin

    Throws:
        E if expression evaluates to false

******************************************************************************/

public void enforceImpl ( istring op, E : Exception = Exception, T1, T2 ) (
    T1 a, T2 b, istring file, int line )
{
    mixin("auto ok = a " ~ op ~ " b;");

    if (!ok)
    {
        static if (is(typeof(new E((char[]).init, file, line))))
        {
            auto exception = new E(null, file, line);
        }
        else static if (is(typeof(new E(file, line))))
        {
            auto exception = new E(file, line);
        }
        else static if (is(typeof(new E((char[]).init))))
        {
            auto exception = new E(null);
        }
        else static if (is(typeof(new E())))
        {
            auto exception = new E();
        }
        else
        {
            static assert (false, "Unsupported constructor signature");
        }

        enforceImpl!(op, T1, T2)(exception, a, b, file, line);
    }
}

/******************************************************************************

    Thin wrapper for enforceImpl that deduces file/line as template arguments
    to avoid ambiguity between overloads.

******************************************************************************/

public void enforce ( istring op, E : Exception = Exception, T1, T2,
    istring file = __FILE__ , int line = __LINE__) ( T1 a, T2 b )
{
    enforceImpl!(op, E, T1, T2)(a, b, file, line);
}

unittest
{
    // uses 'assert' to avoid dependency on itself

    enforce!("==")(2, 2);

    try
    {
        enforce!("==")(2, 3);
        assert(false);
    }
    catch (Exception e)
    {
        assert(getMsg(e) == "expression '2 == 3' evaluates to false");
        assert(e.line == __LINE__ - 6);
    }

    try
    {
        enforce!(">")(3, 4);
        assert(false);
    }
    catch (Exception e)
    {
        assert(getMsg(e) == "expression '3 > 4' evaluates to false");
        assert(e.line == __LINE__ - 6);
    }

    try
    {
        enforce!("!is")(null, null);
        assert(false);
    }
    catch (Exception e)
    {
        assert(e.line == __LINE__ - 5);
        assert(getMsg(e) == "expression '0 !is 0' evaluates to false");
    }

    // Check that enforce won't try to modify the exception reference
    static assert(is(typeof(enforce!("==")(new Exception("test"), 2, 3))));
}



/******************************************************************************

    ditto

    Template_Params:
        op = binary operator string
        E = exception type to create and throw
        T1 = type of left operand
        T2 = type of right operand

    Params:
        e = exception instance to throw in case of an error (evaluated once in
            case of an error, not evaluated otherwise)
        a = left operand
        b = right operand
        file = file of origin
        line = line of origin

    Throws:
        e if expression evaluates to false

******************************************************************************/

public void enforceImpl ( istring op, T1, T2 ) ( lazy Exception e, T1 a,
    T2 b, istring file, int line )
{
    mixin("auto ok = a " ~ op ~ " b;");

    if (!ok)
    {
        auto exception = e;
        exception.msg = Format("expression '{} {} {}' evaluates to false", a, op, b);
        exception.file = file;
        exception.line = line;
        throw exception;
    }
}

/******************************************************************************

    Thin wrapper for enforceImpl that deduces file/line as template arguments
    to avoid ambiguity between overloads.

******************************************************************************/

public void enforce ( istring op, E : Exception, T1, T2, istring file = __FILE__,
    int line = __LINE__  ) ( lazy E e, T1 a, T2 b )
{
    enforceImpl!(op, T1, T2)(e, a, b, file, line);
}

unittest
{
    class MyException : Exception
    {
        this ( istring msg, istring file = __FILE__, int line = __LINE__ )
        {
            super ( msg, file, line );
        }
    }

    auto reusable = new MyException(null);

    enforce!("==")(reusable, 2, 2);
    enforce!("==")(reusable, "2"[], "2"[]);

    try
    {
        enforce!("==")(reusable, 2, 3);
        assert(false);
    }
    catch (MyException e)
    {
        assert(getMsg(e) == "expression '2 == 3' evaluates to false");
        assert(e.line == __LINE__ - 6);
    }

    try
    {
        enforce!("is")(reusable, cast(void*)43, cast(void*)42);
        assert(false);
    }
    catch (MyException e)
    {
        assert(e.line == __LINE__ - 5);
        assert(getMsg(e) == "expression '2b is 2a' evaluates to false");
    }

    // call enforce() with condition "2 == 2" and verify it doesn't evaluate its
    // lazy exception parameter

    enforce!("==")(
        delegate MyException()
        {
            assert(false,
                   "enforce() evaluated its exception parameter without error");
        }(),
        2, 2
    );

    // call enforce() with condition "2 != 2" and verify it does evaluate its
    // lazy exception parameter exactly once

    bool returned_reusable = false;

    try
    {
        enforce!("!=")(
            {
                assert(!returned_reusable,
                       "enforce() evaluated its exception pararmeter more " ~
                       "than once");
                returned_reusable = true;
                return reusable;
            }(),
            2, 2
        );
    }
    catch (Exception e)
    {
        assert(e is reusable, "expected enforce() to throw reusable");
    }

    assert(returned_reusable,
           "enforce() didn't evaluate its exception parameter");
}


/******************************************************************************

    Throws a new exception E chained together with an existing exception.

    Template_Params:
        E = type of exception to throw

    Params:
        e = existing exception to chain with new exception
        msg  = message to pass to exception constructor
        file = file from which this exception was thrown
        line = line from which this exception was thrown

*******************************************************************************/

void throwChained ( E : Throwable = Exception)
    ( lazy Throwable e, lazy istring msg,
      istring file = __FILE__, int line = __LINE__ )
{
    throw new E(msg, file, line, e);
}

///
unittest
{
    auto next_e = new Exception("1");

    try
    {
        throwChained!(Exception)(next_e, "2");
        assert (false);
    }
    catch (Exception e)
    {
        assert (e.next is next_e);
        assert (getMsg(e) == "2");
        assert (e.next.msg == "1");
    }
}
