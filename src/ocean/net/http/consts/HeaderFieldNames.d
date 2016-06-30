/******************************************************************************

    HTTP header field name constants

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.net.http.consts.HeaderFieldNames;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;


/******************************************************************************/

struct HeaderFieldNames
{
    /**************************************************************************

        General header fields for request and response
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.5

     **************************************************************************/

    struct General
    {
        istring CacheControl,        Connection,         Date,
                Pragma,              Trailer,            TransferEncoding,
                Upgrade,             Via,                Warning;

        alias HeaderFieldNames.GeneralNames    Names;
        alias HeaderFieldNames.GeneralNameList NameList;
    }

    /**************************************************************************

        Constant instance holding field names

     **************************************************************************/

    const General GeneralNames =
    {
        CacheControl:     "Cache-Control",
        Connection:       "Connection",
        Date:             "Date",
        Pragma:           "Pragma",
        Trailer:          "Trailer",
        TransferEncoding: "Transfer-Encoding",
        Upgrade:          "Upgrade",
        Via:              "Via",
        Warning:          "Warning"
    };

    /**************************************************************************

        List of field names.

        (Two arrays as a workaround for the issue that it is impossible to have
        run-time initialised static array constants.)

     **************************************************************************/

    public static istring[] GeneralNameList ( )
    {
        return _GeneralNameList;
    }

    private static istring[] _GeneralNameList;

    private static istring[GeneralNames.tupleof.length] GeneralNameList_;

    /**************************************************************************

        Request specific header fields in addition to the Genereal fields
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html#sec5.3

     **************************************************************************/

    struct Request
    {
        istring Accept,              AcceptCharset,      AcceptEncoding,
                AcceptLanguage,      Authorization,      Cookie,
                Expect,              From,               Host,
                IfMatch,             IfModifiedSince,    IfNoneMatch,
                IfRange,             IfUnmodifiedSince,  MaxForwards,
                ProxyAuthorization,  Range,              Referer,
                TE,                  UserAgent;

        alias HeaderFieldNames.RequestNames    Names;
        alias HeaderFieldNames.RequestNameList NameList;
    }

    /**********************************************************************

        Constant instance holding field names

     **********************************************************************/

    const Request RequestNames =
    {
        Accept:             "Accept",
        AcceptCharset:      "Accept-Charset",
        AcceptEncoding:     "Accept-Encoding",
        AcceptLanguage:     "Accept-Language",
        Authorization:      "Authorization",
        Cookie:             "Cookie",
        Expect:             "Expect",
        From:               "From",
        Host:               "Host",
        IfMatch:            "If-Match",
        IfModifiedSince:    "If-Modified-Since",
        IfNoneMatch:        "If-None-Match",
        IfRange:            "If-Range",
        IfUnmodifiedSince:  "If-Unmodified-Since",
        MaxForwards:        "Max-Forwards",
        ProxyAuthorization: "Proxy-Authorization",
        Range:              "Range",
        Referer:            "Referer",
        TE:                 "TE",
        UserAgent:          "User-Agent"
    };

    /**************************************************************************

        List of field names.

        (Two arrays as a workaround for the issue that it is impossible to have
        run-time initialised static array constants.)

     **************************************************************************/

    public static istring[] RequestNameList;

    private static istring[RequestNames.tupleof.length] RequestNameList_;

    /**************************************************************************

        Response specific header fields in addition to the Genereal fields
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec6.html#sec6.2

     **************************************************************************/

    struct Response
    {
        istring AcceptRanges,        Age,                ETag,
                Location,            ProxyAuthenticate,  RetryAfter,
                Server,              Vary,               WwwAuthenticate,
                Allow,               ContentEncoding,    ContentLanguage,
                ContentLength,       ContentLocation,    ContentMD5,
                ContentRange,        ContentType,        Expires,
                LastModified,        SetCookie;

        alias HeaderFieldNames.ResponseNames    Names;
        alias HeaderFieldNames.ResponseNameList NameList;
    }

    /**********************************************************************

        Constant instance holding field names

     **********************************************************************/

    const Response ResponseNames =
    {
        AcceptRanges:      "Accept-Ranges",
        Age:               "Age",
        ETag:              "ETag",
        Location:          "Location",
        ProxyAuthenticate: "Proxy-Authenticate",
        RetryAfter:        "Retry-After",
        Server:            "Server",
        Vary:              "Vary",
        WwwAuthenticate:   "WWW-Authenticate",
        Allow:             "Allow",
        ContentEncoding:   "Content-Encoding",
        ContentLanguage:   "Content-Language",
        ContentLength:     "Content-Length",
        ContentLocation:   "Content-Location",
        ContentMD5:        "Content-MD5",
        ContentRange:      "Content-Range",
        ContentType:       "Content-Type",
        Expires:           "Expires",
        LastModified:      "Last-Modified",
        SetCookie:         "Set-Cookie"
    };

    /**************************************************************************

        List of field names.

        (Two arrays as a workaround for the issue that it is impossible to have
        run-time initialised static array constants.)

     **************************************************************************/

    public static istring[] ResponseNameList;

    private static istring[ResponseNames.tupleof.length] ResponseNameList_;

    /**************************************************************************

        Entity header fields for requests/responses which support entities.
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec7.html#sec7.1

     **************************************************************************/

    struct Entity
    {
        istring Allow,               ContentEncoding,    ContentLanguage,
                ContentLength,       ContentLocation,    ContentMD5,
                ContentRange,        ContentType,        Expires,
                LastModified;

