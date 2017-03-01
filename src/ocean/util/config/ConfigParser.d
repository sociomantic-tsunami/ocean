/*******************************************************************************

    Load Configuration from Config File

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.config.ConfigParser;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.core.Array : copy;

import ocean.core.Exception;
import ocean.core.Enforce;

import ocean.io.Stdout;

import ocean.core.Array;

import ocean.io.stream.TextFile;

import ocean.io.stream.Format;

import ocean.text.convert.Integer_tango: toLong;

import ocean.text.convert.Float: toFloat;

import ocean.text.convert.Formatter;

import ocean.text.Util: locate, trim, delimit, lines;

import ocean.text.convert.Utf;

import ocean.core.Exception_tango;

import ocean.core.Traits : DynamicArrayType;



/******************************************************************************

    ConfigException

*******************************************************************************/

class ConfigException : Exception
{
    mixin DefaultExceptionCtor;
}


/*******************************************************************************

    Config reads all properties of the application from an INI style of the
    following format:

    ---

        // --------------------------
        // Config Example
        // --------------------------

        ; Database config parameters
        [DATABASE]
        table1 = "name_of_table1"
        table2 = "name_of_table2"

        ; An example of a multi-value parameter
        fields = "create_time"
                 "update_time"
                 "count"

        ; Logging config parameters
        [LOGGING]
        level = 4
        file = "access.log"

    ---

    The properties defined in the file are read and stored in an internal array,
    which can then be accessed through get and set methods as follows:

    Usage example:

    ---

        // Read config file from disk
        Config.parseFile("etc/my_config.ini");

        // Read a single value
        istring value = Config.Char["category", "key"];

        // Set a single value
        Config.set("category", "key", "new value");

        // Read a multi-line value
        istring[] values = Config.getListStrict("category", "key");

    ---

    The parseFile() method only needs to be called once, though may be called
    multiple times if the config file needs to be re-read from the file on disk.

    TODO:

    If properties have changed within the program it can be written back to
    the INI file with a write function. This function clears the INI file and
    writes all current parameters stored in properties to INI file.

        Config.set("key", "new value");
        Config.write;

*******************************************************************************/

class ConfigParser
{
    /***************************************************************************

        Variable Iterator. Iterates over keys or key/value pairs of a category.
        The values are converted to T, unless T is istring.

    ***************************************************************************/

    public struct VarIterator ( T = istring )
    {
        ValueNode[istring]* vars;


        /***********************************************************************

            Variable Iterator. Iterates over key/value pairs of a category.

        ***********************************************************************/

        public int opApply ( int delegate ( ref istring key, ref T val ) dg )
        {
            if ( this.vars !is null )
            {
                foreach ( key, valnode; *this.vars )
                {
                    auto val = conv!(T)(valnode.value);

                    if ( int result = dg(key, val) )
                        return result;
                }
            }

            return 0;
        }


        /***********************************************************************

            Variable Iterator. Iterates over keys of a category.

        ***********************************************************************/

        public int opApply ( int delegate ( ref istring x ) dg )
        {
            return this.opApply(
                (ref istring key, ref istring val)
                {
                    return dg(key);
                });
        }
    }


    /***************************************************************************

        Immediate context of the current line being parsed

    ***************************************************************************/

    private struct ParsingContext
    {
        /***********************************************************************

          Current category being parsed

        ***********************************************************************/

        mstring category;


        /***********************************************************************

          Current key being parsed

        ***********************************************************************/

        mstring key;


        /***********************************************************************

          Current value being parsed

        ***********************************************************************/

        mstring value;


        /***********************************************************************

          True if we are at the first multiline value when parsing

        ***********************************************************************/

        bool multiline_first = true;
    }

    private ParsingContext context;


    /***************************************************************************

        Structure representing a single value node in the configuration.

    ***************************************************************************/

    private struct ValueNode
    {
        /***********************************************************************

            The actual value.

        ***********************************************************************/

        istring value;


        /***********************************************************************

            Flag used to allow a config file to be parsed, even when a different
            configuration has already been parsed in the past.

            At the start of every new parse, the flags of all value nodes in an
            already parsed configuration are set to false. If this value node is
            found during the parse, its flag is set to true. All new value nodes
            added will also have the flag set to true. At the end of the parse,
            all value nodes that have the flag set to false are removed.

        **********************************************************************/

