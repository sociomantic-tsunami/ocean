/******************************************************************************

    HTTP request message parser

    Before parsing an HTTP request message, the names of all header fields whose
    values will be required must be added, except the General-Header and
    Request-Header fields specified in RFC 2616 section 4.5 and 5.3,
    respectively.
    After parse() has finished parsing the message hader, the values of these
    message header fields of interest can be obtained by the ParamSet
    (HttpRequest super class) methods. A null value indicates that the request
    message does not contain a header line whose name matches the corresponding
    key.
    Specification of General-Header fields:

    See_Also: http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.5

    Specification of Request-Header fields:

    See_Also: http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html#sec5.3

    Specification of Entity-Header fields:

    See_Also: http://www.w3.org/Protocols/rfc2616/rfc2616-sec7.html#sec7.1

    For the definition of the categories the standard request message header
    fields are of

    See_Also: http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html#sec5

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.net.http.HttpRequest;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.transition;

import ocean.net.http.message.HttpHeader;

import ocean.net.http.message.HttpHeaderParser,
       ocean.net.http.consts.HttpMethod,
       ocean.net.http.consts.StatusCodes: StatusCode;

import ocean.net.http.consts.HttpVersion: HttpVersionIds;

import ocean.net.http.HttpException: HttpException, HeaderParameterException;

import ocean.core.Enforce;
import ocean.net.Uri: Uri;

import ocean.net.http.HttpConst: HttpResponseCode;
import ocean.net.http.time.HttpTimeParser;

/******************************************************************************/

class HttpRequest : HttpHeader
{
    /**************************************************************************

        Maximum accepted request URI length

     **************************************************************************/

    public uint max_uri_length = 16 * 1024;

    /**************************************************************************

        Requested HTTP method

     **************************************************************************/

    public HttpMethod method;

    /**************************************************************************

        URI parser

     **************************************************************************/

    public Uri uri ( )
    {
        return this._uri;
    }

    private Uri _uri;

    /**************************************************************************

        Message header parser instance to get header parse results and set
        limitations.

     **************************************************************************/

    public IHttpHeaderParser header;

    /**************************************************************************

        Request message body

     **************************************************************************/

    private mstring msg_body_;

    /**************************************************************************

        Request message body position counter

     **************************************************************************/

    private size_t msg_body_pos;

    /**************************************************************************

        Message header parser

     **************************************************************************/

    private HttpHeaderParser parser;

    /**************************************************************************

        Tells whether the end of the message header has been reached and we are
        receiving the message body, if any

     **************************************************************************/

    private bool header_complete;

    /**************************************************************************

        Reusable exception instances

     **************************************************************************/

    package HttpException               http_exception;
    private HeaderParameterException    header_param_exception;

    /**************************************************************************

        Constructor

        If the server supports HTTP methods that expect a request message body
        (such as POST or PUT), set add_entity_headers to true to add the
        standard Entity header fields. (The standard General-Header and
        Request-Header fields are added automatically.)

        Note that a non-zero value for msg_body_prealloc_length is senseful only
        when requests with message body (POST, PUT etc.) are supported by this
        server.

        Params:
            add_entity_headers       = set to true to add the standard Entity
                                       header fields as well
            msg_body_prealloc_length = expected message body length for
                                       preallocation;

     **************************************************************************/

    public this ( bool add_entity_headers = false, size_t msg_body_prealloc_length = 0 )
    {
        super(HeaderFieldNames.Request.NameList,
              add_entity_headers? HeaderFieldNames.Entity.NameList : null);

        this.header = this.parser = new HttpHeaderParser;

        this._uri = new Uri;

        this.msg_body_ = new char[msg_body_prealloc_length];

        this.http_exception         = new HttpException;
        this.header_param_exception = new HeaderParameterException;

        this.reset();
    }

    /**************************************************************************

        ditto

     **************************************************************************/

    public this ( size_t msg_body_prealloc_length )
    {
        this(false, msg_body_prealloc_length);
    }


    version (D_Version2) {}
    else
    {
        /***********************************************************************

            Disposer

        ***********************************************************************/

        protected override void dispose ( )
        {
            super.dispose();

            delete this.parser;
            delete this._uri;
            delete this.msg_body_;
        }
    }

    /**************************************************************************

        Returns:
            slice to the method name in the message header start line if the
            start line has already been parsed or null otherwise

     **************************************************************************/

    public cstring method_name ( )
    {
        return this.parser.start_line_tokens[0];
    }

