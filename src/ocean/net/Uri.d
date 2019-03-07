/*******************************************************************************

    Copyright:
        Copyright (c) 2004 Kris Bell.
        Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

********************************************************************************/

module ocean.net.Uri;

public import ocean.net.model.UriView;

import ocean.transition;
import ocean.core.Exception;
import ocean.core.Buffer;
import ocean.stdc.string : memchr;
import Integer = ocean.text.convert.Integer_tango;

version ( UnitTest )
{
    import ocean.core.Test;
}

/*******************************************************************************

    Implements an RFC 2396 compliant URI specification. See
    <A HREF="http://ftp.ics.uci.edu/pub/ietf/uri/rfc2396.txt">this page</A>
    for more information.

    The implementation fails the spec on two counts: it doesn't insist
    on a scheme being present in the Uri, and it doesn't implement the
    "Relative References" support noted in section 5.2. The latter can
    be found in ocean.util.PathUtil instead.

    Note that IRI support can be implied by assuming each of userinfo,
    path, query, and fragment are UTF-8 encoded
    (see <A HREF="http://www.w3.org/2001/Talks/0912-IUC-IRI/paper.html">
    this page</A> for further details).

*******************************************************************************/

class Uri : UriView
{
    // simplistic string appender
    private alias size_t delegate(Const!(void)[]) Consumer;

    /// old method names
    public alias port        getPort;
    public alias defaultPort getDefaultPort;
    public alias host        getHost;
    public alias validPort   getValidPort;
    public alias userinfo    getUserInfo;
    public alias path        getPath;
    public alias query       getQuery;
    public alias fragment    getFragment;
    public alias port        setPort;
    public alias host        setHost;
    public alias userinfo    setUserInfo;
    public alias query       setQuery;
    public alias path        setPath;
    public alias fragment    setFragment;

    public enum { InvalidPort = -1 }

    private int port_;
    private cstring host_, path_, query_, scheme_, userinfo_, fragment_;
    private HeapSlice decoded;

    private static ubyte[] map;

    private static short[istring] genericSchemes;

    private static immutable istring hexDigits = "0123456789abcdef";

    private static Const!(SchemePort[]) schemePorts = [
        {"coffee",      80},
        {"file",        InvalidPort},
        {"ftp",         21},
        {"gopher",      70},
        {"hnews",       80},
        {"http",        80},
        {"http-ng",     80},
        {"https",       443},
        {"imap",        143},
        {"irc",         194},
        {"ldap",        389},
        {"news",        119},
        {"nfs",         2049},
        {"nntp",        119},
        {"pop",         110},
        {"rwhois",      4321},
        {"shttp",       80},
        {"smtp",        25},
        {"snews",       563},
        {"telnet",      23},
        {"wais",        210},
        {"whois",       43},
        {"whois++",     43},
    ];

    public enum
    {
        ExcScheme       = 0x01,
        ExcAuthority    = 0x02,
        ExcPath         = 0x04,
        IncUser         = 0x08,         // encode spec for User
        IncPath         = 0x10,         // encode spec for Path
        IncQuery        = 0x20,         // encode spec for Query
        IncQueryAll     = 0x40,
        IncScheme       = 0x80,         // encode spec for Scheme
        IncGeneric      =
            IncScheme |
            IncUser   |
            IncPath   |
            IncQuery  |
            IncQueryAll
    }

    // scheme and port pairs
    private struct SchemePort
    {
        cstring  name;
        short    port;
    }

    /***********************************************************************

      Initialize the Uri character maps and so on

     ***********************************************************************/

