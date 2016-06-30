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

module ocean.net.model.UriView;

import ocean.transition;

/*******************************************************************************

        Implements an RFC 2396 compliant URI specification. See
        <A HREF="http://ftp.ics.uci.edu/pub/ietf/uri/rfc2396.txt">this page</A>
        for more information.

        The implementation fails the spec on two counts: it doesn't insist
        on a scheme being present in the UriView, and it doesn't implement the
        "Relative References" support noted in section 5.2.

        Note that IRI support can be implied by assuming each of userinfo, path,
        query, and fragment are UTF-8 encoded
        (see <A HREF="http://www.w3.org/2001/Talks/0912-IUC-IRI/paper.html">
        this page</A> for further details).

        Use a Uri instead where you need to alter specific uri attributes.

*******************************************************************************/

abstract class UriView
{
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

        public enum {InvalidPort = -1}

        /***********************************************************************

                Return the default port for the given scheme. InvalidPort
                is returned if the scheme is unknown, or does not accept
                a port.

        ***********************************************************************/

        abstract int defaultPort (cstring scheme);

        /***********************************************************************

                Return the parsed scheme, or null if the scheme was not
                specified. Automatically normalizes the scheme (converts to
                lower case)

                Params:
                    buffer = buffer to store normalized scheme if it
                        wasn't lower case already

        ***********************************************************************/

        abstract cstring getNormalizedScheme (ref mstring buffer);

        /***********************************************************************

                Return the parsed scheme, or null if the scheme was not
                specified.

        ***********************************************************************/

        abstract cstring scheme ();

        /***********************************************************************

                Return the parsed host, or null if the host was not
                specified

        ***********************************************************************/

        abstract cstring host();

        /***********************************************************************

                Return the parsed port number, or InvalidPort if the port
                was not provided.

        ***********************************************************************/

        abstract int port();

        /***********************************************************************

                Return a valid port number by performing a lookup on the
                known schemes if the port was not explicitly specified.

        ***********************************************************************/

        abstract int validPort();

        /***********************************************************************

                Return the parsed userinfo, or null if userinfo was not
                provided.

        ***********************************************************************/

        abstract cstring userinfo();

        /***********************************************************************

                Return the parsed path, or null if the path was not
                provided.

        ***********************************************************************/

        abstract cstring path();

        /***********************************************************************

                Return the parsed query, or null if a query was not
                provided.

        ***********************************************************************/

        abstract cstring query();

        /***********************************************************************

                Return the parsed fragment, or null if a fragment was not
                provided.

        ***********************************************************************/

        abstract cstring fragment();

        /***********************************************************************

                Return whether or not the UriView scheme is considered generic.

        ***********************************************************************/

        abstract bool isGeneric ();

        /***********************************************************************

                Emit the content of this UriView. Output is constructed per
                RFC 2396.

        ***********************************************************************/

        abstract override istring toString ();
}

