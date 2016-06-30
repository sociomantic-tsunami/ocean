/*******************************************************************************

    Iterating JSON parser

    Extends Tango's JsonParser by iteration and token classification facilities.

    Includes methods to extract the values of named entities.

    Usage example:
        See unittests following this class.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.text.json.JsonParserIter;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.text.json.JsonParser;

import ocean.core.Enforce;
import ocean.core.Traits;

import Integer = ocean.text.convert.Integer_tango;

import Float = ocean.text.convert.Float;

version (UnitTest)
{
    import ocean.core.Test;
}


/******************************************************************************/

class JsonParserIter(bool AllowNaN = false) : JsonParser!(char, AllowNaN)
{
    /**************************************************************************

        Import the Token enum into this namespace

     **************************************************************************/

    public alias typeof (super).Token Token;

    /**************************************************************************

        TokenClass enum
        "Other" is for tokens that stand for themselves

     **************************************************************************/

    public enum TokenClass
    {
        Other = 0,
        ValueType,
        Container,
    }

    /**************************************************************************

        Token type descriptions

     **************************************************************************/

    public static istring[Token.max + 1] type_description = [
        Token.Empty:        "Empty",
        Token.Name:         "Name",
        Token.String:       "String",
        Token.Number:       "Number",
        Token.BeginObject:  "BeginObject",
        Token.EndObject:    "EndObject",
        Token.BeginArray:   "BeginArray",
        Token.EndArray:     "EndArray",
        Token.True:         "True",
        Token.False:        "False",
        Token.Null:         "Null",
        Token.NaN:          "NaN",
        Token.Infinity:     "Inf",
        Token.NegInfinity:  "-Inf"
    ];


    /**************************************************************************

        Token to TokenClass association

     **************************************************************************/

    public const TokenClass[Token.max + 1] token_classes =
    [
        Token.Empty:       TokenClass.Other,
        Token.Name:        TokenClass.Other,
        Token.String:      TokenClass.ValueType,
        Token.Number:      TokenClass.ValueType,
        Token.True:        TokenClass.ValueType,
        Token.False:       TokenClass.ValueType,
        Token.Null:        TokenClass.ValueType,
        Token.NaN:         TokenClass.ValueType,
        Token.Infinity:    TokenClass.ValueType,
        Token.NegInfinity: TokenClass.ValueType,
        Token.BeginObject: TokenClass.Container,
        Token.BeginArray:  TokenClass.Container,
        Token.EndObject:   TokenClass.Container,
        Token.EndArray:    TokenClass.Container
    ];

    /**************************************************************************

        Token nesting difference values

     **************************************************************************/

    public const int[Token.max + 1] nestings =
    [
        Token.BeginObject: +1,
        Token.BeginArray:  +1,
        Token.EndObject:   -1,
        Token.EndArray:    -1
    ];

    /**************************************************************************

        Returns the nesting level difference caused by the current token.

        Returns:
            +1 if the current token is BeginObject or BeginArray,
            -1 if the current token is EndObject or EndArray,
             0 otherwise

     **************************************************************************/

    public int nesting ( )
    {
        return this.nestings[super.type];
    }

    /**************************************************************************

        Returns:
            the token class to which the current token (super.type()) belongs to

     **************************************************************************/

    public TokenClass token_class ( )
    {
        return this.token_classes[super.type];
    }

    /**************************************************************************

        Steps to the next token in the current JSON content.

        Returns:
            type of next token or Token.Empty if there is no next one

     **************************************************************************/

    public Token nextType ( )
    {
        return super.next()? super.type : Token.Empty;
    }

    /**************************************************************************

        Resets the instance and sets the input content (convenience wrapper for
        super.reset()).

        Params:
            content = new JSON input content to parse

        Returns:
            this instance

     **************************************************************************/

    public typeof (this) opCall ( cstring content )
    {
        super.reset(content);

        return this;
    }

    /**************************************************************************

        'foreach' iteration over type/value pairs in the current content

     **************************************************************************/

    public int opApply ( int delegate ( ref Token type, ref cstring value ) dg )
    {
        int result = 0;

        do
        {
            Token  type  = super.type;
            cstring value = super.value;

            result = dg(type, value);
        }
        while (!result && super.next());

        return result;
    }


    /**************************************************************************

        'foreach' iteration over type/name/value triples in the current content.

        For unnamed members name will be null.

     **************************************************************************/

    public int opApply ( int delegate ( ref Token type, ref cstring name,
        ref cstring value ) dg )
    {
        int result = 0;

        cstring name = null;

        do
        {
            Token type = super.type;

            auto value = super.value;

            if (type == Token.Name)
            {
                name = value;
            }
            else
            {
                result = dg(type, name, value);
                name = null;
            }
        }
        while (!result && super.next());

        return result;
    }

    /**************************************************************************

        Skips the current member so that the next member is reached by a next()
        call or in the next 'foreach' iteration cycle.
        That is,
            - if the current token denotes an object or array beginning,
              to the corresponding object/array end token,
            - if the current token is a name, steps over the name,
            - if the current member is a value, does nothing.

        Returns:
            0 on success or, if the contend ends before the skip destination
            was reached,
            - the object nesting level if an object was skipped,
            - the array nesting level if an array was skipped,
            - 1 if a name was skipped and the contend ends just after that name.

     **************************************************************************/

    public uint skip ( )
    {
        Token start_type, end_type;

        switch (start_type = super.type)
        {
            case Token.BeginObject:
                end_type = Token.EndObject;
                break;

            case Token.BeginArray:
                end_type = Token.EndArray;
                break;

            case Token.Name:
                return !super.next();
                                                                                // fall through
            default:
                return 0;
        }

        uint nesting = 1;

        for (bool more = super.next(); more; more = super.next())
        {
            Token type = super.type;

            nesting += type == start_type;
            nesting -= type == end_type;

            if (!nesting) break;
        }

        return nesting;
    }

