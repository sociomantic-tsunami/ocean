/*******************************************************************************

    Mixin for an enum class with the following basic features:
        * Contains an enum, called E, with members specified by an associative
          array passed to the mixin.
        * Implements an interface, IEnum, with common shared methods:
            * opIndex: look up an enum member's name by its value and
              vice-versa.
            * opIn_r: check whether a value (int) or name (char[]) is a member
              of the enum.
            * opApply: iteration over over the names & values of the enum's
              members.
            * length: returns the number of members in the enum.
            * min & max: return the minimum/maximum value of the enum's members.
        * A static opCall() method which returns a singleton instance of the
          class. This is the most convenient means of calling the methods listed
          above.

    Basic usage example:

    ---

        // Define enum class by implementing IEnum and mixing in EnumBase with
        // an associative array defining the enum members
        class Commands : IEnum
        {
            // Note: the [] after the first string ensures that the associative
            // array is of type int[char[]], not int[char[3]].
            mixin EnumBase!([
                "Get"[]:1,
                "Put":2,
                "Remove":3
            ]);
        }

        // Look up enum member names by value. (Note that the singleton instance
        // of the enum class is passed, using the static opCall method.)
        assert(Commands()["Get"] == 1);

        // Look up enum member values by name
        assert(Commands()[1] == "Get");

        // Check whether a value is in the enum
        assert(!(5 in Commands()));

        // Check whether a name is in the enum
        assert(!("Delete" in Commands()));

        // Iterate over enum members
        import ocean.io.Stdout;

        foreach ( n, v; Commands() )
        {
            Stdout.formatln("{}: {}", n, v);
        }

    ---

    The mixin also supports the following more advanced features:
        * One enum class can be inherited from another, using standard class
          inheritance. The enum members in a derived enum class extend those of
          the super class.
        * The use of normal class inheritance, along with the IEnum interface,
          allows enum classes to be used abstractly.

    Advanced usage example:

    ---

        import ocean.core.Enum;

        // Basic enum class
        class BasicCommands : IEnum
        {
            mixin EnumBase!([
                "Get"[]:1,
                "Put":2,
                "Remove":3
            ]);
        }

        // Inherited enum class
        class ExtendedCommands : BasicCommands
        {
            mixin EnumBase!([
                "GetAll"[]:4,
                "RemoveAll":5
            ]);
        }

        // Check for a few names.
        assert("Get" in BasicCommands());
        assert("Get" in ExtendedCommands());
        assert(!("GetAll" in BasicCommands()));
        assert("GetAll" in ExtendedCommands());

        // Example of abstract usage of enum classes
        import ocean.io.Stdout;

        void printEnumMembers ( IEnum e )
        {
            foreach ( n, v; e )
            {
                Stdout.formatln("{}: {}", n, v);
            }
        }

        printEnumMembers(BasicCommands());
        printEnumMembers(ExtendedCommands());

    ---

    TODO: does it matter that the enum values are always int? We could add a
    template parameter to specify the base type, but I think it'd be a shame to
    make things more complex. IEnum would have to become a template then.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.core.Enum;


/***************************************************************************

    Imports

***************************************************************************/

import ocean.transition;


/*******************************************************************************

    Interface defining the basic functionality of an enum class.

*******************************************************************************/

public interface IEnum
{
    /***************************************************************************

        Aliases for the types of an enum class' names & values.

    ***************************************************************************/

    public alias istring Name;
    public alias int Value;


    /***************************************************************************

        Looks up an enum member's name from its value.

        Params:
            v = value to look up

        Returns:
            pointer to corresponding name, or null if value doesn't exist in
            enum

    ***************************************************************************/

    public Name* opIn_r ( Value v );


    /***************************************************************************

        Looks up an enum member's value from its name.

        Params:
            n = name to look up

        Returns:
            pointer to corresponding value, or null if name doesn't exist in
            enum

    ***************************************************************************/

    public Value* opIn_r ( Name n );


