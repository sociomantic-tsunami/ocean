/*******************************************************************************

        Copyright:
            Copyright (c) 2004 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: April 2004

        Authors: Kris

*******************************************************************************/

module ocean.net.http.HttpConst;

import ocean.transition;

/*******************************************************************************

        Constants

*******************************************************************************/

struct HttpConst
{
        const istring Eol = "\r\n";
}

/*******************************************************************************

        Headers are distinct types in their own right. This is because they
        are somewhat optimized via a trailing ':' character.

*******************************************************************************/

struct HttpHeaderName
{
        cstring value;
}

/*******************************************************************************

        Define the traditional set of HTTP header names

*******************************************************************************/

struct HttpHeader
{
        // size of both the request & response buffer (per thread)
        const int IOBufferSize                 = 16 * 1024;

        // maximum length for POST parameters (to avoid DOS ...)
        const int MaxPostParamSize             = 4 * 1024;

        const HttpHeaderName Version           = {"HTTP/1.1"};
        const HttpHeaderName TextHtml          = {"text/html"};

        const HttpHeaderName Accept            = {"Accept:"};
        const HttpHeaderName AcceptCharset     = {"Accept-Charset:"};
        const HttpHeaderName AcceptEncoding    = {"Accept-Encoding:"};
        const HttpHeaderName AcceptLanguage    = {"Accept-Language:"};
        const HttpHeaderName AcceptRanges      = {"Accept-Ranges:"};
        const HttpHeaderName Age               = {"Age:"};
        const HttpHeaderName Allow             = {"Allow:"};
        const HttpHeaderName Authorization     = {"Authorization:"};
        const HttpHeaderName CacheControl      = {"Cache-Control:"};
        const HttpHeaderName Connection        = {"Connection:"};
        const HttpHeaderName ContentEncoding   = {"Content-Encoding:"};
        const HttpHeaderName ContentLanguage   = {"Content-Language:"};
        const HttpHeaderName ContentLength     = {"Content-Length:"};
        const HttpHeaderName ContentLocation   = {"Content-Location:"};
        const HttpHeaderName ContentRange      = {"Content-Range:"};
        const HttpHeaderName ContentType       = {"Content-Type:"};
        const HttpHeaderName Cookie            = {"Cookie:"};
        const HttpHeaderName Date              = {"Date:"};
        const HttpHeaderName ETag              = {"ETag:"};
        const HttpHeaderName Expect            = {"Expect:"};
        const HttpHeaderName Expires           = {"Expires:"};
        const HttpHeaderName From              = {"From:"};
        const HttpHeaderName Host              = {"Host:"};
        const HttpHeaderName Identity          = {"Identity:"};
        const HttpHeaderName IfMatch           = {"If-Match:"};
        const HttpHeaderName IfModifiedSince   = {"If-Modified-Since:"};
        const HttpHeaderName IfNoneMatch       = {"If-None-Match:"};
        const HttpHeaderName IfRange           = {"If-Range:"};
        const HttpHeaderName IfUnmodifiedSince = {"If-Unmodified-Since:"};
        const HttpHeaderName KeepAlive         = {"Keep-Alive:"};
        const HttpHeaderName LastModified      = {"Last-Modified:"};
        const HttpHeaderName Location          = {"Location:"};
        const HttpHeaderName MaxForwards       = {"Max-Forwards:"};
        const HttpHeaderName MimeVersion       = {"MIME-Version:"};
        const HttpHeaderName Pragma            = {"Pragma:"};
        const HttpHeaderName ProxyAuthenticate = {"Proxy-Authenticate:"};
        const HttpHeaderName ProxyConnection   = {"Proxy-Connection:"};
        const HttpHeaderName Range             = {"Range:"};
        const HttpHeaderName Referrer          = {"Referer:"};
        const HttpHeaderName RetryAfter        = {"Retry-After:"};
        const HttpHeaderName Server            = {"Server:"};
        const HttpHeaderName ServletEngine     = {"Servlet-Engine:"};
        const HttpHeaderName SetCookie         = {"Set-Cookie:"};
        const HttpHeaderName SetCookie2        = {"Set-Cookie2:"};
        const HttpHeaderName TE                = {"TE:"};
        const HttpHeaderName Trailer           = {"Trailer:"};
        const HttpHeaderName TransferEncoding  = {"Transfer-Encoding:"};
        const HttpHeaderName Upgrade           = {"Upgrade:"};
        const HttpHeaderName UserAgent         = {"User-Agent:"};
        const HttpHeaderName Vary              = {"Vary:"};
        const HttpHeaderName Warning           = {"Warning:"};
        const HttpHeaderName WwwAuthenticate   = {"WWW-Authenticate:"};
}


