/*******************************************************************************

    Serializer, to be used with the StructSerializer in
    ocean.io.serialize.StructSerializer, which dumps a struct to a string.

    Usage example (in conjunction with ocean.io.serialize.StructSerializer):

    ---

        // Example struct to serialize
        struct Data
        {
            struct Id
            {
                cstring name;
                hash_t id;
            }

            Id[] ids;
            cstring name;
            uint count;
            float money;
        }

        // Set up some data in a struct
        Data data;
        test.ids = [Data.Id("hi", 23), Data.Id("hello", 17)];

        // Create serializer object
        scope ser = new StringStructSerializer!(char)();

        // A string buffer
        char[] output;

        // Dump struct to buffer via serializer
        ser.serialize(output, data);

    ---

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.serialize.StringStructSerializer;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.core.Array;

import ocean.io.serialize.StructSerializer;

import ocean.text.convert.Format;

import ocean.text.convert.Layout_tango;

import ocean.text.util.Time;

import ocean.util.container.map.Set;

import ocean.core.Traits;



/*******************************************************************************

    String struct serializer

    Template_Params:
        Char = character type of output string

*******************************************************************************/

public class StringStructSerializer ( Char )
{
    static assert ( isCharType!(Char), typeof(this).stringof ~ " - this class can only handle {char, wchar, dchar}, not " ~ Char.stringof );


    /***************************************************************************

        Indentation size

    ***************************************************************************/

    private const indent_size = 3;


    /***************************************************************************

        Indentation level string - filled with spaces.

    ***************************************************************************/

    private Char[] indent;


    /***************************************************************************

        format string for displaying an item of type floating point

    ***************************************************************************/

    private cstring fp_format;

    /***************************************************************************

        Known list of common timestamp field names

    ***************************************************************************/

    private StandardHashingSet!(cstring) known_timestamp_fields;

    /***************************************************************************

        Constructor, sets the maximum number of decimal digits to show for
        floating point types.

        Params:
            fp_dec_to_display = maximum number of decimal digits to show for
                                floating point types.

    ***************************************************************************/

    public this ( size_t fp_dec_to_display = 2 )
    {
        mstring tmp = "{}{} {} : {:.".dup;
        Format.format(tmp, "{}", fp_dec_to_display);
        tmp ~= "}\n";
        this.fp_format = tmp;
        this.known_timestamp_fields = new StandardHashingSet!(cstring)(128);
    }


    /***************************************************************************

        Convenience method to serialize a struct.

        If a field name of a struct matches one of the names in the
        timestamp_fields array and implicitly converts to `ulong`
        an ISO formatted string will be emitted in parentheses next to the
        value of the field (which is assumed to be a unix timestamp).

        Params:
            T                = type of item
            output           = string to serialize struct data to
            item             = item to append
            timestamp_fields = (optional) an array of timestamp field names

    ***************************************************************************/

    public void serialize ( T ) ( ref Char[] output, ref T item,
        cstring[] timestamp_fields = null )
    {
        this.known_timestamp_fields.clear();

        foreach (field_name; timestamp_fields)
        {
            this.known_timestamp_fields.put(field_name);
        }

        StructSerializer!(true).serialize(&item, this, output);
    }


    /***************************************************************************

        Called at the start of struct serialization - outputs the name of the
        top-level object.

        Params:
            output = string to serialize struct data to
            name = name of top-level object

    ***************************************************************************/

    public void open ( ref Char[] output, cstring name )
    {
        Layout!(Char).format(output, "{}struct {}:\n", this.indent, name);
        this.increaseIndent();
    }


    /***************************************************************************

        Called at the end of struct serialization

        Params:
            output = string to serialize struct data to
            name = name of top-level object

    ***************************************************************************/

    public void close ( ref Char[] output, cstring name )
    {
        this.decreaseIndent();
    }


    /***************************************************************************

        Appends a named item to the output string.

        Note: the main method to use from the outside is the first serialize()
        method above. This method is for the use of the StructSerializer.

        Template_Params:
            T = type of item

        Params:
            output = string to serialize struct data to
            item = item to append
            name = name of item

    ***************************************************************************/

    public void serialize ( T ) ( ref Char[] output, ref T item, cstring name )
    {
        // TODO: temporary support for unions by casting them to ubyte[]
        static if ( is(T == union) )
        {
            Layout!(Char).format(output, "{}union {} {} : {}\n", this.indent, T.stringof, name, (cast(ubyte*)&item)[0..item.sizeof]);
        }
        else static if ( isFloatingPointType!(T) )
        {
            Layout!(Char).format(output, this.fp_format, this.indent, T.stringof, name, item);
        }
        else
        {
            Layout!(Char).format(output, "{}{} {} : {}", this.indent,
                T.stringof, name, item);

            if (is(T : ulong) && name in this.known_timestamp_fields)
            {
                Char[20] tmp;
                Layout!(Char).format(output, " ({})\n", formatTime(item, tmp));
            }
            else
            {
                Layout!(Char).format(output, "\n");
            }
        }
    }


    /***************************************************************************

        Called before a sub-struct is serialized.

        Params:
            output = string to serialize struct data to
            name = name of struct item

    ***************************************************************************/

    public void openStruct ( ref Char[] output, cstring name )
    {
        Layout!(Char).format(output, "{}struct {}:\n", this.indent, name);
        this.increaseIndent();
    }


    /***************************************************************************

        Called after a sub-struct is serialized.

        Params:
            output = string to serialize struct data to
            name = name of struct item

    ***************************************************************************/