    static this ()
    {
        // Map known generic schemes to their default port. Specify
        // InvalidPort for those schemes that don't use ports. Note
        // that a port value of zero is not supported ...
        foreach (SchemePort sp; schemePorts)
            genericSchemes[sp.name] = sp.port;
        genericSchemes.rehash;

        map = new ubyte[256];

        // load the character map with valid symbols
        for (int i='a'; i <= 'z'; ++i)
            map[i] = IncGeneric;

        for (int i='A'; i <= 'Z'; ++i)
            map[i] = IncGeneric;

        for (int i='0'; i<='9'; ++i)
            map[i] = IncGeneric;

        // exclude these from parsing elements
        map[':'] |= ExcScheme;
        map['/'] |= ExcScheme | ExcAuthority;
        map['?'] |= ExcScheme | ExcAuthority | ExcPath;
        map['#'] |= ExcScheme | ExcAuthority | ExcPath;

        // include these as common (unreserved) symbols
        map['-'] |= IncUser | IncQuery | IncQueryAll | IncPath;
        map['_'] |= IncUser | IncQuery | IncQueryAll | IncPath;
        map['.'] |= IncUser | IncQuery | IncQueryAll | IncPath;
        map['!'] |= IncUser | IncQuery | IncQueryAll | IncPath;
        map['~'] |= IncUser | IncQuery | IncQueryAll | IncPath;
        map['*'] |= IncUser | IncQuery | IncQueryAll | IncPath;
        map['\''] |= IncUser | IncQuery | IncQueryAll | IncPath;
        map['('] |= IncUser | IncQuery | IncQueryAll | IncPath;
        map[')'] |= IncUser | IncQuery | IncQueryAll | IncPath;

        // include these as scheme symbols
        map['+'] |= IncScheme;
        map['-'] |= IncScheme;
        map['.'] |= IncScheme;

        // include these as userinfo symbols
        map[';'] |= IncUser;
        map[':'] |= IncUser;
        map['&'] |= IncUser;
        map['='] |= IncUser;
        map['+'] |= IncUser;
        map['$'] |= IncUser;
        map[','] |= IncUser;

        // include these as path symbols
        map['/'] |= IncPath;
        map[';'] |= IncPath;
        map[':'] |= IncPath;
        map['@'] |= IncPath;
        map['&'] |= IncPath;
        map['='] |= IncPath;
        map['+'] |= IncPath;
        map['$'] |= IncPath;
        map[','] |= IncPath;

        // include these as query symbols
        map[';'] |= IncQuery | IncQueryAll;
        map['/'] |= IncQuery | IncQueryAll;
        map[':'] |= IncQuery | IncQueryAll;
        map['@'] |= IncQuery | IncQueryAll;
        map['='] |= IncQuery | IncQueryAll;
        map['$'] |= IncQuery | IncQueryAll;
        map[','] |= IncQuery | IncQueryAll;

        // '%' are permitted inside queries when constructing output
        map['%'] |= IncQueryAll;
        map['?'] |= IncQueryAll;
        map['&'] |= IncQueryAll;
    }

    /***********************************************************************

        Create an empty Uri

        Params:
            initial_buffer_size = the initial amount of memory to
                allocate to hold the URI-decoded URI. Will be extended
                if necessary.

     ***********************************************************************/

    this ( uint initial_buffer_size = 512 )
    {
        port_ = InvalidPort;
        decoded.expand (initial_buffer_size);
    }

    /***********************************************************************

      Construct a Uri from the provided character string

     ***********************************************************************/

    this (cstring uri)
    {
        this ();
        parse (uri);
    }

    /***********************************************************************

      Construct a Uri from the given components. The query is
      optional.

     ***********************************************************************/

    this (cstring scheme, cstring host, cstring path, cstring query = null)
    {
        this ();

        this.scheme_ = scheme;
        this.query_ = query;
        this.host_ = host;
        this.path_ = path;
    }

    /***********************************************************************

      Clone another Uri. This can be used to make a mutable Uri
      from an immutable UriView.

     ***********************************************************************/

    this (UriView other)
    {
        with (other)
        {
            this (scheme, getHost, getPath, getQuery);
            this.userinfo_ = getUserInfo;
            this.fragment_ = getFragment;
            this.port_ = getPort;
        }
    }

