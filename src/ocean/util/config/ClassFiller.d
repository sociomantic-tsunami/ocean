/*******************************************************************************

    Provides convenient functions to fill the values of a given class

    Provides functions that use a given source to fill the member variables
    of a provided or newly created instance of a given class.

    The provided class can use certain wrappers to add conditions or
    informations to the variable in question. The value of a wrapped variable
    can be accessed using the opCall syntax "variable()"

    Overview of available wrappers:

    * Required  — This variable has to be set in the configuration file
                  Example:  Required!(char[]) nodes_config;
    * MinMax    — This numeric variable has to be within the specified range
                  Example: MinMax!(long, -10, 10) range;
    * Min       — This numeric variable has to be >= the specified value
                  Example: Min!(int, -10) min_range;
    * Max       — This numeric variable has to be <= the specified value
                  Example: Max!(int, 20) max_range;
    * LimitCmp  — This variable must be one of the given values. To compare the
                  config value with the given values, the given function will be
                  used
                  Example:  LimitCmp!(char[], "red", defComp!(char[]),
                                      "red", "green", "blue", "yellow") color;
    * LimitInit — This variable must be one of the given values, it will default
                  to the given value.
                  Example: LimitInit!(char[], "red", "red", "green") color;
    * Limit     — This variable must be one of the given values
                  Example: Limit!(char[], "up", "down", "left", "right") dir;
    * SetInfo   — the 'set' member can be used to query whether this
                  variable was set from the configuration file or not
                  Example: SetInfo!(bool) enable; // enable.set

    Use debug=Config to get a printout of all the configuration options

    Config file for the example below:
    -------
    [Example.FirstGroup]
    number = 1
    required_string = SET
    was_this_set = "there, I set it!"
    limited = 20

    [Example.SecondGroup]
    number = 2
    required_string = SET_AGAIN

    [Example.ThirdGroup]
    number = 3
    required_string = SET
    was_this_set = "arrr"
    limited = 40
    -------

    Usage Example:
    -------
    import Class = ocean.util.config.ClassFiller;
    import ocean.util.Config;

    class ConfigParameters
    {
        int number;
        Required!(char[]) required_string;
        SetInfo!(char[]) was_this_set;
        Required!(MinMax!(size_t, 1, 30)) limited;
        Limit!(char[], "one", "two", "three") limited_set;
        LimitInit!(char[], "one", "one", "two", "three") limited_set_with_default;
    }

    void main ( char[][] argv )
    {
        Config.parseFile(argv[1]);

        auto iter = Class.iterate!(ConfigParameters)("Example");

        foreach ( name, conf; iter ) try
        {
            // Outputs FirstGroup/SecondGroup/ThirdGroup
            Stdout.formatln("Group: {}", name);
            Stdout.formatln("Number: {}", conf.number);
            Stdout.formatln("Required: {}", conf.required_string());
            if ( conf.was_this_set.set )
            {
                Stdout.formatln("It was set! And the value is {}",
                was_this_set());
            }
            // If limited was not set, an exception will be thrown
            // If limited was set but is outside of the specified
            // range [1 .. 30], an exception will be thrown as well
            Stdout.formatln("Limited: {}", conf.limited());

            // If limited_set is not a value in the given set ("one", "two",
            // "three"), an exception will be thrown
            Stdout.formatln("Limited_set: {}", conf.limited_set());

            // If limited_set is not a value in the given set ("one", "two",
            // "three"), an exception will be thrown, if it is not set, it
            // defaults to "one"
            Stdout.formatln("Limited_set_with_default: {}",
                             conf.limited_set_with_default());
        }
        catch ( Exception e )
        {
            Stdout.formatln("Required parameter wasn't set: {}", getMsg(e));
        }
    }
    -------

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.config.ClassFiller;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

public import ocean.util.config.ConfigParser: ConfigException;

import ocean.core.Traits;

import ocean.core.Exception_tango, ocean.core.Enforce;

import ocean.core.Traits;

import ocean.util.config.ConfigParser;

import ocean.util.Convert;

import ocean.core.Traits : DynamicArrayType, isStringType,
                           isIntegerType, isRealType;

import ocean.io.Stdout;

import ocean.text.convert.Format;

version (UnitTest) import ocean.core.Test;

/*******************************************************************************

    Whether loose parsing is enabled or not.
    Loose parsing means, that variables that have no effect are allowed.

    States
        false = variables that have no effect cause an exception
        true  = variables that have no effect cause a stderr warning message

*******************************************************************************/

