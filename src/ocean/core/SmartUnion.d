/******************************************************************************

    Template for a union that knows its active field and uses contracts to
    assert that always the active field is read.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.core.SmartUnion;

import ocean.transition;
import ocean.core.ExceptionDefinitions;
import ocean.core.Test;
import ocean.core.Traits;



/******************************************************************************

    Provides a getter and setter method for each member of U. Additionally an
    "Active" enumerator and an "active" getter method is provided. The "Active"
    enumerator members copy the U member names, the values of that members start
    with 1. The "Active" enumerator has an additional "none" member with the
    value 0. The "active" getter method returns the "Active" enumerator value of
    the type currently set in the union -- this may be "none" if the union is in
    its initial state.

 ******************************************************************************/

struct SmartUnion ( U )
{
    static assert (is (U == union), "SmartUnion: need a union, not \"" ~ U.stringof ~ '"');

    /**************************************************************************

        Holds the actual union U instance and Active enumerator value. To reduce
        the risk of a name collision, this member is named "_".

     **************************************************************************/

    private SmartUnionIntern!(U) _;

    /**************************************************************************

        Active enumerator type alias

        Note: There is a member named "_".

     **************************************************************************/

    alias _.Active Active;

    /**************************************************************************

        Returns:
            Active enumerator value of the currently active member or 0
            (Active.none) if no member has yet been set.

     **************************************************************************/

    Active active ( ) { return (&this)._.active; }

    /***************************************************************************

        Returns:
            name of the currently active member or "none" if no member has yet
            been set.

    ***************************************************************************/

    public istring active_name ( )
    {
        return (&this)._.active_names[(&this)._.active];
    }

    /**************************************************************************

        Member getter/setter method definitions string mixin

     **************************************************************************/

    mixin (AllMethods!(U, "", 0));

    private alias typeof(*(&this)) Type;
}

///
unittest
{
    union MyUnion
    {
        int x;
        mstring y;
    }

    void main ( )
    {
        SmartUnion!(MyUnion) u;
        istring name;
        u.Active a;             // u.Active is defined as
                                // `enum u.Active {none, x, y}`

        a = u.active;           // a is now a.none
        name = u.active_name;   // name is now "none"
        int b = u.x;            // error, u.x has not yet been set
        u.x   = 35;
        a = u.active;           // a is now a.x
        name = u.active_name;   // name is now "x"
        mstring c = u.y;        // error, u.y is not the active member
    }
}

unittest
{
    SmartUnion!(U1) u1;
    SmartUnion!(U2) u2;
    SmartUnion!(U3) u3;

    test!("==")(u1.active, u1.Active.none);
    test!("==")(u2.active, u2.Active.none);
    test!("==")(u3.active, u3.Active.none);

    test!("==")(u1.active, 0);
    test!("==")(u2.active, 0);
    test!("==")(u3.active, 0);

    test!("==")(u1.active_name, "none");
    test!("==")(u2.active_name, "none");
    test!("==")(u3.active_name, "none");

    testThrown!(Exception)(u1.a(), false);
    testThrown!(Exception)(u1.b(), false);
    testThrown!(Exception)(u2.a(), false);
    testThrown!(Exception)(u2.b(), false);
    testThrown!(Exception)(u3.a(), false);
    testThrown!(Exception)(u3.b(), false);

    u1.a(42);
    test!("==")(u1.a, 42);
    test!("==")(u1.active, u1.Active.a);
    test!("==")(u1.active_name, "a");
    testThrown!(Exception)(u1.b(), false);

    u2.a(new C1());
    test!("==")(u2.a.v, uint.init);
    test!("==")(u2.active, u2.Active.a);
    test!("==")(u2.active_name, "a");
    testThrown!(Exception)(u2.b(), false);

    u3.a(S1(42));
    test!("==")(u3.a, S1(42));
    test!("==")(u3.active, u3.Active.a);
    test!("==")(u3.active_name, "a");
    testThrown!(Exception)(u3.b(), false);

    u1.b("Hello world".dup);
    test!("==")(u1.b, "Hello world"[]);
    test!("==")(u1.active, u1.Active.b);
    test!("==")(u1.active_name, "b");
    testThrown!(Exception)(u1.a(), false);

    u2.b(S1.init);
    test!("==")(u2.b, S1.init);
    test!("==")(u2.active, u2.Active.b);
    test!("==")(u2.active_name, "b");
    testThrown!(Exception)(u2.a(), false);

    u3.b(21);
    test!("==")(u3.b, 21);
    test!("==")(u3.active, u3.Active.b);
    test!("==")(u3.active_name, "b");
    testThrown!(Exception)(u3.a(), false);

}

