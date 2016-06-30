/*******************************************************************************

    Xml entity en/decoder.

    Example usage:

    ---

        import ocean.text.entities.XmlEntityCodec;

        scope entity_codec = new XmlEntityCodec;

        char[] test = "hello & world © &gt;&amp;#x230;'";

        if ( entity_codec.containsUnencoded(test) )
        {
            char[] encoded;
            entity_codec.encode(test, encoded);
        }

    ---

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.text.entities.XmlEntityCodec;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.text.entities.model.MarkupEntityCodec;

import ocean.text.entities.XmlEntitySet;

import ocean.transition;

/*******************************************************************************

    Class to en/decode xml entities.

*******************************************************************************/

public alias MarkupEntityCodec!(XmlEntitySet) XmlEntityCodec;


/*******************************************************************************

    Unit test

*******************************************************************************/

version ( UnitTest )
{
    void encodeTest ( Char ) ( XmlEntityCodec codec, Const!(Char)[] str,
        Const!(Char)[] expected_result )
    {
        Char[] encoded;

        if ( codec.containsUnencoded(str) )
        {
            codec.encode(str, encoded);
            assert(codec.containsEncoded(encoded));
        }
        else
        {
            encoded = str.dup;
        }

        assert(encoded == expected_result);
    }

    void decodeTest ( Char ) ( XmlEntityCodec codec, Const!(Char)[] str,
        Const!(Char)[] expected_result )
    {
        Char[] decoded;

        if ( codec.containsEncoded(str) )
        {
            codec.decode(str, decoded);
        }
        else
        {
            decoded = str.dup;
        }

        assert(decoded == expected_result);
    }

    // Perform tests for various char types
    void test ( Char ) ( )
    {
        struct Test
        {
            Const!(Char)[] before;
            Const!(Char)[] after;
        }

        scope codec = new XmlEntityCodec;

        // Check encoding
        Test[] encode_tests = [
            Test("", "" ), // saftey check
            Test("&", "&amp;"),
            Test("'", "&apos;"),
            Test("\"", "&quot;"),
            Test("<", "&lt;"),
            Test(">", "&gt;"),
            Test("©", "©"), // trick question
            Test("'hello'", "&apos;hello&apos;"),
            Test("&amp;", "&amp;") // already encoded
        ];

        foreach ( t; encode_tests )
        {
            encodeTest!(Char)(codec, t.before, t.after);
        }

        // Check decoding
        Test[] decode_tests = [
           Test("", ""), // saftey check
           Test("&#80;", "P"),
           Test("&#x50;", "P"),
           Test("&amp;", "&"),
           Test("&apos;", "'"),
           Test("&quot;", "\""),
           Test("&lt;", "<"),
           Test("&gt;", ">"),
           Test("©", "©"), // trick question
           Test("&amp;#23;&#80;", "&#23;P") // double encoding
           ];

        foreach ( t; decode_tests )
        {
            decodeTest!(Char)(codec, t.before, t.after);
        }
    }
}

unittest
{
    test!(char)();
    test!(wchar)();
    test!(dchar)();
}