private bool loose_parsing = false;

/*******************************************************************************

    Evaluates to the original type with which a Wrapper Struct was initialised

    If T is not a struct, T itself is returned

    Template_Params:
        T = struct or type to find the basetype for

*******************************************************************************/

template BaseType ( T )
{
    static if ( is(typeof(T.value)) )
    {
        alias BaseType!(typeof(T.value)) BaseType;
    }
    else
    {
        alias T BaseType;
    }
}

/*******************************************************************************

    Returns the value of the given struct/value.

    If value is not a struct, the value itself is returned

    Template_Params:
        v = instance of a struct the value itself

*******************************************************************************/

BaseType!(T) Value ( T ) ( T v )
{
    static if ( is(T == BaseType!(typeof(v))) )
    {
        return v;
    }
    else
    {
        return Value(v.value);
    }
}

/*******************************************************************************

    Contains methods used in all WrapperStructs to access and set the value
    variable

    Template_Params:
        T = type of the value

*******************************************************************************/

template WrapperStructCore ( T, T init = T.init )
{
    /***************************************************************************

        The value of the configuration setting

    ***************************************************************************/

    private T value = init;


    /***************************************************************************

        Returns the value that is wrapped

    ***************************************************************************/

    public BaseType!(T) opCall ( )
    {
        return Value(this.value);
    }

    /***************************************************************************

        Returns the value that is wrapped

    ***************************************************************************/

    public BaseType!(T) opCast ( )
    {
        return Value(this.value);
    }

    /***************************************************************************

        Sets the wrapped value to val

        Params:
            val = new value

        Returns:
            val

    ***************************************************************************/

    public BaseType!(T) opAssign ( BaseType!(T) val )
    {
        return value = val;
    }

    /***************************************************************************

        Calls check_() with the same parameters. If check doesn't throw an
        exception it checks whether the wrapped value is also a struct and if so
        its check function is called.

        Params:
            bool  = whether the variable existed in the configuration file
            group = group this variable should appear
            name  = name of the variable

    ***************************************************************************/

    private void check ( bool found, cstring group, cstring name )
    {
        static if ( !is (BaseType!(T) == T) )
        {
            scope(success) this.value.check(found, group, name);
        }

        this.check_(found, group, name);
    }
}

/*******************************************************************************

    Configuration settings that are mandatory can be marked as such by
    wrapping them with this template.
    If the variable is not set, then an exception is thrown.

    The value can be accessed with the opCall method

    Template_Params:
        T = the original type of the variable

*******************************************************************************/

struct Required ( T )
{
    mixin WrapperStructCore!(T);

    /***************************************************************************

        Checks whether the checked value was found, throws if not

        Params:
            found = whether the variable was found in the configuration
            group = group the variable appeares in
            name  = name of the variable

        Throws:
            ConfigException

    ***************************************************************************/

    private void check_ ( bool found, cstring group, cstring name )
    {
        enforce!(ConfigException)(
            found,
            Format("Mandatory variable {}.{} not set.", group, name));
    }
}

/*******************************************************************************

    Configuration settings that are required to be within a certain numeric
    range can be marked as such by wrapping them with this template.

    If the value is outside the provided range, an exception is thrown.

    The value can be accessed with the opCall method

    Template_Params:
        T    = the original type of the variable (can be another struct)
        min  = smallest allowed value
        max  = biggest allowed value
        init = default value when it is not given in the configuration file

*******************************************************************************/

struct MinMax ( T, T min, T max, T init = T.init )
{
    mixin WrapperStructCore!(T, init);

    /***************************************************************************

        Checks whether the configuration value is bigger than the smallest
        allowed value and smaller than the biggest allowed value.
        If not, an exception is thrown

        Params:
            bool  = whether the variable existed in the configuration file
            group = group this variable should appear
            name  = name of the variable

        Throws:
            ConfigException

    ***************************************************************************/

    private void check_ ( bool found, cstring group, cstring name )
    {
        enforce!(ConfigException)(
            Value(this.value) >= min,
            Format("Configuration key {}.{} is smaller than allowed minimum of {}",
                   group, name, min));
        enforce!(ConfigException)(
            Value(this.value) <= max,
            Format("Configuration key {}.{} is bigger than allowed maximum of {}",
                   group, name, max));
    }
}

