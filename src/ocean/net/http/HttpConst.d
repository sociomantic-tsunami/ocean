/*******************************************************************************

        Copyright:
            Copyright (c) 2004 Kris Bell.
            Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
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
        enum istring Eol = "\r\n";
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
        enum int IOBufferSize                 = 16 * 1024;

        // maximum length for POST parameters (to avoid DOS ...)
        enum int MaxPostParamSize             = 4 * 1024;

        enum HttpHeaderName Version           = {"HTTP/1.1"};
        enum HttpHeaderName TextHtml          = {"text/html"};

        enum HttpHeaderName Accept            = {"Accept:"};
        enum HttpHeaderName AcceptCharset     = {"Accept-Charset:"};
        enum HttpHeaderName AcceptEncoding    = {"Accept-Encoding:"};
        enum HttpHeaderName AcceptLanguage    = {"Accept-Language:"};
        enum HttpHeaderName AcceptRanges      = {"Accept-Ranges:"};
        enum HttpHeaderName Age               = {"Age:"};
        enum HttpHeaderName Allow             = {"Allow:"};
        enum HttpHeaderName Authorization     = {"Authorization:"};
        enum HttpHeaderName CacheControl      = {"Cache-Control:"};
        enum HttpHeaderName Connection        = {"Connection:"};
        enum HttpHeaderName ContentEncoding   = {"Content-Encoding:"};
        enum HttpHeaderName ContentLanguage   = {"Content-Language:"};
        enum HttpHeaderName ContentLength     = {"Content-Length:"};
        enum HttpHeaderName ContentLocation   = {"Content-Location:"};
        enum HttpHeaderName ContentRange      = {"Content-Range:"};
        enum HttpHeaderName ContentType       = {"Content-Type:"};
        enum HttpHeaderName Cookie            = {"Cookie:"};
        enum HttpHeaderName Date              = {"Date:"};
        enum HttpHeaderName ETag              = {"ETag:"};
        enum HttpHeaderName Expect            = {"Expect:"};
        enum HttpHeaderName Expires           = {"Expires:"};
        enum HttpHeaderName From              = {"From:"};
        enum HttpHeaderName Host              = {"Host:"};
        enum HttpHeaderName Identity          = {"Identity:"};
        enum HttpHeaderName IfMatch           = {"If-Match:"};
        enum HttpHeaderName IfModifiedSince   = {"If-Modified-Since:"};
        enum HttpHeaderName IfNoneMatch       = {"If-None-Match:"};
        enum HttpHeaderName IfRange           = {"If-Range:"};
        enum HttpHeaderName IfUnmodifiedSince = {"If-Unmodified-Since:"};
        enum HttpHeaderName KeepAlive         = {"Keep-Alive:"};
        enum HttpHeaderName LastModified      = {"Last-Modified:"};
        enum HttpHeaderName Location          = {"Location:"};
        enum HttpHeaderName MaxForwards       = {"Max-Forwards:"};
        enum HttpHeaderName MimeVersion       = {"MIME-Version:"};
        enum HttpHeaderName Pragma            = {"Pragma:"};
        enum HttpHeaderName ProxyAuthenticate = {"Proxy-Authenticate:"};
        enum HttpHeaderName ProxyConnection   = {"Proxy-Connection:"};
        enum HttpHeaderName Range             = {"Range:"};
        enum HttpHeaderName Referrer          = {"Referer:"};
        enum HttpHeaderName RetryAfter        = {"Retry-After:"};
        enum HttpHeaderName Server            = {"Server:"};
        enum HttpHeaderName ServletEngine     = {"Servlet-Engine:"};
        enum HttpHeaderName SetCookie         = {"Set-Cookie:"};
        enum HttpHeaderName SetCookie2        = {"Set-Cookie2:"};
        enum HttpHeaderName TE                = {"TE:"};
        enum HttpHeaderName Trailer           = {"Trailer:"};
        enum HttpHeaderName TransferEncoding  = {"Transfer-Encoding:"};
        enum HttpHeaderName Upgrade           = {"Upgrade:"};
        enum HttpHeaderName UserAgent         = {"User-Agent:"};
        enum HttpHeaderName Vary              = {"Vary:"};
        enum HttpHeaderName Warning           = {"Warning:"};
        enum HttpHeaderName WwwAuthenticate   = {"WWW-Authenticate:"};
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
        static const(HttpStatus) Continue                     = {HttpResponseCode.Continue, "Continue"};
        static const(HttpStatus) SwitchingProtocols           = {HttpResponseCode.SwitchingProtocols, "SwitchingProtocols"};
        static const(HttpStatus) OK                           = {HttpResponseCode.OK, "OK"};
        static const(HttpStatus) Created                      = {HttpResponseCode.Created, "Created"};
        static const(HttpStatus) Accepted                     = {HttpResponseCode.Accepted, "Accepted"};
        static const(HttpStatus) NonAuthoritativeInformation  = {HttpResponseCode.NonAuthoritativeInformation, "NonAuthoritativeInformation"};
        static const(HttpStatus) NoContent                    = {HttpResponseCode.NoContent, "NoContent"};
        static const(HttpStatus) ResetContent                 = {HttpResponseCode.ResetContent, "ResetContent"};
        static const(HttpStatus) PartialContent               = {HttpResponseCode.PartialContent, "PartialContent"};
        static const(HttpStatus) MultipleChoices              = {HttpResponseCode.MultipleChoices, "MultipleChoices"};
        static const(HttpStatus) MovedPermanently             = {HttpResponseCode.MovedPermanently, "MovedPermanently"};
        static const(HttpStatus) Found                        = {HttpResponseCode.Found, "Found"};
        static const(HttpStatus) TemporaryRedirect            = {HttpResponseCode.TemporaryRedirect, "TemporaryRedirect"};
        static const(HttpStatus) SeeOther                     = {HttpResponseCode.SeeOther, "SeeOther"};
        static const(HttpStatus) NotModified                  = {HttpResponseCode.NotModified, "NotModified"};
        static const(HttpStatus) UseProxy                     = {HttpResponseCode.UseProxy, "UseProxy"};
        static const(HttpStatus) BadRequest                   = {HttpResponseCode.BadRequest, "BadRequest"};
        static const(HttpStatus) Unauthorized                 = {HttpResponseCode.Unauthorized, "Unauthorized"};
        static const(HttpStatus) PaymentRequired              = {HttpResponseCode.PaymentRequired, "PaymentRequired"};
        static const(HttpStatus) Forbidden                    = {HttpResponseCode.Forbidden, "Forbidden"};
        static const(HttpStatus) NotFound                     = {HttpResponseCode.NotFound, "NotFound"};
        static const(HttpStatus) MethodNotAllowed             = {HttpResponseCode.MethodNotAllowed, "MethodNotAllowed"};
        static const(HttpStatus) NotAcceptable                = {HttpResponseCode.NotAcceptable, "NotAcceptable"};
        static const(HttpStatus) ProxyAuthenticationRequired  = {HttpResponseCode.ProxyAuthenticationRequired, "ProxyAuthenticationRequired"};
        static const(HttpStatus) RequestTimeout               = {HttpResponseCode.RequestTimeout, "RequestTimeout"};
        static const(HttpStatus) Conflict                     = {HttpResponseCode.Conflict, "Conflict"};
        static const(HttpStatus) Gone                         = {HttpResponseCode.Gone, "Gone"};
        static const(HttpStatus) LengthRequired               = {HttpResponseCode.LengthRequired, "LengthRequired"};
        static const(HttpStatus) PreconditionFailed           = {HttpResponseCode.PreconditionFailed, "PreconditionFailed"};
        static const(HttpStatus) RequestEntityTooLarge        = {HttpResponseCode.RequestEntityTooLarge, "RequestEntityTooLarge"};
        static const(HttpStatus) RequestURITooLarge           = {HttpResponseCode.RequestURITooLarge, "RequestURITooLarge"};
        static const(HttpStatus) UnsupportedMediaType         = {HttpResponseCode.UnsupportedMediaType, "UnsupportedMediaType"};
        static const(HttpStatus) RequestedRangeNotSatisfiable = {HttpResponseCode.RequestedRangeNotSatisfiable, "RequestedRangeNotSatisfiable"};
        static const(HttpStatus) ExpectationFailed            = {HttpResponseCode.ExpectationFailed, "ExpectationFailed"};
        static const(HttpStatus) InternalServerError          = {HttpResponseCode.InternalServerError, "InternalServerError"};
        static const(HttpStatus) NotImplemented               = {HttpResponseCode.NotImplemented, "NotImplemented"};
        static const(HttpStatus) BadGateway                   = {HttpResponseCode.BadGateway, "BadGateway"};
        static const(HttpStatus) ServiceUnavailable           = {HttpResponseCode.ServiceUnavailable, "ServiceUnavailable"};
        static const(HttpStatus) GatewayTimeout               = {HttpResponseCode.GatewayTimeout, "GatewayTimeout"};
        static const(HttpStatus) VersionNotSupported          = {HttpResponseCode.VersionNotSupported, "VersionNotSupported"};
}
