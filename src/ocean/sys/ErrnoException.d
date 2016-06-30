/*******************************************************************************

    Mapping from C errno to D exception

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.sys.ErrnoException;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;
import ocean.stdc.errno;

version (UnitTest)
{
    import ocean.core.Test;
}

/*******************************************************************************

    Exception class which reads, stores and resets the thread-local errno

*******************************************************************************/

public class ErrnoException : Exception
{
    import ocean.stdc.string;
    import ocean.stdc.stringz;
    import ocean.core.Traits : ReturnTypeOf;

    import ocean.core.Exception : ReusableExceptionImplementation;
    import ocean.core.Traits : identifier;

    /**************************************************************************

        Provides standard reusable exception API

    **************************************************************************/

    mixin ReusableExceptionImplementation!() ReusableImpl;

    /**************************************************************************

        Last processed .errno

    ***************************************************************************/

    private int last_errno = 0;

    /**************************************************************************

        Last failed function name

    ***************************************************************************/

    private istring func_name;

    /**************************************************************************

        Returns:
            last processed .errno getter

    ***************************************************************************/

    public int errorNumber ( )
    {
        return this.last_errno;
    }

    /**************************************************************************

        Returns:
            last failed function name getter

    ***************************************************************************/

    public istring failedFunctionName ( )
    {
        return this.func_name;
    }

    /**************************************************************************

        Tries to evaluate `expr`. If it fails, checks the global errno and
        uses matching message as base for exception message, as well as throws
        the exception.

        Params:
            expr = expression that returns `false` upon failure that is
                expected to set global errno
            msg = extra error message to append after main error
                description, can be empty
            name = extern function name that is expected to set errno
            file = file where the expr is evaluated
            line = line where the expr is evaluated

        Throws:
            this if 'expr' is false

    ***************************************************************************/

    public void enforce ( bool expr, lazy cstring msg, istring name = "",
        istring file = __FILE__, int line = __LINE__ )
    {
        if (!expr)
        {
            this.func_name = name;
            throw this.useGlobalErrno(name, file, line).addMessage(msg);
        }
    }

    ///
    unittest
    {
        try
        {
            (new ErrnoException).enforce(
                { .errno = EMFILE; return false; } (),
                "extra",
                "FUNCTION"
            );
            assert (false);
        }
        catch (ErrnoException e)
        {
            test!("==")(getMsg(e),
                        "FUNCTION: Too many open files (extra)"[]);
            test!("==")(e.errorNumber(), EMFILE);
        }
    }

    /**************************************************************************

        Calls `Func` automatically checking errno and storing name

        If `verify` returns `false` when called with return value of `Func`,
        global `errno` gets checked and this ErrnoException instance gets
        thrown with message set from that `errno` and caller name set to
        `Func` identifier.

        Presence of additional wrapper struct is dictated by limitations
        of dmd1 type inference in method/function signatures.

        Template_Params:
            Func = function alias, usually C library function

        Params:
            verify = lambda that takes return value of Func and returns
                `true` itself if result is considered successful
            file = file where the expr is evaluated
            line = line where the expr is evaluated

        Returns:
            proxy `Caller` value with a single `call` method which accepts
            same arguments as `Func` and throws this exception if
            `verify(Func(args))` evaluates to `false`.

    **************************************************************************/

    public Caller!(typeof(&Func)) enforceRet (alias Func) (
        bool function (ReturnTypeOf!(Func)) verify,
        istring file = __FILE__, int line = __LINE__ )
    {
        static assert (is(typeof(Func) == function));
        this.func_name = identifier!(Func);
        return Caller!(typeof(&Func))(&Func, file, line, this, verify);
    }

    /**************************************************************************

        Calls `enforceRet` expecting `Func` to return non-NULL

        Wraps `enforceRet` with a lambda that verifies that return value is
        not null

        Returns:
            same as `enforceRet`

    **************************************************************************/

    public Caller!(typeof(&Func)) enforceRetPtr (alias Func) (
        istring file = __FILE__, int line = __LINE__ )
    {
        static bool verify ( ReturnTypeOf!(Func) x)
        {
            return x !is null;
        }

        return enforceRet!(Func)(&verify, file, line);
    }

    ///
    unittest
    {
        extern(C) static void* func ( )
        {
            .errno = EMFILE;
            return null;
        }

        try
        {
            (new ErrnoException).enforceRetPtr!(func).call();
            assert (false);
        }
        catch (ErrnoException e)
        {
            test!("==")(getMsg(e), "func: Too many open files"[]);
            test!("==")(e.line, __LINE__ - 6);
        }
    }

    /**************************************************************************

        Calls `enforceRet` interpreting return value as error code

        Wraps `enforceRet` with a lambda that verifies that return value is
        zero (success code). Any non-zero return value of `Func` is interpreted
        as a failure.

        Returns:
            same as `enforceRet`

    **************************************************************************/

