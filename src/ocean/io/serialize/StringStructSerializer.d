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
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.serialize.StringStructSerializer;




import ocean.transition;

import ocean.core.Array;

import ocean.io.serialize.StructSerializer;

import ocean.text.convert.Formatter;

import ocean.text.util.Time;

import ocean.util.container.map.Set;

import ocean.core.Exception;

import ocean.meta.traits.Basic;

/*******************************************************************************

    SerializerException

*******************************************************************************/

class SerializerException : Exception
{
    mixin ReusableExceptionImplementation!();
}

/*******************************************************************************

    Reusable exception instance.

*******************************************************************************/

private SerializerException serializer_exception;

static this ()
{
    .serializer_exception = new SerializerException();
}


/*******************************************************************************

    String struct serializer

    Params:
        Char = character type of output string

*******************************************************************************/

public class StringStructSerializer ( Char )
{
    static assert(isCharType!(Char), typeof(this).stringof ~
        " - this class can only handle {char, wchar, dchar}, not " ~
        Char.stringof);


    /***************************************************************************

        Indentation size

    ***************************************************************************/

    private static immutable indent_size = 3;


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

        Flag that is set to true if single character fields in structs should be
        serialized into equivalent friendly string representations (applicable
        only if these fields contain whitespace or other unprintable
        characters).
        e.g. the newline character will be serialized to the string '\n' instead
        of to an actual new line.

    ***************************************************************************/

    private bool turn_ws_char_to_str;


    /***************************************************************************

        Temporary formatting buffer.

    ***************************************************************************/

    private mstring buf;


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
        sformat(tmp, "{}", fp_dec_to_display);
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
            turn_ws_char_to_str = true if individual whitespace or unprintable
                character fields should be serialized into a friendlier string
                representation, e.g. tab character into '\t' (defaults to false)

    ***************************************************************************/