    /***********************************************************************

        Return the default port for the given scheme. InvalidPort
        is returned if the scheme is unknown, or does not accept
        a port.

     ***********************************************************************/

    final override int defaultPort (cstring scheme)
    {
        short* port = scheme in genericSchemes;
        if (port is null)
            return InvalidPort;
        return *port;
    }

    /***********************************************************************

        Return the parsed scheme, or null if the scheme was not
        specified. Automatically normalizes scheme (converts to lower
        case)

        Params:
            buffer = buffer to store normalized scheme if it
            wasn't lower case already

     ***********************************************************************/

    final override cstring getNormalizedScheme (ref mstring buffer)
    {
        foreach (c; scheme_)
        {
            if (c >= 'A' && c <= 'Z')
            {
                buffer.length = scheme_.length;
                buffer[] = scheme_[];
                return toLower(buffer);
            }
        }
        return scheme_;
    }

    /***********************************************************************

        Return the parsed scheme, or null if the scheme was not
        specified

     ***********************************************************************/

    final override cstring scheme ()
    {
        return scheme_;
    }

    /***********************************************************************

        Return the parsed host, or null if the host was not
        specified

     ***********************************************************************/

    final override cstring host()
    {
        return host_;
    }

    /***********************************************************************

        Return the parsed port number, or InvalidPort if the port
        was not provided.

     ***********************************************************************/

    final override int port()
    {
        return port_;
    }

    /***********************************************************************

        Return a valid port number by performing a lookup on the
        known schemes if the port was not explicitly specified.

     ***********************************************************************/

    final override int validPort()
    {
        if (port_ is InvalidPort)
            return defaultPort (scheme_);
        return port_;
    }

    /***********************************************************************

        Return the parsed userinfo, or null if userinfo was not
        provided.

     ***********************************************************************/

    final override cstring userinfo()
    {
        return userinfo_;
    }

    /***********************************************************************

        Return the parsed path, or null if the path was not
        provided.

     ***********************************************************************/

    final override cstring path()
    {
        return path_;
    }

    /***********************************************************************

        Return the parsed query, or null if a query was not
        provided.

     ***********************************************************************/

    final override cstring query()
    {
        return query_;
    }

    /***********************************************************************

        Return the parsed fragment, or null if a fragment was not
        provided.

     ***********************************************************************/

    final override cstring fragment()
    {
        return fragment_;
    }

    /***********************************************************************

        Return whether or not the Uri scheme is considered generic.

     ***********************************************************************/

    final override bool isGeneric ()
    {
        return (scheme_ in genericSchemes) !is null;
    }

    /***********************************************************************

        Emit the content of this Uri via the provided Consumer. The
        output is constructed per RFC 2396.

     ***********************************************************************/

    final size_t produce (scope Consumer consume)
    {
        size_t ret;

        if (scheme_.length)
            ret += consume (scheme_), ret += consume (":");


        if (userinfo_.length || host_.length || port_ != InvalidPort)
        {
            ret += consume ("//");

            if (userinfo_.length)
                ret += encode (consume, userinfo_, IncUser), ret +=consume ("@");

            if (host_.length)
                ret += consume (host_);

            if (port_ != InvalidPort && port_ != getDefaultPort(scheme_))
            {
                char[8] tmp;
                ret += consume (":"), ret += consume (Integer.itoa (tmp, cast(uint) port_));
            }
        }

        if (path_.length)
            ret += encode (consume, path_, IncPath);

        if (query_.length)
        {
            ret += consume ("?");
            ret += encode (consume, query_, IncQueryAll);
        }

        if (fragment_.length)
        {
            ret += consume ("#");
            ret += encode (consume, fragment_, IncQuery);
        }

        return ret;
    }

    /// Ditto
    final size_t produce (ref Buffer!(char) buffer)
    {
        buffer.reset();
        return this.produce((Const!(void)[] chunk) {
            buffer ~= cast(mstring) chunk;
            return buffer.length;
        });
    }

