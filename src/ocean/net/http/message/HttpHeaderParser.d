/******************************************************************************

    HTTP message header parser

    Link with

        -L-lglib-2.0

    .

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.net.http.message.HttpHeaderParser;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.transition;
import ocean.core.Enforce;
import ocean.text.util.SplitIterator: ChrSplitIterator, ISplitIterator;

import ocean.net.http.HttpException: HttpParseException;

public alias long ssize_t;

/******************************************************************************

    Searches the haystack[0 .. haystack_len], if haystack_len is >= 0, for the
    first occurrence of the string needle. If haystack[0 .. haystack_len]
    contains a NUL byte, the search will stop there.
    If haystack_len is -1, haystack is assumed to be a NUL-terminated string and
    needle is searched in the whole haystack string.

    This is a GLib function.

    @see http://developer.gnome.org/glib/stable/glib-String-Utility-Functions.html#g-strstr-len

    Params:
        haystack     = haystack.ptr for haystack_len >= 0 or a pointer to a
                       NUL-terminated string if haystack_len = -1
        haystack_len = haystack.length or -1 if haystack is NUL-terminated
        needle       = the string to search for (NUL-terminated)

    Returns:
        a pointer to the found occurrence, or null if not found.

 ******************************************************************************/

extern (C) private char* g_strstr_len(Const!(char)* haystack, ssize_t haystack_len, Const!(char)* needle);

/******************************************************************************

    Interface for the header parser to get the parse results and set limits

 ******************************************************************************/

interface IHttpHeaderParser
{
    /**************************************************************************

        Header element

     **************************************************************************/

    struct HeaderElement
    {
        cstring key, val;
    }

    /**************************************************************************

        Obtains a list of HeaderElement instances referring to the header lines
        parsed so far. The key member of each element references the slice of
        the corresponding header line before the first ':', the val member the
        slice after the first ':'. Leading and tailing white space is trimmed
        off both key and val.

        Returns:
            list of HeaderElement instances referring to the header lines parsed
            so far

     **************************************************************************/

    HeaderElement[] header_elements ( );

    /**************************************************************************

        Returns:
            list of the the header lines parsed so far

     **************************************************************************/

    cstring[] header_lines ( );

    /**************************************************************************

        Returns:
            limit for the number of HTTP message header lines

     **************************************************************************/

    size_t header_lines_limit ( );

    /**************************************************************************

        Sets the limit for the number of HTTP message header lines.

        Note: A buffer size is set to n elements so use a realistic value (not
              uint.max for example).

        Params:
            n = limit for the number of HTTP message header lines

        Returns:
           limit for the number of HTTP message header lines

     **************************************************************************/

    size_t header_lines_limit ( size_t n );

    /**************************************************************************

        Returns:
            limit for the number of HTTP message header lines

     **************************************************************************/

    size_t header_length_limit ( );

    /**************************************************************************

        Sets the HTTP message header size limit. This will reset the parse
        state and clear the content.

        Note: A buffer size is set to n elements so use a realistic value (not
              uint.max for example).

        Params:
            n = HTTP message header size limit

        Returns:
            HTTP message header size limit

     **************************************************************************/

    size_t header_length_limit ( size_t n );
}

/******************************************************************************

    HttpHeaderParser class

 ******************************************************************************/

class HttpHeaderParser : IHttpHeaderParser
{
    /***************************************************************************

         Object pool index -- allows the construction of a pool of objects of
         this type.

    ***************************************************************************/

    public size_t object_pool_index;

    /**************************************************************************

        Default values for header size limitation

     **************************************************************************/

    const size_t DefaultSizeLimit  = 16 * 1024,
                 DefaultLinesLimit = 64;

    /**************************************************************************

        Header lines split iterator

     **************************************************************************/

