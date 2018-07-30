/*******************************************************************************

    Copyright:
        Copyright (C) 2007 Aaron Craelius and Kris Bell
        Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

    Authors: Aaron, Kris

*******************************************************************************/

module ocean.text.xml.PullParser;

import ocean.transition;

import ocean.text.Util : indexOf;

import ocean.core.ExceptionDefinitions : XmlException;

import Integer = ocean.text.convert.Integer_tango;

import Utf = ocean.text.convert.Utf : toString;

version (UnitTest)
{
    import ocean.core.Test;
}

/*******************************************************************************

        Use -version=whitespace to retain whitespace as data nodes. We
        see a %25 increase in token count and 10% throughput drop when
        parsing "hamlet.xml" with this option enabled (pullparser alone)

*******************************************************************************/

version (whitespace)
    version = retainwhite;
else
{
   version = stripwhite;
   version = partialwhite;
}

/*******************************************************************************

        The XML node types

*******************************************************************************/

public enum XmlNodeType
{
    Element,
    Data,
    Attribute,
    CData,
    Comment,
    PI,
    Doctype,
    Document
}

/*******************************************************************************

        Values returned by the pull-parser

*******************************************************************************/

public enum XmlTokenType
{
    Done,
    StartElement,
    Attribute,
    EndElement,
    EndEmptyElement,
    Data,
    Comment,
    CData,
    Doctype,
    PI,
    None
}

/*******************************************************************************

        Token based xml Parser.  Templated to operate with char[], wchar[],
        and dchar[] content.

        The parser is constructed with some tradeoffs relating to document
        integrity. It is generally optimized for well-formed documents, and
        currently may read past a document-end for those that are not well
        formed. There are various compilation options to enable checks and
        balances, depending on how things should be handled. We'll settle
        on a common configuration over the next few weeks, but for now all
        settings are somewhat experimental. Partly because making some tiny
        unrelated change to the code can cause notable throughput changes,
        and we need to track that down.

        We're not yet clear why these swings are so pronounced (for changes
        outside the code path) but they seem to be related to the alignment
        of codegen. It could be a cache-line issue, or something else. We'll
        figure it out, yet it's interesting that some hardware buttons are
        clearly being pushed

*******************************************************************************/

class PullParser(ChMut = char)
{
    alias Const!(ChMut)  Ch;

    public int           depth;
    public Ch[]          prefix;
    public Ch[]          rawValue;
    public Ch[]          localName;
    public XmlTokenType  type = XmlTokenType.None;

    package XmlText!(Ch) text;
    private bool         stream;
    private istring      errMsg;

    /***********************************************************************

      Construct a parser on the given content (may be null)

     ***********************************************************************/

    this(Ch[] content = null)
    {
        reset (content);
    }

    /***********************************************************************

      Consume the next token and return its type

     ***********************************************************************/