        bool present_in_config;
    }


    /***************************************************************************

        Config Keys and Properties

    ***************************************************************************/

    alias istring String;
    private ValueNode[String][String] properties;


    /***************************************************************************

        Config File Location

    ***************************************************************************/

    private istring config_file;


    /***************************************************************************

         Constructor

    ***************************************************************************/

    public this ( )
    { }


    /***************************************************************************

         Constructor

         Params:
             config = path to the configuration file

    ***************************************************************************/

    public this ( istring config )
    {
        this.parseFile(config);
    }


    /***************************************************************************

        Returns an iterator over keys or key/value pairs in a category.
        The values are converted to T, unless T is istring.

        Params:
            category = category to iterate over

        Returns:
            an iterator over the keys or key/value pairs in category.

    ***************************************************************************/

    public VarIterator!(T) iterateCategory ( T = istring ) ( cstring category )
    {
        return VarIterator!(T)(category in this.properties);
    }


    /***************************************************************************

        Iterator. Iterates over categories of the config file

    ***************************************************************************/

    public int opApply ( int delegate ( ref istring x ) dg )
    {
        int result = 0;

        foreach ( key, val; this.properties )
        {
            result = dg(key);

            if ( result ) break;
        }

        return result;
    }


    /***************************************************************************

        Read Config File

        Reads the content of the configuration file and copies to a static
        array buffer.

        Each property in the ini file belongs to a category. A property always
        has a key and a value associated with the key. The function parses the
        following different elements:

        i. Categories
        [Example Category]

        ii. Comments
        // comments start with two slashes,
        ;  a semi-colon
        #  or a hash

        iii. Property
        key = value

        iv. Multi-value property
        key = value1
              value2
              value3

        Usage Example:

        ---

            Config.parseFile("etc/config.ini");

        ---

        Params:
            file_path = string that contains the path to the configuration file
            clean_old = true if the existing configuration should be overwritten
                        with the result of the current parse, false if the
                        current parse should only add to or update the existing
                        configuration. (defaults to true)

    ***************************************************************************/

    public void parseFile ( istring file_path = "etc/config.ini",
                            bool clean_old = true )
    {
        this.config_file = file_path;

        auto get_line = new TextFileInput(this.config_file);

        this.parseIter(get_line, clean_old);
    }


    /***************************************************************************

        Parse a string

        See parseFile() for details on the parsed syntax.

        Usage Example:

        ---

            Config.parseString(
                "[section]\n"
                "key = value1\n"
                "      value2\n"
                "      value3\n"
            );

        ---

        Params:
            T   = Type of characters in the string
            str = string to parse
            clean_old = true if the existing configuration should be overwritten
                        with the result of the current parse, false if the
                        current parse should only add to or update the existing
                        configuration. (defaults to true)

    ***************************************************************************/

    public void parseString (T : dchar) ( T[] str, bool clean_old = true )
    {
        static struct Iterator
        {
            T[] data;

            int opApply ( int delegate ( ref T[] x ) dg )
            {
                int result = 0;

                foreach ( ref line; lines(this.data) )
                {
                    result = dg(line);

                    if ( result ) break;
                }

                return result;
            }
        }

        this.parseIter(Iterator(str), clean_old);
    }


    /***************************************************************************

        Tells whether the config object has no values loaded.

        Returns:
            true if it doesn't have any values, false otherwise

    ***************************************************************************/

    public bool isEmpty()
    {
        return this.properties.length == 0;
    }


    /***************************************************************************

        Checks if Key exists in Category

        Params:
            category = category in which to look for the key
            key      = key to be checked

        Returns:
            true if the configuration key exists in this category

    ***************************************************************************/

    public bool exists ( cstring category, cstring key )
    {
        return ((category in this.properties) &&
                (key in this.properties[category]));
    }


    /***************************************************************************

        Strict method to get the value of a config key. If the requested key
        cannot be found, an exception is thrown.

        Template can be instantiated with integer, float or string (istring)
        type.

        Usage Example:

        ---

            Config.parseFile("some-config.ini");
            // throws if not found
            auto str = Config.getStrict!(istring)("some-cat", "some-key");
            auto n = Config.getStrict!(int)("some-cat", "some-key");

        ---

        Params:
            category = category to get key from
            key = key whose value is to be got

        Throws:
            if the specified key does not exist

        Returns:
            value of a configuration key, or null if none

    ***************************************************************************/