    private static scope class SplitHeaderLines : ISplitIterator
    {
        /**************************************************************************

            End-of-header-line token

         **************************************************************************/

        const EndOfHeaderLine = "\r\n";

        /**************************************************************************

            Locates the first occurrence of the current delimiter string in str,
            starting from str[start].

            Params:
                 str     = string to scan for delimiter
                 start   = search start index

            Returns:
                 index of first occurrence of the current delimiter string in str or
                 str.length if not found

         **************************************************************************/

        public override size_t locateDelim ( cstring str, size_t start = 0 )
        in
        {
            assert (start < str.length, typeof (this).stringof ~ ".locateDelim: start index out of range");
        }
        body
        {
            char* item = g_strstr_len(str.ptr + start, str.length - start, this.EndOfHeaderLine.ptr);

            return item? item - str.ptr : str.length;
        }

        /**************************************************************************

            Skips the delimiter which str starts with.
            Note that the result is correct only if str really starts with a
            delimiter.

            Params:
                str = string starting with delimiter

            Returns:
                index of the first character after the starting delimiter in str

         **************************************************************************/

        protected override size_t skipDelim ( cstring str )
        in
        {
            assert (str.length >= this.EndOfHeaderLine.length);
        }
        body
        {
            return this.EndOfHeaderLine.length;
        }
    }

    /**************************************************************************

         HTTP message header content buffer.
         content.length determines the header length limit.

     **************************************************************************/

    private mstring content;

    /**************************************************************************

         Length of actual data in content.

     **************************************************************************/

    private size_t content_length;

    /**************************************************************************

        Position (index) in the content up to which the content has already been
        parsed

     **************************************************************************/

    private size_t pos       = 0;

    /**************************************************************************

        false after reset() and before the start line is complete

     **************************************************************************/

    private bool have_start_line = false;

    /**************************************************************************

        Number of header lines parsed so far, excluding the start line

     **************************************************************************/

    private size_t n_header_lines = 0;

    /**************************************************************************

        Header lines, excluding the start line; elements slice this.content.

     **************************************************************************/

    private cstring[] header_lines_;

    /**************************************************************************

        Header elements

        "key" references the slice of the corresponding header line before the
        first ':' and "val" after the first ':'. Leading and tailing white space
        is trimmed off both key and val.

     **************************************************************************/

    private HeaderElement[] header_elements_;

    /**************************************************************************

        Reusable exception instance

     **************************************************************************/

    private HttpParseException exception;

    /**************************************************************************

        Indicates that the header is complete

     **************************************************************************/

    private bool finished = false;

    /**************************************************************************

        Counter consistency check

     **************************************************************************/

    invariant ( )
    {
        assert (this.pos <= this.content_length);
        assert (this.header_elements_.length == this.header_lines_.length);
        assert (this.n_header_lines <= this.header_lines_.length);

        assert (this.content_length <= this.content.length);
    }

    /**************************************************************************

        Constructor

     **************************************************************************/

    public this ( )
    {
        this(this.DefaultSizeLimit, this.DefaultLinesLimit);
    }

    /**************************************************************************

        Constructor

        Note: Each a buffer with size_limit and lines_limit elements is
              allocated so use realistic values (not uint.max for example).

        Params:
            size_limit  = HTTP message header size limit
            lines_limit = limit for the number of HTTP message header lines

     **************************************************************************/

    public this ( size_t size_limit, size_t lines_limit )
    {
        this.exception        = new HttpParseException;
        this.content          = new char[size_limit];
        this.header_lines_    = new cstring[lines_limit];
        this.header_elements_ = new HeaderElement[lines_limit];
    }


    version (D_Version2) {}
    else
    {
        /***********************************************************************

            Called immediately when this instance is deleted.
            (Must be protected to prevent an invariant from failing.)

        ***********************************************************************/

        protected override void dispose ( )
        {
            this.start_line_tokens[] = null;

            delete this.content;
            delete this.header_lines_;
            delete this.header_elements_;
        }
    }


    /**************************************************************************

        Start line tokens; slice the internal content buffer

     **************************************************************************/

    public cstring[3] start_line_tokens;

    /**************************************************************************

        Obtains a list of HeaderElement instances referring to the header lines
        parsed so far. The key member of each element references the slice of
        the corresponding header line before the first ':', the val member the
        slice after the first ':'. Leading and tailing white space is trimmed
        off both key and val.

        Returns:
            list of HeaderElement instances referring to the header lines parsed
            so far

     **************************************************************************/