    /**************************************************************************

        Returns:
            URI instance which is set to the requested URI if the start line has
            already been parsed

     **************************************************************************/

    public cstring uri_string ( )
    {
        return this.parser.start_line_tokens[1];
    }

    /**************************************************************************

        Obtains the request message body (which may be empty). It may be
        incomplete if parse() did not yet reach the end of the request message
        or null if parse() did not yet reach the end of the request message
        header.

        Returns:
            request message body parsed so far or null if parse() did not yet
            reach the end of the request message header

     **************************************************************************/

    public cstring msg_body ( )
    {
        return this.msg_body_;
    }

    /**************************************************************************

        Obtains the integer value of the request header field corresponding to
        header_field_name. The header field value is expected to represent an
        unsigned integer number in decimal representation.

        Params:
            header_field_name = request header field name (case-insensitive;
                                must be one of the message header field values
                                of interest passed on instantiation)

        Returns:
            integer value of the request header field

        Throws:
            HeaderParameterException if
                - the field is missing in the header or
                - the field does not contain an unsigned integer value in
                  decimal representation.

     **************************************************************************/

    public uint getUint ( T = uint ) ( cstring header_field_name )
    {
        uint n;

        bool is_set,
             ok = super.getUnsigned(header_field_name, n, is_set);

        enforce(this.header_param_exception.set("Missing header parameter : ")
                .append(header_field_name),
                is_set);
        enforce(this.header_param_exception.set("Expected decimal unsigned integer for header : ")
                .append(header_field_name),
                ok);

        return n;
    }

    /**************************************************************************

        Parses content which is expected to be either the start of a HTTP
        message or a HTTP message fragment that continues the content passed on
        the last call to this method.
        If this method is called again after having finished, it will reset the
        status first and start parsing a new request message.

        Params:
            content         = content to parse
            msg_body_length = callback returning the message body length; will
                              be called at most once after the message header
                              has been parsed.

        Returns:
            number of elements consumed from content.

        Throws:
            HttpParseException
                - on parse error: if
                    * the number of start line tokens is different from 3 or
                    * a regular header_line does not contain a ':';
                - on limit excess: if
                    * the header size in bytes exceeds the requested limit or
                    * the number of header lines in exceeds the requested limit.

            HttpException if
                - the HTTP method is unknown or
                - the HTTP version identifier is unknown or
                - the URI is missing or
                - the URI length exceeds the requested max_uri_length.

            Note that msg_body_length() may throw a HttpException, especially if
                - the announced message body length exceeds an allowed limit or
                - the announced message body length cannot be determined because
                  header parameters are missing.

     **************************************************************************/

    public size_t parse ( cstring content, lazy size_t msg_body_length )
    {
        size_t consumed;

        if (this.finished)
        {
            this.reset();
        }

        if (this.header_complete)
        {
            consumed = this.appendMsgBody(content);
        }
        else
        {
            cstring msg_body_start = this.parser.parse(content);

            consumed = content.length - msg_body_start.length;

            if (msg_body_start !is null)
            {
                this.header_complete = true;

                this.setRequestLine();

                foreach (element; this.parser.header_elements)
                {
                    this.set(element.key, element.val);
                }

                this.msg_body_.length = msg_body_length();
                enableStomping(this.msg_body_);

                consumed += this.appendMsgBody(msg_body_start);
            }
        }

        assert (consumed == content.length || this.finished);

        return consumed;
    }

    /**************************************************************************

        Returns:
            true if parse() has finished parsing the message or false otherwise

     **************************************************************************/

    public bool finished ( )
    {
        return this.header_complete && this.msg_body_pos >= this.msg_body_.length;
    }

    /**************************************************************************

        Appends chunk to the message body as long as the message body length
        does not exceed the length reported to parse() by the msg_body_length
        parameter.

        Params:
            chunk = chunk to append to the message body

        Returns:
            number of elements appended

     **************************************************************************/

    private size_t appendMsgBody ( cstring chunk )
    {
        size_t len = min(chunk.length, this.msg_body_.length - this.msg_body_pos),
               end = this.msg_body_pos + len;

        this.msg_body_[this.msg_body_pos .. end] = chunk[0 .. len];

        this.msg_body_pos = end;

        return len;
    }

    /**************************************************************************

        Obtains the request line parameters.

        Throws:
            HttpException if
                - the HTTP method is unknown or
                - the HTTP version identifier is unknown or
                - the URI is missing or
                - the URI length exceeds the requested max_uri_length.

     **************************************************************************/