    /***********************************************************************

      Emit the content of this Uri via the provided Consumer. The
      output is constructed per RFC 2396.

     ***********************************************************************/

    final override istring toString ()
    {
        Buffer!(char) buffer;
        this.produce(buffer);
        return cast(istring) buffer[];
    }

    /***********************************************************************

      Encode uri characters into a Consumer, such that
      reserved chars are converted into their %hex version.

     ***********************************************************************/

    static size_t encode (scope Consumer consume, cstring s, int flags)
    {
        size_t  ret;
        char[3] hex;
        int     mark;

        hex[0] = '%';
        foreach (int i, char c; s)
        {
            if (! (map[c] & flags))
            {
                ret += consume (s[mark..i]);
                mark = i+1;

                hex[1] = hexDigits [(c >> 4) & 0x0f];
                hex[2] = hexDigits [c & 0x0f];
                ret += consume (hex);
            }
        }

        // add trailing section
        if (mark < s.length)
            ret += consume (s[mark..s.length]);

        return ret;
    }

    /***********************************************************************

      Encode uri characters into a string, such that reserved
      chars are converted into their %hex version.

      Returns a dup'd string

     ***********************************************************************/

    static mstring encode (cstring text, int flags)
    {
        void[] s;
        encode ((Const!(void)[] v) {s ~= v; return  v.length;}, text, flags);
        return cast(mstring) s;
    }

    /***********************************************************************

      Decode a character string with potential %hex values in it.
      The decoded strings are placed into a thread-safe expanding
      buffer, and a slice of it is returned to the caller.

     ***********************************************************************/

    private cstring decoder (cstring s, char ignore=0)
    {
        static int toInt (char c)
        {
            if (c >= '0' && c <= '9')
                c -= '0';
            else
                if (c >= 'a' && c <= 'f')
                    c -= ('a' - 10);
                else
                    if (c >= 'A' && c <= 'F')
                        c -= ('A' - 10);
            return c;
        }

        auto length = s.length;

        // take a peek first, to see if there's work to do
        if (length && memchr (s.ptr, '%', length))
        {
            char* p;
            int   j;

            // ensure we have enough decoding space available
            p = cast(char*) decoded.expand (cast(int) length);

            // scan string, stripping % encodings as we go
            for (auto i = 0; i < length; ++i, ++j, ++p)
            {
                int c = s[i];

                if (c is '%' && (i+2) < length)
                {
                    c = toInt(s[i+1]) * 16 + toInt(s[i+2]);

                    // leave ignored escapes in the stream,
                    // permitting escaped '&' to remain in
                    // the query string
                    if (c && (c is ignore))
                        c = '%';
                    else
                        i += 2;
                }

                *p = cast(char) c;
            }

            // return a slice from the decoded input
            return cast(mstring) decoded.slice (j);
        }

        // return original content
        return s;
    }

    /***********************************************************************

      Decode a duplicated string with potential %hex values in it

     ***********************************************************************/

    final mstring decode (cstring s)
    {
        return decoder(s).dup;
    }

    /***********************************************************************

      Parsing is performed according to RFC 2396

      <pre>
      ^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?
      12            3  4          5       6  7        8 9

      2 isolates scheme
      4 isolates authority
      5 isolates path
      7 isolates query
      9 isolates fragment
      </pre>

      This was originally a state-machine; it turned out to be a
      lot faster (~40%) when unwound like this instead.

     ***********************************************************************/