version (UnitTest)
{
    class C1
    {
        uint v;
    }

    struct S1
    {
        uint v;
    }

    union U1
    {
        uint a;
        char[] b;
    }

    union U2
    {
        C1 a;
        S1 b;
    }

    union U3
    {
        S1 a;
        uint b;
    }
}


/*******************************************************************************

    Calls the specified callable with the active field of the provided
    smart-union. If no field is active, does nothing.

    Note: declared at module-scope (rather than nested inside the SmartUnion
    template) to work around limitations of template alias parameters. (Doing it
    like this allows it to be called with a local name.)

    Params:
        Callable = alias for the thing to be called with the active member of
            the provided smart-union
        SU = type of smart-union to operate on
        smart_union = smart-union instance whose active field should be passed
            to Callable

*******************************************************************************/

public void callWithActive ( alias Callable, SU ) ( SU smart_union )
{
    static assert(is(TemplateInstanceArgs!(SmartUnion, SU)));
    alias typeof(smart_union._.u) U;

    if ( !smart_union._.active )
        return;

    auto active_i = smart_union._.active - 1;
    assert(active_i < U.tupleof.length);

    // "static foreach", unrolls into the equivalent of a switch
    foreach ( i, ref field; smart_union._.u.tupleof )
    {
        if ( i == active_i )
        {
            Callable(field);
            break;
        }
    }
}

///
version (D_Version2) unittest
{
    // This example is D2 only because it requires a function template,
    // `print`, and D1 doesn't allow defining a function template at the scope
    // of a function, including a `unittest`. In D1 this example works if
    // `print`, is defined outside of function scope.

    union TestUnion
    {
        int a;
        float b;
    }
    alias SmartUnion!(TestUnion) TestSmartUnion;

    static struct ActiveUnionFieldPrinter
    {
        static void print ( T ) ( T t )
        {
            Stdout.formatln("{}", t);
        }

        void printActiveUnionField ( )
        {
            TestSmartUnion su;
            su.a = 23;
            callWithActive!(print)(su);
        }
    }
}

version ( UnitTest )
{
    import ocean.io.Stdout;
}

/******************************************************************************

    Holds the actual union U instance and Active enumerator value and provides
    templates to generate the code defining the member getter/setter methods and
    the Active enumerator.

 ******************************************************************************/

private struct SmartUnionIntern ( U )
{
    /**************************************************************************

        U instance

     **************************************************************************/

    U u;

    /**************************************************************************

        Number of members in U

     **************************************************************************/

    enum N = U.tupleof.length;

    /**************************************************************************

        Active enumerator definition string mixin

     **************************************************************************/

    mixin("enum Active{none" ~ MemberList!(0, N, U) ~ "}");

    /**************************************************************************

        Memorizes which member is currently active (initially none which is 0)

     **************************************************************************/

    Active active;

    /***************************************************************************

        List of active state names

    ***************************************************************************/

    enum istring[] active_names = member_string_list();

    /***************************************************************************

        CTFE function to generate the list of active state names for union U.

        Returns:
            a list containing the names of each of the active states of the
            smart-union (i.e. the names of the fields of U)

    ***************************************************************************/

