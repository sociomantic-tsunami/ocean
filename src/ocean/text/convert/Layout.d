/*******************************************************************************

    Layout class (wrapping ocean.text.convert.Layout_tango) with a single static
    method to write a formatted string into a provided buffer.

    Note: This module exists because a method with this behaviour does not exist
    in original Layout -- the closest being the sprint() method, which writes to
    an output buffer, but which will not exceed the passed buffer's length.

    Usage example:

    ---

        import ocean.text.convert.Layout;

        char[] str;

        Layout!(char).print(str, "{}, {}{}", "Hello", "World", '!');

        // str will now hold the string "Hello, World!"

    ---

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.text.convert.Layout;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.core.Array : append;

import ocean.util.container.AppendBuffer;

import TangoLayout = ocean.text.convert.Layout_tango;


/*******************************************************************************

    Platform issues ...

*******************************************************************************/

version (DigitalMars) version (X86_64)
{
    version = DigitalMarsX86_64;
}

version (DigitalMarsX86_64)
{

    /*
     * va_list/_start/_arg/_end must be public imported because they are used in
     * the vaArg template, which is instantiated in other modules as well.
     */

    public import ocean.core.Vararg: va_arg, va_list,
                               // implicitly referenced by the compiler... YEAH!
                                     __va_argsave_t;
}
else static assert (false, "only Digital Mars x86-64 supported");

/*******************************************************************************



*******************************************************************************/

abstract class Layout ( T = char )
{
    /**************************************************************************

        Layout formatter instance

     **************************************************************************/

    private TangoLayout.Layout!(T) layout;

    /**************************************************************************

        Constructor

     **************************************************************************/

    protected this ( )
    {
        this.layout = new TangoLayout.Layout!(T);
    }


    version (D_Version2) {}
    else
    {
        /***********************************************************************

            Disposer

        ***********************************************************************/

        protected override void dispose ( )
        {
            delete this.layout;
        }
    }

    /**************************************************************************

        Appends the variable arguments to the content, formatted according to
        fmt, if any. If no variable arguments are given, simply appends fmt to
        the content.

        Params:
            fmt = format specifier or string to write if no variable arguments
                  are given.
            ... = values to format or nothing to simply append fmt.

        Returns:
            this instance

     **************************************************************************/

    public typeof (this) format ( Const!(T)[] fmt, ... )
    {
        return this.vformat(fmt, _arguments, _argptr);
    }

    /**************************************************************************

        Appends all given variable arguments in the order of appearance,
        formatted using the default format for each argument.

        Params:
            ... = values to format

        Returns:
            this instance

     **************************************************************************/

    public typeof (this) opCall ( ... )
    {
        return this.vwrite(_arguments, _argptr);
    }

    /**************************************************************************

        Appends the variable arguments to the content, formatted according to
        fmt, if any. If no variable arguments are given, simply appends fmt to
        the content.

        Params:
            fmt       = format specifier or string to write if arguments is
                        empty
            arguments = type ids of arguments which argptr points to
            argptr    = pointer to variable argument data

        Returns:
            this instance

     **************************************************************************/

    public typeof (this) vformat ( Const!(T)[] fmt, TypeInfo[] arguments, va_list argptr )
    {
        if (arguments.length)
        {
            this.layout.convert(&this.append, arguments, argptr, fmt);
        }
        else
        {
            this.append(fmt);
        }

        return this;
    }

    /**************************************************************************

        Formats all given variable arguments in the order of appearance, using
        the default format for each argument.

        Params:
            arguments = type ids of arguments which argptr points to
            argptr    = pointer to variable argument data

        Returns:
            this instance

     **************************************************************************/

    public typeof (this) vwrite ( TypeInfo[] arguments, va_list argptr )
    {
        foreach (ref argument; arguments)
        {
            if (argument is typeid (T[]))
            {
                 this.append(va_arg!(T[])(argptr));
            }
            else if (argument is typeid (T))
            {
                T x = va_arg!(T)(argptr);
                this.append((&x)[0..1]);
            }
            else
            {
                this.vformat("{}", (&argument)[0 .. 1], argptr);
            }
        }

        return this;
    }