/*******************************************************************************

        Declare the traditional set of HTTP response codes

*******************************************************************************/

enum HttpResponseCode
{
        OK                           = 200,

        Continue                     = 100,
        SwitchingProtocols           = 101,
        Created                      = 201,
        Accepted                     = 202,
        NonAuthoritativeInformation  = 203,
        NoContent                    = 204,
        ResetContent                 = 205,
        PartialContent               = 206,
        MultipleChoices              = 300,
        MovedPermanently             = 301,
        Found                        = 302,
        SeeOther                     = 303,
        NotModified                  = 304,
        UseProxy                     = 305,
        TemporaryRedirect            = 307,
        BadRequest                   = 400,
        Unauthorized                 = 401,
        PaymentRequired              = 402,
        Forbidden                    = 403,
        NotFound                     = 404,
        MethodNotAllowed             = 405,
        NotAcceptable                = 406,
        ProxyAuthenticationRequired  = 407,
        RequestTimeout               = 408,
        Conflict                     = 409,
        Gone                         = 410,
        LengthRequired               = 411,
        PreconditionFailed           = 412,
        RequestEntityTooLarge        = 413,
        RequestURITooLarge           = 414,
        UnsupportedMediaType         = 415,
        RequestedRangeNotSatisfiable = 416,
        ExpectationFailed            = 417,
        InternalServerError          = 500,
        NotImplemented               = 501,
        BadGateway                   = 502,
        ServiceUnavailable           = 503,
        GatewayTimeout               = 504,
        VersionNotSupported          = 505
}

static assert(HttpResponseCode.init == HttpResponseCode.OK);

/*******************************************************************************

        Status is a compound type, with a name and a code.

*******************************************************************************/

struct HttpStatus
{
        int     code;
        char[]  name;
}

/*******************************************************************************

        Declare the traditional set of HTTP responses

*******************************************************************************/

