/******************************************************************************

    HTTP response message generator

    Before rendering an HTTP response message, the names of all header fields
    the response may contain must be added, except the General-Header,
    Response-Header and Entity-Header fields specified in RFC 2616 section 4.5,
    6.2 and 7.1, respectively.
    Before calling render(), the values of these message header fields of
    interest can be assigned by the ParamSet (HttpResponse super class) methods.
    Header fields with a null value (which is the value reset() assigns to all
    fields) will be omitted when rendering the response message header.
    Specification of General-Header fields:

        See_Also: http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.5

    Specification of Request-Header fields:

        See_Also: http://www.w3.org/Protocols/rfc2616/rfc2616-sec6.html#sec6.2

    Specification of Entity-Header fields:

        See_Also: http://www.w3.org/Protocols/rfc2616/rfc2616-sec7.html#sec7.1

    For the definition of the categories the standard request message header
    fields are of

        See_Also: http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html#sec5

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.net.http.HttpResponse;


import ocean.transition;

import ocean.core.Verify;

import ocean.net.http.HttpConst : HttpResponseCode;

import ocean.net.http.message.HttpHeader;

import ocean.net.http.consts.StatusCodes: StatusPhrases;
import ocean.net.http.consts.HttpVersion: HttpVersion, HttpVersionIds;

import ocean.net.http.time.HttpTimeFormatter;

import ocean.util.container.AppendBuffer;

version (UnitTest)
    import ocean.core.Test;

/******************************************************************************/

class HttpResponse : HttpHeader
{
    /**************************************************************************

        Response HTTP version; defaults to HTTP/1.1

     **************************************************************************/

    private HttpVersion http_version_ = HttpVersion.v1_1;

    /**************************************************************************

        Content string buffer

     **************************************************************************/

    private AppendBuffer!(char) content;

    /**************************************************************************

        Header line appender

     **************************************************************************/

    private AppendHeaderLines append_header_lines;

    /**************************************************************************

        Time formatter

     **************************************************************************/

    private HttpTimeFormatter time;

    /**************************************************************************

        Decimal string buffer for Content-Length header value

     **************************************************************************/

    private char[ulong_dec_length] dec_content_length;

    /**************************************************************************

        Constructor

        Params:
            initial_buffer_size = the initial amount of memory to allocate to
                hold the rendered response. Will be extended if necessary.

     **************************************************************************/

    public this ( size_t initial_buffer_size = 1024 )
    {
        super(HeaderFieldNames.Response.NameList,
              HeaderFieldNames.Entity.NameList);

        this.append_header_lines = new AppendHeaderLines(
                this.content = new AppendBuffer!(char)(initial_buffer_size));
    }

    /**************************************************************************

        Renders the response message, using the 200 "OK" status code.
        If a message body is provided, the "Content-Length" header field will be
        set and, if head is false, msg_body will be copied into an internal
        buffer.

        Params:
            msg_body = response message body
            head     = set to true if msg_body should actually not be appended
                       to the response message (HEAD response)

        Returns:


     **************************************************************************/

    public cstring render ( cstring msg_body = null, bool head = false )
    {
        return this.render(HttpResponseCode.init, msg_body);
    }

    /**************************************************************************

        Renders the response message.
        If a message body is provided, it is appended to the response message
        according to RFC 2616, section 4.3; that is,
        - If status is either below 200 or 204 or 304, neither a message body
          nor a "Content-Length" header field are appended.
        - Otherwise, if head is true, a "Content-Length" header field reflecting
          msg_body.length is appended but the message body itself is not.
        - Otherwise, if head is false, both a "Content-Length" header field
          reflecting msg_body.length and the message body itself are appended.

        If a message body is not provided, the same is done as for a message
        body with a zero length.

        Params:
            status   = status code; must be at least 100 and less than 1000
            msg_body = response message body
            head     = set to true if msg_body should actually not be appended
                       to the response message (HEAD response)

        Returns:
            response message (exposes an internal buffer)

     **************************************************************************/

    public cstring render ( HttpResponseCode status, cstring msg_body = null,
        bool head = false )
    {
        verify(100 <= status, "invalid HTTP status code (below 100)");
        verify(status < 1000, "invalid HTTP status code (1000 or above)");

        bool append_msg_body = this.setContentLength(status, msg_body);

        this.content.clear();

        this.setStatusLine(status);

        this.setDate();

        foreach (key, val; super) if (val)
        {
            this.append_header_lines(key, val);
        }

        this.addHeaders(this.append_header_lines);

        this.content.append("\r\n"[],
                            (append_msg_body && !head)? msg_body : null);

        return this.content[];
    }

    /**************************************************************************

        Called by render() when a subclass may use append to add its response
        header lines.

        Example:

        ---

        class MyHttpResponse : HttpResponse
        {
            protected override addHeaders ( AppendHeaderLines append )
            {
                // append "Hello: World!\r\n"

                append("Hello", "World!");
            }
        }

        ---

        If the header field value of a header line needs to be assembled
        incrementally, the AppendHeaderLines.IncrementalValue may be used; see
        the documentation of that class below for further information.

        Params:
            append = header line appender

     **************************************************************************/