    final Uri parse (cstring uri, bool relative = false)
    {
        char    c;
        int     i,
                mark;
        auto    prefix = path_;
        auto    len = uri.length;

        if (! relative)
            reset;

        // isolate scheme (note that it's OK to not specify a scheme)
        for (i=0; i < len && !(map[c = uri[i]] & ExcScheme); ++i) {}
        if (c is ':')
        {
            scheme_ = uri [mark .. i];
            mark = i + 1;
        }

        // isolate authority
        if (mark < len-1 && uri[mark] is '/' && uri[mark+1] is '/')
        {
            for (mark+=2, i=mark; i < len && !(map[uri[i]] & ExcAuthority); ++i) {}
            parseAuthority (uri[mark .. i]);
            mark = i;
        }
        else
            if (relative)
            {
                auto head = (uri[0] is '/') ? host_ : toLastSlash(prefix);
                query_ = fragment_ = null;
                uri = head ~ uri;
                len = uri.length;
                mark = cast(int) head.length;
            }

        // isolate path
        for (i=mark; i < len && !(map[uri[i]] & ExcPath); ++i) {}
        path_ = decoder (uri[mark .. i]);
        mark = i;

        // isolate query
        if (mark < len && uri[mark] is '?')
        {
            for (++mark, i=mark; i < len && uri[i] != '#'; ++i) {}
            query_ = decoder (uri[mark .. i], '&');
            mark = i;
        }

        // isolate fragment
        if (mark < len && uri[mark] is '#')
            fragment_ = decoder (uri[mark+1 .. len]);

        return this;
    }

    /***********************************************************************

      Clear everything to null.

     ***********************************************************************/

    final void reset()
    {
        decoded.reset;
        port_ = InvalidPort;
        host_ = path_ = query_ = scheme_ = userinfo_ = fragment_ = null;
    }

    /***********************************************************************

      Parse the given uri, with support for relative URLs

     ***********************************************************************/

    final Uri relParse (mstring uri)
    {
        return parse (uri, true);
    }

    /***********************************************************************

      Set the Uri scheme

     ***********************************************************************/

    final Uri scheme (cstring scheme)
    {
        this.scheme_ = scheme;
        return this;
    }

    /***********************************************************************

      Set the Uri host

     ***********************************************************************/

    final Uri host (cstring host)
    {
        this.host_ = host;
        return this;
    }

    /***********************************************************************

      Set the Uri port

     ***********************************************************************/

    final Uri port (int port)
    {
        this.port_ = port;
        return this;
    }

    /***********************************************************************

      Set the Uri userinfo

     ***********************************************************************/

    final Uri userinfo (cstring userinfo)
    {
        this.userinfo_ = userinfo;
        return this;
    }

    /***********************************************************************

      Set the Uri query

     ***********************************************************************/

    final Uri query (char[] query)
    {
        this.query_ = query;
        return this;
    }

    /***********************************************************************

      Extend the Uri query

     ***********************************************************************/

    final cstring extendQuery (cstring tail)
    {
        if (tail.length)
        {
            if (query_.length)
                query_ = query_ ~ "&" ~ tail;
            else
                query_ = tail;
        }
        return query_;
    }

    /***********************************************************************

      Set the Uri path

     ***********************************************************************/

    final Uri path (cstring path)
    {
        this.path_ = path;
        return this;
    }

    /***********************************************************************

      Set the Uri fragment

     ***********************************************************************/

    final Uri fragment (cstring fragment)
    {
        this.fragment_ = fragment;
        return this;
    }

    /***********************************************************************

      Authority is the section after the scheme, but before the
      path, query or fragment; it typically represents a host.

      ---
      ^(([^@]*)@?)([^:]*)?(:(.*))?
      12         3       4 5

      2 isolates userinfo
      3 isolates host
      5 isolates port
      ---

     ***********************************************************************/

    private void parseAuthority (cstring auth)
    {
        int     mark,
                len = cast(int) auth.length;

        // get userinfo: (([^@]*)@?)
        foreach (int i, char c; auth)
            if (c is '@')
            {
                userinfo_ = decoder (auth[0 .. i]);
                mark = i + 1;
                break;
            }

        // get port: (:(.*))?
        for (int i=mark; i < len; ++i)
            if (auth [i] is ':')
            {
                port_ = Integer.atoi (auth [i+1 .. len]);
                len = i;
                break;
            }

        // get host: ([^:]*)?
        host_ = auth [mark..len];
    }

