/******************************************************************************

    HTTP version identifier constants and enumerator

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.net.http.consts.HttpVersion;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.transition;
import ocean.stdc.ctype: isdigit;


/******************************************************************************

    HTTP version enumerator

 ******************************************************************************/

enum HttpVersion : ubyte
{
    Undefined = 0,
    v1_1,
    v1_0
}

/******************************************************************************

    HTTP version identifier string constants and enumerator value association

 ******************************************************************************/

struct HttpVersionIds
{
    /**************************************************************************

        HTTP version identifier string constants

        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.1

     **************************************************************************/

    const istring[HttpVersion.max + 1] list =
    [
        HttpVersion.v1_1: "HTTP/1.1",
        HttpVersion.v1_0: "HTTP/1.0"
    ];

    /**************************************************************************

        Obtains the HTTP identifier string by version enumerator value. ver must
        be a HttpVersion value different from HttpVersion.Undefined.

        Params:
            ver = HTTP version enumerator value

         Returns:
             HTTP version identifier string corresponding to val

         Throws:
             assert()s that ver is in range and not HttpVersion.Undefined.

     **************************************************************************/

    static istring opIndex ( HttpVersion ver )
    in
    {
        assert (ver,            "no version id for HttpVersion.Undefined");
        assert (ver <= ver.max, "invalid HttpVersion enumerator value");
    }
    body
    {
        return list[ver];
    }

    /**************************************************************************

        Obtains the HTTP version enumerator value by identifier string.

        Params:
            id = HTTP version identifier string

         Returns:
             Pointer to the HTTP version enumerator value corresponding to
             identifier string or null if the name identifier does not match any
             known HTTP version identifier string.

     **************************************************************************/

    static HttpVersion* opIn_r ( cstring id )
    {
        return id.length? id in codes : null;
    }

    /**************************************************************************

        Obtains the HTTP version enumerator value by identifier string. Does not
        throw an exception.

        Params:
            id = HTTP version identifier string

         Returns:
             HTTP version enumerator value corresponding to identifier string or
             HttpVersion.Undefined if the name string is unknown.

     **************************************************************************/

    static HttpVersion opIndex ( cstring id )
    {
        HttpVersion* code = opIn_r(id);

        return code? *code : (*code).Undefined;
    }

    /**************************************************************************

        Checks whether id has a valid syntax for a HTTP version identifier
        string:

        "HTTP" "/" 1*DIGIT "." 1*DIGIT

        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.1

        Params:
            id = HTTP version identifier string

         Returns:
             true if d has a valid syntax for a HTTP version identifier string
             or false otherwise.

     **************************************************************************/

    static bool validSyntax ( cstring id )
    {
        const prefix = "HTTP/";

        bool valid = id.length > prefix.length;

        if (valid)
        {
            valid = id[0 .. prefix.length] == prefix;
        }

        if (valid)
        {
            size_t n_before_dot = 0;

            foreach (i, c; id[prefix.length .. $])
            {
                if (!isdigit(c))
                {
                    if (c == '.')
                    {
                        n_before_dot = i;
                    }
                    else
                    {
                        valid = false;
                    }

                    break;
                }
            }

            valid &= n_before_dot != 0;

            if (valid)
            {
                size_t after_dot = n_before_dot + prefix.length + 1;

                valid &= id.length > after_dot;

                if (valid) foreach (i, c; id[after_dot .. $])
                {
                    if (!isdigit(c))
                    {
                        valid = false;
                        break;
                    }
                }
            }
        }

        return valid;
    }

    /**************************************************************************

        Unittest for validSyntax()

     **************************************************************************/

    unittest
    {
        assert (validSyntax("HTTP/1.1"));
        assert (validSyntax("HTTP/1.23"));
        assert (validSyntax("HTTP/123.456"));
        assert (!validSyntax("HTTP/123456"));
        assert (!validSyntax("HTTP/.123456"));
        assert (!validSyntax("HTTP/1,1"));
        assert (!validSyntax("HTTP/1."));
        assert (!validSyntax("HTTP/.1"));
        assert (!validSyntax("HTTP/."));
        assert (!validSyntax("HTTP/"));
        assert (!validSyntax(""));
    }

    /**************************************************************************

        HTTP version code enumerator value by name string

     **************************************************************************/

    private static HttpVersion[istring] codes;

    /**************************************************************************

        Static constructor; populates this.codes

     **************************************************************************/

    static this ( )
    {
        foreach (i, str; list)
        {
            codes[str] = cast (HttpVersion) i;
        }

        codes.rehash;
    }
}


unittest
{
    static assert(HttpVersionIds.list[HttpVersion.v1_1]     == "HTTP/1.1");
    static assert(HttpVersionIds.list[HttpVersion.v1_0]     == "HTTP/1.0");

    assert(!HttpVersionIds.list[HttpVersion.Undefined].length);

    assert(HttpVersionIds.list[HttpVersion.v1_1]     == "HTTP/1.1");
    assert(HttpVersionIds.list[HttpVersion.v1_0]     == "HTTP/1.0");

    assert(HttpVersionIds["HTTP/1.1"]     == HttpVersion.v1_1);
    assert(HttpVersionIds["HTTP/1.0"]     == HttpVersion.v1_0);
    assert(HttpVersionIds["SPAM"]         == HttpVersion.Undefined);
    assert(HttpVersionIds[""]             == HttpVersion.Undefined);
    assert(HttpVersionIds[null]           == HttpVersion.Undefined);

    HttpVersion* v = "HTTP/1.1" in HttpVersionIds;
    assert(v);
    assert(*v == (*v).v1_1);

    v = "HTTP/1.0" in HttpVersionIds;
    assert(v);
    assert(*v == (*v).v1_0);

    assert(!("SPAM" in HttpVersionIds));
    assert(!(""     in HttpVersionIds));
    assert(!(null   in HttpVersionIds));
}
