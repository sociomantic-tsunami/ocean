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

deprecated module ocean.util.config.ClassFiller;

pragma (msg, "Deprecated. Please use `ocean.util.config.ConfigFiller` instead.");

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ConfigFiller = ocean.util.config.ConfigFiller;

version (UnitTest)
{
    import ocean.core.Test;
    import ocean.util.config.ConfigParser;
}

/*******************************************************************************

    Evaluates to the original type with which a Wrapper Struct was initialised

    If T is not a struct, T itself is returned

    Template_Params:
        T = struct or type to find the basetype for

*******************************************************************************/

public alias ConfigFiller.BaseType BaseType;

/*******************************************************************************

    Returns the value of the given struct/value.

    If value is not a struct, the value itself is returned

    Template_Params:
        v = instance of a struct the value itself

*******************************************************************************/

public alias ConfigFiller.Value Value;

/*******************************************************************************

    Contains methods used in all WrapperStructs to access and set the value
    variable

    Template_Params:
        T = type of the value

*******************************************************************************/

public alias ConfigFiller.WrapperStructCore WrapperStructCore;

/*******************************************************************************

    Configuration settings that are mandatory can be marked as such by
    wrapping them with this template.
    If the variable is not set, then an exception is thrown.

    The value can be accessed with the opCall method

    Template_Params:
        T = the original type of the variable

*******************************************************************************/

public alias ConfigFiller.Required Required;

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

public alias ConfigFiller.MinMax MinMax;

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

public alias ConfigFiller.Min Min;

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

public alias ConfigFiller.Max Max;

/*******************************************************************************

    Default compare function, used with the LimitCmp struct/template

    Params:
        a = first value to compare
        b = second value to compare with

    Returns:
        whether a == b

*******************************************************************************/

public alias ConfigFiller.defComp defComp;

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

public alias ConfigFiller.LimitCmp LimitCmp;

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

public alias ConfigFiller.LimitInit LimitInit;

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

public alias ConfigFiller.Limit Limit;

/*******************************************************************************

    Adds the information of whether the filler actually set the value
    or whether it was left untouched.

    Template_Params:
        T = the original type

*******************************************************************************/

public alias ConfigFiller.SetInfo SetInfo;

/*******************************************************************************

    Template that evaluates to true when T is a supported type

    Template_Params:
        T = type to check for

*******************************************************************************/

public alias ConfigFiller.IsSupported IsSupported;

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

public alias ConfigFiller.enable_loose_parsing enable_loose_parsing;


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

public alias ConfigFiller.fill fill;


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

private alias ConfigFiller.hasField hasField;


/*******************************************************************************

    Class Iterator. Iterates over variables of a category

    Params:
        T = type of the class to iterate upon
        Source = type of the source of values of the class' members - must
            provide foreach iteration over its elements
            (defaults to ConfigParser)

*******************************************************************************/

public alias ConfigFiller.ClassIterator ClassIterator;


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

public alias ConfigFiller.iterate iterate;


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

public alias ConfigFiller.readFields readFields;


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

    foreach ( entity; iter )
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
