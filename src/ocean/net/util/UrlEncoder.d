/*******************************************************************************

    Functions to convert non-ASCII and characters reserved in URLs to percent
    encoded form.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.net.util.UrlEncoder;

/**************************************************************************

    Imports

 **************************************************************************/

import ocean.transition;
import ocean.stdc.ctype: isgraph;


/******************************************************************************

    Converts non-unreserved characters. Unreserved characters are the ASCII
    alphanumeric characters and

        -._~

    .

    @see http://tools.ietf.org/html/rfc3986#section-2.3

    Special cases:

    - The whitespace character 0x20 is encoded as "%20" (not "+").
    - Characters below 0x20 and above 0x7E are encoded straight away, regardless
      of any encoding or codepage. For example, the UTF-8 encoded string
      "MÃ¼nzstraÃŸe", which corresponds to the byte sequence
      [0x4D, 0xC3, 0xBC, 0x6E, 0x7A, 0x73, 0x74, 0x72, 0x61, 0xC3, 0x9F, 0x65]
       ...M  .........Ã¼  ....n ...z  ...s  ...t  ...r  ...a  .........ÃŸ  ...e
      , is encoded as "M%C3%BCnzstra%C3%9Fe".

    UrlEncoder class

    Memory friendly, suitable for stack-allocated 'scope' instances.

 ******************************************************************************/

class EncodeNonUnreserved : PercentEncoder
{
    /**************************************************************************

        Character map, true for unreserved characters.

     **************************************************************************/

    const bool[char.max + 1] unreserved =
    [
        'A': true, 'B': true, 'C': true, 'D': true, 'E': true, 'F': true,
        'G': true, 'H': true, 'I': true, 'J': true, 'K': true, 'L': true,
        'M': true, 'N': true, 'O': true, 'P': true, 'Q': true, 'R': true,
        'S': true, 'T': true, 'U': true, 'V': true, 'W': true, 'X': true,
        'Y': true, 'Z': true,
        'a': true, 'b': true, 'c': true, 'd': true, 'e': true, 'f': true,
        'g': true, 'h': true, 'i': true, 'j': true, 'k': true, 'l': true,
        'm': true, 'n': true, 'o': true, 'p': true, 'q': true, 'r': true,
        's': true, 't': true, 'u': true, 'v': true, 'w': true, 'x': true,
        'y': true, 'z': true,
        '0': true, '1': true, '2': true, '3': true, '4': true, '5': true,
        '6': true, '7': true, '8': true, '9': true,
        '-': true, '_': true, '.': true, '~': true
    ];

    /**************************************************************************

        Constructor

        Params:
            source_in = source string

     **************************************************************************/

    public this ( cstring source_in = null )
    {
        super(source_in);
    }

    /**************************************************************************

        Tells whether c should be converted.

        Params:
            c = character in question

        Returns:
            true if c should be converted or false otherwise.

     **************************************************************************/

    protected override bool encode ( char c )
    {
        return !this.unreserved[c];
    }
}

/******************************************************************************

    Encodes all characters except the ASCII graphic, that is, encodes ASCII
    whitespace and control characters and non-ASCII characters.

 ******************************************************************************/

class EncodeExceptAsciiGraph : PercentEncoder
{
    /**************************************************************************

        Constructor

        Params:
            source_in = source string

     **************************************************************************/

    public this ( cstring source_in = null )
    {
        super(source_in);
    }

    /**************************************************************************

        Tells whether c should be converted.

        Params:
            c = character in question

        Returns:
            true if c should be converted or false otherwise.

     **************************************************************************/

    protected override bool encode ( char c )
    {
        return !.isgraph(c);
    }
}

/******************************************************************************

    Abstract encoder

 ******************************************************************************/

class PercentEncoder
{
    /**************************************************************************

        Source string, may be changed at any time except during encoding
        'foreach' iteration.

     **************************************************************************/

    public cstring source;

    /**************************************************************************

        Constructor

        Params:
            source_in = source string

     **************************************************************************/

    public this ( cstring source_in = null )
    {
        this.source = source_in;
    }

    /**************************************************************************

        Encodes this.source in an 'foreach' iteration over encoded chunks.
        Each chunk is guaranteed not to be empty.

     **************************************************************************/

    public int opApply ( int delegate ( ref cstring chunk ) dg )
    {
        int result = 0;

        int callDg ( cstring chunk )
        {
            return result = dg(chunk);
        }

        size_t  start = 0;
        char[3] hex;

        hex[0] = '%';

        foreach (i, c; this.source)
        {
            if (this.encode(c))
            {
                assert (start <= i);

                if (start < i)
                {
                    if (callDg(this.source[start .. i])) return result;
                }

                const hex_digits = "0123456789ABCDEF";

                hex[1] = hex_digits [(c >> 4) & 0xF];
                hex[2] = hex_digits [c & 0xF];

                if (callDg(hex)) return result;

                start = i + 1;
            }
        }

        assert (start <= this.source.length);

        return (start < this.source.length)?
                callDg(this.source[start .. $]) : result;
    }

    /******************************************************************************

        Encodes all characters except the ASCII graphic, that is, encodes ASCII
        whitespace and control characters and non-ASCII characters.

     ******************************************************************************/

    protected abstract bool encode ( char c );
}


unittest
{
    static void checkRange ( char first, char last )
    {
        for (char c = first; c <= last; c++)
        {
            assert (EncodeNonUnreserved.unreserved[c],
                    "'" ~ c ~ "' is supposed to be unreserved");
        }
    }

    checkRange('A', 'Z');
    checkRange('a', 'z');
    checkRange('0', '9');

    foreach (c; "-_.~")
    {
        assert (EncodeNonUnreserved.unreserved[c],
                "'" ~ c ~ "' is supposed to be unreserved");
    }

    scope encoder = new EncodeNonUnreserved("For example, the octet "
    "corresponding to the tilde (\"~\") character is often encoded as "
    "\"%7E\" by older URI processing implementations; the \"%7E\" can be "
    "replaced by \"~\" without chänging its interpretation.");

    const istring[] chunks =
    [
        "For", "%20", "example", "%2C", "%20", "the", "%20", "octet", "%20",
        "corresponding","%20", "to", "%20", "the", "%20", "tilde", "%20",
        "%28", "%22", "~", "%22", "%29", "%20", "character", "%20", "is",
        "%20", "often", "%20", "encoded", "%20", "as", "%20", "%22", "%25",
        "7E", "%22", "%20", "by", "%20", "older", "%20", "URI", "%20",
        "processing", "%20", "implementations", "%3B", "%20", "the", "%20",
        "%22", "%25", "7E", "%22", "%20", "can", "%20", "be", "%20",
        "replaced", "%20", "by", "%20", "%22", "~", "%22", "%20", "without",
        "%20", "ch", "%C3", "%A4", "nging", "%20", "its", "%20",
        "interpretation."
    ];

    size_t i = 0;

    foreach (chunk; encoder)
    {
        assert (i < chunks.length);
        assert (chunks[i++] == chunk);
    }
}
