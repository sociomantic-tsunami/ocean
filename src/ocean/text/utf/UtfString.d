/*******************************************************************************

    Struct template to iterate over strings in variable encoding format (utf8,
    utf16, utf32), extracting one unicode character at a time. Each unicode
    character may be represented by one or more character in the input string,
    depending on the encoding format.

    The struct takes a template parameter (pull_dchars) which determines
    whether its methods return unicode characters (utf32 - dchars) or characters
    in the same format as the source string.

    The template also has an index operator, to extract the nth unicode
    character in the string, and methods and static methods for extracting
    single characters from a string of variable encoding.

    Example usage:

    ---

        import ocean.text.utf.UtfString;

        char[] test = "test string";
        UtfString!(char) utfstr = { test };

        foreach ( width, i, c; utfstr )
        {
            Stdout.formatln("Character {} is {} and it's {} wide", i, c, width);
        }

    ---

    There is also a utf_match function in the module, which compares two strings
    for equivalence, irrespective of whether they're in the same encoding or
    not.

    Example:

    ---

        import ocean.text.utf.UtfString;

        char[] str1 = "hello world ®"; // utf8 encoding
        dchar[] str2 = "hello world ®"; // utf32 encoding

        assert(utf_match(str1, str2));

    ---

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.text.utf.UtfString;



/*******************************************************************************

    Imports

*******************************************************************************/

import Utf = ocean.text.convert.Utf;

import ocean.transition;


/*******************************************************************************

    Invalid unicode.

*******************************************************************************/

public const dchar InvalidUnicode = cast(dchar)0xffffffff;



/*******************************************************************************

    Encoding agnostic string compare function.

    Template_Params:
        Char1 = character type of first string to compare
        Char2 = character type of second string to compare

    Params:
        str1 = first string to compare
        str2 = second string to compare

    Returns:
        true if the strings contain the same unicode characters

*******************************************************************************/

bool utf_match ( Char1, Char2 ) ( Char1[] str1, Char2[] str2 )
{
    static if ( is(Char1 == Char2) )
    {
        return str1 == str2;
    }
    else
    {
        if ( (str1.length == 0 || str2.length == 0) && str1.length != str2.length )
        {
            return false;
        }
        UtfString!(Char1, true) utf_str1 = { str1 };
        UtfString!(Char2, true) utf_str2 = { str2 };

        foreach ( c1; utf_str1 )
        {
            auto c2 = utf_str2.extract(true);

            if ( c1 != c2 )
            {
                return false;
            }
        }

        return true;
    }
}



/*******************************************************************************

    UtfString template struct

    Template_Params:
        Char = type of strings to process
        pull_dchars = determines the output type of the struct's methods. If
            true they will all output dchars (ie unicode / utf32 characters),
            otherwise they output slices of the input string, containing the
            characters representing a single unicode character.

*******************************************************************************/

public struct UtfString ( Char = char, bool pull_dchars = false )
{
    /***************************************************************************

        Check the parameter type of this class.

    ***************************************************************************/

    static assert(
        is(Unqual!(Char) == char)
            || is(Unqual!(Char) == wchar)
            || is(Unqual!(Char) == dchar),
        This.stringof ~ " template parameter Char must be one of {char, wchar, dchar}, not " ~ Char.stringof
    );

    /***************************************************************************

        This alias.

    ***************************************************************************/

    public alias typeof(this) This;


    /***************************************************************************

        String to iterate over.

    ***************************************************************************/

    public Char[] string;


    /***************************************************************************

        Output type alias.

    ***************************************************************************/

    static if ( pull_dchars )
    {
        public alias dchar OutType;
        public alias dchar[] ArrayOutType;
    }
    else
    {
        public alias Char[] OutType;
        public alias Char[] ArrayOutType;
    }


    /***************************************************************************

        Internal buffer, used by the slice operator.

    ***************************************************************************/

    private ArrayOutType slice_string;


    /***************************************************************************

        foreach iterator.

        Exposes the following foreach parameters:
            size_t width = number of input characters for this unicode character
            size_t i = current index into the input string
            OutType c = the next unicode character in the string

    ***************************************************************************/

    public int opApply ( int delegate ( ref size_t, ref size_t, ref OutType ) dg )
    {
        int res;
        size_t i;

        while ( i < this.string.length )
        {
            Char[] process = this.string[i..$];

            size_t width;
            auto c = This.extract(process, width);

            res = dg(width, i, c);
            if ( res )
            {
                break;
            }

            i += width;
        }

        return res;
    }


    /***************************************************************************

        foreach iterator.

        Exposes the following foreach parameters:
            size_t i = current index into the input string
            OutType c = the next unicode character in the string

    ***************************************************************************/

    public int opApply ( int delegate ( ref size_t, ref OutType ) dg )
    {
        int res;
        size_t i;

        while ( i < this.string.length )
        {
            Char[] process = this.string[i..$];

            size_t width;
            auto c = This.extract(process, width);

            res = dg(i, c);
            if ( res )
            {
                break;
            }

            i += width;
        }

        return res;
    }


    /***************************************************************************

        foreach iterator.

        Exposes the following foreach parameters:
            OutType c = the next unicode character in the string

    ***************************************************************************/

    public int opApply ( int delegate ( ref OutType ) dg )
    {
        int res;
        size_t i;

        while ( i < this.string.length )
        {
            Char[] process = this.string[i..$];

            size_t width;
            auto c = This.extract(process, width);

            res = dg(c);
            if ( res )
            {
                break;
            }

            i += width;
        }

        return res;
    }