    public T getStrict ( T ) ( cstring category, cstring key )
    {
        enforce!(ConfigException)(
            exists(category, key),
            format("Critical Error: No configuration key '{}:{}' found",
                   category, key)
        );
        try
        {
            auto value_node = this.properties[category][key];

            return conv!(T)(value_node.value);
        }
        catch ( IllegalArgumentException )
        {
            throw new ConfigException(
                          format("Critical Error: Configuration key '{}:{}' "
                               ~ "appears not to be of type '{}'",
                                 category, key, T.stringof));
        }

        assert(0);
    }


    /***************************************************************************

        Alternative form strict config value getter, returning the retrieved
        value via a reference. (The advantage being that the template type can
        then be inferred by the compiler.)

        Template can be instantiated with integer, float or string (istring)
        type.

        Usage Example:

        ---

            Config.parseFile("some-config.ini");
            // throws if not found
            istring str;
            int n;

            Config.getStrict(str, "some-cat", "some-key");
            Config.getStrict(n, "some-cat", "some-key");

        ---

        Params:
            value = output for config value
            category = category to get key from
            key = key whose value is to be got

        Throws:
            if the specified key does not exist

        TODO: perhaps we should discuss removing the other version of
        getStrict(), above? It seems a little bit confusing having both methods,
        and I feel this version is more convenient to use.

    ***************************************************************************/

    public void getStrict ( T ) ( ref T value, cstring category, cstring key )
    {
        value = this.getStrict!(T)(category, key);
    }


    /***************************************************************************

        Non-strict method to get the value of a config key into the specified
        output value. If the config key does not exist, the given default value
        is returned.

        Template can be instantiated with integer, float or string (istring)
        type.

        Usage Example:

        ---

            Config.parseFile("some-config.ini");
            auto str = Config.get("some-cat", "some-key", "my_default_value");
            int n = Config.get("some-cat", "some-int", 5);

        ---

        Params:
            category = category to get key from
            key = key whose value is to be got
            default_value = default value to use if missing in the config

        Returns:
            config value, if existing, otherwise default value

    ***************************************************************************/

    public DynamicArrayType!(T) get ( T ) ( cstring category, cstring key,
            T default_value )
    {
        if ( exists(category, key) )
        {
            return getStrict!(DynamicArrayType!(T))(category, key);
        }
        return default_value;
    }


    /***************************************************************************

        Alternative form non-strict config value getter, returning the retrieved
        value via a reference. (For interface consistency with the reference
        version of getStrict(), above.)

        Template can be instantiated with integer, float or string (istring)
        type.

        Usage Example:

        ---

            Config.parseFile("some-config.ini");
            istring str;
            int n;

            Config.get(str, "some-cat", "some-key", "default value");
            Config.get(n, "some-cat", "some-key", 23);

        ---

        Params:
            value = output for config value
            category = category to get key from
            key = key whose value is to be got
            default_value = default value to use if missing in the config

        TODO: perhaps we should discuss removing the other version of
        get(), above? It seems a little bit confusing having both methods,
        and I feel the reference version is more convenient to use.

    ***************************************************************************/

    public void get ( T ) ( ref T value, cstring category,
        cstring key, T default_value )
    {
        value = this.get(category, key, default_value);
    }


    /***************************************************************************

        Strict method to get a multi-line value. If the requested key cannot be
        found, an exception is thrown.

        Retrieves the value list of a configuration key with a multi-line value.
        If the value is a single line, the list has one element.

        Params:
            category = category to get key from
            key = key whose value is to be got

        Throws:
            if the specified key does not exist

        Returns:
            list of values

    ***************************************************************************/

    public T[] getListStrict ( T = istring ) ( cstring category, cstring key )
    {
        auto value = this.getStrict!(istring)(category, key);
        T[] r;
        foreach ( elem; delimit(value, "\n") )
        {
            r ~= this.conv!(T)(elem);
        }
        return r;
    }


