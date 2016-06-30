/******************************************************************************

    HTTP session "cookie" attribute name constants as defined in RFC 2109

    @see http://www.w3.org/Protocols/rfc2109/rfc2109.txt

    Note: CookieAttributeNames contains the "expires" instead of the "max-age"
    cookie attribute name as defined in RFC 2109. The reason is that,
    unfortunately, the cross-browser compatibility of "expires" is much better
    than of "max-age".

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.net.http.consts.CookieAttributeNames;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;


/******************************************************************************/

struct CookieAttributeNames
{
    istring Comment, Domain,
           Expires,
           Path, Secure, Version;

    alias .CookieAttributeNameStrings   Names;
    alias .CookieAttributeNameList      NameList;
}

const CookieAttributeNames CookieAttributeNameStrings =
{
    Comment: "comment",
    Domain:  "domain",
    Expires: "expires",
    Path:    "path",
    Secure:  "secure",
    Version: "version"
};

istring[] CookieAttributeNameList ( )
{
    return _CookieAttributeNameList;
}

private istring[] _CookieAttributeNameList;

private istring[CookieAttributeNames.tupleof.length] CookieAttributeNameList_;

static this ( )
{
    foreach (i, name; CookieAttributeNameStrings.tupleof)
    {
        CookieAttributeNameList_[i] = name;
    }

    _CookieAttributeNameList = CookieAttributeNameList_;
}

/******************************************************************************/

unittest
{
    static assert(CookieAttributeNames.Names.Comment == "comment");
    static assert(CookieAttributeNames.Names.Domain  == "domain");
    static assert(CookieAttributeNames.Names.Expires == "expires");
    static assert(CookieAttributeNames.Names.Path    == "path");
    static assert(CookieAttributeNames.Names.Secure  == "secure");
    static assert(CookieAttributeNames.Names.Version == "version");

    foreach (i, attribute_name; CookieAttributeNames.Names.tupleof)
    {
        assert(_CookieAttributeNameList[i] == attribute_name,
               "mismatch of CookieAttributeNameList[" ~ i.stringof ~ ']');
    }
}