    /**************************************************************************

        Iterates over the json string looking for the named object and
        halting iteration if it is found.

        Note that the search takes place from the current iteration position,
        and all iterations are cumulative. The iteration position is reset using
        the 'reset' method (in super).

        Params:
            name = name to search for

        Returns:
            true if named object found

     **************************************************************************/

    public bool nextNamedObject ( cstring name )
    {
        bool in_object;
        do
        {
            if ( in_object )
            {
                if ( super.value == name )
                {
                    return true;
                }
                else
                {
                    in_object = false;
                }
            }
            else
            {
                if ( super.type == Token.BeginObject )
                {
                    in_object = true;
                }
            }
        }
        while ( super.next );

        return false;
    }


    /**************************************************************************

        Iterates over the json string looking for the named element and
        returning the value of the following element.

        Note that the search takes place from the current iteration position,
        and all iterations are cumulative. The iteration position is reset using
        the 'reset' method (in super).

        Params:
            name = name to search for
            found = output value, set to true if named value was found

        Returns:
            value of element after the named element

     **************************************************************************/

    public cstring nextNamed ( cstring name, out bool found )
    {
        return this.nextNamedValue(name, found, ( Token token ) { return true; });
    }


    /**************************************************************************

        Iterates over the json string looking for the named element and
        returning the value of the following element if it is a boolean. If the
        value is not boolean the search continues.

        Note that the search takes place from the current iteration position,
        and all iterations are cumulative. The iteration position is reset using
        the 'reset' method (in super).

        Params:
            name = name to search for
            found = output value, set to true if named value was found

        Returns:
            boolean value of element after the named element

     **************************************************************************/

    public bool nextNamedBool ( cstring name, out bool found )
    {
        return this.nextNamedValue(name, found, ( Token token ) { return token == Token.True || token == Token.False; }) == "true";
    }


    /**************************************************************************

        Iterates over the json string looking for the named element and
        returning the value of the following element if it is a string. If the
        value is not a string the search continues.

        Note that the search takes place from the current iteration position,
        and all iterations are cumulative. The iteration position is reset using
        the 'reset' method (in super).

        Params:
            name = name to search for
            found = output value, set to true if named value was found

        Returns:
            value of element after the named element

     **************************************************************************/

    public cstring nextNamedString ( cstring name, out bool found )
    {
        return this.nextNamedValue(name, found, ( Token token ) { return token == Token.String; });
    }


    /**************************************************************************

        Iterates over the json string looking for the named element and
        returning the value of the following element if it is a number. If the
        value is not a number the search continues.

        Note that the search takes place from the current iteration position,
        and all iterations are cumulative. The iteration position is reset using
        the 'reset' method (in super).

        Template_Params:
            T = numerical type to return

        Params:
            name = name to search for
            found = output value, set to true if named value was found

        Returns:
            numerical value of element after the named element

        Throws:
            if the value is not valid number

     **************************************************************************/

    public T nextNamedNumber ( T ) ( cstring name, out bool found )
    {
        T ret;
        auto str = this.nextNamedValue(name, found,
            ( Token token )
            {
                return token == Token.Number || token == Token.NaN ||
                       token == Token.Infinity || token == Token.NegInfinity;
            }
        );

        if ( found )
        {
            static if ( isRealType!(T) )
            {
                ret = Float.toFloat(str);
            }
            else static if ( isSignedIntegerType!(T) )
            {
                ret = Integer.toLong(str);
            }
            else static if ( isUnsignedIntegerType!(T) )
            {
                auto tmp = Integer.toUlong(str);
                enforce(tmp <= T.max && tmp >= T.min,
                        "Value returned from toULong is out of bound for type "
                        ~ T.stringof);
                ret = cast(T) tmp;
            }
            else
            {
                static assert(false, typeof(this).stringof ~ ".nextNamedNumber - template type must be numerical, not " ~ T.stringof);
            }
        }

        return ret;
    }

    /**************************************************************************

        Iterates over the json string looking for the named element and
        returning the value of the following element if its type matches the
        requirements of the passed delegate.

        Note that the search takes place from the current iteration position,
        and all iterations are cumulative. The iteration position is reset using
        the 'reset' method (in super).

        Params:
            name = name to search for
            found = output value, set to true if named value was found
            type_match_dg = delegate which receives the type of the element
                following a correctly named value, and decides whether this is
                the value to be returned

        Returns:
            value of element after the named element

     **************************************************************************/

    private cstring nextNamedValue ( cstring name, out bool found,
        bool delegate ( Token ) type_match_dg )
    {
        bool got_name;
        foreach ( type, value; this )
        {
            if ( got_name )
            {
                if ( type_match_dg(type) )
                {
                    found = true;
                    return value;
                }
                else
                {
                    got_name = false;
                }
            }

            if ( type == Token.Name && value == name )
            {
                got_name = true;
            }
        }

        return "";
    }
}

///
unittest
{
    alias JsonParserIter!(true) JsonParserIterWithNan;
    alias JsonParserIter!(false) JsonParserIterNoNan;

    bool found;
    istring json = `{ "object": { "cost": 12.34, "sub": { "cost": 42 } } }`;

    scope parser = new JsonParserIterNoNan();
    parser.reset(json);

    auto val = parser.nextNamed("cost", found);
    assert(found, "Boolean flag should be set to true");
    test!("==")(val, "12.34"[]);

    found = false;
    auto uval = parser.nextNamedNumber!(uint)("cost", found);
    assert(found, "Boolean flag should be set to true");
    test!("==")(uval, 42);
}