    /**********************************************************************

     **********************************************************************/

    private final cstring toLastSlash (cstring path)
    {
        if (path.ptr)
            for (auto p = path.ptr+path.length; --p >= path.ptr;)
                if (*p is '/')
                    return path [0 .. (p-path.ptr)+1];
        return path;
    }

    /**********************************************************************

      in-place conversion to lowercase

     **********************************************************************/

    private final static mstring toLower (mstring src)
    {
        foreach (ref char c; src)
            if (c >= 'A' && c <= 'Z')
                c = cast(char)(c + ('a' - 'A'));
        return src;
    }
}

///
unittest
{
    auto s_uri = "http://example.net/magic?arg&arg#id";
    auto uri = new Uri(s_uri);

    test!("==")(uri.scheme, "http");
    test!("==")(uri.host, "example.net");
    test!("==")(uri.port, Uri.InvalidPort);

    Buffer!(char) buffer;
    uri.produce(buffer);
    test!("==") (buffer[], s_uri);
}


/*******************************************************************************

*******************************************************************************/

private struct HeapSlice
{
    private uint    used;
    private void[]  buffer;

    /***********************************************************************

      Reset content length to zero

     ***********************************************************************/

    final void reset ()
    {
        used = 0;
    }

    /***********************************************************************

      Potentially expand the content space, and return a pointer
      to the start of the empty section.

     ***********************************************************************/

    final void* expand (uint size)
    {
        auto len = used + size;
        if (len > buffer.length)
            buffer.length = len + len/2;

        return &buffer [used];
    }

    /***********************************************************************

      Return a slice of the content from the current position
      with the specified size. Adjusts the current position to
      point at an empty zone.

     ***********************************************************************/

    final void[] slice (int size)
    {
        uint i = used;
        used += size;
        return buffer [i..used];
    }
}

/*******************************************************************************

    Unittest

*******************************************************************************/

