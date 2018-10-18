/*******************************************************************************

        Copyright:
            Copyright (C) 2008 Aaron Craelius & Kris Bell.
            Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: July 2008

        Authors: Aaron, Kris

*******************************************************************************/

module ocean.text.json.JsonParser;

import ocean.transition;
import ocean.core.Exception;
import ocean.util.container.more.Stack;

version(UnitTest) import ocean.core.Test;

/*******************************************************************************

 If AllowNaN is true, then NaN, Infinity, and -Infinity are parsed.

 NaN, Infinity, and -Infinity are technically not part of
 the JSON specification, but Javascript writes it by default, so it is
 by the far the most common cause of invalid JSON. Practically all
 JSON parsers (eg, Google GSON, Jackson, Ruby's JSON, simplejson,
 JSON.net, Lua CJson) ...have an option to accept NaN.

*******************************************************************************/

class JsonParser(T, bool AllowNaN = false)
{
    /***************************************************************************

         JSON tokens. The last three are used only if AllowNaN is true

    ***************************************************************************/

    public enum Token
    {
        Empty, Name, String, Number, BeginObject, EndObject,
        BeginArray, EndArray, True, False, Null,
        NaN, Infinity, NegInfinity
    }

    private enum State
    {
        Object,
        Array
    };

    private struct Iterator
    {
        Const!(T)*   ptr;
        Const!(T)*   end;
        Const!(T)[]  text;

        void reset (Const!(T)[] text)
        {
            (&this).text = text;
            (&this).ptr = text.ptr;
            (&this).end = (&this).ptr + text.length;
        }
    }

    protected Iterator              str;
    private Stack!(State, 16)       state;
    private Const!(T)*              curLoc;
    private ptrdiff_t               curLen;
    private State                   curState;
    protected Token                 curType;
    protected JsonParserException   exception;

    /***************************************************************************

        Construct a parser from a string

        Params:
            text = Text to initialize this parser to. Can be `null`.

    ***************************************************************************/

    this (Const!(T)[] text = null)
    {
        this.exception = new JsonParserException();
        this.reset(text);
    }


    /// Returns: `true` if there is a next element, `false` otherwise
    final bool next ()
    {
        if (this.str.ptr is null || this.str.end is null)
            return false;

        auto p = this.str.ptr;
        auto e = this.str.end;

        while (*p <= 32 && p < e)
            ++p;

        if ((this.str.ptr = p) >= e)
            return false;

        if (this.curState is State.Array)
            return this.parseArrayValue();

        switch (this.curType)
        {
        case Token.Name:
            return this.parseMemberValue();

        default:
            break;
        }

        return this.parseMemberName();
    }

    /// Returns: The `Token` type of the current token
    final Token type ()
    {
        return this.curType;
    }

    /// Returns: The current value of the token
    final Const!(T)[] value ()
    {
        return this.curLoc[0 .. this.curLen];
    }

    /***************************************************************************

        Reset the parser to a new string

        Params:
            json = new string to process

        Returns:
            `true` if the document starts with a '{' or a '['

    ***************************************************************************/

    bool reset (Const!(T)[] json = null)
    {
        this.state.clear();
        this.str.reset(json);
        this.curType = Token.Empty;
        this.curState = State.Object;

        if (json.length)
        {
            auto p = this.str.ptr;
            auto e = this.str.end;

            while (*p <= 32 && p < e)
                ++p;
            if (p < e)
                return this.start(*(this.str.ptr = p));
        }
        return false;
    }


    /// Throws: a new exception with "expected `token`" as message
    protected final void expected (cstring token)
    {
        throw this.exception.set("expected ").append(token);
    }

    /***************************************************************************

        Report error about an expected token not being found

        Params:
            token = the token that was expected to be found
            point = Where the token was expected

        Throws:
            Always end up throwing a new expection

    ***************************************************************************/

    protected final void expected (cstring token, Const!(T)* point)
    {
        auto diff = cast(int) (point - this.str.text.ptr);
        throw this.exception.set("expected ").append(token).append(" @input[")
            .append(diff).append("]");
    }

