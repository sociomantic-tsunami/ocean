/*******************************************************************************

        Copyright:
            Copyright (C) 2008 Aaron Craelius & Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
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
            this.text = text;
            this.ptr = text.ptr;
            this.end = this.ptr + text.length;
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
            while (c = *++p, c >= '0' && c <= '9') {}

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
    const istring json =
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
    assert(p);
    assert(p.type == p.Token.BeginObject);
    assert(p.next);
    assert(p.type == p.Token.Name);
    assert(p.value == "glossary", p.value);
    assert(p.next);
    assert(p.value == "", p.value);
    assert(p.type == p.Token.BeginObject);
    assert(p.next);
    assert(p.type == p.Token.Name);
    assert(p.value == "title", p.value);
    assert(p.next);
    assert(p.type == p.Token.String);
    assert(p.value == "example glossary", p.value);
    assert(p.next);
    assert(p.type == p.Token.Name);
    assert(p.value == "GlossDiv", p.value);
    assert(p.next);
    assert(p.type == p.Token.BeginObject);
    assert(p.next);
    assert(p.type == p.Token.Name);
    assert(p.value == "title", p.value);
    assert(p.next);
    assert(p.type == p.Token.String);
    assert(p.value == "S", p.value);
    assert(p.next);
    assert(p.type == p.Token.Name);
    assert(p.value == "GlossList", p.value);
    assert(p.next);
    assert(p.type == p.Token.BeginObject);
    assert(p.next);
    assert(p.type == p.Token.Name);
    assert(p.value == "GlossEntry", p.value);
    assert(p.next);
    assert(p.type == p.Token.BeginObject);
    assert(p.next);
    assert(p.type == p.Token.Name);
    assert(p.value == "ID", p.value);
    assert(p.next);
    assert(p.type == p.Token.String);
    assert(p.value == "SGML", p.value);
    assert(p.next);
    assert(p.type == p.Token.Name);
    assert(p.value == "SortAs", p.value);
    assert(p.next);
    assert(p.type == p.Token.String);
    assert(p.value == "SGML", p.value);
    assert(p.next);
    assert(p.type == p.Token.Name);
    assert(p.value == "GlossTerm", p.value);
    assert(p.next);
    assert(p.type == p.Token.String);
    assert(p.value == "Standard Generalized Markup Language", p.value);
    assert(p.next);
    assert(p.type == p.Token.Name);
    assert(p.value == "Acronym", p.value);
    assert(p.next);
    assert(p.type == p.Token.String);
    assert(p.value == "SGML", p.value);
    assert(p.next);
    assert(p.type == p.Token.Name);
    assert(p.value == "Abbrev", p.value);
    assert(p.next);
    assert(p.type == p.Token.String);
    assert(p.value == "ISO 8879:1986", p.value);
    assert(p.next);
    assert(p.type == p.Token.Name);
    assert(p.value == "GlossDef", p.value);
    assert(p.next);
    assert(p.type == p.Token.BeginObject);
    assert(p.next);
    assert(p.type == p.Token.Name);
    assert(p.value == "para", p.value);
    assert(p.next);

    assert(p.type == p.Token.String);
    assert(p.value == "A meta-markup language, used to create markup languages such as DocBook.", p.value);
    assert(p.next);
    assert(p.type == p.Token.Name);
    assert(p.value == "GlossSeeAlso", p.value);
    assert(p.next);
    assert(p.type == p.Token.BeginArray);
    assert(p.next);
    assert(p.type == p.Token.String);
    assert(p.value == "GML", p.value);
    assert(p.next);
    assert(p.type == p.Token.String);
    assert(p.value == "XML", p.value);
    assert(p.next);
    assert(p.type == p.Token.EndArray);
    assert(p.next);
    assert(p.type == p.Token.EndObject);
    assert(p.next);
    assert(p.type == p.Token.Name);
    assert(p.value == "GlossSee", p.value);
    assert(p.next);
    assert(p.type == p.Token.String);
    assert(p.value == "markup", p.value);
    assert(p.next);
    assert(p.type == p.Token.Name);
    assert(p.value == "ANumber", p.value);
    assert(p.next);
    assert(p.type == p.Token.Number);
    assert(p.value == "12345.6e7", p.value);
    assert(p.next);
    assert(p.type == p.Token.Name);
    assert(p.value == "BNumber", p.value);
    assert(p.next);
    assert(p.type == p.Token.Number);
    assert(p.value == "12345.6e+7", p.value);
    assert(p.next);
    assert(p.type == p.Token.Name);
    assert(p.value == "CNumber", p.value);
    assert(p.next);
    assert(p.type == p.Token.Number);
    assert(p.value == "12345.6e-7", p.value);
    assert(p.next);
    assert(p.type == p.Token.Name);
    assert(p.value == "DNumber", p.value);
    assert(p.next);
    assert(p.type == p.Token.Number);
    assert(p.value == "12345.6E7", p.value);
    assert(p.next);
    assert(p.type == p.Token.Name);
    assert(p.value == "ENumber", p.value);
    assert(p.next);
    assert(p.type == p.Token.Number);
    assert(p.value == "12345.6E+7", p.value);
    assert(p.next);
    assert(p.type == p.Token.Name);
    assert(p.value == "FNumber", p.value);
    assert(p.next);
    assert(p.type == p.Token.Number);
    assert(p.value == "12345.6E-7", p.value);
    assert(p.next);
    assert(p.type == p.Token.Name);
    assert(p.value == "True", p.value);
    assert(p.next);
    assert(p.type == p.Token.True);
    assert(p.next);
    assert(p.type == p.Token.Name);
    assert(p.value == "False", p.value);
    assert(p.next);
    assert(p.type == p.Token.False);
    assert(p.next);
    assert(p.type == p.Token.Name);
    assert(p.value == "Null", p.value);
    assert(p.next);
    assert(p.type == p.Token.Null);
    assert(p.next);
    assert(p.type == p.Token.EndObject);
    assert(p.next);
    assert(p.type == p.Token.EndObject);
    assert(p.next);
    assert(p.type == p.Token.EndObject);
    assert(p.next);
    assert(p.type == p.Token.EndObject);
    assert(p.next);
    assert(p.type == p.Token.EndObject);
    assert(!p.next);

    assert(p.state.size == 0);
}