    private void setRequestLine ( )
    {
        this.method = HttpMethodNames[this.method_name];

        enforce(this.http_exception.set(StatusCode.BadRequest)
                .append(" : invalid HTTP method"),
                this.method);

        this.http_version_ = HttpVersionIds[this.parser.start_line_tokens[2]];

        if (!this.http_version_)
        {
            this.http_version_ = this.http_version_.v1_0;

            if (HttpVersionIds.validSyntax(this.parser.start_line_tokens[2]))
            {
                throw this.http_exception.set(StatusCode.VersionNotSupported);
            }
            else
            {
                throw this.http_exception.set(StatusCode.BadRequest)
                    .append(" : invalid HTTP version");
            }
        }

        enforce(this.http_exception.set(StatusCode.BadRequest)
                .append(" : no uri in request"),
                this.parser.start_line_tokens[1].length);
        enforce(this.http_exception.set(StatusCode.RequestURITooLarge),
                this.parser.start_line_tokens[1].length <= this.max_uri_length);

        this._uri.parse(this.parser.start_line_tokens[1]);
    }

    /**************************************************************************

        Resets the state

     **************************************************************************/

    public override void reset ( )
    {
        this.method          = this.method.init;
        this.http_version_   = this.http_version_.init;
        this.msg_body_pos    = 0;
        this.header_complete = false;
        this._uri.reset();
        this.parser.reset();

        super.reset();
    }

    /**************************************************************************

        Returns the minimum of a and b.

        Returns:
            minimum of a and b

     **************************************************************************/

    static size_t min ( size_t a, size_t b )
    {
        return ((a < b)? a : b);
    }
}

//version = OceanPerformanceTest;

version (OceanPerformanceTest)
{
    import ocean.io.Stdout_tango;
    import ocean.core.internal.gcInterface: gc_disable, gc_enable;
}

version ( UnitTest )
{
    import ocean.core.Test;
    import ocean.stdc.time: time;
    import ocean.stdc.posix.stdlib: srand48, drand48;
}