    final XmlTokenType next()
    {
        auto e = text.end;
        auto p = text.point;

        // at end of document?
        if (p >= e)
            return endOfInput;
        version (stripwhite)
        {
            // strip leading whitespace
            while (*p <= 32)
                if (++p >= e)
                    return endOfInput;
        }
        // StartElement or Attribute?
        if (type < XmlTokenType.EndElement)
        {
            version (retainwhite)
            {
                // strip leading whitespace (thanks to DRK)
                while (*p <= 32)
                    if (++p >= e)
                        return endOfInput;
            }
            switch (*p)
            {
                case '>':
                    // termination of StartElement
                    ++depth;
                    ++p;
                    break;

                case '/':
                    // empty element closure
                    text.point = p;
                    return doEndEmptyElement;

                default:
                    // must be attribute instead
                    text.point = p;
                    return doAttributeName;
            }
        }

        // consume data between elements?
        if (*p != '<')
        {
            auto q = p;
            while (++p < e && *p != '<') {}

            if (p < e)
            {
                version (partialwhite)
                {
                    // include leading whitespace
                    while (*(q-1) <= 32)
                        --q;
                }
                text.point = p;
                rawValue = q [0 .. p - q];
                return type = XmlTokenType.Data;
            }
            return endOfInput;
        }

        // must be a '<' character, so peek ahead
        switch (p[1])
        {
            case '!':
                // one of the following ...
                if (p[2..4] == "--")
                {
                    text.point = p + 4;
                    return doComment;
                }
                else
                    if (p[2..9] == "[CDATA[")
                    {
                        text.point = p + 9;
                        return doCData;
                    }
                    else
                        if (p[2..9] == "DOCTYPE")
                        {
                            text.point = p + 9;
                            return doDoctype;
                        }
                return doUnexpected("!", p);

            case '\?':
                // must be PI data
                text.point = p + 2;
                return doPI;

            case '/':
                // should be a closing element name
                p += 2;
                auto q = p;
                while (*q > 63 || text.name[*q])
                    ++q;

                if (*q is ':')
                {
                    prefix = p[0 .. q - p];
                    p = ++q;
                    while (*q > 63 || text.attributeName[*q])
                        ++q;

                    localName = p[0 .. q - p];
                }
                else
                {
                    prefix = null;
                    localName = p[0 .. q - p];
                }

                while (*q <= 32)
                    if (++q >= e)
                        return endOfInput;

                if (*q is '>')
                {
                    --depth;
                    text.point = q + 1;
                    return type = XmlTokenType.EndElement;
                }
                return doExpected(">", q);

            default:
                // scan new element name
                auto q = ++p;
                while (*q > 63 || text.name[*q])
                    ++q;

                // check if we ran past the end
                if (q >= e)
                    return endOfInput;

                if (*q != ':')
                {
                    prefix = null;
                    localName = p [0 .. q - p];
                }
                else
                {
                    prefix = p[0 .. q - p];
                    p = ++q;
                    while (*q > 63 || text.attributeName[*q])
                        ++q;
                    localName = p[0 .. q - p];
                }

                text.point = q;
                return type = XmlTokenType.StartElement;
        }
    }

    /***********************************************************************

     ***********************************************************************/

    private XmlTokenType doAttributeName()
    {
        auto p = text.point;
        auto q = p;
        auto e = text.end;

        while (*q > 63 || text.attributeName[*q])
            ++q;
        if (q >= e)
            return endOfInput;

        if (*q is ':')
        {
            prefix = p[0 .. q - p];
            p = ++q;

            while (*q > 63 || text.attributeName[*q])
                ++q;

            localName = p[0 .. q - p];
        }
        else
        {
            prefix = null;
            localName = p[0 .. q - p];
        }

        if (*q <= 32)
        {
            while (*++q <= 32) {}
            if (q >= e)
                return endOfInput;
        }

        if (*q is '=')
        {
            while (*++q <= 32) {}
            if (q >= e)
                return endOfInput;

            auto quote = *q;
            switch (quote)
            {
                case '"':
                case '\'':
                    p = q + 1;
                    while (*++q != quote) {}
                    if (q < e)
                    {
                        rawValue = p[0 .. q - p];
                        text.point = q + 1;   // skip end quote
                        return type = XmlTokenType.Attribute;
                    }
                    return endOfInput;

                default:
                    return doExpected("\' or \"", q);
            }
        }

        return doExpected ("=", q);
    }

    /***********************************************************************

     ***********************************************************************/

    private XmlTokenType doEndEmptyElement()
    {
        if (text.point[0] is '/' && text.point[1] is '>')
        {
            localName = prefix = null;
            text.point += 2;
            return type = XmlTokenType.EndEmptyElement;
        }
        return doExpected("/>", text.point);
    }

    /***********************************************************************

     ***********************************************************************/

    private XmlTokenType doComment()
    {
        auto e = text.end;
        auto p = text.point;
        auto q = p;

        while (p < e)
        {
            while (*p != '-')
                if (++p >= e)
                    return endOfInput;

            if (p[0..3] == "-->")
            {
                text.point = p + 3;
                rawValue = q [0 .. p - q];
                return type = XmlTokenType.Comment;
            }
            ++p;
        }

        return endOfInput;
    }

    /***********************************************************************

     ***********************************************************************/