unittest
{
    auto uri = new Uri;
    auto uristring = "http://www.example.com/click.html/c=37571:RoS_Intern_search-link3_LB_Sky_Rec/b=98983:news-time-search-link_leader_neu/l=68%7C%7C%7C%7Cde/url=http://ads.ad4max.com/adclick.aspx?id=cf722624-efd5-4b10-ad53-88a5872a8873&pubad=b9c8acc4-e396-4b0b-b665-8bb3078128e6&avid=963171985&adcpc=xrH%2f%2bxVeFaPVkbVCMufB5A%3d%3d&a1v=6972657882&a1lang=de&a1ou=http%3a%2f%2fad.search.ch%2fiframe_ad.html%3fcampaignname%3dRoS_Intern_search-link3_LB_Sky_Rec%26bannername%3dnews-time-search-link_leader_neu%26iframeid%3dsl_if1%26content%3dvZLLbsIwEEX3%2bQo3aqUW1XEgkAckSJRuKqEuoDuELD%2bmiSEJyDEE%2fr7h0cKm6q6SF9bVjH3uzI3vMOaVYdpgPIwrodXGIHPYQGIb2BuyZDt2Vu2hRUh8Nx%2b%2fjj5Gc4u0UNAJ95H7jCbAJGi%2bZlqix3eoqyfUIhaT3YLtabpVEiXI5pEImRBdDF7k4y53Oea%2b38Mh554bhO1OCL49%2bO6qlTTZsa3546pmoNLMHOXIvaoapNIgTnpmzKZPCJNOBUyLzBEZEbkSKyczRU5E4gW9oN2frmf0rTSgS3quw7kqVx6dvNDZ6kCnIAhPojAKvX7Z%2bMFGFYBvKml%2bskxL2JI88cOHYPxzJJCtzpP79pXQaCZWqkxppcVvlDsF9b9CqiJNLiB1Xd%2bQqIKlUBHXSdWnjQbN1heLoRWTcwz%2bCAlqLCZXg5VzHoEj1gW5XJeVffOcFR8TCKVs8vcF%26crc%3dac8cc2fa9ec2e2de9d242345c2d40c25";


    with(uri)
    {

        parse(uristring);

        test(scheme == "http");
        test(host == "www.example.com");
        test(port == InvalidPort);
        test(userinfo == null);
        test(fragment == null);
        test(path == "/click.html/c=37571:RoS_Intern_search-link3_LB_Sky_Rec/b=98983:news-time-search-link_leader_neu/l=68||||de/url=http://ads.ad4max.com/adclick.aspx");
        test(query == "id=cf722624-efd5-4b10-ad53-88a5872a8873&pubad=b9c8acc4-e396-4b0b-b665-8bb3078128e6&avid=963171985&adcpc=xrH/+xVeFaPVkbVCMufB5A==&a1v=6972657882&a1lang=de&a1ou=http://ad.search.ch/iframe_ad.html?campaignname=RoS_Intern_search-link3_LB_Sky_Rec%26bannername=news-time-search-link_leader_neu%26iframeid=sl_if1%26content=vZLLbsIwEEX3+Qo3aqUW1XEgkAckSJRuKqEuoDuELD+miSEJyDEE/r7h0cKm6q6SF9bVjH3uzI3vMOaVYdpgPIwrodXGIHPYQGIb2BuyZDt2Vu2hRUh8Nx+/jj5Gc4u0UNAJ95H7jCbAJGi+Zlqix3eoqyfUIhaT3YLtabpVEiXI5pEImRBdDF7k4y53Oea+38Mh554bhO1OCL49+O6qlTTZsa3546pmoNLMHOXIvaoapNIgTnpmzKZPCJNOBUyLzBEZEbkSKyczRU5E4gW9oN2frmf0rTSgS3quw7kqVx6dvNDZ6kCnIAhPojAKvX7Z+MFGFYBvKml+skxL2JI88cOHYPxzJJCtzpP79pXQaCZWqkxppcVvlDsF9b9CqiJNLiB1Xd+QqIKlUBHXSdWnjQbN1heLoRWTcwz+CAlqLCZXg5VzHoEj1gW5XJeVffOcFR8TCKVs8vcF%26crc=ac8cc2fa9ec2e2de9d242345c2d40c25");

        parse("psyc://example.net/~marenz?what#_presence");

        test(scheme == "psyc");
        test(host == "example.net");
        test(port == InvalidPort);
        test(fragment == "_presence");
        test(path == "/~marenz");
        test(query == "what");
        test!("==") (toString(), "psyc://example.net/~marenz?what#_presence");

    }

    //Cout (uri).newline;
    //Cout (uri.encode ("&#$%", uri.IncQuery)).newline;

}

/*******************************************************************************

    Add unittests for Uri.encode method

*******************************************************************************/

unittest
{
    void encode ( cstring url, ref mstring working_buffer, int flags )
    {
        working_buffer.length = 0;
        enableStomping(working_buffer);

        Uri.encode((Const!(void)[] data)
        {
            working_buffer ~= cast (cstring) data;
            return data.length;
        }, url, flags);
    }

    mstring buffer;

    // Test various modes of encoding
    cstring url = "https://eu-sonar.sociomantic.com/js/";
    cstring expected_result = "https%3a%2f%2feu-sonar.sociomantic.com%2fjs%2f";
    encode(url, buffer, Uri.IncScheme);
    test!("==")(buffer, expected_result);

    expected_result = "https:%2f%2feu-sonar.sociomantic.com%2fjs%2f";
    encode(url, buffer, Uri.IncUser);
    test!("==")(buffer, expected_result);

    url = `https://eu-sonar.sociomantic.com/js/&ao=[{"id":"1987392158"}]`;
    expected_result = "https://eu-sonar.sociomantic.com/js/&ao=%5b%7b%22id" ~
        "%22:%221987392158%22%7d%5d";
    encode(url, buffer, Uri.IncGeneric);
    test!("==")(buffer, expected_result);
}