    /***************************************************************************

        Non-strict method to get a multi-line value. The existence or
        non-existence of the key is returned. If the configuration key cannot be
        found, the output list remains unchanged.

        If the value is a single line, the output list has one element.

        Params:
            category = category to get key from
            key = key whose value is to be got
            default_value = default list to use if missing in the config

        Returns:
            the list of values corresponding to the given category + key
            combination if such a combination exists, the given list of default
            values otherwise

    ***************************************************************************/

    public T[] getList ( T = istring ) ( cstring category, cstring key,
            T[] default_value )
    {
        if ( exists(category, key) )
        {
            return getListStrict!(T)(category, key);
        }
        return default_value;
    }


    /***************************************************************************

        Set Config-Key Property

        Usage Example:

        ---

            Config.parseFile(`etc/config.ini`);

            Config.set(`category`, `key`, `value`);

        ---

        Params:
            category = category to be set
            key      = key to be set
            value    = value of the property

    ***************************************************************************/

    public void set ( istring category, istring key, istring value )
    {
        if ( category == "" || key == "" || value == "" )
        {
            return;
        }

        if ( this.exists(category, key) )
        {
            (this.properties[category][key]).value = value;
        }
        else
        {
            ValueNode value_node = { value, true };

            this.properties[category][key] = value_node;
        }
    }


    /***************************************************************************

        Remove Config-Key Property

        Usage Example:

        ---

            Config.parseFile(`etc/config.ini`);

            Config.remove(`category`, `key`);

        ---

        Params:
            category = category from which the property is to be removed
            key      = key of the property to be removed

    ***************************************************************************/

    public void remove ( istring category, istring key )
    {
        if ( category == "" || key == "" )
        {
            return;
        }

        if ( this.exists(category, key) )
        {
            (this.properties[category][key]).present_in_config = false;

            this.pruneConfiguration();
        }
    }


    /***************************************************************************

         Prints the current configuration to the given formatted text stream.

         Note that no guarantees can be made about the order of the categories
         or the order of the key-value pairs within each category.

         Params:
             output = formatted text stream in which to print the configuration
                      (defaults to Stdout)

    ***************************************************************************/

    public void print ( FormatOutput!(char) output = Stdout )
    {
        foreach ( category, key_value_pairs; this.properties )
        {
            output.formatln("{}", category);

            foreach ( key, value_node; key_value_pairs )
            {
                output.formatln("    {} = {}", key, value_node.value);
            }
        }
    }


    /***************************************************************************

        Actually performs parsing of the lines of a config file or a string.
        Each line to be parsed is obtained via an iterator.

        Template_Params:
            I = type of the iterator that will supply lines to be parsed

        Params:
            iter = iterator that will supply lines to be parsed
            clean_old = true if the existing configuration should be overwritten
                        with the result of the current parse, false if the
                        current parse should only add to or update the existing
                        configuration.

    ***************************************************************************/

    private void parseIter ( I ) ( I iter, bool clean_old )
    {
        this.clearParsingContext();

        if ( clean_old )
        {
            this.clearAllValueNodeFlags();
        }

        foreach ( ref line; iter )
        {
            this.parseLine(line);
        }

        this.saveFromParsingContext();

        this.pruneConfiguration();

        this.clearParsingContext();
    }


    /***************************************************************************

        Converts a string to a boolean value. The following string values are
        accepted:

            false / true, disabled / enabled, off / on, no / yes, 0 / 1

        Params:
            property = string to extract boolean value from

        Throws:
            if the string does not match one of the possible boolean strings

        Returns:
            boolean value interpreted from string

    ***************************************************************************/

    private static bool toBool ( cstring property )
    {
        const istring[2][] BOOL_IDS =
        [
           ["false",    "true"],
           ["disabled", "enabled"],
           ["off",      "on"],
           ["no",       "yes"],
           ["0",        "1"]
        ];

        foreach ( id; BOOL_IDS )
        {
            if ( property == id[0] ) return false;
            if ( property == id[1] ) return true;
        }

        throw new IllegalArgumentException(
                                      "Config.toBool :: invalid boolean value");
    }


    /***************************************************************************

        Converts property to T

        Params:
            property = value to convert

        Returns:
            property converted to T

    ***************************************************************************/

