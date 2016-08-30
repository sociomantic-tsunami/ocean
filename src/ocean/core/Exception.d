/******************************************************************************

    Ocean Exceptions

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.core.Exception;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.text.convert.Format;
import ocean.transition;

static import ocean.core.Enforce;

version (UnitTest)
{
    import ocean.core.Test;
}


/******************************************************************************

    Creates an iteratable data structure over a chained sequence of
    exceptions.

*******************************************************************************/

struct ExceptionChain
{
    /**************************************************************************

        Exception that forms the root of the exception chain.  This can
        be passed in like a constructor argument:

            foreach (e; ExceptionChain(myException))
            {
                ...
            }

    ***************************************************************************/

    private Throwable root;


    /**************************************************************************

        Allows the user to iterate over the exception chain

    ***************************************************************************/

    public int opApply (int delegate (ref Throwable) dg)
    {
        int result;

        for (auto e = root; e !is null; e = e.next)
        {
            result = dg(e);

            if (result)
            {
                break;
            }
        }

        return result;
    }
}

unittest
{
    auto e1 = new Exception("1");
    auto e2 = new Exception("2", __FILE__, __LINE__, e1);

    size_t counter;
    foreach (e; ExceptionChain(e2))
        ++counter;
    assert (counter == 2);
}

/******************************************************************************

    Common code to implement reusable exception semantics - one that has
    mutable message buffer where message data gets stored to

******************************************************************************/

public template ReusableExceptionImplementation()
{
    import ocean.transition;
    static import ocean.text.convert.Integer_tango;
    import ocean.core.Buffer;
    static import ocean.core.array.Mutation;

    static assert (is(typeof(this) : Exception));

    /**************************************************************************

        Fields used instead of `msg` for mutable messages. `Exception.msg`
        has `istring` type thus can't be overwritten with new data

    ***************************************************************************/

    protected Buffer!(char) reused_msg;

    /***************************************************************************

        Constructs exception object with mutable buffer pre-allocated to length
        `size` and other fields kept invalid.

        Params:
            size = initial size/length of mutable message buffer

    ***************************************************************************/

    this (size_t size = 128)
    {
        this.reused_msg.length = size;
        super(null);
    }

    /***************************************************************************

        Sets exception information for this instance.

        Params:
            msg  = exception message
            file = file where the exception has been thrown
            line = line where the exception has been thrown

        Returns:
            this instance

    ***************************************************************************/

    public typeof (this) set ( cstring msg, istring file = __FILE__,
        long line = __LINE__ )
    {
        ocean.core.array.Mutation.copy(this.reused_msg, msg);
        this.msg  = null;
        this.file = file;
        this.line = line;
        return this;
    }

   /***************************************************************************

        Throws this instance if ok is false, 0 or null.

        Params:
            ok   = condition to enforce
            msg  = exception message
            file = file where the exception has been thrown
            line = line where the exception has been thrown

        Throws:
            this instance if ok is false, 0 or null.

    ***************************************************************************/

    public void enforce ( T ) ( T ok, lazy cstring msg, istring file = __FILE__,
        long line = __LINE__ )
    {
        if (!ok)
            throw this.set(msg, file, line);
    }

    static if (is(typeof(Throwable.message)))
    {
        /**************************************************************************

            Returns:
                currently active exception message

        ***************************************************************************/

        public override cstring message ( ) /* d1to2fix_inject: const */
        {
            return this.msg[].ptr is null ? this.reused_msg[] : this.msg;
        }
    }

    /**************************************************************************

        Appends new substring to mutable exception message

        Intended to be used in hosts that do dynamic formatting of the
        error message and want to avoid repeating allocation with help
        of ReusableException semantics

        Leaves other fields untouched

        Params:
            msg = string to append to the message

        Returns:
            this instance

    ***************************************************************************/

    public typeof (this) append ( cstring msg )
    {
        ocean.core.array.Mutation.append(this.reused_msg, msg);
        return this;
    }

    /**************************************************************************

        Appends an integer to mutable exception message

        Does not cause any appenditional allocations

        Params:
            num = number to be formatted
            hex = optional, indicates that value needs to be formatted as hex

        Returns:
            this instance

    **************************************************************************/

    public typeof (this) append ( long num, bool hex = false )
    {
        char[long.max.stringof.length + 1] buff;
        if (hex)
        {
            ocean.core.array.Mutation.append(this.reused_msg, "0x"[]);
            ocean.core.array.Mutation.append(
                this.reused_msg,
                ocean.text.convert.Integer_tango.format(buff, num, "X"));
        }
        else
            ocean.core.array.Mutation.append(
                this.reused_msg,
                ocean.text.convert.Integer_tango.format(buff, num));
        return this;
    }
}

///
unittest
{
    auto e = new SomeReusableException(100);

    e.set("message");
    assert (getMsg(e) == "message");
    auto old_ptr = e.reused_msg[].ptr;

    try
    {
        ocean.core.Enforce.enforce(e, false, "immutable");
        assert (false);
    }
    catch (SomeReusableException) { }
    assert (getMsg(e) == "immutable");

    try
    {
        e.enforce(false, "longer message");
    }
    catch (SomeReusableException) { }
    assert (getMsg(e) == "longer message");
    assert (old_ptr is e.reused_msg[].ptr);

    try
    {
        e.badName("NAME", 42);
    }
    catch (SomeReusableException) { }
    assert (getMsg(e) == "Wrong name (NAME) 0x2A 42");
    assert (old_ptr is e.reused_msg[].ptr);
}

version (UnitTest)
{
    private class SomeReusableException : Exception
    {
        void badName(istring name, uint id)
        {
            this.set("Wrong name (")
                .append(name)
                .append(") ")
                .append(id, true)
                .append(" ")
                .append(id);
            throw this;
        }

        mixin ReusableExceptionImplementation!();
    }
}


/******************************************************************************

    Common code to implement exception constructor, which takes a message as
    a required parameter, and file and line with default value, and forward
    it to the `super` constructor

******************************************************************************/

public template DefaultExceptionCtor()
{
    import ocean.transition;

    public this (istring msg, istring file = __FILE__,
                 typeof(__LINE__) line = __LINE__)
    {
        super (msg, file, line);
    }
}

version (UnitTest)
{
    public class CardBoardException : Exception
    {
        mixin DefaultExceptionCtor;
    }
}

///
unittest
{
    auto e = new CardBoardException("Transmogrification failed");
    try
    {
        throw e;
    }
    catch (CardBoardException e)
    {
        test!("==")(getMsg(e), "Transmogrification failed"[]);
        test!("==")(e.file, __FILE__[]);
        test!("==")(e.line, __LINE__ - 9);
    }
}

// Check that the inherited `Exception.toString` is not
// shadowed by anything (like nested imports).
unittest
{
    auto s = (new SomeReusableException).toString();
}