    /***************************************************************************

        Looks up an enum member's name from its value, using opIndex.

        Params:
            v = value to look up

        Returns:
            corresponding name

        Throws:
            ArrayBoundsException if value doesn't exist in enum

    ***************************************************************************/

    public Name opIndex ( Value v );


    /***************************************************************************

        Looks up an enum member's value from its name, using opIndex.

        Params:
            n = name to look up

        Returns:
            corresponding value

        Throws:
            ArrayBoundsException if name doesn't exist in enum

    ***************************************************************************/

    public Value opIndex ( Name n );


    /***************************************************************************

        Returns:
            the number of members in the enum

    ***************************************************************************/

    public size_t length ( );


    /***************************************************************************

        Returns:
            the lowest value in the enum

    ***************************************************************************/

    Value min ( );


    /***************************************************************************

        Returns:
            the highest value in the enum

    ***************************************************************************/

    Value max ( );


    /***************************************************************************

        foreach iteration over the names and values in the enum.

    ***************************************************************************/

    public int opApply ( int delegate ( ref Const!(Name) name,
        ref Const!(Value) value ) dg );


    /***************************************************************************

        foreach iteration over the names and values in the enum and their
        indices.

    ***************************************************************************/

    public int opApply ( int delegate ( ref size_t i, ref Const!(Name) name,
        ref Const!(Value) value ) dg );
}


/*******************************************************************************

    Template which evaluates to a string containing the code for a list of enum
    members, as specified by the first two members of the passed tuple, which
    must be an array of strings and an array of integers, respectively. The
    strings specify the names of the enum members, and the integers their
    values.

    This template is public for technical reason, and should not be needed
    in client code - See IEnum and EnumBase for template / interface you
    should use.

    Template_Params:
        T = tuple:
            T[0] must be an array of strings
            T[1] must be an array of ints
        (Note that the template accepts a tuple purely as a workaround for the
        compiler's inability to handle templates which accept values of types
        such as char[][] and int[].)

*******************************************************************************/

public template EnumValues ( size_t i, T ... )
{
    static assert(T.length == 2);
    static assert(is(typeof(T[0]) : Const!(istring[])));
    static assert(is(typeof(T[1]) : Const!(int[])));

    static if ( i == T[0].length - 1 )
    {
        const EnumValues = T[0][i] ~ "=" ~ T[1][i].stringof;
    }
    else
    {
        const EnumValues = T[0][i] ~ "=" ~ T[1][i].stringof ~ ","
            ~ EnumValues!(i + 1, T);
    }
}


/*******************************************************************************

    Template which evaluates to a size_t corresponding to the index in the type
    tuple T which contains a class implementing the IEnum interface. If no such
    type exists in T, then the template evaluates to T.length.

    This template is public for technical reason, and should not be needed
    in client code - See IEnum and EnumBase for template / interface you
    should use.

    Template_Params:
        i = recursion index over T
        T = type tuple

*******************************************************************************/

public template SuperClassIndex ( size_t i, T ... )
{
    static if ( i == T.length )
    {
        const size_t SuperClassIndex = i;
    }
    else
    {
        static if ( is(T[i] == class) && is(T[i] : IEnum) )
        {
            const size_t SuperClassIndex = i;
        }
        else
        {
            const size_t SuperClassIndex = SuperClassIndex!(i + 1, T);
        }
    }
}


/*******************************************************************************

    Template mixin to add enum functionality to a class.

    Note that the [0..$] which is used in places in this method is a workaround
    for various weird compiler issues / segfaults.

    Template_Params:
        T = tuple:
            T[0] must be an associative array of type int[char[]]
        (Note that the template accepts a tuple purely as a workaround for the
        compiler's inability to handle templates which accept associative array
        values.)

    TODO: adapt to accept *either* an AA or a simple list of names (for an
    auto-enum with values starting at 0).

*******************************************************************************/