    public override HeaderElement[] header_elements ( )
    {
        return this.header_elements_[0 .. this.n_header_lines];
    }

    /**************************************************************************

        Returns:
            list of the the header lines parsed so far

     **************************************************************************/

    public cstring[] header_lines ( )
    {
        return this.header_lines_[0 .. this.n_header_lines];
    }

    /**************************************************************************

        Returns:
            limit for the number of HTTP message header lines

     **************************************************************************/

    public override size_t header_lines_limit ( )
    {
        return this.header_lines_.length;
    }

    /**************************************************************************

        Sets the limit for the number of HTTP message header lines.

        Note: A buffer size is set to n elements so use a realistic value (not
              uint.max for example).

        Params:
            n = limit for the number of HTTP message header lines

        Returns:
           limit for the number of HTTP message header lines

     **************************************************************************/

    public override size_t header_lines_limit ( size_t n )
    {
        if (this.n_header_lines > n)
        {
            this.n_header_lines = n;
        }

        return this.header_lines_.length = n;
    }

    /**************************************************************************

        Returns:
            HTTP message header size limit

     **************************************************************************/

    public override size_t header_length_limit ( )
    {
        return this.content.length;
    }

    /**************************************************************************

        Sets the HTTP message header size limit. This will reset the parse
        state and clear the content.

        Note: A buffer size is set to n elements so use a realistic value (not
              uint.max for example).

        Params:
            n = HTTP message header size limit

        Returns:
            HTTP message header size limit

     **************************************************************************/

    public override size_t header_length_limit ( size_t n )
    {
        this.reset();

        return this.content.length = n;
    }

    /**************************************************************************

        Resets the parse state and clears the content.

        Returns:
            this instance

     **************************************************************************/

    typeof (this) reset ( )
    {
        this.start_line_tokens[] = null;

        this.pos            = 0;
        this.content_length = 0;

        this.n_header_lines = 0;

        this.have_start_line = false;
        this.finished        = false;

        return this;
    }

    /**************************************************************************

        Parses content which is expected to be either the start of a HTTP
        message or a HTTP message fragment that continues the content passed on
        the last call to this method. Appends the slice of content which is part
        of the HTTP message header (that is, everything before the end-of-header
        token "\r\n\r\n" or content itself if it does not contain that token).
        After the end of the message header has been reached, which is indicated
        by a non-null return value, reset() must be called before calling this
        method again.
        Leading empty header lines are tolerated and ignored:

            "In the interest of robustness, servers SHOULD ignore any empty
            line(s) received where a Request-Line is expected."

            @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.1

        Returns:
            A slice of content after the end-of-header token (which may be an
            empty string) or null if content does not contain the end-of-header
            token.

        Throws:
            HttpParseException
                - on parse error: if
                    * the number of start line tokens is different from 3 or
                    * a regular header_line does not contain a ':';
                - on limit excess: if
                    * the header size in bytes exceeds the requested limit or
                    * the number of header lines in exceeds the requested limit.

            Assert()s that this method is not called after the end of header had
            been reacched.

     **************************************************************************/

    public cstring parse ( cstring content )
    in
    {
        assert (!this.finished, "parse() called after finished");
    }
    body
    {
        cstring msg_body_start = null;

        scope split_header = new SplitHeaderLines;

        split_header.include_remaining = false;

        cstring content_remaining = this.appendContent(content);

        foreach (header_line; split_header.reset(this.content[this.pos .. this.content_length]))
        {
            cstring remaining = split_header.remaining;

            if (header_line.length)
            {
                if (this.have_start_line)
                {
                    this.parseRegularHeaderLine(header_line);
                }
                else
                {
                    this.parseStartLine(header_line);

                    this.have_start_line = true;
                }

                this.pos = this.content_length - remaining.length;
            }
            else
            {
                this.finished = this.have_start_line;                           // Ignore empty leading header lines

                if (this.finished)
                {
                    msg_body_start = remaining.length? remaining : content_remaining;
                    break;
                }
            }
        }

        return msg_body_start;
    }

    alias parse opCall;

    /**************************************************************************

        Appends content to this.content.

        Params:
            content = content fragment to append

        Returns:
            current content from the current parse position to the end of the
            newly appended fragment

        Throws:
            HttpParseException if the header size in bytes exceeds the requested
            limit.

     **************************************************************************/