    private static T conv ( T ) ( cstring property )
    {
        static if ( is(T : bool) )
        {
            return toBool(property);
        }
        else static if ( is(T : long) )
        {
            auto v = toLong(property);
            enforce!(IllegalArgumentException)(
                v >= T.min && v <= T.max,
                "Value of " ~ cast(istring) property ~ " is out of " ~ T.stringof ~ " bounds");
            return cast(T) v;
        }
        else static if ( is(T : real) )
        {
            return toFloat(property);
        }
        else static if ( is(T U : U[]) &&
                         ( is(Unqual!(U) : char) || is(Unqual!(U) : wchar)
                           || is(Unqual!(U) : dchar)) )
        {
            auto r = fromString8!(Unqual!(U))(property, T.init);
            return cast(T) r.dup;
        }
        else
        {
            static assert(false,
                          __FILE__ ~ " : get(): type '" ~ T.stringof
                          ~ "' is not supported");
        }
    }


    /***************************************************************************

        Saves the current contents of the context into the configuration.

    ***************************************************************************/

    private void saveFromParsingContext ( )
    {
        auto ctx = &this.context;

        if ( ctx.category.length == 0 ||
             ctx.key.length == 0 ||
             ctx.value.length == 0 )
        {
            return;
        }

        if ( this.exists(ctx.category, ctx.key) )
        {
            ValueNode * value_node = &this.properties[ctx.category][ctx.key];

            if ( value_node.value != ctx.value )
            {
                value_node.value = idup(ctx.value);
            }

            value_node.present_in_config = true;
        }
        else
        {
            ValueNode value_node = { ctx.value.dup, true };

            this.properties[idup(ctx.category)][idup(ctx.key)] = value_node;
        }

        ctx.value.length = 0;
        enableStomping(ctx.value);
    }


    /***************************************************************************

        Clears the 'present_in_config' flags associated with all value nodes in
        the configuration.

    ***************************************************************************/

    private void clearAllValueNodeFlags ( )
    {
        foreach ( category, key_value_pairs; this.properties )
        {
            foreach ( key, ref value_node; key_value_pairs )
            {
                value_node.present_in_config = false;
            }
        }
    }


    /***************************************************************************

        Prunes the configuration removing all keys whose value nodes have the
        'present_in_config' flag set to false. Also removes all categories that
        have no keys.

    ***************************************************************************/

    private void pruneConfiguration ( )
    {
        istring[] keys_to_remove;
        istring[] categories_to_remove;

        // Remove obsolete keys

        foreach ( category, ref key_value_pairs; this.properties )
        {
            foreach ( key, value_node; key_value_pairs )
            {
                if ( ! value_node.present_in_config )
                {
                    keys_to_remove ~= key;
                }
            }

            foreach ( key; keys_to_remove )
            {
                key_value_pairs.remove(key);
            }

            keys_to_remove.length = 0;
            enableStomping(keys_to_remove);
        }

        // Remove categories that have no keys

        foreach ( category, key_value_pairs; this.properties )
        {
            if ( key_value_pairs.length == 0 )
            {
                categories_to_remove ~= category;
            }
        }

        foreach ( category; categories_to_remove )
        {
            this.properties.remove(category);
        }
    }


    /***************************************************************************

        Clears the current parsing context.

    ***************************************************************************/

    private void clearParsingContext ( )
    {
        auto ctx = &this.context;

        ctx.value.length    = 0;
        enableStomping(ctx.value);
        ctx.category.length = 0;
        enableStomping(ctx.category);
        ctx.key.length      = 0;
        enableStomping(ctx.key);
        ctx.multiline_first = true;
    }


    /***************************************************************************

        Parse a line

        See parseFile() for details on the parsed syntax. This method only makes
        sense to do partial parsing of a string.

        Usage Example:

        ---

            Config.parseLine("[section]");
            Config.parseLine("key = value1\n");
            Config.parseLine("      value2\n");
            Config.parseLine("      value3\n");

        ---

        Params:
            line = line to parse

    ***************************************************************************/

