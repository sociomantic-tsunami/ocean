/*******************************************************************************

    Helper function for formatting a SmartUnion's active member to a string.

    This function is not placed in the SmartUnion class itself so as to avoid
    spreading the dependency on ocean.text.convert.Formatter throughout the
    codebase.

    Copyright:
        Copyright (c) 2018 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.text.formatter.SmartUnion;

import ocean.transition;
import ocean.core.SmartUnion;
import ocean.core.Verify;
import ocean.text.convert.Formatter;

/*******************************************************************************

    Gets a wrapper struct with a toString method to format the provided smart
    union.

    Params:
        SU = type of smart union to get formatting wrapper for
        smart_union = smart union to get formatting wrapper for
        include_name = flag to toggle formatting of the name of the active union
            member. If true, format output will look like
            "<activename>: value". If false, format output will look like
            "value"

*******************************************************************************/

public SmartUnionFormatter!(SU) asActiveField ( SU ) ( SU smart_union,
    bool include_name = false )
{
    return SmartUnionFormatter!(SU)(smart_union, include_name);
}

///
unittest
{
    union U
    {
        int i;
        cstring s;
    }

    SmartUnion!(U) su;

    // format from ocean.text.convert.Formatter
    format("union active member: {}", asActiveField(su));
}

/*******************************************************************************

    Struct that wraps a smart union with a toString method, for Formatter
    compatibility.

    Params:
        SU = type of smart union to format

*******************************************************************************/

private struct SmartUnionFormatter ( SU )
{
    import ocean.core.Traits : TemplateInstanceArgs;

    static assert(is(TemplateInstanceArgs!(SmartUnion, SU)));

    mixin TypeofThis;

    /// Smart union to format.
    private SU smart_union;

    /// Flag to toggle formatting of the name of the active union member. If
    /// true, format output will look like "<activename>: value". If false,
    /// format output will look like "value".
    private bool include_name;

    /// Formatting sink delegate, passed to toString and used by
    /// formatUnionMember.
    static private void delegate ( cstring chunk ) sink;

    /***************************************************************************

        Formats the smart union as a string to the provided sink delegate
        (suitable for use with ocean.text.convert.Formatter). The formatted text
        depends on whether a field of the union is active or not and whether
        the `include_name` member is true or false:
            * No union field active; `include_name` is:
                - true:  "<none>".
                - false: "".
            * Union field active; `include_name` is:
                - true:  "<name>: value".
                - false: "value".

        Params:
            sink = formatter sink delegate to use

    ***************************************************************************/

    public void toString ( scope void delegate ( cstring chunk ) sink )
    {
        if ( (&this).smart_union.active )
        {
            if ( (&this).include_name )
                sformat(sink, "<{}>: ", (&this).smart_union.active_name);

            This.sink = sink;
            scope ( exit ) This.sink = null;

            callWithActive!(formatUnionMember)((&this).smart_union);
        }
        else
        {
            if ( (&this).include_name )
                sformat(sink, "<{}>", (&this).smart_union.active_name);
        }
    }

    /***************************************************************************

        Formats the specified argument with the static sink delegate.

        Note: this function has to be public, so that it can be accessed by the
        callWithActive function in ocean.core.SmartUnion. It is not intended to
        be called by users.

        Params:
            T = type of union member to format
            union_member = union member to format

    ***************************************************************************/

    // FIXME_IN_D2: `package ocean.core`
    static public void formatUnionMember ( T ) ( T union_member )
    {
        verify(This.sink !is null);
        sformat(sink, "{}", union_member);
    }
}

version ( UnitTest )
{
    import ocean.core.Test;
}

unittest
{
    union U
    {
        int i;
        cstring s;
    }

    SmartUnion!(U) su;

    // Inactive union.
    test!("==")(format("{}", asActiveField(su)), "");

    // Inactive union, plus name formatting.
    test!("==")(format("{}", asActiveField(su, true)), "<none>");

    // i active.
    su.i = 23;
    test!("==")(format("{}", asActiveField(su)), "23");

    // s active.
    su.s = "hello";
    test!("==")(format("{}", asActiveField(su)), "hello");

    // s active, plus name formatting.
    test!("==")(format("{}", asActiveField(su, true)), "<s>: hello");
}