/*******************************************************************************

    Configuration settings that are required to be within a certain numeric
    range can be marked as such by wrapping them with this template.

    If the value is outside the provided range, an exception is thrown.

    The value can be accessed with the opCall method

    Template_Params:
        T    = the original type of the variable (can be another struct)
        min  = smallest allowed value
        init = default value when it is not given in the configuration file

*******************************************************************************/

struct Min ( T, T min, T init = T.init )
{
    mixin WrapperStructCore!(T, init);

    /***************************************************************************

        Checks whether the configuration value is bigger than the smallest
        allowed value. If not, an exception is thrown

        Params:
            bool  = whether the variable existed in the configuration file
            group = group this variable should appear
            name  = name of the variable

        Throws:
            ConfigException

    ***************************************************************************/

    private void check_ ( bool found, cstring group, cstring name )
    {
        enforce!(ConfigException)(
            Value(this.value) >= min,
            Format("Configuration key {}.{} is smaller than allowed minimum of {}",
                   group, name, min));
    }
}


/*******************************************************************************

    Configuration settings that are required to be within a certain numeric
    range can be marked as such by wrapping them with this template.

    If the value is outside the provided range, an exception is thrown.

    The value can be accessed with the opCall method

    Template_Params:
        T    = the original type of the variable (can be another struct)
        max  = biggest allowed value
        init = default value when it is not given in the configuration file

*******************************************************************************/

struct Max ( T, T max, T init = T.init )
{
    mixin WrapperStructCore!(T, init);

    /***************************************************************************

        Checks whether the configuration value is smaller than the biggest
        allowed value. If not, an exception is thrown

        Params:
            bool  = whether the variable existed in the configuration file
            group = group this variable should appear
            name  = name of the variable

        Throws:
            ConfigException

    ***************************************************************************/

    private void check_ ( bool found, cstring group, cstring name )
    {
        enforce!(ConfigException)(
            Value(this.value) <= max,
            Format("Configuration key {}.{} is bigger than allowed maximum of {}",
                   group, name, max));
    }
}


/*******************************************************************************

    Default compare function, used with the LimitCmp struct/template

    Params:
        a = first value to compare
        b = second value to compare with

    Returns:
        whether a == b

*******************************************************************************/

bool defComp ( T ) ( T a, T b )
{
    return a == b;
}

/*******************************************************************************

    Configuration settings that are limited to a certain set of values can be
    marked as such by wrapping them with this template.

    If the value is not in the provided set, an exception is thrown.

    The value can be accessed with the opCall method

    Template_Params:
        T    = the original type of the variable (can be another struct)
        init = default value when it is not given in the configuration file
        comp = compare function to be used to compare two values from the set
        Set  = tuple of values that are valid

*******************************************************************************/

struct LimitCmp ( T, T init = T.init, alias comp = defComp!(T), Set... )
{
    mixin WrapperStructCore!(T, init);

    /***************************************************************************

        Checks whether the configuration value is within the set of allowed
        values. If not, an exception is thrown

        Params:
            bool  = whether the variable existed in the configuration file
            group = group this variable should appear
            name  = name of the variable

         Throws:
            ConfigException

    ***************************************************************************/

    private void check_ ( bool found, cstring group, cstring name )
    {
        if ( found == false ) return;

        foreach ( el ; Set )
        {
            static assert (
                is ( typeof(el) : T ),
                "Tuple contains incompatible types! ("
                    ~ typeof(el).stringof ~ " to " ~ T.stringof ~ " )"
            );

            if ( comp(Value(this.value), el) )
                return;
        }

        istring allowed_vals;

        foreach ( el ; Set )
        {
            allowed_vals ~= ", " ~ to!(istring)(el);
        }

        throw new ConfigException(
            Format("Value '{}' of configuration key {}.{} is not within the "
                   ~ "set of allowed values ({})",
                   Value(this.value), group, name, allowed_vals[2 .. $]));
    }
}


unittest
{
    test(is(typeof({ LimitCmp!(int, 1, defComp!(int), 0, 1) val; })));
    test(is(typeof({ LimitCmp!(istring, "", defComp!(istring), "red"[], "green"[]) val; })));
}