    /// Throws: A new expection with "unexpected end-of-input: msg" as message
    private void unexpectedEOF (cstring msg)
    {
        throw this.exception.set("unexpected end-of-input: ").append(msg);
    }


    /// Called by `reset`, ensure the document starts with '{' or '['
    private bool start (T c)
    {
        if (c is '{')
            return this.push(Token.BeginObject, State.Object);

        if (c is '[')
            return this.push(Token.BeginArray, State.Array);

        this.expected("'{' or '[' at start of document");

        assert(0);
    }

    ///
    private bool parseMemberName ()
    {
        auto p = this.str.ptr;
        auto e = this.str.end;

        if (*p is '}')
            return this.pop(Token.EndObject);

        if (*p is ',')
            ++p;

        while (*p <= 32)
            ++p;

        if (*p != '"')
        {
            if (*p == '}')
                this.expected("an attribute-name after (a potentially trailing) ','", p);
            else
                this.expected("'\"' before attribute-name", p);
        }

        this.curLoc = p + 1;
        this.curType = Token.Name;

        while (++p < e)
            if (*p is '"' && !this.escaped(p))
                break;

        if (p < e)
            this.curLen = p - this.curLoc;
        else
            this.unexpectedEOF("in attribute-name");

        this.str.ptr = p + 1;
        return true;
    }

    ///
    private bool parseMemberValue ()
    {
        auto p = this.str.ptr;

        if (*p != ':')
            this.expected("':' before attribute-value", p);

        auto e = this.str.end;
        while (++p < e && *p <= 32) {}

        return this.parseValue(*(this.str.ptr = p));
    }

    ///
    private bool parseValue (T c)
    {
        switch (c)
        {
        case '{':
            return this.push(Token.BeginObject, State.Object);

        case '[':
            return this.push(Token.BeginArray, State.Array);

        case '"':
            return this.doString();

        case 'n':
            if (this.match("null", Token.Null))
                return true;
            this.expected("'null'", this.str.ptr);
            assert(false);

        case 't':
            if (this.match("true", Token.True))
                return true;
            this.expected("'true'", this.str.ptr);
            assert(false);

        case 'f':
            if (this.match("false", Token.False))
                return true;
            this.expected("'false'", this.str.ptr);
            assert(false);

        static if (AllowNaN)
        {
        case 'N':
            if (this.match("NaN", Token.NaN))
                return true;
            this.expected ("'NaN'", this.str.ptr);
            assert(false);

        case 'I':
            if (this.match("Infinity", Token.Infinity))
                return true;
            this.expected ("'Infinity'", this.str.ptr);
            assert(false);

        case '-':
            if (this.match("-Infinity", Token.NegInfinity))
                return true;
            break;
        }

        default:
            break;
        }

        return this.parseNumber();
    }

    ///
    private bool doString ()
    {
        auto p = this.str.ptr;
        auto e = this.str.end;

        this.curLoc = p+1;
        this.curType = Token.String;

        while (++p < e)
            if (*p is '"' && !this.escaped(p))
                break;

        if (p < e)
            this.curLen = p - this.curLoc;
        else
            this.unexpectedEOF("in string");

        this.str.ptr = p + 1;
        return true;
    }

    ///
    private bool parseNumber ()
    {
        auto p = this.str.ptr;
        auto e = this.str.end;
        T c = *(this.curLoc = p);

        this.curType = Token.Number;

        if (c is '-' || c is '+')
            c = *++p;

        while (c >= '0' && c <= '9')
            c = *++p;

        if (c is '.')
            do { c = *++p; } while (c >= '0' && c <= '9');

        if (c is 'e' || c is 'E')
        {
            c = *++p;

            if (c is '-' || c is '+')
                c = *++p;

            while (c >= '0' && c <= '9')
                c = *++p;
        }

        if (p < e)
            this.curLen = p - this.curLoc;
        else
            this.unexpectedEOF("after number");

        this.str.ptr = p;
        return this.curLen > 0;
    }