    static private istring[] member_string_list ( )
    {
        istring[] names = ["none"[]];
        foreach ( i, F; typeof(U.init.tupleof) )
        {
            names ~= FieldName!(i, U);
        }
        return names;
    }
}

/*******************************************************************************

    Evaluates to a ',' separated list of the names of the members of U.

    Template_Params:
        i   = U member start index
        len = number of members in U
        U = aggregate to iterate over

    Evaluates to:
        a ',' separated list of the names of the members of U

*******************************************************************************/

private template MemberList ( uint i, size_t len, U )
{
    static if ( i == len )
    {
        static immutable MemberList = "";
    }
    else
    {
        static immutable MemberList = "," ~ FieldName!(i, U) ~ MemberList!(i + 1, len, U);
    }
}

/*******************************************************************************

    Evaluates to code defining a getter, a setter and a static opCall()
    initializer method, where the name of the getter/setter method is
    pre ~ ".u." ~ the name of the i-th member of U.

    The getter/setter methods use pre ~ ".active" which must be the Active
    enumerator:
        - the getter uses an 'in' contract to make sure the active member is
          accessed,
        - the setter method sets pre ~ ".active" to the active member.

    Example: For
    ---
        union U {int x; char y;}
    ---

    ---
        mixin (Methods!("my_smart_union", 1).both);
    ---
    evaluates to
    ---
        // Getter for my_smart_union.u.y. Returns:
        //     my_smart_union.u.y

        char[] y()
        in
        {
            assert(my_smart_union.active == my_smart_union.active.y,
                   "UniStruct: \"y\" not active");
        }
        body
        {
            return my_smart_union.u.y;
        }

        // Setter for my_smart_union.u.y. Params:
        //     y = new value for y
        // Returns:
        //     y

        char[] y(char[] y)
        {
           my_smart_union.active = my_smart_union.active.y;
           return my_smart_union.u.y = y;
        }
    ---

    Methods.get and Methods.set evaluate to only the getter or setter
    method, respectively.

    Template_Params:
        pre = prefix for U instance "u"
        i   = index of U instance "u" member

    Evaluates to:
        get  = getter method for the U member
        set  = setter method for the U member
        opCall = static SmartUnion initialiser with the value set to the U
            member

*******************************************************************************/

private template Methods ( U, uint i )
{
    static immutable member = FieldName!(i, U);

    static immutable member_access = "_.u." ~ member;

    static immutable type = "typeof(" ~ member_access ~ ")";

    static immutable get = type ~ ' ' ~  member ~ "() "
        ~ "in { enforce(_.active == _.active." ~ member ~ ", "
        ~ `"SmartUnion: '` ~ member ~ `' not active"); } `
        ~ "body { return " ~ member_access ~ "; }";

    static immutable set = type ~ ' ' ~  member ~ '(' ~ type ~ ' ' ~ member ~ ")"
        ~ "{ _.active = _.active." ~ member ~ ";"
        ~ "return " ~ member_access ~ '=' ~ member ~ "; }";

    static immutable ini = "static Type opCall(" ~ type ~ ' ' ~ member ~ ")"
        ~ "{ Type su; su." ~ member ~ '=' ~ member ~ "; return su; }";

    static immutable local_import = "import ocean.core.Enforce;\n";

    static immutable all = local_import ~ get ~ '\n' ~ set ~ '\n' ~ ini;
}

/*******************************************************************************

    Evaluates to code defining a getter and setter method for each U member.

    Template_Params:
        u_pre = prefix for U instance "u"
        pre   = method definition code prefix, code will be appended to pre
        i     = U instance "u" member start index

    Evaluates to:
        code defining a getter and setter method for each U member

*******************************************************************************/

private template AllMethods ( U, istring pre, uint i)
{
    static if (i < U.tupleof.length)
    {
        static immutable AllMethods =
            AllMethods!(U, pre ~ '\n' ~ Methods!(U, i).all, i + 1);
    }
    else
    {
        static immutable AllMethods = pre;
    }
}