    private cstring appendContent ( cstring chunk )
    in
    {
        assert (this.content_length <= this.content.length);
    }
    out (remaining)
    {
        assert (remaining.length <= chunk.length);
    }
    body
    {
        size_t max_len  = this.content.length - this.content_length,
               consumed = chunk.length;

        if (consumed > max_len)
        {
            /*
             * If the chunk exceeds the header length limit, it may contain the
             * start of the message body: Look for the end-of-header token in
             * chunk[0 .. max_len]. If not found, the header is really too long.
             */

            const end_of_header = "\r\n\r\n";

            char* header_end = g_strstr_len(chunk.ptr, max_len, end_of_header.ptr);

            enforce(this.exception.set("request header too long: ")
                    .append(this.start_line_tokens[1]),
                    header_end !is null);

            consumed = (header_end - chunk.ptr) + end_of_header.length;

            assert (chunk[consumed - end_of_header.length .. consumed] == end_of_header);
        }

        // Append chunk to this.content.

        size_t end = this.content_length + consumed;

        this.content[this.content_length .. end] = chunk[0 .. consumed];

        this.content_length = end;

        /*
         * Return the tail of chunk that was not appended. This tail is empty
         * unless chunk exceeded the header length limit and the end-of-header
         * token was found in chunk.
         */

        return chunk[consumed .. $];
    }

    /**************************************************************************

        Parses header_line which is expected to be a regular HTTP message header
        line (not the start line or the empty message header termination line).

        Params:
            header_line = regular message header line

        Returns:
            HeaderElement instance referring to the parsed line

        Throws:
            HttpParseException
                - if the number of header lines exceeds the requested limit or
                - on parse error: if the header_line does not contain a ':'.

     **************************************************************************/

    private void parseRegularHeaderLine ( cstring header_line )
    {

        enforce(this.exception.set("too many request header lines"),
                this.n_header_lines <= this.header_lines_.length);

        scope split_tokens = new ChrSplitIterator(':');

        split_tokens.collapse          = true;
        split_tokens.include_remaining = false;


        foreach (field_name; split_tokens.reset(header_line))
        {
            this.header_elements_[this.n_header_lines] = HeaderElement(ChrSplitIterator.trim(field_name),
                                                                       ChrSplitIterator.trim(split_tokens.remaining));

            break;
        }

        enforce(this.exception.set("invalid header line (no ':')"),
                split_tokens.n);

        this.header_lines_[this.n_header_lines++] = header_line;
    }

    /**************************************************************************

        Parses start_line which is expected to be the HTTP message header start
        line (not a regular header line or the empty message header termination
        line).

        Params:
            header_line = regular message header line

        Throws:
            HttpParseException on parse error: if the number of start line
            tokens is different from 3.

     **************************************************************************/

    private void parseStartLine ( cstring start_line )
    {
        scope split_tokens = new ChrSplitIterator(' ');

        split_tokens.collapse          = true;
        split_tokens.include_remaining = true;

        uint i = 0;

        foreach (token; split_tokens.reset(start_line))
        {
            i = split_tokens.n;

            this.start_line_tokens[i - 1] = token;

            /*
             * For http responses, the third token is the error description,
             * which may contain spaces. eg,
             * "HTTP/1.1 301 Moved Permanently"
             *
             * TODO: Replace this foreach with calls to split_tokens.next
             */

            if (i >= this.start_line_tokens.length - 1)
            {
                this.start_line_tokens[i] = split_tokens.remaining;
                ++i;
                break;
            }
        }

        enforce(this.exception.set("invalid start line (too few tokens)"),
                i == this.start_line_tokens.length);
    }
}

//version = OceanPerformanceTest;

import core.stdc.time: time;
import core.sys.posix.stdlib: srand48, drand48;

version (OceanPerformanceTest)
{
    import ocean.io.Stdout_tango;
    import ocean.core.internal.gcInterface: gc_disable, gc_enable;
}

