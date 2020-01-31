/******************************************************************************

    CTFE functions and templates used for code generation to be used with
    ocean.task.Task

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

******************************************************************************/

module ocean.task.internal.TaskExtensionMixins;


import ocean.meta.types.Qualifiers;

version (unittest)
{
    import ocean.core.Test;
    import ocean.core.Tuple;
}

/******************************************************************************

    For a given list of struct types generates aggregate struct type and
    a variable/field named 'extensions' of that type.

    Refers to extensions types as `Extensions[i]` instead of actual name to
    avoid issue with missing imports in the mixin context.

    Params:
        Extensions = variadic template argument list of struct types

******************************************************************************/

public istring genExtensionAggregate ( Extensions... ) ( )
{
    istring result = "struct ExtensionAggregate\n{\n";

    foreach (i, extension; Extensions)
    {
        result ~= "Extensions[" ~ i.stringof ~ "] ";
        result ~= toFieldName(extension.stringof);
        result ~= ";\n";
    }

    result ~= "}\nExtensionAggregate extensions;\n";

    return result;
}

///
unittest
{
    static struct Test1 { }
    static struct Test2 { }

    alias Tuple!(Test1, Test2) Extensions;
    mixin (genExtensionAggregate!(Extensions)());

    /*
        struct ExtensionAggregate
        {
            Extensions[0] test1;
            Extensions[1] test2;
        }

        ExtensionAggregate extensions;
     */

    static assert (is(typeof(extensions.test1) == Test1));
    static assert (is(typeof(extensions.test2) == Test2));
}

/******************************************************************************

    CTFE helper for field name generation

    Params:
        type_name = CamelCase struct/class type name

    Returns:
        Matching field name using lower_case

******************************************************************************/

private mstring toFieldName ( istring type_name )
{
    mstring result;

    foreach (index, char c; type_name)
    {
        if (c >= 'A' && c <= 'Z')
        {
            if (index != 0)
                result ~= "_";
            result ~= cast(char) (c + 32);
        }
        else
            result ~= c;
    }

    return result;
}

///
unittest
{
    test!("==")(toFieldName("DoSomeMagic"), "do_some_magic");
    test!("==")(toFieldName("Magic"), "magic");
}