    private void parseLine ( cstring line )
    {
        auto ctx = &this.context;

        line = trim(line);

        if ( line.length == 0 )
        {
            // Ignore empty lines.
            return;
        }

        bool slash_comment = line.length >= 2 && line[0 .. 2] == "//";
        bool hash_comment = line[0] == '#';
        bool semicolon_comment = line[0] == ';';

        if ( slash_comment || semicolon_comment || hash_comment )
        {
            // Ignore comment lines.
            return;
        }

        auto pos = locate(line, '['); // category present in line?

        if ( pos == 0 )
        {
            this.saveFromParsingContext();

            auto cat = trim(line[pos + 1 .. locate(line, ']')]);

            ctx.category.copy(cat);

            ctx.key.length = 0;
            enableStomping(ctx.key);
        }
        else
        {
            pos = locate(line, '='); // check for key value pair

            if ( pos < line.length )
            {
                this.saveFromParsingContext();

                ctx.key.copy(trim(line[0 .. pos]));

                ctx.value.copy(trim(line[pos + 1 .. $]));

                ctx.multiline_first = !ctx.value.length;
            }
            else
            {
                if ( ! ctx.multiline_first )
                {
                    ctx.value ~= '\n';
                }

                ctx.value ~= line;

                ctx.multiline_first = false;
            }
        }
    }
}



/*******************************************************************************

    Unittest

*******************************************************************************/

version ( UnitTest )
{
    import ocean.core.Test;
}