    ///
    private bool match (Const!(T)[] name, Token token)
    {
        auto i = name.length;
        if (this.str.ptr[0 .. i] == name)
        {
            this.curLoc = this.str.ptr;
            this.curType = token;
            this.str.ptr += i;
            this.curLen = i;
            return true;
        }
        return false;
    }

    ///
    private bool push (Token token, State next)
    {
        this.curLen = 0;
        this.curType = token;
        this.curLoc = this.str.ptr++;
        this.state.push(this.curState);
        this.curState = next;
        return true;
    }

    ///
    private bool pop (Token token)
    {
        this.curLen = 0;
        this.curType = token;
        this.curLoc = this.str.ptr++;
        this.curState = this.state.pop;
        return true;
    }

    ///
    private bool parseArrayValue ()
    {
        auto p = this.str.ptr;
        if (*p is ']')
            return this.pop(Token.EndArray);

        if (*p is ',')
            ++p;

        auto e = this.str.end;
        while (p < e && *p <= 32)
            ++p;

        return this.parseValue(*(this.str.ptr = p));
    }

    ///
    private int escaped (Const!(T)* p)
    {
        int i;

        while (*--p is '\\')
            ++i;
        return i & 1;
    }
}

public class JsonParserException : Exception
{
    mixin ReusableExceptionImplementation!() R;
}