    /**************************************************************************

        Output appender, called repeatedly when there is string data to append.

        Params:
            chunk = string data to append or write

         Returns:
             number of elements appended/written

     **************************************************************************/

    abstract protected uint append ( Const!(T)[] chunk );
}

/*******************************************************************************

    AppendBuffer using Layout

*******************************************************************************/

class StringLayout ( T = char ) : AppendBuffer!(T)
{
    /***************************************************************************

        Buffer appending layout formatter

    ***************************************************************************/

    class AppendLayout : Layout!(T)
    {
        protected override uint append ( Const!(T)[] chunk )
        {
            return cast (uint) this.outer.append(chunk).length;
        }
    }

    private Layout!(T) layout;

    /***************************************************************************

        Constructor

        Params:
            n = initial buffer length

    ***************************************************************************/

    public this ( size_t n = 0 )
    {
        super(n);

        this.layout = this.new AppendLayout;
    }


    version (D_Version2) {}
    else
    {
        /***********************************************************************

            Disposer

        ***********************************************************************/

        protected override void dispose ( )
        {
            super.dispose();
            delete this.layout;
        }
    }

    /**************************************************************************

        Appends all given variable arguments in the order of appearance,
        formatted using the default format for each argument.

        Params:
            ... = values to format

        Returns:
            this instance

     **************************************************************************/

    T[] opCall ( ... )
    {
        return this.vwrite(_arguments, _argptr);
    }

    /**************************************************************************

        Appends the variable arguments to the content, formatted according to
        fmt, if any. If no variable arguments are given, simply appends fmt to
        the content.

        Params:
            fmt = format specifier or string to write if no variable arguments
                  are given.
            ... = values to format or nothing to simply append fmt.

        Returns:
            this instance

     **************************************************************************/

    T[] format ( Const!(T)[] fmt, ... )
    {
        return this.vformat(fmt, _arguments, _argptr);
    }

    /**************************************************************************

        Appends the variable arguments to the content, formatted according to
        fmt, if any. If no variable arguments are given, simply appends fmt to
        the content.

        Params:
            fmt       = format specifier or string to write if arguments is
                        empty
            arguments = type ids of arguments which argptr points to
            argptr    = pointer to variable argument data

        Returns:
            this instance

     **************************************************************************/

    T[] vformat ( Const!(T)[] fmt, TypeInfo[] arguments, va_list argptr )
    {
        this.layout.vformat(fmt, arguments, argptr);

        return this[];
    }

    /**************************************************************************

        Formats all given variable arguments in the order of appearance, using
        the default format for each argument.

        Params:
            arguments = type ids of arguments which argptr points to
            argptr    = pointer to variable argument data

        Returns:
            this instance

     **************************************************************************/

    T[] vwrite ( TypeInfo[] arguments, va_list argptr )
    {
        this.layout.vwrite(arguments, argptr);

        return this[];
    }
}

/*******************************************************************************

    To be mixed into a variadic method.

    Calls dg with _arguments and _argptr, calling va_start()/va_end() if
    required for the current platform and compiler. dg must use va_arg() from
    ocean.core.Vararg to iterate over argptr.

    dg must comply to

        R delegate ( A dg_args, TypeInfo[] arguments, va_list argptr )

    where R is the return type and dg_args

    Basic usage:
    ---

        void f ( ... )
        {
            mixin vaArgCall!();

            vaArgCall(
                (TypeInfo[] arguments, va_list argptr)
                {
                    // use va_args(argptr) to access the arguments
                }
            );
        }

    ---

    Template_Params:
        R = dg return type
        A = types of additional arguments for dg

    Params:
        dg      = callback delegate
        dg_args = additional arguments for dg

    Returns:
        passes through the return value of dg.

*******************************************************************************/

public R vaArgCall ( R = void, A ... ) ( R delegate ( A dg_args, TypeInfo[] arguments, va_list argptr ) dg,
                                         A dg_args )
{
    return dg(dg_args, _arguments, _argptr);
}
