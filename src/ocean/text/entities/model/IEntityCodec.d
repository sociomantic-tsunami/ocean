/*******************************************************************************

    An abstract class template representing an entity de/coder, over a specific
    set of entities.

    The class has various abstract methods, which must be implemented, to decode
    and encode strings.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.text.entities.model.IEntityCodec;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.text.entities.model.IEntitySet;

import Utf = ocean.text.convert.Utf;

import ocean.transition;

/*******************************************************************************

    Abstract entity codec template class. Provides

    Template_Params:
        E = entity set the codec deals with

*******************************************************************************/

public abstract class IEntityCodec ( E : IEntitySet )
{
    /***************************************************************************

        Abstract methods to encode any unencoded entities in a string.

        (Unfortunately template methods can't be abstract.)

    ***************************************************************************/

    public abstract char[]  encode ( Const!(char)[]  text, ref char[] encoded );
    public abstract wchar[] encode ( Const!(wchar)[] text, ref wchar[] encoded );
    public abstract dchar[] encode ( Const!(dchar)[] text, ref dchar[] encoded );


    /***************************************************************************

        Abstract methods to decode any encoded entities in a string.

        (Unfortunately template methods can't be abstract.)

    ***************************************************************************/

    public abstract char[] decode  ( Const!(char)[]  text, ref char[] decoded );
    public abstract wchar[] decode ( Const!(wchar)[] text, ref wchar[] decoded );
    public abstract dchar[] decode ( Const!(dchar)[] text, ref dchar[] decoded );


    /***************************************************************************

        Abstract methods to tell whether a string contains any unencoded
        entities.

        (Unfortunately template methods can't be abstract.)

    ***************************************************************************/

    public abstract bool containsUnencoded ( Const!(char)[]  text );
    public abstract bool containsUnencoded ( Const!(wchar)[] text );
    public abstract bool containsUnencoded ( Const!(dchar)[] text );


    /***************************************************************************

        Abstract methods to tell whether a string contains any encoded entities.

        (Unfortunately template methods can't be abstract.)

    ***************************************************************************/

    public abstract bool containsEncoded ( Const!(char)[]  text );
    public abstract bool containsEncoded ( Const!(wchar)[] text );
    public abstract bool containsEncoded ( Const!(dchar)[] text );


    /***************************************************************************

        Internal entity set

    ***************************************************************************/

    protected E entities;


    /***************************************************************************

        Constructor.

    ***************************************************************************/

    public this ( )
    {
        this.entities = new E();
    }


    /***************************************************************************

        Tells whether a string is fully encoded (ie contains no unencoded
        entities).

        Params:
            text = string to check

        Returns:
            true if there are no unencoded entities in the string

    ***************************************************************************/

    public bool encoded ( Char ) ( Char[] text )
    {
        return !this.unencoded();
    }


    /***************************************************************************

        Tells whether a string is unencoded (ie contains one or more unencoded
        entities).

        Params:
            text = string to check

        Returns:
            true if there are unencoded entities in the string

    ***************************************************************************/

    public bool unencoded ( Char ) ( Char[] text )
    {
        return this.containsUnencoded(text);
    }


    /***************************************************************************

        Static template method to convert from a char to another type.

        Template_Params:
            Char = type to convert to

        Params:
            c = character to convert

        Returns:
            converted character

    ***************************************************************************/

    protected static Char[] charTo ( Char ) ( char c )
    {
        char[1] str;
        str[0] = c;
        return this.charTo!(Char)(str);
    }


    /***************************************************************************

        Static template method to convert from a char[] to another type.

        Template_Params:
            Char = type to convert to

        Params:
            text = string to convert
            output = buffer to write the output to

        Returns:
            converted string

    ***************************************************************************/

    protected static Char[] charTo ( Char ) ( char[] text, ref Char[] output )
    {
        output.length = text.length;
        enableStomping(output);

        static if ( is(Char == dchar) )
        {
            return Utf.toString32(text, output);
        }
        else static if ( is(Char == wchar) )
        {
            return Utf.toString16(text, output);
        }
        else static if ( is(Char == char) )
        {
            return text;
        }
        else
        {
            static assert(false, This.stringof ~ ".charTo - template parameter must be one of {char, wchar, dchar}");
        }
    }


    /***************************************************************************

        Static template method to convert from a dchar to another type.

        Template_Params:
            Char = type to convert to

        Params:
            c = character to convert
            output = buffer to write the output to

        Returns:
            converted character

    ***************************************************************************/

    protected static Char[] dcharTo ( Char ) ( dchar c, ref Char[] output )
    {
        dchar[1] str;
        str[0] = c;
        return this.dcharTo!(Char)(str, output);
    }

    /***************************************************************************

        Static template method to convert from a dchar[] to another type.

        Template_Params:
            Char = type to convert to

        Params:
            text = string to convert
            output = buffer to write the output to

        Returns:
            converted string

    ***************************************************************************/

    protected static Char[] dcharTo ( Char ) ( dchar[] text, ref Char[] output )
    {
        output.length = text.length * 4; // Maximum one unicode character -> 4 bytes
        enableStomping(output);

        static if ( is(Char == dchar) )
        {
            output[0..text.length] = text[];

            return output[0..text.length];
        }
        else static if ( is(Char == wchar) )
        {
            return Utf.toString16(text, output);
        }
        else static if ( is(Char == char) )
        {
            return Utf.toString(text, output);
        }
        else
        {
            static assert(false, This.stringof ~ ".charTo - template parameter must be one of {char, wchar, dchar}");
        }
    }
}