unittest
{

    {
        scope parser = new HttpHeaderParser;

        const content1 = "POST / HTTP/1.1\r\n"      // 17
                       ~ "Content-Length: 12\r\n"   // 37
                       ~ "\r\n"                     // 39
                       ~ "Hello World!";


        parser.header_length_limit = 39;

        try
        {
            parser.parse(content1);
        }
        catch (HttpParseException e)
        {
            assert (false);
        }

        parser.reset();

        parser.header_length_limit = 38;

        try
        {
            parser.parse(content1);
        }
        catch (HttpParseException e) { }
    }

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

    const istring content2 =
      "POST /dir?query=Hello%20World!&abc=def&ghi HTTP/1.1\r\n"
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

    const parts = 10;

    /*
     * content will be split into parts parts where the length of each part is
     * content.length / parts + d with d a random number in the range
     * [-(content.length / parts) / 3, +(content.length / parts) / 3].
     */

    static size_t random_chunk_length ( )
    {
        const c = content2.length * (2.0f / (parts * 3));

        static assert (c >= 3, "too many parts");

        return cast (size_t) (c + cast (float) drand48() * c);
    }

    srand48(time(null));

    scope parser = new HttpHeaderParser;

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
        parser.reset();

        {
            size_t next = random_chunk_length();

            cstring msg_body_start = parser.parse(content2[0 .. next]);

            while (msg_body_start is null)
            {
                size_t pos = next;

                next = pos + random_chunk_length();

                if (next < content2.length)
                {
                    msg_body_start = parser.parse(content2[pos .. next]);
                }
                else
                {
                    msg_body_start = parser.parse(content2[pos .. content2.length]);

                    assert (msg_body_start !is null);
                    assert (msg_body_start.length <= content2.length);
                    assert (msg_body_start == content2[content2.length - msg_body_start.length .. content2.length]);
                }
            }
        }

        assert (parser.start_line_tokens[0]  == "POST");
        assert (parser.start_line_tokens[1]  == "/dir?query=Hello%20World!&abc=def&ghi");
        assert (parser.start_line_tokens[2]  == "HTTP/1.1");

        {
            auto elements = parser.header_elements;

            with (elements[0]) assert (key == "Host"            && val == "www.example.org:12345");
            with (elements[1]) assert (key == "User-Agent"      && val == "Mozilla/5.0 (X11; U; Linux i686; de; rv:1.9.2.17) Gecko/20110422 Ubuntu/9.10 (karmic) Firefox/3.6.17");
            with (elements[2]) assert (key == "Accept"          && val == "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
            with (elements[3]) assert (key == "Accept-Language" && val == "de-de,de;q=0.8,en-us;q=0.5,en;q=0.3");
            with (elements[4]) assert (key == "Accept-Encoding" && val == "gzip,deflate");
            with (elements[5]) assert (key == "Accept-Charset"  && val == "UTF-8,*");
            with (elements[6]) assert (key == "Keep-Alive"      && val == "115");
            with (elements[7]) assert (key == "Connection"      && val == "keep-alive");
            with (elements[8]) assert (key == "Cache-Control"   && val == "max-age=0");

            assert (elements.length == 9);
        }

        {
            auto lines = parser.header_lines;

            assert (lines[0] == "Host: www.example.org:12345");
            assert (lines[1] == "User-Agent: Mozilla/5.0 (X11; U; Linux i686; de; rv:1.9.2.17) Gecko/20110422 Ubuntu/9.10 (karmic) Firefox/3.6.17");
            assert (lines[2] == "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
            assert (lines[3] == "Accept-Language: de-de,de;q=0.8,en-us;q=0.5,en;q=0.3");
            assert (lines[4] == "Accept-Encoding: gzip,deflate");
            assert (lines[5] == "Accept-Charset: UTF-8,*");
            assert (lines[6] == "Keep-Alive: 115");
            assert (lines[7] == "Connection: keep-alive");
            assert (lines[8] == "Cache-Control: max-age=0");

            assert (lines.length == 9);
        }

        version (OceanPerformanceTest)
        {
            uint j = i + 1;

            if (!(j % 10_000))
            {
                Stderr(HttpHeaderParser.stringof)(' ')(j)("\n").flush();
            }
        }
    }
}