        alias HeaderFieldNames.EntityNames    Names;
        alias HeaderFieldNames.EntityNameList NameList;
    }

    /**********************************************************************

        Constant instance holding field names

     **********************************************************************/

    const Entity EntityNames =
    {
        Allow:           "Allow",
        ContentEncoding: "Content-Encoding",
        ContentLanguage: "Content-Language",
        ContentLength:   "Content-Length",
        ContentLocation: "Content-Location",
        ContentMD5:      "Content-MD5",
        ContentRange:    "Content-Range",
        ContentType:     "Content-Type",
        Expires:         "Expires",
        LastModified:    "Last-Modified"
    };

    /**************************************************************************

        List of field names.

        (Two arrays as a workaround for the issue that it is impossible to have
        run-time initialised static array constants.)

     **************************************************************************/

    public static istring[] EntityNameList;

    private static istring[EntityNames.tupleof.length] EntityNameList_;

    /**************************************************************************

        Static constructor, populates the lists of field names.

     **************************************************************************/

    static this ( )
    {
        foreach (i, name; GeneralNames.tupleof)
        {
            GeneralNameList_[i] = name;
        }

        _GeneralNameList = GeneralNameList_;

        foreach (i, name; RequestNames.tupleof)
        {
            RequestNameList_[i] = name;
        }

        RequestNameList = RequestNameList_;

        foreach (i, name; ResponseNames.tupleof)
        {
            ResponseNameList_[i] = name;
        }

        ResponseNameList = ResponseNameList_;

        foreach (i, name; EntityNames.tupleof)
        {
            EntityNameList_[i] = name;
        }

        EntityNameList = EntityNameList_;
    }

    // Assertion check for the struct members

    static assert(General.Names.CacheControl == "Cache-Control");
    static assert(General.Names.Connection == "Connection");
    static assert(General.Names.Date == "Date");
    static assert(General.Names.Pragma == "Pragma");
    static assert(General.Names.Trailer == "Trailer");
    static assert(General.Names.TransferEncoding == "Transfer-Encoding");
    static assert(General.Names.Upgrade == "Upgrade");
    static assert(General.Names.Via == "Via");
    static assert(General.Names.Warning == "Warning");

    static assert(Request.Names.Accept == "Accept");
    static assert(Request.Names.AcceptCharset == "Accept-Charset");
    static assert(Request.Names.AcceptEncoding == "Accept-Encoding");
    static assert(Request.Names.AcceptLanguage == "Accept-Language");
    static assert(Request.Names.Authorization == "Authorization");
    static assert(Request.Names.Cookie == "Cookie");
    static assert(Request.Names.Expect == "Expect");
    static assert(Request.Names.From == "From");
    static assert(Request.Names.Host == "Host");
    static assert(Request.Names.IfMatch == "If-Match");
    static assert(Request.Names.IfModifiedSince == "If-Modified-Since");
    static assert(Request.Names.IfNoneMatch == "If-None-Match");
    static assert(Request.Names.IfRange == "If-Range");
    static assert(Request.Names.IfUnmodifiedSince == "If-Unmodified-Since");
    static assert(Request.Names.MaxForwards == "Max-Forwards");
    static assert(Request.Names.ProxyAuthorization == "Proxy-Authorization");
    static assert(Request.Names.Range == "Range");
    static assert(Request.Names.Referer == "Referer");
    static assert(Request.Names.TE == "TE");
    static assert(Request.Names.UserAgent == "User-Agent");

    static assert(Response.Names.AcceptRanges == "Accept-Ranges");
    static assert(Response.Names.Age == "Age");
    static assert(Response.Names.ETag == "ETag");
    static assert(Response.Names.Location == "Location");
    static assert(Response.Names.ProxyAuthenticate == "Proxy-Authenticate");
    static assert(Response.Names.RetryAfter == "Retry-After");
    static assert(Response.Names.Server == "Server");
    static assert(Response.Names.Vary == "Vary");
    static assert(Response.Names.WwwAuthenticate == "WWW-Authenticate");
    static assert(Response.Names.Allow == "Allow");
    static assert(Response.Names.ContentEncoding == "Content-Encoding");
    static assert(Response.Names.ContentLanguage == "Content-Language");
    static assert(Response.Names.ContentLength == "Content-Length");
    static assert(Response.Names.ContentLocation == "Content-Location");
    static assert(Response.Names.ContentMD5 == "Content-MD5");
    static assert(Response.Names.ContentRange == "Content-Range");
    static assert(Response.Names.ContentType == "Content-Type");
    static assert(Response.Names.Expires == "Expires");
    static assert(Response.Names.LastModified == "Last-Modified");
    static assert(Response.Names.SetCookie == "Set-Cookie");

    static assert(Entity.Names.Allow == "Allow");
    static assert(Entity.Names.ContentEncoding == "Content-Encoding");
    static assert(Entity.Names.ContentLanguage == "Content-Language");
    static assert(Entity.Names.ContentLength == "Content-Length");
    static assert(Entity.Names.ContentLocation == "Content-Location");
    static assert(Entity.Names.ContentMD5 == "Content-MD5");
    static assert(Entity.Names.ContentRange == "Content-Range");
    static assert(Entity.Names.ContentType == "Content-Type");
    static assert(Entity.Names.Expires == "Expires");
    static assert(Entity.Names.LastModified == "Last-Modified");
}