struct HttpResponses
{
        static Const!(HttpStatus) Continue                     = {HttpResponseCode.Continue, "Continue"};
        static Const!(HttpStatus) SwitchingProtocols           = {HttpResponseCode.SwitchingProtocols, "SwitchingProtocols"};
        static Const!(HttpStatus) OK                           = {HttpResponseCode.OK, "OK"};
        static Const!(HttpStatus) Created                      = {HttpResponseCode.Created, "Created"};
        static Const!(HttpStatus) Accepted                     = {HttpResponseCode.Accepted, "Accepted"};
        static Const!(HttpStatus) NonAuthoritativeInformation  = {HttpResponseCode.NonAuthoritativeInformation, "NonAuthoritativeInformation"};
        static Const!(HttpStatus) NoContent                    = {HttpResponseCode.NoContent, "NoContent"};
        static Const!(HttpStatus) ResetContent                 = {HttpResponseCode.ResetContent, "ResetContent"};
        static Const!(HttpStatus) PartialContent               = {HttpResponseCode.PartialContent, "PartialContent"};
        static Const!(HttpStatus) MultipleChoices              = {HttpResponseCode.MultipleChoices, "MultipleChoices"};
        static Const!(HttpStatus) MovedPermanently             = {HttpResponseCode.MovedPermanently, "MovedPermanently"};
        static Const!(HttpStatus) Found                        = {HttpResponseCode.Found, "Found"};
        static Const!(HttpStatus) TemporaryRedirect            = {HttpResponseCode.TemporaryRedirect, "TemporaryRedirect"};
        static Const!(HttpStatus) SeeOther                     = {HttpResponseCode.SeeOther, "SeeOther"};
        static Const!(HttpStatus) NotModified                  = {HttpResponseCode.NotModified, "NotModified"};
        static Const!(HttpStatus) UseProxy                     = {HttpResponseCode.UseProxy, "UseProxy"};
        static Const!(HttpStatus) BadRequest                   = {HttpResponseCode.BadRequest, "BadRequest"};
        static Const!(HttpStatus) Unauthorized                 = {HttpResponseCode.Unauthorized, "Unauthorized"};
        static Const!(HttpStatus) PaymentRequired              = {HttpResponseCode.PaymentRequired, "PaymentRequired"};
        static Const!(HttpStatus) Forbidden                    = {HttpResponseCode.Forbidden, "Forbidden"};
        static Const!(HttpStatus) NotFound                     = {HttpResponseCode.NotFound, "NotFound"};
        static Const!(HttpStatus) MethodNotAllowed             = {HttpResponseCode.MethodNotAllowed, "MethodNotAllowed"};
        static Const!(HttpStatus) NotAcceptable                = {HttpResponseCode.NotAcceptable, "NotAcceptable"};
        static Const!(HttpStatus) ProxyAuthenticationRequired  = {HttpResponseCode.ProxyAuthenticationRequired, "ProxyAuthenticationRequired"};
        static Const!(HttpStatus) RequestTimeout               = {HttpResponseCode.RequestTimeout, "RequestTimeout"};
        static Const!(HttpStatus) Conflict                     = {HttpResponseCode.Conflict, "Conflict"};
        static Const!(HttpStatus) Gone                         = {HttpResponseCode.Gone, "Gone"};
        static Const!(HttpStatus) LengthRequired               = {HttpResponseCode.LengthRequired, "LengthRequired"};
        static Const!(HttpStatus) PreconditionFailed           = {HttpResponseCode.PreconditionFailed, "PreconditionFailed"};
        static Const!(HttpStatus) RequestEntityTooLarge        = {HttpResponseCode.RequestEntityTooLarge, "RequestEntityTooLarge"};
        static Const!(HttpStatus) RequestURITooLarge           = {HttpResponseCode.RequestURITooLarge, "RequestURITooLarge"};
        static Const!(HttpStatus) UnsupportedMediaType         = {HttpResponseCode.UnsupportedMediaType, "UnsupportedMediaType"};
        static Const!(HttpStatus) RequestedRangeNotSatisfiable = {HttpResponseCode.RequestedRangeNotSatisfiable, "RequestedRangeNotSatisfiable"};
        static Const!(HttpStatus) ExpectationFailed            = {HttpResponseCode.ExpectationFailed, "ExpectationFailed"};
        static Const!(HttpStatus) InternalServerError          = {HttpResponseCode.InternalServerError, "InternalServerError"};
        static Const!(HttpStatus) NotImplemented               = {HttpResponseCode.NotImplemented, "NotImplemented"};
        static Const!(HttpStatus) BadGateway                   = {HttpResponseCode.BadGateway, "BadGateway"};
        static Const!(HttpStatus) ServiceUnavailable           = {HttpResponseCode.ServiceUnavailable, "ServiceUnavailable"};
        static Const!(HttpStatus) GatewayTimeout               = {HttpResponseCode.GatewayTimeout, "GatewayTimeout"};
        static Const!(HttpStatus) VersionNotSupported          = {HttpResponseCode.VersionNotSupported, "VersionNotSupported"};
}
