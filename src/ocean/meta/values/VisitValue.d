/*******************************************************************************

    Generic utility allowing to recursively visit every field in an aggregate
    and possibly those indirectly reachable from them.

    Intended as a common implementation base for various more domain-specific
    utilities.

    Copyright:
        Copyright (c) 2018 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.meta.values.VisitValue;

import ocean.meta.traits.Basic;
import ocean.meta.types.Arrays;
import ocean.meta.types.Typedef;

/*******************************************************************************

    Recursively iterates over `value` fields and calls `visitor.visit` for each
    one of those. `visitor.visit` is expected to be a template with the
    following signature:

    `bool visit ( T ) ( T* value )`

    The return value indicates whether the value should be recursed into or
    not.

    Example:

    ---
    struct SumIntegersVisitor
    {
        /// Visitor can have any internal state it may need
        long sum;

        /// Returns: 'true' if recursion shall continue for this type
        bool visit ( T ) ( T* value )
        {
            static if (isIntegerType!(T))
                sum += *value;

            return true;
        }
    }

    SumIntegersVisitor visitor;
    visitValue(some_value, visitor);
    ---

    Params:
        value = root value to visit
        visitor = struct providing templated `visit` method accepting single
            argument which will be a pointer to visited element

*******************************************************************************/

public void visitValue ( T, Visitor ) ( ref T value, ref Visitor visitor )
{
    VisitImpl!(Visitor) impl;
    impl.visitor = &visitor;
    impl.visitAll(&value);
}

/*******************************************************************************

    Implementation of visiting logic. Some types are currently not supported
    because it is not clear what would recursing mean for them.

    Params:
        Visitor = user-provided struct implementing templated `visit` method
            to be called for individual values

*******************************************************************************/

private struct VisitImpl ( Visitor )
{
    /// Refers to the persistent instance of visitor struct in case
    /// implementation / may need internal state
    Visitor* visitor;

    /***************************************************************************

        Main recursive type/value visiting implementation

        Params:
            value = pointer to currently processed value. Pointer is used
                instead of a reference because D1 does not allow defining
                a reference to a static array

    ***************************************************************************/

    private void visitAll ( T ) ( T* value )
    {
        auto deeper = (&this).visitor.visit(value);

        if (!deeper)
            return;

        static if (isPrimitiveType!(T))
        {
            // do nothing, already processed
        }
        else static if (isTypedef!(T))
        {
            auto reinterp = cast(TypedefBaseType!(T)*) value;
            (&this).visitAll(reinterp);
        }
        else static if (isAggregateType!(T))
        {
            bool ignore = false;

            static if (is(T == class))
            {
                ignore = *value is null;

                // Recurse into super class fields
                static if (is(T Bases == super))
                {
                    foreach (Base; Bases)
                    {
                        static if (Base.init.tupleof.length)
                        {
                            Base base = *value; // implicit upcast
                            (&this).visitAll(&base);
                        }
                    }
                }
            }

            if (!ignore)
            {
                foreach (ref field; (*value).tupleof)
                {
                    (&this).visitAll(&field);
                }
            }
        }
        else static if (isArrayType!(T))
        {
            static if (
                   isArrayType!(T) == ArrayKind.Static
                || isArrayType!(T) == ArrayKind.Dynamic)
            {
                foreach (ref elem; *value)
                    (&this).visitAll(&elem);
            }
            else
            {
                static assert (false, "AA currently not supported");
            }
        }
        else static if (isFunctionType!(T))
        {
            // ignored for now (until someone proposes useful semantics)
        }
        else static if (isPointerType!(T))
        {
            if (*value !is null)
                (&this).visitAll(*value);
        }
        else static if (is(T U == enum))
        {
            auto reinterp = cast(U*) value;
            (&this).visitAll(reinterp);
        }
        else
        {
            static assert (
                false,
                "Unexpected type kind during recursive iteration: "
                    ~ T.stringof
            );
        }
    }
}