public template EnumBase ( T ... )
{
    import ocean.transition;

    alias IEnum.Name Name;
    alias IEnum.Value Value;

    /***************************************************************************

        Ensure that the class into which this template is mixed is an IEnum.

    ***************************************************************************/

    static assert(is(typeof(this) : IEnum));


    /***************************************************************************

        Ensure that the tuple T contains a single element which is of type
        int[char[]].

    ***************************************************************************/

    static assert(T.length == 1);
    static assert(is(typeof(T[0].keys) : Const!(char[][])));
    static assert(is(typeof(T[0].values) : Const!(int[])));


    /***************************************************************************

        Constants determining whether this class is derived from another class
        which implements IEnum.

    ***************************************************************************/

    static if ( is(typeof(this) S == super) )
    {
        private const super_class_index = SuperClassIndex!(0, S);

        private const is_derived_enum = super_class_index < S.length;
    }
    else
    {
        private const is_derived_enum = false;
    }


    /***************************************************************************

        Constant arrays of enum member names and values.

        If the class into which this template is mixed has a super class which
        is also an IEnum, the name and value arrays of the super class are
        concatenated with those in the associative array in T[0].

    ***************************************************************************/

    static if ( is_derived_enum )
    {
        public const _internal_names =
            S[super_class_index]._internal_names[0..$] ~ T[0].keys[0..$];
        public const _internal_values =
            S[super_class_index]._internal_values[0..$] ~ T[0].values[0..$];
    }
    else
    {
        public const _internal_names = T[0].keys;
        public const _internal_values = T[0].values;
    }

    static assert(_internal_names.length == _internal_values.length);

    private static names = _internal_names;
    private static values = _internal_values;

    /***************************************************************************

        The actual enum, E.

    ***************************************************************************/

    mixin("enum E {" ~ EnumValues!(0, _internal_names[0..$],
        _internal_values[0..$]) ~ "}");


    /***************************************************************************

        Internal maps from names <-> values. The maps are filled in the static
        constructor.

    ***************************************************************************/

    static protected Value[Name] n_to_v;
    static protected Name[Value] v_to_n;

    static this ( )
    {
        foreach ( i, n; names )
        {
            n_to_v[n] = values[i];
        }
        n_to_v.rehash;

        foreach ( i, v; values )
        {
            v_to_n[v] = names[i];
        }
        v_to_n.rehash;
    }


    /***************************************************************************

        Protected constructor, prevents external instantiation. (Use the
        singleton instance returned by opCall().)

    ***************************************************************************/

    protected this ( )
    {
        static if ( is_derived_enum )
        {
            super();
        }
    }


    /***************************************************************************

        Singleton instance of this class (used to access the IEnum methods).

    ***************************************************************************/

    private alias typeof(this) This;

    static private This inst;


    /***************************************************************************

        Returns:
            class singleton instance

    ***************************************************************************/

    static public This opCall ( )
    {
        if ( !inst )
        {
            inst = new This;
        }
        return inst;
    }


    /***************************************************************************

        Looks up an enum member's name from its value.

        Params:
            v = value to look up

        Returns:
            pointer to corresponding name, or null if value doesn't exist in
            enum

    ***************************************************************************/

    public override Name* opIn_r ( Value v )
    {
        return v in v_to_n;
    }


    /***************************************************************************

        Looks up an enum member's value from its name.

        Params:
            n = name to look up

        Returns:
            pointer to corresponding value, or null if name doesn't exist in
            enum

    ***************************************************************************/

    public override Value* opIn_r ( Name n )
    {
        return n in n_to_v;
    }


    /***************************************************************************

        Looks up an enum member's name from its value, using opIndex.

        Params:
            v = value to look up

        Returns:
            corresponding name

        Throws:
            (in non-release builds) ArrayBoundsException if value doesn't exist
            in enum

    ***************************************************************************/

    public override Name opIndex ( Value v )
    {
        return v_to_n[v];
    }


    /***************************************************************************

        Looks up an enum member's value from its name, using opIndex.

        Params:
            n = name to look up

        Returns:
            corresponding value

        Throws:
            (in non-release builds) ArrayBoundsException if value doesn't exist
            in enum

    ***************************************************************************/

    public override Value opIndex ( Name n )
    {
        return n_to_v[n];
    }


    /***************************************************************************

        Returns:
            the number of members in the enum

    ***************************************************************************/

    public override size_t length ( )
    {
        return names.length;
    }


    /***************************************************************************

        Returns:
            the lowest value in the enum

    ***************************************************************************/

    public override Value min ( )
    {
        return E.min;
    }


    /***************************************************************************

        Returns:
            the highest value in the enum

    ***************************************************************************/

    public override Value max ( )
    {
        return E.max;
    }


    /***************************************************************************

        foreach iteration over the names and values in the enum.

        Note that the iterator passes the enum values as type Value (i.e. int),
        rather than values of the real enum E. This is in order to keep the
        iteration functionality in the IEnum interface, which knows nothing of
        E.

    ***************************************************************************/

    public override int opApply ( int delegate ( ref Const!(Name) name,
        ref Const!(Value) value ) dg )
    {
        int res;
        foreach ( i, name; this.names )
        {
            res = dg(name, values[i]);
            if ( res ) break;
        }
        return res;
    }


    /***************************************************************************

        foreach iteration over the names and values in the enum and their
        indices.

        Note that the iterator passes the enum values as type Value (i.e. int),
        rather than values of the real enum E. This is in order to keep the
        iteration functionality in the IEnum interface, which knows nothing of
        E.

    ***************************************************************************/

    public override int opApply ( int delegate ( ref size_t i,
        ref Const!(Name) name, ref Const!(Value) value ) dg )
    {
        int res;
        foreach ( i, name; this.names )
        {
            res = dg(i, name, values[i]);
            ++i;
            if ( res ) break;
        }
        return res;
    }
}