/*******************************************************************************

    Simplified version of LimitCmp that uses default comparison

    Template_Params:
        T = type of the value
        init = default initial value if config value wasn't set
        Set = set of allowed values

*******************************************************************************/

template LimitInit ( T, T init = T.init, Set... )
{
    alias LimitCmp!(T, init, defComp!(T), Set) LimitInit;
}

unittest
{
    test(is(typeof({LimitInit!(int, 1, 0, 1) val;})));
    test(is(typeof({LimitInit!(istring, "green"[], "red"[], "green"[]) val;})));
}


/*******************************************************************************

    Simplified version of LimitCmp that uses default comparison and default
    initializer

    Template_Params:
        T = type of the value
        Set = set of allowed values

*******************************************************************************/

template Limit ( T, Set... )
{
    alias LimitInit!(T, T.init, Set) Limit;
}


/*******************************************************************************

    Adds the information of whether the filler actually set the value
    or whether it was left untouched.

    Template_Params:
        T = the original type

*******************************************************************************/

struct SetInfo ( T )
{
    mixin WrapperStructCore!(T);

    /***************************************************************************

        Query method for the value with optional default initializer

        Params:
            def = the value that should be used when it was not found in the
                  configuration

    ***************************************************************************/

    public BaseType!(T) opCall ( BaseType!(T) def = BaseType!(T).init )
    {
        if ( set )
        {
            return Value(this.value);
        }

        return def;
    }

    /***************************************************************************

        Whether this value has been set

    ***************************************************************************/

    public bool set;

    /***************************************************************************

        Sets the set attribute according to whether the variable appeared in
        the configuration or not

        Params:
            bool  = whether the variable existed in the configuration file
            group = group this variable should appear
            name  = name of the variable

    ***************************************************************************/

    private void check_ ( bool found, cstring group, cstring name )
    {
        this.set = found;
    }
}


/*******************************************************************************

    Template that evaluates to true when T is a supported type

    Template_Params:
        T = type to check for

*******************************************************************************/

public template IsSupported ( T )
{
    static if ( is(T : bool) )
    {
        const IsSupported = true;
    }
    else static if ( isIntegerType!(T) || isRealType!(T) )
    {
        const IsSupported = true;
    }
    else static if ( is(T U : U[])) // If it is an array
    {
        static if ( isStringType!(T) ) // If it is a string
        {
            const IsSupported = true;
        }
        else static if ( isStringType!(U) ) // If it is string of strings
        {
            const IsSupported = true;
        }
        else static if ( isIntegerType!(U) || isRealType!(U) )
        {
            const IsSupported = true;
        }
        else
        {
            const IsSupported = false;
        }
    }
    else
    {
        const IsSupported = false;
    }
}


/*******************************************************************************

    Set whether loose parsing is enabled or not.
    Loose parsing means, that variables that have no effect are allowed.

    Initial value is false.

    Params:
        state =
            default: true
            false: variables that have no effect cause an exception
            true:  variables that have no effect cause a stderr warning message

*******************************************************************************/

public bool enable_loose_parsing ( bool state = true )
{
    return loose_parsing = state;
}


/*******************************************************************************

    Creates an instance of T, and fills it with according values from the
    configuration file. The name of each variable will used to get it
    from the given section in the configuration file.

    Variables can be marked as required with the Required template.
    If it is important to know whether the setting has been set, the
    SetInfo struct can be used.

    Params:
        group     = the group/section of the variable
        config    = instance of the source to use

    Returns:
        a new instance filled with values from the configuration file

    See_Also:
        Required, SetInfo

*******************************************************************************/

public T fill ( T : Object, Source = ConfigParser )
              ( cstring group, Source config )
in
{
    assert(config !is null, "ClassFiller.fill: Cannot use null config");
}
body
{
    T reference;
    return fill(group, reference, config);
}


/*******************************************************************************

    Fill the given instance of T with according values from the
    configuration file. The name of each variable will used to get it
    from the given section in the configuration file.

    If reference is null, an instance will be created.

    Variables can be marked as required with the Required template.
    If it is important to know whether the setting has been set, the
    SetInfo struct can be used.

    Params:
        group     = the group/section of the variable
        reference = the instance to fill. If null it will be created
        config    = instance of the source to use

    Returns:
        an instance filled with values from the configuration file

    See_Also:
        Required, SetInfo

*******************************************************************************/

public T fill ( T : Object, Source = ConfigParser )
              ( cstring group, ref T reference, Source config )