    public Caller!(typeof(&Func)) enforceRetCode (alias Func) (
        istring file = __FILE__, int line = __LINE__ )
    {
        static bool verify ( ReturnTypeOf!(Func) x )
        {
            return x == 0;
        }

        return enforceRet!(Func)(&verify, file, line);
    }

    ///
    unittest
    {
        extern(C) static int func(int a, int b)
        {
            .errno = EMFILE;
            test!("==")(a, 41);
            test!("==")(b, 43);
            return -1;
        }

        try
        {
            (new ErrnoException).enforceRetCode!(func)().call(41, 43);
            assert (false);
        }
        catch (ErrnoException e)
        {
            test!("==")(getMsg(e), "func: Too many open files"[]);
            test!("==")(e.failedFunctionName(), "func"[]);
            test!("==")(e.line, __LINE__ - 7);
        }
    }


    /**************************************************************************

        Initializes local reusable error message based on global errno value
        and resets errno to 0.

        Params:
            name = extern function name that is expected to set errno, optional
            file = file where the exception errno is set
            line = line where the exception errno is set

        Returns:
            this instance

     **************************************************************************/

    public typeof (this) useGlobalErrno ( istring name = "",
        istring file = __FILE__, int line = __LINE__ )
    {
        return this.set(.errno, name, file, line);
    }

    ///
    unittest
    {
        .errno = ENOTBLK;
        auto e = new ErrnoException;
        test!("==")(
            getMsg(e.useGlobalErrno("func").append(" str1").append(" str2")),
            "func: Block device required str1 str2"[]
        );
        test!("==")(.errno, ENOTBLK);
    }

    /**************************************************************************

        Initializes local reusable error message based on supplied errno value

        Params:
            err_num = error number with same value set as in errno
            name = extern function name that is expected to set errno, optional
            file = file where the exception errno is set
            line = line where the exception errno is set

        Returns:
            this

     **************************************************************************/

    public typeof (this) set ( int err_num, istring name = "",
        istring file = __FILE__, int line = __LINE__ )
    {
        this.func_name = name;
        this.last_errno = err_num;

        if (this.func_name.length)
            this.ReusableImpl.set(this.func_name, file, line).append(": ");
        else
            this.ReusableImpl.set("", file, line);

        if (err_num == 0)
            return this.append("Expected non-zero errno after failure");

        char[256] buf;
        auto errmsg = fromStringz(strerror_r(err_num, buf.ptr, buf.length));
        return this.ReusableImpl.append(errmsg);
    }

    ///
    unittest
    {
        auto e = new ErrnoException;
        e.set(0);
        test!("==")(getMsg(e), "Expected non-zero errno after failure"[]);
    }

    /**************************************************************************

        Convenience method to append extra message in brackets

        If `msg` is empty, nothing is done

        Params:
            msg = additional message to clarify the error, will be appended
                after errno-based messaged inside parenthesis

        Returns:
            this

    **************************************************************************/

    public typeof (this) addMessage ( cstring msg )
    {
        if (msg.length)
            return this.append(" (").append(msg).append(")");
        else
            return this;
    }

    ///
    unittest
    {
        auto e = new ErrnoException;
        e.set(ENOTBLK).addMessage("msg");
        test!("==")(getMsg(e), "Block device required (msg)"[]);
    }
}

/*******************************************************************************

    Struct that captures callable object together with ErrnoException exception
    object and line/file values of original context.

    Used only as return type of `ErrnoException.enforceRet`

*******************************************************************************/

public struct Caller ( T )
{
    import ocean.core.Traits : ParameterTupleOf, isCallableType, ReturnTypeOf;

    static assert (isCallableType!(T));
    static assert (!is(ReturnTypeOf!(T) == void));

    /// wrapped function to call/verify
    private T              fn;
    /// file where `Caller` was created, used as exception file
    private istring        original_file;
    /// line where `Caller` was created, used as exception line
    private int            original_line;
    /// exception to throw if `verify` fails
    private ErrnoException e;
    /// function that checks if return value of `this.fn` is "success"
    private bool function (ReturnTypeOf!(T)) verify;

    /***************************************************************************

        Calls stored function pointer / delegate with `args` and throws
        stored exception object if return value of callable evaulates to `false`

        Params:
            args = variadic argument list to proxy

        Returns:
            whatever `this.fn` returns

        Throws:
            this.e if stored function returns 'false'

    ***************************************************************************/

    public ReturnTypeOf!(T) call ( ParameterTupleOf!(T) args )
    {
        auto ret = this.fn(args);
        if (!verify(ret))
            throw e.useGlobalErrno(e.func_name, this.original_file,
                this.original_line);
        return ret;
    }
}