unittest
{
    struct ConfigSanity
    {
        uint num_categories;

        cstring[] categories;

        cstring[] keys;
    }

    void parsedConfigSanityCheck ( ConfigParser config, ConfigSanity expected,
                                   istring test_name )
    {
        auto t = new NamedTest(test_name);
        cstring[] obtained_categories;
        cstring[] obtained_keys;

        t.test!("==")(config.isEmpty, (expected.num_categories == 0));

        foreach ( category; config )
        {
            obtained_categories ~= category;

            foreach ( key; config.iterateCategory(category) )
            {
                obtained_keys ~= key;
            }
        }

        t.test!("==")(obtained_categories.length, expected.num_categories);

        t.test!("==")(sort(obtained_categories), sort(expected.categories));

        t.test!("==")(sort(obtained_keys), sort(expected.keys));
    }

    // Wrapper function that just calls the 'parsedConfigSanityCheck' function,
    // but appends the line number to the test name. This is useful when
    // slightly different variations of the same basic type of test need to be
    // performed.
    void parsedConfigSanityCheckN ( ConfigParser config, ConfigSanity expected,
                                    cstring test_name,
                                    typeof(__LINE__) line_num = __LINE__ )
    {
        parsedConfigSanityCheck(config, expected,
                                format("{} (line: {})", test_name, line_num));
    }

    scope Config = new ConfigParser();

    /***************************************************************************

        Section 1: unit-tests to confirm correct parsing of config files

    ***************************************************************************/

    auto str1 =
`
[Section1]
multiline = a
# unittest comment
b
; comment with a different style in multiline
c
// and the ultimative comment
d
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
bool_arr = true
       false
`.dup;
    ConfigSanity str1_expectations =
        { 1,
          [ "Section1" ],
          [ "multiline", "int_arr", "ulong_arr", "float_arr", "bool_arr" ]
        };

    Config.parseString(str1);
    parsedConfigSanityCheck(Config, str1_expectations, "basic string");

    scope l = Config.getListStrict("Section1", "multiline");

    test!("==")(l.length, 4);

    test!("==")(l, ["a", "b", "c", "d"][]);

    scope ints = Config.getListStrict!(int)("Section1", "int_arr");
    test!("==")(ints, [30, 40, -60, 1111111111, 0x10][]);

    scope ulong_arr = Config.getListStrict!(ulong)("Section1", "ulong_arr");
    ulong[] ulong_array = [0, 50, ulong.max, 0xa123bcd];
    test!("==")(ulong_arr, ulong_array);

    scope float_arr = Config.getListStrict!(float)("Section1", "float_arr");
    float[] float_array = [10.2, -25.3, 90, 0.000000001];
    test!("==")(float_arr, float_array);

    scope bool_arr = Config.getListStrict!(bool)("Section1", "bool_arr");
    test!("==")(bool_arr, [true, false][]);

    try
    {
        scope w_bool_arr = Config.getListStrict!(bool)("Section1", "int_arr");
    }
    catch ( IllegalArgumentException e )
    {
        test!("==")(getMsg(e), "Config.toBool :: invalid boolean value"[]);
    }

    // Manually set a property (new category).
    Config.set("Section2", "set_key", "set_value"[]);

    istring new_val;
    Config.getStrict(new_val, "Section2", "set_key");
    test!("==")(new_val, "set_value"[]);

    // Manually set a property (existing category, new key).
    Config.set("Section2", "another_set_key", "another_set_value"[]);

    Config.getStrict(new_val, "Section2", "another_set_key");
    test!("==")(new_val, "another_set_value"[]);

    // Manually set a property (existing category, existing key).
    Config.set("Section2", "set_key", "new_set_value");

    Config.getStrict(new_val, "Section2", "set_key");
    test!("==")(new_val, "new_set_value"[]);

    // Check if the 'exists' function works as expected.
    test( Config.exists("Section1", "int_arr"), "exists API failure");
    test(!Config.exists("Section420", "int_arr"), "exists API failure");
    test(!Config.exists("Section1", "key420"), "exists API failure");

    ConfigSanity new_str1_expectations =
        { 2,
          [ "Section1", "Section2" ],
          [ "multiline", "int_arr", "ulong_arr", "float_arr", "bool_arr",
            "set_key", "another_set_key" ]
        };
    parsedConfigSanityCheck(Config, new_str1_expectations, "modified string");

    // Remove properties from the config.
    Config.remove("Section2", "set_key");
    Config.remove("Section2", "another_set_key");
    parsedConfigSanityCheck(Config, str1_expectations, "back to basic string");

    // getList tests
    scope gl1 = Config.getList("Section1", "dummy",
                        ["this", "is", "a", "list", "of", "default", "values"]);
    test!("==")(gl1.length, 7);
    test!("==")(gl1, ["this", "is", "a", "list", "of", "default", "values"][]);

    scope gl2 = Config.getList("Section1", "multiline",
                        ["this", "is", "a", "list", "of", "default", "values"]);
    test!("==")(gl2.length, 4);
    test!("==")(gl2, ["a", "b", "c", "d"][]);

    // Whitespaces handling

    istring white_str =
`
[ Section1 ]
key = val
`;
    ConfigSanity white_str_expectations =
        { 1,
          [ "Section1" ],
          [ "key" ]
        };

    Config.parseString(white_str);
    parsedConfigSanityCheckN(Config, white_str_expectations, "white spaces");

    white_str =
`
[Section1 ]
key = val
`;
    Config.parseString(white_str);
    parsedConfigSanityCheckN(Config, white_str_expectations, "white spaces");

    white_str =
`
[	       Section1]
key = val
`;
    Config.parseString(white_str);
    parsedConfigSanityCheckN(Config, white_str_expectations, "white spaces");

    white_str =
`
[Section1]
key =		   val
`;
    Config.parseString(white_str);
    parsedConfigSanityCheckN(Config, white_str_expectations, "white spaces");

    white_str =
`
[Section1]
key	     = val
`;
    Config.parseString(white_str);
    parsedConfigSanityCheckN(Config, white_str_expectations, "white spaces");

    white_str =
`
[Section1]
	  key	     = val
`;
    Config.parseString(white_str);
    parsedConfigSanityCheckN(Config, white_str_expectations, "white spaces");

    white_str =
`
[	       Section1   ]
	  key	     =		       val
`;
    Config.parseString(white_str);
    parsedConfigSanityCheckN(Config, white_str_expectations, "white spaces");

    // Parse a new configuration

    auto str2 =
`
[German]
one = eins
two = zwei
three = drei
[Hindi]
one = ek
two = do
three = teen
`;
    ConfigSanity str2_expectations =
        { 2,
          [ "German", "Hindi" ],
          [ "one", "two", "three", "one", "two", "three" ],
        };

    Config.parseString(str2);
    parsedConfigSanityCheck(Config, str2_expectations, "new string");


    /***************************************************************************

        Section 2: unit-tests to check memory usage

    ***************************************************************************/

    // Test to ensure that an additional parse of the same configuration does
    // not allocate at all.

    testNoAlloc(Config.parseString(str2));

    // Test to ensure that a few hundred additional parses of the same
    // configuration does not allocate at all.

    size_t mem_used1, mem_free1;
    gc_usage(mem_used1, mem_free1);

    const num_parses = 200;
    for (int i; i < num_parses; i++)
    {
        Config.parseString(str2);
    }

    size_t mem_used2, mem_free2;
    gc_usage(mem_used2, mem_free2);

    test!("==")(mem_used1, mem_used2);
    test!("==")(mem_free1, mem_free2);

    Config.clearParsingContext();
}