    public void closeStruct ( ref Char[] output, cstring name )
    {
        this.decreaseIndent();
    }


    /***************************************************************************

        Appends a named array to the output string

        Template_Params:
            T = base type of array

        Params:
            output = string to serialize struct data to
            array = array to append
            name = name of array item

    ***************************************************************************/

    public void serializeArray ( T ) ( ref Char[] output, cstring name, T[] array )
    {
        Layout!(Char).format(output, "{}{}[] {} (length {}):{}{}\n",
            this.indent, T.stringof, name, array.length,
            array.length ? " " : "", array);
    }


    /***************************************************************************

        Called before a struct array is serialized.

        Template_Params:
            T = base type of array

        Params:
            output = string to serialize struct data to
            name = name of struct item
            array = array to append

    ***************************************************************************/

    public void openStructArray ( T ) ( ref Char[] output, cstring name, T[] array )
    {
        Layout!(Char).format(output, "{}{}[] {} (length {}):\n", this.indent, T.stringof, name, array.length);
        this.increaseIndent();
    }


    /***************************************************************************

        Called after a struct array is serialized.

        Template_Params:
            T = base type of array

        Params:
            output = string to serialize struct data to
            name = name of struct item
            array = array to append

    ***************************************************************************/

    public void closeStructArray ( T ) ( ref Char[] output, cstring name, T[] array )
    {
        this.decreaseIndent();
    }


    /***************************************************************************

        Increases the indentation level.

    ***************************************************************************/

    private void increaseIndent ( )
    {
        this.indent.length = this.indent.length + indent_size;
        enableStomping(this.indent);
        this.indent[] = ' ';
    }


    /***************************************************************************

        Decreases the indentation level.

    ***************************************************************************/

    private void decreaseIndent ( )
    in
    {
        assert(this.indent.length >= indent_size, typeof(this).stringof ~ ".decreaseIndent - indentation cannot be decreased");
    }
    body
    {
        this.indent.length = this.indent.length - indent_size;
        enableStomping(this.indent);
        this.indent[] = ' ';
    }
}

version(UnitTest)
{
    import ocean.core.Test;
    import ocean.stdc.time;
}

unittest
{
    auto t = new NamedTest("struct serializer test");
    auto serializer = new StringStructSerializer!(char);

    struct TextFragment
    {
        char[] text;
        int type;
    }

    TextFragment text_fragment;
    text_fragment.text = "eins".dup;
    text_fragment.type = 1;

    char[] buffer;
    serializer.serialize(buffer, text_fragment);

    t.test(buffer.length == 69, "Incorrect string serializer result length");
    t.test(buffer == "struct TextFragment:\n"
                     "   char[] text (length 4): eins\n"
                     "   int type : 1\n",
        "Incorrect string serializer result");

    cstring[] timestamp_fields = ["lastseen", "timestamp", "update_time"];

    struct TextFragmentTime
    {
        char[] text;
        time_t time;        // not detected
        char[] lastseen;    // not detected (doesn't convert to ulong)
        time_t timestamp;   // detected
        time_t update_time; // detected
    }

    TextFragmentTime text_fragment_time;
    text_fragment_time.text = "eins".dup;
    text_fragment_time.time = 1456829726;

    buffer.length = 0;
    enableStomping(buffer);
    serializer.serialize(buffer, text_fragment_time, timestamp_fields);

    t.test(buffer.length == 204, "Incorrect string serializer result length");
    t.test(buffer == "struct TextFragmentTime:\n"
                     "   char[] text (length 4): eins\n"
                     "   long time : 1456829726\n"
                     "   char[] lastseen (length 0):\n"
                     "   long timestamp : 0 (1970-01-01 00:00:00)\n"
                     "   long update_time : 0 (1970-01-01 00:00:00)\n",
        "Incorrect string serializer result");

    buffer.length = 0;
    enableStomping(buffer);
    serializer.serialize(buffer, text_fragment_time);

    t.test(buffer.length == 160, "Incorrect string serializer result length");
    t.test(buffer == "struct TextFragmentTime:\n"
                     "   char[] text (length 4): eins\n"
                     "   long time : 1456829726\n"
                     "   char[] lastseen (length 0):\n"
                     "   long timestamp : 0\n"
                     "   long update_time : 0\n",
        "Incorrect string serializer result");

    struct MultiDimensionalArray
    {
        TextFragment[][] text_fragments;
    }

    MultiDimensionalArray multi_dimensional_array;
    multi_dimensional_array.text_fragments ~= [[TextFragment("eins".dup, 1)],
        [TextFragment("zwei".dup, 2), TextFragment("drei".dup, 3)]];

    buffer.length = 0;
    enableStomping(buffer);
    serializer.serialize(buffer, multi_dimensional_array);

    t.test(buffer.length == 461, "Incorrect string serializer result length");
    t.test(buffer == "struct MultiDimensionalArray:\n"
                     "   TextFragment[][] text_fragments (length 2):\n"
                     "      TextFragment[] text_fragments (length 1):\n"
                     "         struct TextFragment:\n"
                     "            char[] text (length 4): eins\n"
                     "            int type : 1\n"
                     "      TextFragment[] text_fragments (length 2):\n"
                     "         struct TextFragment:\n"
                     "            char[] text (length 4): zwei\n"
                     "            int type : 2\n"
                     "         struct TextFragment:\n"
                     "            char[] text (length 4): drei\n"
                     "            int type : 3\n",
        "Incorrect string serializer result");
}