in
{
    assert(config !is null, "ClassFiller.fill: Cannot use null config");
}
body
{
    if ( reference is null )
    {
        reference = new T;
    }

    foreach ( var; config.iterateCategory(group) )
    {
        if ( !hasField(reference, var) )
        {
            auto msg = cast(istring) ("Invalid configuration key "
                ~ group ~ "." ~ var);
            enforce!(ConfigException)(loose_parsing, msg);
            Stderr.formatln("#### WARNING: {}", msg);
        }
    }

    readFields!(T)(group, reference, config);

    return reference;
}

/*******************************************************************************

    Checks whether T or any of its super classes contain
    a variable called field

    Params:
        reference = reference of the object that will be checked
        field     = name of the field to check for

    Returns:
        true when T or any parent class has a member named the same as the
        value of field,
        else false

*******************************************************************************/

private bool hasField ( T : Object ) ( T reference, cstring field )
{
    foreach ( si, unused; reference.tupleof )
    {
        auto key = reference.tupleof[si].stringof["reference.".length .. $];

        if ( key == field ) return true;
    }

    bool was_found = true;

    // Recurse into super any classes
    static if ( is(T S == super ) )
    {
        was_found = false;

        foreach ( G; S ) static if ( !is(G == Object) )
        {
            if ( hasField!(G)(cast(G) reference, field))
            {
                was_found = true;
                break;
            }
        }
    }

    return was_found;
}

/*******************************************************************************

    Class Iterator. Iterates over variables of a category

*******************************************************************************/

struct ClassIterator ( T, Source = ConfigParser )
{
    Source config;
    istring root;

    invariant()
    {
        assert(this.config !is null, "ClassFiller.ClassIterator: Cannot have null config");
    }

    /***************************************************************************

        Variable Iterator. Iterates over variables of a category

    ***************************************************************************/

    public int opApply ( int delegate ( ref istring name, ref T x ) dg )
    {
        int result = 0;

        foreach ( key; this.config )
        {
            scope T instance = new T;

            if ( key.length > this.root.length
                 && key[0 .. this.root.length] == this.root
                 && key[this.root.length] == '.' )
            {
                .fill(key, instance, this.config);

                auto name = key[this.root.length + 1 .. $];
                result = dg(name, instance);

                if (result) break;
            }
        }

        return result;
    }

    /***************************************************************************

        Fills the properties of the given category into an instance representing
        that category.

        Params:
            name = category whose properties are to be filled
            instance = instance into which to fill the properties

    ***************************************************************************/

    public void fill ( cstring name, ref T instance )
    {
        auto key = this.root ~ "." ~ name;

        .fill(key, instance, this.config);
    }
}

/*******************************************************************************

    Creates an iterator that iterates over groups that start with
    a common string, filling an instance of the passed class type from
    the variables of each matching group and calling the delegate.

    TemplateParams:
        T = type of the class to fill
        Source = source to use

    Params:
        root = start of the group name
        config = instance of the source to use

    Returns:
        iterator that iterates over all groups matching the pattern

*******************************************************************************/

public ClassIterator!(T) iterate ( T, Source = ConfigParser )
                                 ( istring root, Source config )
in
{
    assert(config !is null, "ClassFiller.iterate: Cannot use null config");
}
body
{
    return ClassIterator!(T, Source)(config, root);
}


/*******************************************************************************

    Fills the fields of the `reference` from config file's group.

    Template Params:
        T  = type of the class to fill
        Source = source to use

    Params:
        group = group to read fields from
        reference = reference to the object to be filled
        config = instance of the source to use

*******************************************************************************/

protected void readFields ( T, Source )
                          ( cstring group, T reference, Source config )