    private XmlTokenType doCData()
    {
        auto e = text.end;
        auto p = text.point;

        while (p < e)
        {
            auto q = p;
            while (*p != ']')
                if (++p >= e)
                    return endOfInput;

            if (p[0..3] == "]]>")
            {
                text.point = p + 3;
                rawValue = q [0 .. p - q];
                return type = XmlTokenType.CData;
            }
            ++p;
        }

        return endOfInput;
    }

    /***********************************************************************

     ***********************************************************************/

    private XmlTokenType doPI()
    {
        auto e = text.end;
        auto p = text.point;
        auto q = p;

        while (p < e)
        {
            while (*p != '\?')
                if (++p >= e)
                    return endOfInput;

            if (p[1] == '>')
            {
                rawValue = q [0 .. p - q];
                text.point = p + 2;
                return type = XmlTokenType.PI;
            }
            ++p;
        }
        return endOfInput;
    }

    /***********************************************************************

     ***********************************************************************/

    private XmlTokenType doDoctype()
    {
        auto e = text.end;
        auto p = text.point;

        // strip leading whitespace
        while (*p <= 32)
            if (++p >= e)
                return endOfInput;

        auto q = p;
        while (p < e)
        {
            if (*p is '>')
            {
                rawValue = q [0 .. p - q];
                prefix = null;
                text.point = p + 1;
                return type = XmlTokenType.Doctype;
            }
            else
            {
                if (*p == '[')
                    do {
                        if (++p >= e)
                            return endOfInput;
                    } while (*p != ']');
                ++p;
            }
        }

        if (p >= e)
            return endOfInput;
        return XmlTokenType.Doctype;
    }

    /***********************************************************************

     ***********************************************************************/

    private XmlTokenType endOfInput ()
    {
        if (depth && (stream is false))
            error ("Unexpected EOF");

        return XmlTokenType.Done;
    }

    /***********************************************************************

     ***********************************************************************/

    private XmlTokenType doUnexpected (istring msg, Ch* p)
    {
        return position ("parse error :: unexpected  " ~ msg, p);
    }

    /***********************************************************************

     ***********************************************************************/

    private XmlTokenType doExpected (istring msg, Ch* p)
    {
        char[6] tmp = void;
        return position ("parse error :: expected  " ~ msg ~ " instead of "
                ~ idup(Utf.toString(p[0..1], tmp)), p);
    }

    /***********************************************************************

     ***********************************************************************/

    private XmlTokenType position (istring msg, Ch* p)
    {
        return error (msg ~ " at position "
                ~ idup(Integer.toString(p-text.text.ptr)));
    }

    /***********************************************************************

     ***********************************************************************/

    protected final XmlTokenType error (istring msg)
    {
        errMsg = msg;
        throw new XmlException (msg);
    }

    /***********************************************************************

      Return the raw value of the current token

     ***********************************************************************/

    final Ch[] value()
    {
        return rawValue;
    }

    /***********************************************************************

      Return the name of the current token

     ***********************************************************************/

    final Ch[] name()
    {
        if (prefix.length)
            return prefix ~ ":" ~ localName;
        return localName;
    }

    /***********************************************************************

      Returns the text of the last error

     ***********************************************************************/

    final istring error()
    {
        return errMsg;
    }

    /***********************************************************************

      Reset the parser

     ***********************************************************************/

    final bool reset()
    {
        text.reset (text.text);
        reset_;
        return true;
    }

    /***********************************************************************

      Reset parser with new content

     ***********************************************************************/

    final void reset(Ch[] newText)
    {
        text.reset (newText);
        reset_;
    }

    /***********************************************************************

        experimental: set streaming mode

        Use at your own risk, may be removed.

     ***********************************************************************/

    final void incremental (bool yes = true)
    {
        stream = yes;
    }

    /***********************************************************************

     ***********************************************************************/