unittest
{
    static immutable istring json =
    `{
        "glossary": {
            "title": "example glossary",
            "GlossDiv": {
                "title": "S",
                "GlossList": {
                    "GlossEntry": {
                        "ID": "SGML",
                        "SortAs": "SGML",
                        "GlossTerm": "Standard Generalized Markup Language",
                        "Acronym": "SGML",
                        "Abbrev": "ISO 8879:1986",
                        "GlossDef": {
                            "para": "A meta-markup language, used to create markup languages such as DocBook.",
                            "GlossSeeAlso": [
                                "GML",
                                "XML"
                            ]
                        },
                        "GlossSee": "markup",
                        "ANumber": 12345.6e7
                        "BNumber": 12345.6e+7
                        "CNumber": 12345.6e-7
                        "DNumber": 12345.6E7
                        "ENumber": 12345.6E+7
                        "FNumber": 12345.6E-7
                        "True": true
                        "False": false
                        "Null": null
                    }
                }
            }
        }
     }`;

    auto p = new JsonParser!(char)(json);
    test(p);
    test(p.type == p.Token.BeginObject);
    test(p.next);
    test(p.type == p.Token.Name);
    test(p.value == "glossary", p.value);
    test(p.next);
    test(p.value == "", p.value);
    test(p.type == p.Token.BeginObject);
    test(p.next);
    test(p.type == p.Token.Name);
    test(p.value == "title", p.value);
    test(p.next);
    test(p.type == p.Token.String);
    test(p.value == "example glossary", p.value);
    test(p.next);
    test(p.type == p.Token.Name);
    test(p.value == "GlossDiv", p.value);
    test(p.next);
    test(p.type == p.Token.BeginObject);
    test(p.next);
    test(p.type == p.Token.Name);
    test(p.value == "title", p.value);
    test(p.next);
    test(p.type == p.Token.String);
    test(p.value == "S", p.value);
    test(p.next);
    test(p.type == p.Token.Name);
    test(p.value == "GlossList", p.value);
    test(p.next);
    test(p.type == p.Token.BeginObject);
    test(p.next);
    test(p.type == p.Token.Name);
    test(p.value == "GlossEntry", p.value);
    test(p.next);
    test(p.type == p.Token.BeginObject);
    test(p.next);
    test(p.type == p.Token.Name);
    test(p.value == "ID", p.value);
    test(p.next);
    test(p.type == p.Token.String);
    test(p.value == "SGML", p.value);
    test(p.next);
    test(p.type == p.Token.Name);
    test(p.value == "SortAs", p.value);
    test(p.next);
    test(p.type == p.Token.String);
    test(p.value == "SGML", p.value);
    test(p.next);
    test(p.type == p.Token.Name);
    test(p.value == "GlossTerm", p.value);
    test(p.next);
    test(p.type == p.Token.String);
    test(p.value == "Standard Generalized Markup Language", p.value);
    test(p.next);
    test(p.type == p.Token.Name);
    test(p.value == "Acronym", p.value);
    test(p.next);
    test(p.type == p.Token.String);
    test(p.value == "SGML", p.value);
    test(p.next);
    test(p.type == p.Token.Name);
    test(p.value == "Abbrev", p.value);
    test(p.next);
    test(p.type == p.Token.String);
    test(p.value == "ISO 8879:1986", p.value);
    test(p.next);
    test(p.type == p.Token.Name);
    test(p.value == "GlossDef", p.value);
    test(p.next);
    test(p.type == p.Token.BeginObject);
    test(p.next);
    test(p.type == p.Token.Name);
    test(p.value == "para", p.value);
    test(p.next);

    test(p.type == p.Token.String);
    test(p.value == "A meta-markup language, used to create markup languages such as DocBook.", p.value);
    test(p.next);
    test(p.type == p.Token.Name);
    test(p.value == "GlossSeeAlso", p.value);
    test(p.next);
    test(p.type == p.Token.BeginArray);
    test(p.next);
    test(p.type == p.Token.String);
    test(p.value == "GML", p.value);
    test(p.next);
    test(p.type == p.Token.String);
    test(p.value == "XML", p.value);
    test(p.next);
    test(p.type == p.Token.EndArray);
    test(p.next);
    test(p.type == p.Token.EndObject);
    test(p.next);
    test(p.type == p.Token.Name);
    test(p.value == "GlossSee", p.value);
    test(p.next);
    test(p.type == p.Token.String);
    test(p.value == "markup", p.value);
    test(p.next);
    test(p.type == p.Token.Name);
    test(p.value == "ANumber", p.value);
    test(p.next);
    test(p.type == p.Token.Number);
    test(p.value == "12345.6e7", p.value);
    test(p.next);
    test(p.type == p.Token.Name);
    test(p.value == "BNumber", p.value);
    test(p.next);
    test(p.type == p.Token.Number);
    test(p.value == "12345.6e+7", p.value);
    test(p.next);
    test(p.type == p.Token.Name);
    test(p.value == "CNumber", p.value);
    test(p.next);
    test(p.type == p.Token.Number);
    test(p.value == "12345.6e-7", p.value);
    test(p.next);
    test(p.type == p.Token.Name);
    test(p.value == "DNumber", p.value);
    test(p.next);
    test(p.type == p.Token.Number);
    test(p.value == "12345.6E7", p.value);
    test(p.next);
    test(p.type == p.Token.Name);
    test(p.value == "ENumber", p.value);
    test(p.next);
    test(p.type == p.Token.Number);
    test(p.value == "12345.6E+7", p.value);
    test(p.next);
    test(p.type == p.Token.Name);
    test(p.value == "FNumber", p.value);
    test(p.next);
    test(p.type == p.Token.Number);
    test(p.value == "12345.6E-7", p.value);
    test(p.next);
    test(p.type == p.Token.Name);
    test(p.value == "True", p.value);
    test(p.next);
    test(p.type == p.Token.True);
    test(p.next);
    test(p.type == p.Token.Name);
    test(p.value == "False", p.value);
    test(p.next);
    test(p.type == p.Token.False);
    test(p.next);
    test(p.type == p.Token.Name);
    test(p.value == "Null", p.value);
    test(p.next);
    test(p.type == p.Token.Null);
    test(p.next);
    test(p.type == p.Token.EndObject);
    test(p.next);
    test(p.type == p.Token.EndObject);
    test(p.next);
    test(p.type == p.Token.EndObject);
    test(p.next);
    test(p.type == p.Token.EndObject);
    test(p.next);
    test(p.type == p.Token.EndObject);
    test(!p.next);

    test(p.state.size == 0);
}