in
{
    assert ( config !is null, "ClassFiller.readFields: Cannot use null config");
}
body
{
    foreach ( si, field; reference.tupleof )
    {
        alias BaseType!(typeof(field)) Type;

        static assert ( IsSupported!(Type),
                        "ClassFiller.readFields: Type "
                        ~ Type.stringof ~ " is not supported" );

        auto key = reference.tupleof[si].stringof["reference.".length .. $];

        if ( config.exists(group, key) )
        {
            static if ( is(Type U : U[]) && !isStringType!(Type))
            {
                reference.tupleof[si] = config.getListStrict!(DynamicArrayType!(U))(group, key);
            }
            else
            {
                reference.tupleof[si] = config.getStrict!(DynamicArrayType!(Type))(group, key);
            }


            debug (Config) Stdout.formatln("Config Debug: {}.{} = {}", group,
                             reference.tupleof[si]
                            .stringof["reference.".length  .. $],
                            Value(reference.tupleof[si]));

            static if ( !is (Type == typeof(field)) )
            {
                reference.tupleof[si].check(true, group, key);
            }
        }
        else
        {
            debug (Config) Stdout.formatln("Config Debug: {}.{} = {} (builtin)", group,
                             reference.tupleof[si]
                            .stringof["reference.".length  .. $],
                            Value(reference.tupleof[si]));

            static if ( !is (Type == typeof(field)) )
            {
                reference.tupleof[si].check(false, group, key);
            }
        }
    }

    // Recurse into super any classes
    static if ( is(T S == super ) )
    {
        foreach ( G; S ) static if ( !is(G == Object) )
        {
            readFields!(G)(group, cast(G) reference, config);
        }
    }
}


version ( UnitTest )
{
    class SolarSystemEntity
    {
        uint radius;
        uint circumference;
    }
}

unittest
{
    auto config_parser = new ConfigParser();

    auto config_str =
`
[SUN.earth]
radius = 6371
circumference = 40075

[SUN-andromeda]
lunch = dessert_place

[SUN_wannabe_solar_system_entity]
radius = 4525
circumference = 35293

[SUN.earth.moon]
radius = 1737
circumference = 10921

[SUNBLACKHOLE]
shoe_size = 42
`;

    config_parser.parseString(config_str);

    auto iter = iterate!(SolarSystemEntity)("SUN", config_parser);

    SolarSystemEntity entity_details;

    foreach ( entity, conf; iter )
    {
        test((entity == "earth") || (entity == "earth.moon"),
            "'" ~ entity ~ "' is neither 'earth' nor 'earth.moon'");

        iter.fill(entity, entity_details);

        if (entity == "earth")
        {
            test!("==")(entity_details.radius, 6371);
            test!("==")(entity_details.circumference, 40075);
        }
        else // if (entity == "earth.moon")
        {
            test!("==")(entity_details.radius, 1737);
            test!("==")(entity_details.circumference, 10921);
        }
    }
}

unittest
{
    const config_text =
`
[Section]
str = I'm a string
integer = -300
pi = 3.14
`;

    auto config_parser = new ConfigParser();
    config_parser.parseString(config_text);

    class SingleValues
    {
        istring str;
        int integer;
        float pi;
        uint default_value = 99;
    }

    auto single_values = new SingleValues();

    readFields("Section", single_values, config_parser);
    test!("==")(single_values.str, "I'm a string");
    test!("==")(single_values.integer, -300);
    test!("==")(single_values.pi, cast(float)3.14);
    test!("==")(single_values.default_value, 99);
}

unittest
{
    const config_text =
`
[Section]
str = I'm a mutable string
`;

    auto config_parser = new ConfigParser();
    config_parser.parseString(config_text);

    class MutString
    {
        mstring str;
    }

    auto mut_string = new MutString();

    readFields("Section", mut_string, config_parser);
    test!("==")(mut_string.str, "I'm a mutable string");
}

unittest
{
    const config_text =
`
[SectionArray]
string_arr = Hello
         World
int_arr = 30
      40
      -60
      1111111111
      0x10
ulong_arr = 0
        50
        18446744073709551615
        0xa123bcd
float_arr = 10.2
        -25.3
        90
        0.000000001
`;

    auto config_parser = new ConfigParser();
    config_parser.parseString(config_text);

    class ArrayValues
    {
        istring[] string_arr;
        int[] int_arr;
        ulong[] ulong_arr;
        float[] float_arr;
    }

    auto array_values = new ArrayValues();
    readFields("SectionArray", array_values, config_parser);
    test!("==")(array_values.string_arr, ["Hello", "World"]);
    test!("==")(array_values.int_arr, [30, 40, -60, 1111111111, 0x10]);
    ulong[] ulong_array = [0, 50, ulong.max, 0xa123bcd];
    test!("==")(array_values.ulong_arr, ulong_array);
    float[] float_array = [10.2, -25.3, 90, 0.000000001];
    test!("==")(array_values.float_arr, float_array);
}