    private void reset_()
    {
        depth = 0;
        errMsg = null;
        type = XmlTokenType.None;

        auto p = text.point;
        if (p)
        {
            static if (Ch.sizeof == 1)
            {
                // consume UTF8 BOM
                if (p[0] is 0xef && p[1] is 0xbb && p[2] is 0xbf)
                    p += 3;
            }

            //TODO enable optional declaration parsing
            auto e = text.end;
            while (p < e && *p <= 32)
                ++p;

            if (p < e)
                if (p[0] is '<' && p[1] is '\?' && p[2..5] == "xml")
                {
                    p += 5;
                    while (p < e && *p != '\?')
                        ++p;
                    p += 2;
                }
            text.point = p;
        }
    }
}


/*******************************************************************************

 *******************************************************************************/

package struct XmlText(Ch)
{
    package Ch*     end;
    package size_t  len;
    package Ch[]    text;
    package Ch*     point;

    final void reset(Ch[] newText)
    {
        (&this).text = newText;
        (&this).len = newText.length;
        (&this).point = text.ptr;
        (&this).end = point + len;
    }

    static Const!(ubyte[64]) name =
    [
        // 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
        0,  1,  1,  1,  1,  1,  1,  1,  1,  0,  0,  1,  1,  0,  1,  1,  // 0
        1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  // 1
        0,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  0,  // 2
        1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  0,  1,  1,  1,  0,  0   // 3
    ];

    static Const!(ubyte[64]) attributeName =
    [
        // 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
        0,  1,  1,  1,  1,  1,  1,  1,  1,  0,  0,  1,  1,  0,  1,  1,  // 0
        1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  // 1
        0,  0,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  0,  // 2
        1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  0,  1,  0,  0,  0,  0   // 3
    ];
}

/*******************************************************************************

 *******************************************************************************/

version (UnitTest)
{
    /***********************************************************************

     ***********************************************************************/

    void testParser(Ch)(PullParser!(Ch) itr)
    {
        test(itr.next);
        test(itr.value == "element [ <!ELEMENT element (#PCDATA)>]");
        test(itr.type == XmlTokenType.Doctype);
        test(itr.next);
        test(itr.localName == "element");
        test(itr.type == XmlTokenType.StartElement);
        test(itr.depth == 0);
        test(itr.next);
        test(itr.localName == "attr");
        test(itr.value == "1");
        test(itr.next);
        test(itr.type == XmlTokenType.Attribute);
        test(itr.localName == "attr2");
        test(itr.value == "two");
        test(itr.next);
        test(itr.value == "comment");
        test(itr.next);
        test(itr.rawValue == "test&amp;&#x5a;");
        test(itr.next);
        test(itr.prefix == "qual");
        test(itr.localName == "elem");
        test(itr.next);
        test(itr.type == XmlTokenType.EndEmptyElement);
        test(itr.next);
        test(itr.localName == "el2");
        test(itr.depth == 1);
        test(itr.next);
        test(itr.localName == "attr3");
        test(itr.value == "3three", itr.value);
        test(itr.next);
        test(itr.rawValue == "sdlgjsh");
        test(itr.next);
        test(itr.localName == "el3");
        test(itr.depth == 2);
        test(itr.next);
        test(itr.type == XmlTokenType.EndEmptyElement);
        test(itr.next);
        test(itr.value == "data");
        test(itr.next);
        test(itr.rawValue == "pi test", itr.rawValue);
        test(itr.next);
        test(itr.localName == "el2");
        test(itr.next);
        test(itr.localName == "element");
        test(!itr.next);
    }


    /***********************************************************************

     ***********************************************************************/

    static immutable istring testXML = "<?xml version=\"1.0\" ?><!DOCTYPE element [ <!ELEMENT element (#PCDATA)>]><element "
        ~ "attr=\"1\" attr2=\"two\"><!--comment-->test&amp;&#x5a;<qual:elem /><el2 attr3 = "
        ~ "'3three'><![CDATA[sdlgjsh]]><el3 />data<?pi test?></el2></element>";
}

unittest
{
    auto itr = new PullParser!(char)(testXML);
    testParser (itr);

    // Parsing new text (or even the same one) should not involve any further
    // memory allocation
    testNoAlloc({
        itr.reset(testXML);
        testParser(itr);
    }());
}