/*******************************************************************************

    Unit test.

    Tests:
        * All IEnum interface methods.
        * Enum class inheritance.

*******************************************************************************/

version ( UnitTest )
{
    /***************************************************************************

        Runs a series of asserts to check that the specified enum type contains
        members with the specified names and values. The name and value lists
        are assumed to be in the same order (i.e. names[i] corresponds to
        values[i]).

        Template_Params:
            E = enum type to check

        Params:
            names = list of names expected to be in the enum
            values = list of values expected to be in the enum

    ***************************************************************************/

    void checkEnum ( E : IEnum ) ( istring[] names, int[] values )
    in
    {
        assert(names.length == values.length);
        assert(names.length);
    }
    body
    {
        // Internal name/value lists
        assert(E.names == names);
        assert(E.values == values);

        // opIn_r lookup by name
        foreach ( i, n; names )
        {
            assert(n in E());
            assert(*(n in E()) == values[i]);
        }

        // opIn_r lookup by value
        foreach ( i, v; values )
        {
            assert(v in E());
            assert(*(v in E()) == names[i]);
        }

        // opIndex lookup by name
        foreach ( i, n; names )
        {
            assert(E()[n] == values[i]);
        }

        // opIndex lookup by value
        foreach ( i, v; values )
        {
            assert(E()[v] == names[i]);
        }

        // length
        assert(E().length == names.length);

        // Check min & max
        int min = int.max;
        int max = int.min;
        foreach ( v; values )
        {
            if ( v < min ) min = v;
            if ( v > max ) max = v;
        }
        assert(E().min == min);
        assert(E().max == max);

        // opApply 1
        size_t i;
        foreach ( n, v; E() )
        {
            assert(n == names[i]);
            assert(v == values[i]);
            i++;
        }

        // opApply 2
        foreach ( i, n, v; E() )
        {
            assert(n == names[i]);
            assert(v == values[i]);
        }
    }

    class Enum1 : IEnum
    {
        mixin EnumBase!(["a"[]:1, "b":2, "c":3]);
    }

    class Enum2 : Enum1
    {
        mixin EnumBase!(["d"[]:4, "e":5, "f":6]);
    }
}

unittest
{
    checkEnum!(Enum1)(["a", "b", "c"], [1, 2, 3]);
    checkEnum!(Enum2)(["a", "b", "c", "d", "e", "f"], [1, 2, 3, 4, 5, 6]);
}