    public void serialize ( T ) ( ref Char[] output, ref T item,
        cstring[] timestamp_fields = null, bool turn_ws_char_to_str = false )
    {
        this.turn_ws_char_to_str = turn_ws_char_to_str;

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
        .serializer_exception.enforce(this.indent.length == 0,
                "Non-zero indentation in open");

        sformat(output, "struct {}:\n", name);
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

        Params:
            T = type of item
            output = string to serialize struct data to
            item = item to append
            name = name of item

    ***************************************************************************/

    public void serialize ( T ) ( ref Char[] output, ref T item, cstring name )
    {
        .serializer_exception.enforce(this.indent.length > 0,
                "Incorrect indentation in serialize");

        // TODO: temporary support for unions by casting them to ubyte[]
        static if ( is(T == union) )
        {
            sformat(output, "{}union {} {} : {}\n", this.indent, T.stringof,
                name, (cast(ubyte*)&item)[0..item.sizeof]);
        }
        else static if ( isFloatingPointType!(T) )
        {
            sformat(output, this.fp_format, this.indent, T.stringof, name,
                item);
        }
        else static if ( is(T == char) )
        {
            // Individual character fields are handled in a special manner so
            // that friendly string representations can be generated for them if
            // necessary

            sformat(output, "{}{} {} : {}\n", this.indent, T.stringof, name,
                this.getCharAsString(item));
        }
        else
        {
            sformat(output, "{}{} {} : {}", this.indent, T.stringof, name,
                item);

            if ( is(T : ulong) && name in this.known_timestamp_fields )
            {
                Char[20] tmp;
                sformat(output, " ({})\n", formatTime(item, tmp));
            }
            else
            {
                sformat(output, "\n");
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
        .serializer_exception.enforce(this.indent.length > 0,
                "Incorrect indentation in openStruct");

        sformat(output, "{}struct {}:\n", this.indent, name);
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

        Params:
            T = base type of array
            output = string to serialize struct data to
            array = array to append
            name = name of array item

    ***************************************************************************/

    public void serializeArray ( T ) ( ref Char[] output, cstring name,
        T[] array )
    {
        .serializer_exception.enforce(this.indent.length > 0,
            "Incorrect indentation in serializeArray");

        sformat(output, "{}{}[] {} (length {}):", this.indent, T.stringof, name,
            array.length);

        if ( array.length )
        {
            sformat(output, " {}", array);
        }
        else
        {
            static if ( isCharType!(T) )
            {
                sformat(output, ` ""`);
            }
            else
            {
                sformat(output, " []");
            }
        }

        sformat(output, "\n");
    }


    /***************************************************************************

        Called before a struct array is serialized.

        Params:
            T = base type of array
            output = string to serialize struct data to
            name = name of struct item
            array = array to append

    ***************************************************************************/

    public void openStructArray ( T ) ( ref Char[] output, cstring name,
        T[] array )
    {
        .serializer_exception.enforce(this.indent.length > 0,
            "Incorrect indentation in openStructArray");

        sformat(output, "{}{}[] {} (length {}):\n", this.indent, T.stringof,
            name, array.length);
        this.increaseIndent();
    }


    /***************************************************************************

        Called after a struct array is serialized.

        Params:
            T = base type of array
            output = string to serialize struct data to
            name = name of struct item
            array = array to append

    ***************************************************************************/

    public void closeStructArray ( T ) ( ref Char[] output, cstring name,
        T[] array )
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
    {
        .serializer_exception.enforce(this.indent.length >= indent_size,
                typeof(this).stringof ~ ".decreaseIndent - indentation cannot be decreased");

        this.indent.length = this.indent.length - indent_size;
        enableStomping(this.indent);
    }


    /***************************************************************************

        Gets the string equivalent of a character. For most characters, the
        string contains just the character itself; but in case of whitespace or
        other unprintable characters, a friendlier string representation is
        generated (provided the flag requesting this generation has been set).
        For example, the string '\n' will be generated for the newline
        character, '\t' for the tab character and so on.

        Params:
            c = character whose string equivalent is to be got

        Returns:
            string equivalent of the character

    ***************************************************************************/

    private mstring getCharAsString ( char c )
    {
        this.buf.length = 0;
        enableStomping(this.buf);

        if ( !this.turn_ws_char_to_str )
        {
            sformat(this.buf, "{}", c);
            return this.buf;
        }

        // The set of characters to use for creating cases within the following
        // switch block. These are just whitepace or unprintable characters but
        // without their preceding backslashes.
        static immutable letters = ['0', 'a', 'b', 'f', 'n', 'r', 't', 'v'];

        switch ( c )
        {
            case c.init:
                sformat(this.buf, "{}", "''");
                break;

            mixin(ctfeCreateCases(letters));

            default:
                sformat(this.buf, "{}", c);
                break;
        }

        return this.buf;
    }


    /***************************************************************************

        Creates a string containing all the necessary case statements to be
        mixed-in into the switch block that generates friendly string
        representations of whitespace or unprintable characters. This function
        is evaluated at compile-time.

        Params:
            letters = string containing all the characters corresponding to the
                various case statements

        Returns:
            string containing all case statements to be mixed-in

    ***************************************************************************/

    private static istring ctfeCreateCases ( istring letters )
    {
        istring mixin_str;

        foreach ( c; letters )
        {
            mixin_str ~=
                `case '\` ~ c ~ `':` ~
                    `sformat(this.buf, "{}", "'\\` ~ c ~ `'");` ~
                    `break;`;
        }

        return mixin_str;
    }
}

version(UnitTest)
{
    import ocean.core.Test;
    import core.stdc.time;
}

unittest
{
    // empty struct

    auto serializer = new StringStructSerializer!(char);
    mstring buffer;

    struct EmptyStruct
    {
    }

    EmptyStruct e;

    serializer.serialize(buffer, e);

    test!("==")(buffer.length, 20);
    test!("==")(buffer, "struct EmptyStruct:\n");
}

unittest
{
    // regular arbitrary struct

    auto serializer = new StringStructSerializer!(char);
    mstring buffer;

    struct TextFragment
    {
        char[] text;
        int type;
    }

    TextFragment text_fragment;
    text_fragment.text = "eins".dup;
    text_fragment.type = 1;

    serializer.serialize(buffer, text_fragment);

    test!("==")(buffer.length, 69);
    test!("==")(buffer, "struct TextFragment:\n" ~
                     "   char[] text (length 4): eins\n" ~
                     "   int type : 1\n");
}

unittest
{
    // struct with timestamp fields

    auto serializer = new StringStructSerializer!(char);
    mstring buffer;
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

    serializer.serialize(buffer, text_fragment_time, timestamp_fields);

    test!("==")(buffer.length, 207);
    test!("==")(buffer, "struct TextFragmentTime:\n" ~
                     "   char[] text (length 4): eins\n" ~
                     "   long time : 1456829726\n" ~
                     `   char[] lastseen (length 0): ""` ~ "\n" ~
                     "   long timestamp : 0 (1970-01-01 00:00:00)\n" ~
                     "   long update_time : 0 (1970-01-01 00:00:00)\n");

    buffer.length = 0;
    enableStomping(buffer);
    serializer.serialize(buffer, text_fragment_time);

    test!("==")(buffer.length, 163);
    test!("==")(buffer, "struct TextFragmentTime:\n" ~
                     "   char[] text (length 4): eins\n" ~
                     "   long time : 1456829726\n" ~
                     `   char[] lastseen (length 0): ""` ~ "\n" ~
                     "   long timestamp : 0\n" ~
                     "   long update_time : 0\n");
}

unittest
{
    // struct with multi-dimensional array field

    auto serializer = new StringStructSerializer!(char);
    mstring buffer;

    struct TextFragment
    {
        char[] text;
        int type;
    }

    struct MultiDimensionalArray
    {
        TextFragment[][] text_fragments;
    }

    MultiDimensionalArray multi_dimensional_array;
    multi_dimensional_array.text_fragments ~= [[TextFragment("eins".dup, 1)],
        [TextFragment("zwei".dup, 2), TextFragment("drei".dup, 3)]];

    serializer.serialize(buffer, multi_dimensional_array);

    test!("==")(buffer.length, 461);
    test!("==")(buffer, "struct MultiDimensionalArray:\n" ~
                     "   TextFragment[][] text_fragments (length 2):\n" ~
                     "      TextFragment[] text_fragments (length 1):\n" ~
                     "         struct TextFragment:\n" ~
                     "            char[] text (length 4): eins\n" ~
                     "            int type : 1\n" ~
                     "      TextFragment[] text_fragments (length 2):\n" ~
                     "         struct TextFragment:\n" ~
                     "            char[] text (length 4): zwei\n" ~
                     "            int type : 2\n" ~
                     "         struct TextFragment:\n" ~
                     "            char[] text (length 4): drei\n" ~
                     "            int type : 3\n");
}

unittest
{
    // struct with nested struct field

    auto serializer = new StringStructSerializer!(char);
    mstring buffer;

    struct OuterStruct
    {
        int outer_a;
        struct InnerStruct
        {
            int inner_a;
        }
        InnerStruct s;
    }

    OuterStruct s;
    s.outer_a = 100;
    s.s.inner_a = 200;

    serializer.serialize(buffer, s);

    test!("==")(buffer.length, 78);
    test!("==")(buffer, "struct OuterStruct:\n" ~
                     "   int outer_a : 100\n" ~
                     "   struct s:\n" ~
                     "      int inner_a : 200\n");
}

unittest
{
    // struct with floating point fields

    auto serializer = new StringStructSerializer!(char);
    mstring buffer;

    struct StructWithFloatingPoints
    {
        float a;
        double b;
        real c;
    }

    StructWithFloatingPoints sf;
    sf.a = 10.00;
    sf.b = 23.42;

    serializer.serialize(buffer, sf);

    test!("==")(buffer.length, 85);
    test!("==")(buffer, "struct StructWithFloatingPoints:\n" ~
                     "   float a : 10\n" ~
                     "   double b : 23.42\n" ~
                     "   real c : nan\n");
}

unittest
{
    // struct with nested union field

    auto serializer = new StringStructSerializer!(char);
    mstring buffer;

    struct StructWithUnion
    {
        union U
        {
            int a;
            char b;
            double c;
        }

        U u;
    }

    StructWithUnion su;
    su.u.a = 100;

    serializer.serialize(buffer, su);

    test!("==")(buffer.length, 66);
    test!("==")(buffer, "struct StructWithUnion:\n" ~
                     "   union U u : [100, 0, 0, 0, 0, 0, 0, 0]\n");

    su.u.b = 'a';

    buffer.length = 0;
    enableStomping(buffer);
    serializer.serialize(buffer, su);

    test!("==")(buffer.length, 65);
    test!("==")(buffer, "struct StructWithUnion:\n" ~
                     "   union U u : [97, 0, 0, 0, 0, 0, 0, 0]\n");
}

unittest
{
    // struct with individual char fields

    auto serializer = new StringStructSerializer!(char);
    mstring buffer;

    struct StructWithChars
    {
        char c0;
        char c1;
        char c2;
        char c3;
        char c4;
        char c5;
        char c6;
        char c7;
        char c8;
        char c9;
    }

    StructWithChars sc;
    sc.c0 = 'g';
    sc.c1 = 'k';
    sc.c2 = '\0';
    sc.c3 = '\a';
    sc.c4 = '\b';
    sc.c5 = '\f';
    sc.c6 = '\n';
    sc.c7 = '\r';
    sc.c8 = '\t';
    sc.c9 = '\v';

    // Generation of friendly string representations of characters disabled
    serializer.serialize(buffer, sc);

    test!("==")(buffer.length, 174);
    test!("==")(buffer, "struct StructWithChars:\n" ~
                     "   char c0 : g\n" ~
                     "   char c1 : k\n" ~
                     "   char c2 : \0\n" ~
                     "   char c3 : \a\n" ~
                     "   char c4 : \b\n" ~
                     "   char c5 : \f\n" ~
                     "   char c6 : \n\n" ~
                     "   char c7 : \r\n" ~
                     "   char c8 : \t\n" ~
                     "   char c9 : \v\n");

    // Generation of friendly string representations of characters enabled
    buffer.length = 0;
    enableStomping(buffer);
    serializer.serialize(buffer, sc, [""], true);

    test!("==")(buffer.length, 198);
    test!("==")(buffer, "struct StructWithChars:\n" ~
                     "   char c0 : g\n" ~
                     "   char c1 : k\n" ~
                     "   char c2 : '\\0'\n" ~
                     "   char c3 : '\\a'\n" ~
                     "   char c4 : '\\b'\n" ~
                     "   char c5 : '\\f'\n" ~
                     "   char c6 : '\\n'\n" ~
                     "   char c7 : '\\r'\n" ~
                     "   char c8 : '\\t'\n" ~
                     "   char c9 : '\\v'\n");
}

unittest
{
    // struct with regular int arrays

    auto serializer = new StringStructSerializer!(char);
    mstring buffer;

    struct StructWithIntArrays
    {
        int[] a;
        int[] b;
    }

    StructWithIntArrays sia;
    sia.a = [10, 20, 30];

    serializer.serialize(buffer, sia);

    test!("==")(buffer.length, 90);
    test!("==")(buffer, "struct StructWithIntArrays:\n" ~
                     "   int[] a (length 3): [10, 20, 30]\n" ~
                     "   int[] b (length 0): []\n");
}

unittest
{
    // struct with individual typedef field

    auto serializer = new StringStructSerializer!(char);
    mstring buffer;

    mixin(Typedef!(hash_t, "AdskilletId"));

    struct StructWithTypedef
    {
        AdskilletId a;
    }

    StructWithTypedef st;
    st.a = cast(AdskilletId)1000;

    serializer.serialize(buffer, st);

    version (D_Version2)
    {
        test!("==")(buffer.length, 50);
        test!("==")(buffer, "struct StructWithTypedef:\n" ~
                         "   AdskilletId a : 1000\n");
    }
    else
    {
        test!("==")(buffer.length, 44);
        test!("==")(buffer, "struct StructWithTypedef:\n" ~
                         "   ulong a : 1000\n");
    }
}

unittest
{
    // struct with array of typedefs

    auto serializer = new StringStructSerializer!(char);
    mstring buffer;

    mixin(Typedef!(hash_t, "AdskilletId"));

    struct StructWithTypedefArray
    {
        AdskilletId[] ids;
    }

    StructWithTypedefArray sta;

    sta.ids = new AdskilletId[](4);

    foreach (idx, ref element; sta.ids)
    {
        element = cast(AdskilletId)(64 + idx);
    }

    serializer.serialize(buffer, sta);

    test!("==")(buffer, "struct StructWithTypedefArray:\n" ~
                     "   AdskilletId[] ids (length 4): [64, 65, 66, 67]\n");
}
