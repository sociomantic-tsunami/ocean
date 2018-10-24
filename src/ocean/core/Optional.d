/******************************************************************************

    Wraps any type in a struct that also contains boolean field indicating if
    value is in defined state.

    If T is a value type, `Optional!(T)` is value type too.

    Copyright:
        Copyright (c) 2009-2017 dunnhumby Germany GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).


*******************************************************************************/

module ocean.core.Optional;

version(UnitTest)
{
    import ocean.core.Test;
}

/// ditto
struct Optional ( T )
{
    /// Alias to make code working with undefined state more readable
    public enum undefined = Optional!(T).init;

    /// wrapped arbitrary value
    private T value;

    /// flag indicating if stored value is in defined state
    private bool defined = false;

    /**************************************************************************

        Puts `this` into defined state

        Params:
            rhs = value to assign

    **************************************************************************/

    public void opAssign ( T rhs )
    {
        (&this).defined = true;
        (&this).value = rhs;
    }

    /**************************************************************************

        Puts `this` into undefined state

    **************************************************************************/

    public void reset()
    {
        (&this).tupleof[] = Optional.undefined.tupleof[];
    }

    /**************************************************************************

        Interface to retrieve stored value. It is intentionally designed in a
        way that forces you to handle "undefined" state to avoid issues akin
        to "null pointer".

        This will become more convenient with D2 when lambda type inference
        will happen, as well as shorter notation:

        ---
            value.visit(
                ()  => { },
                (x) => { }
            );
        ---

        Parameters:
            cb_undefined = action to take if value is not defined
            cb_defined   = ditto for defined. May modify internal value via
                reference

    **************************************************************************/

    public void visit ( scope void delegate() cb_undefined,
        scope void delegate(ref T) cb_defined )
    {
        if ((&this).defined)
            cb_defined((&this).value);
        else
            cb_undefined();
    }

    /**************************************************************************

        A more "old-school" version of `visit`. Provided both to conform style
        of existing code and avoid delegate bugs in dmd1.

        Discouraged by default as more error-prone than `visit`.

        Parameters:
            value = will be set to content of `this` if defined, will remain
                unchanged otherwise

        Return:
            `true` if this is defined and `value` was updated.

    **************************************************************************/

    public bool get ( ref T value )
    {
        if ((&this).defined)
            value = (&this).value;
        return (&this).defined;
    }

    /**************************************************************************

        Returns:
            `true` if this is defined.

    **************************************************************************/

    public bool isDefined ( )
    {
        return (&this).defined;
    }
}

///
unittest
{
    alias Optional!(bool) Maybe;

    Maybe x, y, z;
    x = true;
    y = false;
    z = Maybe.undefined;

    x.visit(
        ()               { test(false); },
        (ref bool value) { test(value); }
    );

    y.visit(
        ()               { test(false); },
        (ref bool value) { test(!value); }
    );

    z.visit(
        ()               { test(true); },
        (ref bool value) { test(false); }
    );
}

unittest
{
    Optional!(int) x;
    test(!x.isDefined());
    int y = 10;
    bool ok = x.get(y);
    test(!ok);
    test(y == 10);
    x = 42;
    ok = x.get(y);
    test(ok);
    test(y == 42);
}

/******************************************************************************

    Shortcut on top of Optional to created defined value, uses IFTI to reduce
    the noise

    Parameters:
        value = value to wrap into Optional

    Returns:
        wrapped value

******************************************************************************/

public Optional!(T) optional ( T ) ( T value )
{
    return Optional!(T)(value, true);
}

///
unittest
{
    Optional!(int) foo ( bool x )
    {
        if (x)
            return optional(42);
        else
            return Optional!(int).undefined;
    }

    foo(true).visit(
        ()              { test(false); },
        (ref int value) { test(value == 42); }
    );

    foo(false).visit(
        ()              { },
        (ref int value) { test(false); }
    );
}