    /***************************************************************************

        opIndex. Extracts the nth unicode character from the referenced string.

        Params:
            index = index of character to extract

        Returns:
            the extracted character, either as a dchar or a slice into the input
            string (depending on the pull_dchars template parameter).

    ***************************************************************************/

    public OutType opIndex ( size_t index )
    in
    {
        assert(this.string.length, This.stringof ~ ".opIndex - attempted to index into an empty string");
    }
    body
    {
        size_t i;
        size_t count;
        OutType c;
        do
        {
            size_t width;
            c = This.extract(this.string[i..$], width);
            i += width;
        } while ( count++ < index );

        return c;
    }


    /***************************************************************************

        opSlice. Extracts an indexed sequence of unicode characters from the
        referenced string.

        For dchar output, the returned slice is built up in the internal
        slice_string member. Otherwise a slice into the referenced string is
        returned.

        Params:
            start = index of first character to extract
            end = index of last character to extract

        Returns:
            the sliced characters (either as dchars or as the same type as the
            referenced string).

    ***************************************************************************/

    public ArrayOutType opSlice ( size_t start, size_t end )
    in
    {
        assert(end > start, typeof(this).stringof ~ ".opSlice - end <= start!");
    }
    body
    {
        static if ( pull_dchars )
        {
            return this.sliceCopy(start, end, this.slice_string);
        }
        else
        {
            size_t start_i;
            size_t char_count;
            size_t src_i;

            while ( src_i < this.string.length )
            {
                if ( char_count == start )
                {
                    start_i = src_i;
                }
                if ( char_count >= end )
                {
                    return this.string[start_i .. src_i];
                }

                Char[] process = this.string[src_i..$];

                size_t width;
                This.extract(process, width);

                src_i += width;
                char_count++;
            }

            assert(false, typeof(this).stringof ~ ".opSlice - end > array length");
        }
    }


    /***************************************************************************

        Slice / copy. Extracts an indexed sequence of unicode characters from
        the referenced string and copies them into the provided buffer.

        The returned slice is built up in the passed string.

        Params:
            start = index of first character to extract
            end = index of last character to extract
            output = string into which the sliced characters are placed

        Returns:
            the sliced characters (either as dchars or as the same type as the
            referenced string).

    ***************************************************************************/

    public ArrayOutType sliceCopy ( size_t start, size_t end, ref ArrayOutType output )
    {
        output.length = 0;

        size_t i;
        foreach ( c; *this )
        {
            if ( i >= start )
            {
                output ~= c;
            }

            if ( ++i >= end )
            {
                break;
            }
        }

        return output;
    }


    /***************************************************************************

        Calculates the number of unicode characters in the referenced string.
        The calculation requires that the whole string is iterated over.

        Returns:
            number of unicode characters in the string

    ***************************************************************************/

    public size_t length ( )
    {
        size_t len;

        foreach ( c; *this )
        {
            len++;
        }

        return len;
    }


    /***************************************************************************

        Extract the next character from the referenced string.

        Params:
            consume = if true, the extracted characters are removed from the
                string (the start of the slice is advanced)

        Returns:
            the extracted character, either as a dchar or a slice into the input
            string (depending on the pull_dchars template parameter).

    ***************************************************************************/

    public OutType extract ( bool consume = false )
    {
        size_t width;
        return this.extract(width, consume);
    }


    /***************************************************************************

        Extract the next character from the referenced string.

        Params:
            width = outputs the width (in terms of the number of characters in
                the input string) of the extracted character
            consume = if true, the extracted characters are removed from the
                string (the start of the slice is advanced)

        Returns:
            the extracted character, either as a dchar or a slice into the input
            string (depending on the pull_dchars template parameter).

    ***************************************************************************/

    public OutType extract ( out size_t width, bool consume = false )
    {
        auto extracted = This.extract(this.string, width);
        if ( consume )
        {
            this.string = this.string[width..$];
        }

        return extracted;
    }


    /***************************************************************************

        Static method to extract the next character from the passed string.

        Params:
            text = string to extract from

        Returns:
            the extracted character, either as a dchar or a slice into the input
            string (depending on the pull_dchars template parameter).

    ***************************************************************************/

    public static OutType extract ( Char[] text )
    {
        size_t width;
        return This.extract(text, width);
    }


    /***************************************************************************

        Static method to extract the next character from the passed string.

        Params:
            text = string to extract from
            width = outputs the width (in terms of the number of characters in
                the input string) of the extracted character

        Returns:
            the extracted character, either as a dchar or a slice into the input
            string (depending on the pull_dchars template parameter).

    ***************************************************************************/

    static if ( pull_dchars )
    {
        public static OutType extract ( Char[] text, out size_t width )
        {
            if ( !text.length )
            {
                return InvalidUnicode;
            }

            static if ( is(Unqual!(Char) == dchar) )
            {
                width = 1;
                return text[0];
            }
            else
            {
                dchar unicode = Utf.decode(text, width);
                return unicode;
            }
        }
    }
    else
    {
        public static OutType extract ( Char[] text, out size_t width )
        {
            if ( !text.length )
            {
                return "";
            }

            static if ( is(Unqual!(Char) == dchar) )
            {
                width = 1;
            }
            else
            {
                dchar unicode = Utf.decode(text, width);
            }

            return text[0..width];
        }
    }
}


unittest
{
    istring str1 = "hello world ®"; // utf8 encoding
    Const!(dchar)[] str2 = "hello world ®"; // utf32 encoding

    assert(utf_match(str1, str2));
}
