/******************************************************************************

    HTTP method name constants and enumerator

    TODO: add support for extension methods (when needed)

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.net.http.consts.HttpMethod;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;


/******************************************************************************

    HTTP method enumerator

 ******************************************************************************/

enum HttpMethod : ubyte
{
    Undefined = 0,
    Get,
    Head,
    Post,
    Put,
    Delete,
    Trace,
    Connect,
    Options
}

/******************************************************************************

    HTTP method name string constants and enumerator value association

 ******************************************************************************/

struct HttpMethodNames
{
    /**************************************************************************

        HTTP method name string constants

        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html#sec5.1.1

     **************************************************************************/

    const istring[HttpMethod.max + 1] List =
    [
        HttpMethod.Undefined:  "",
        HttpMethod.Get:        "GET",
        HttpMethod.Head:       "HEAD",
        HttpMethod.Post:       "POST",
        HttpMethod.Put:        "PUT",
        HttpMethod.Delete:     "DELETE",
        HttpMethod.Trace:      "TRACE",
        HttpMethod.Connect:    "CONNECT",
        HttpMethod.Options:    "OPTIONS"
    ];

    /**************************************************************************

        HTTP method enumerator value by name string

     **************************************************************************/

    private static HttpMethod[istring] methods_by_name;

    /**************************************************************************

        Obtains the HTTP method enumerator value by name string. Does not throw
        an exception.

        Params:
            name = HTTP method name string

         Returns:
             HTTP method enumerator value corresponding to name string or
             HttpMethod.Undefined if the name string is unknown.

     **************************************************************************/

    static HttpMethod opIndex ( cstring name )
    {
        HttpMethod* method = name? name in methods_by_name : null;

        return method? *method : HttpMethod.init;
    }

    /**************************************************************************

        Obtains the HTTP method name string by enumerator value. Does not throw
        an exception.

        Params:
            method = HTTP method enumerator value

         Returns:
             HTTP method name string corresponding to name method or null on
             invalid value.

     **************************************************************************/

    static istring opIndex ( HttpMethod method )
    in
    {
        static assert (method.max < List.length);
    }
    body
    {
        return (method <= method.max)? List[method] : null;
    }

    /**************************************************************************

        Static constructor; populates the association map

     **************************************************************************/

    static this ( )
    {
        foreach (method, name; List)
        {
            methods_by_name[name] = cast (HttpMethod) method;
        }

        methods_by_name.rehash;
    }
}


unittest
{
    static assert(HttpMethodNames.List[HttpMethod.Get]     == "GET");
    static assert(HttpMethodNames.List[HttpMethod.Head]    == "HEAD");
    static assert(HttpMethodNames.List[HttpMethod.Post]    == "POST");
    static assert(HttpMethodNames.List[HttpMethod.Put]     == "PUT");
    static assert(HttpMethodNames.List[HttpMethod.Delete]  == "DELETE");
    static assert(HttpMethodNames.List[HttpMethod.Trace]   == "TRACE");
    static assert(HttpMethodNames.List[HttpMethod.Connect] == "CONNECT");
    static assert(HttpMethodNames.List[HttpMethod.Options] == "OPTIONS");

    static assert(!HttpMethodNames.List[HttpMethod.Undefined].length);

    assert(HttpMethodNames[HttpMethod.Get]     == "GET");
    assert(HttpMethodNames[HttpMethod.Head]    == "HEAD");
    assert(HttpMethodNames[HttpMethod.Post]    == "POST");
    assert(HttpMethodNames[HttpMethod.Put]     == "PUT");
    assert(HttpMethodNames[HttpMethod.Delete]  == "DELETE");
    assert(HttpMethodNames[HttpMethod.Trace]   == "TRACE");
    assert(HttpMethodNames[HttpMethod.Connect] == "CONNECT");
    assert(HttpMethodNames[HttpMethod.Options] == "OPTIONS");

    assert(!HttpMethodNames[HttpMethod.Undefined].length);

    assert(HttpMethodNames[cast(HttpMethod)(HttpMethod.max + 1)] is null);

    assert(HttpMethodNames["GET"]     == HttpMethod.Get);
    assert(HttpMethodNames["HEAD"]    == HttpMethod.Head);
    assert(HttpMethodNames["POST"]    == HttpMethod.Post);
    assert(HttpMethodNames["PUT"]     == HttpMethod.Put);
    assert(HttpMethodNames["DELETE"]  == HttpMethod.Delete);
    assert(HttpMethodNames["TRACE"]   == HttpMethod.Trace);
    assert(HttpMethodNames["CONNECT"] == HttpMethod.Connect);
    assert(HttpMethodNames["OPTIONS"] == HttpMethod.Options);

    assert(HttpMethodNames["SPAM"]    == HttpMethod.Undefined);
    assert(HttpMethodNames[""]        == HttpMethod.Undefined);
    assert(HttpMethodNames[null]      == HttpMethod.Undefined);
}