    protected void addHeaders ( AppendHeaderLines append ) { }

    /**************************************************************************

        Sets the content buffer length to the lowest currently possible value.

        Returns:
            this instance

     **************************************************************************/

    public typeof (this) minimizeContentBuffer ( )
    {
        this.content.minimize();

        return this;
    }

    /**************************************************************************

        Sets the Content-Length response message header.

        Params:
            status   = HTTP status code
            msg_body = HTTP response message body

        Returns:
            true if msg_body should be appended to the HTTP response or false
            if it should not be appended because a message body is not allowed
            with the provided status code.

     **************************************************************************/

    private bool setContentLength ( HttpResponseCode code, cstring msg_body )
    {
        switch (code)
        {
            default:
                if (code >= 200)
                {
                    bool b = super.set("Content-Length", msg_body.length, this.dec_content_length);
                    verify(b);

                    return true;
                }
                return false;

            case HttpResponseCode.NoContent:
                bool b = super.set("Content-Length", "0");
                verify(b);

                return false;

            case HttpResponseCode.NotModified:
                return false;
        }
    }

    /**************************************************************************

        Resets the content and renders the response status line.

        Params:
            status   = status code

        Returns:
            response status line

     **************************************************************************/

    private cstring setStatusLine ( HttpResponseCode status )
    {
        verify(this.http_version_ != 0, "HTTP version undefined");

        char[3] status_dec;

        return this.content.append(HttpVersionIds[this.http_version_],  " "[],
                                   super.writeUnsigned(status_dec, status), " "[],
                                   StatusPhrases[status],             "\r\n"[]);
    }

    /**************************************************************************

        Sets the Date message header to the current wall clock time if it is not
        already set.

     **************************************************************************/

    private void setDate ( )
    {
        super.access(HeaderFieldNames.General.Names.Date, (cstring, ref cstring val)
        {
            if (!val)
            {
                val = this.time.format();
            }
        });
    }

    /**************************************************************************

        Utility class; an instance is passed to addHeaders() to be used by a
        subclass to append a header line to the response message.

     **************************************************************************/

    protected static class AppendHeaderLines
    {
        /**********************************************************************

            Response content

         **********************************************************************/

        private AppendBuffer!(char) content;

        /**********************************************************************

            Constructor

            Params:
                content = response content

         **********************************************************************/

        this ( AppendBuffer!(char) content )
        {
            this.content = content;
        }

        /**********************************************************************

            Appends a response message header line; that is, appends
            name ~ ": " ~ value ~ "\r\n" to the response message content.

            Params:
                name  = header field name
                value = header field value

         **********************************************************************/

        typeof (this) opCall ( cstring name, cstring value )
        {
            this.content.append(name, ": "[], value, "\r\n"[]);

            return this;
        }

        /**********************************************************************

            true when an instance of AppendHeaderLine for this instance exists.

         **********************************************************************/

        private bool occupied = false;

        /**********************************************************************

            Utility class to append a response message header line where the
            value is appended incrementally.

            Usage in a HttpResponse subclass:

            ---

            class MyHttpResponse : HttpResponse
            {
                protected override addHeaders ( AppendHeaderLines append )
                {
                    // append "Hello: World!\r\n"

                    {
                        // constructor appends "Hello: "

                        scope inc_val = append.new IncrementalValue("Hello");

                         // append "Wor" ~ "ld!"

                        inc_val.appendToValue("Wor");
                        inc_val.appendToValue("ld!");

                        // destructor appends "\r\n"
                    }
                }
            }

            ---

            Note: At most one instance may exist at a time per outer instance.

         **********************************************************************/

        class IncrementalValue
        {
            /******************************************************************

                Constructor; opens a response message header line by appending
                name ~ ": " to the response message content.

                Params:
                    name = header field name

                In:
                    No other instance for the outer instance may currently
                    exist.

             ******************************************************************/

            this ( cstring name )
            {
                verify(!this.outer.occupied);
                this.outer.occupied = true;
                this.outer.content.append(name, ": "[]);
            }

            /******************************************************************

                Appends str to the header field value.

                Params:
                    chunk = header field value chunk

             ******************************************************************/

            void appendToValue ( cstring chunk )
            {
                this.outer.content ~= chunk;
            }

            /******************************************************************

                Destructor; closes a response message header line by appending
                "\r\n" to the response message content.

             ******************************************************************/

            ~this ( )
            {
                this.outer.content ~= "\r\n";
                this.outer.occupied = false;
            }
        }
    }
}

unittest
{
    static class MyHttpResponse : HttpResponse
    {
        protected override void addHeaders ( AppendHeaderLines append )
        {
            {
                scope key1 = append.new IncrementalValue("Key1");
            }

            {
                scope key2 = append.new IncrementalValue("Key2");
                key2.appendToValue("chunk1");
                key2.appendToValue("chunk2");
            }
        }
    }

    auto response = new MyHttpResponse;
    response["Date"] = "dummy";
    auto rendered = response.render();

    test!("==")(
        rendered,
        "HTTP/1.1 200 OK\r\nDate: dummy\r\nContent-Length: 0\r\n"
            ~ "Key1: \r\nKey2: chunk1chunk2\r\n\r\n"
    );
}