unittest
{
    const istring lorem_ipsum =
        "Lorem ipsum dolor sit amet, consectetur adipisici elit, sed eiusmod "
      ~ "tempor incidunt ut labore et dolore magna aliqua. Ut enim ad minim "
      ~ "veniam, quis nostrud exercitation ullamco laboris nisi ut aliquid ex "
      ~ "ea commodi consequat. Quis aute iure reprehenderit in voluptate velit "
      ~ "esse cillum dolore eu fugiat nulla pariatur. Excepteur sint obcaecat "
      ~ "cupiditat non proident, sunt in culpa qui officia deserunt mollit "
      ~ "anim id est laborum. Duis autem vel eum iriure dolor in hendrerit in "
      ~ "vulputate velit esse molestie consequat, vel illum dolore eu feugiat "
      ~ "nulla facilisis at vero eros et accumsan et iusto odio dignissim qui "
      ~ "blandit praesent luptatum zzril delenit augue duis dolore te feugait "
      ~ "nulla facilisi. Lorem ipsum dolor sit amet, consectetuer adipiscing "
      ~ "elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna "
      ~ "aliquam erat volutpat. Ut wisi enim ad minim veniam, quis nostrud "
      ~ "exerci tation ullamcorper suscipit lobortis nisl ut aliquip ex ea "
      ~ "commodo consequat. Duis autem vel eum iriure dolor in hendrerit in "
      ~ "vulputate velit esse molestie consequat, vel illum dolore eu feugiat "
      ~ "nulla facilisis at vero eros et accumsan et iusto odio dignissim qui "
      ~ "blandit praesent luptatum zzril delenit augue duis dolore te feugait "
      ~ "nulla facilisi. Nam liber tempor cum soluta nobis eleifend option "
      ~ "congue nihil imperdiet doming id quod mazim placerat facer possim "
      ~ "assum. Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed "
      ~ "diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam "
      ~ "erat volutpat. Ut wisi enim ad minim veniam, quis nostrud exerci "
      ~ "tation ullamcorper suscipit lobortis nisl ut aliquip ex ea commodo "
      ~ "consequat. Duis autem vel eum iriure dolor in hendrerit in vulputate "
      ~ "velit esse molestie consequat, vel illum dolore eu feugiat nulla "
      ~ "facilisis. At vero eos et accusam et justo duo dolores et ea rebum. "
      ~ "Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum "
      ~ "dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing "
      ~ "elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore "
      ~ "magna aliquyam erat, sed diam voluptua. At vero eos et accusam et "
      ~ "justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea "
      ~ "takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor "
      ~ "sit amet, consetetur sadipscing elitr, At accusam aliquyam diam diam "
      ~ "dolore dolores duo eirmod eos erat, et nonumy sed tempor et et "
      ~ "invidunt justo labore Stet clita ea et gubergren, kasd magna no "
      ~ "rebum. sanctus sea sed takimata ut vero voluptua. est Lorem ipsum "
      ~ "dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing "
      ~ "elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore "
      ~ "magna aliquyam erat. Consetetur sadipscing elitr, sed diam nonumy "
      ~ "eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed "
      ~ "diam voluptua. At vero eos et accusam et justo duo dolores et ea "
      ~ "rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem "
      ~ "ipsum dolor sit amet. Lorem ipsum dolor sit amet, consetetur "
      ~ "sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et "
      ~ "dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam "
      ~ "et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea "
      ~ "takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor "
      ~ "sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor "
      ~ "invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. "
      ~ "At vero eos et accusam et justo duo dolores et ea rebum. Stet clita "
      ~ "kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit "
      ~ "amet.";

    const istring content =
        "GET /dir?query=Hello%20World!&abc=def&ghi HTTP/1.1\r\n"
      ~ "Host: www.example.org:12345\r\n"
      ~ "User-Agent: Mozilla/5.0 (X11; U; Linux i686; de; rv:1.9.2.17) Gecko/20110422 Ubuntu/9.10 (karmic) Firefox/3.6.17\r\n"
      ~ "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\n"
      ~ "Accept-Language: de-de,de;q=0.8,en-us;q=0.5,en;q=0.3\r\n"
      ~ "Accept-Encoding: gzip,deflate\r\n"
      ~ "Accept-Charset: UTF-8,*\r\n"
      ~ "Keep-Alive: 115\r\n"
      ~ "Connection: keep-alive\r\n"
      ~ "Cache-Control: max-age=0\r\n"
      ~ "\r\n" ~
        lorem_ipsum;

    const parts = 3;

    /*
     * content will be split into parts parts where the length of each part is
     * content.length / parts + d with d a random number in the range
     * [-(content.length / parts) / 3, +(content.length / parts) / 3].
     */

    static size_t random_chunk_length ( )
    {
        const c = content.length * (2.0f / (parts * 3));

        static assert (c >= 3, "too many parts");

        return cast (size_t) (c + cast (float) drand48() * c);
    }

    scope request = new HttpRequest;

    request.addCustomHeaders("Keep-Alive");

    srand48(time(null));

    version (OceanPerformanceTest)
    {
        const n = 1000_000;
    }
    else
    {
        const n = 10;
    }

    version (OceanPerformanceTest)
    {
        gc_disable();

        scope (exit) gc_enable();
    }

    for (uint i = 0; i < n; i++)
    {
        {
            size_t len = request.min(random_chunk_length(), content.length),
                   ret = request.parse(content[0 .. len], lorem_ipsum.length);

            for (size_t pos = len; !request.finished; pos += len)
            {
                len = request.min(random_chunk_length() + pos, content.length - pos);
                ret = request.parse(content[pos .. pos + len], lorem_ipsum.length);
            }
        }

        test!("==")(request.method_name           ,"GET"[]);
        test!("==")(request.method                ,request.method.Get);
        test!("==")(request.uri_string            ,"/dir?query=Hello%20World!&abc=def&ghi"[]);
        test!("==")(request.http_version          ,request.http_version.v1_1);
        test!("==")(request["user-agent"]         ,"Mozilla/5.0 (X11; U; Linux i686; de; rv:1.9.2.17) Gecko/20110422 Ubuntu/9.10 (karmic) Firefox/3.6.17"[]);
        test!("==")(request["Accept"]             ,"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"[]);
        test!("==")(request["Accept-Language"]    ,"de-de,de;q=0.8,en-us;q=0.5,en;q=0.3"[]);
        test!("==")(request["Accept-Encoding"]    ,"gzip,deflate"[]);
        test!("==")(request["Accept-Charset"]     ,"UTF-8,*"[]);
        test!("==")(request.getUint("keep-alive"), 115);

        test!("==")(request["connection"]         ,"keep-alive"[]);

        test(request.msg_body == lorem_ipsum, ">" ~ request.msg_body ~ "<");

        version (OceanPerformanceTest)
        {
            uint j = i + 1;

            if (!(j % 10_000))
            {
                Stderr(HttpRequest.stringof)(' ')(j)("\n").flush();
            }
        }
    }
}
