/*******************************************************************************

        Copyright:
            Copyright (c) 2004 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: January 2006

        Authors: Kris

*******************************************************************************/

deprecated module ocean.net.http.HttpPost;

public import ocean.net.Uri;

import ocean.io.model.IConduit;

import ocean.net.http.HttpClient,
       ocean.net.http.HttpHeaders;

/*******************************************************************************

        Supports the basic needs of a client sending POST requests to a
        HTTP server. The following is a usage example:

        ---
        // open a web-page for posting (see HttpGet for simple reading)
        auto post = new HttpPost ("http://yourhost/yourpath");

        // send, retrieve and display response
        Cout (cast(char[]) post.write("posted data", "text/plain"));
        ---

*******************************************************************************/

deprecated class HttpPost : HttpClient
{
        /***********************************************************************

                Create a client for the given URL. The argument should be
                fully qualified with an "http:" or "https:" scheme, or an
                explicit port should be provided.

        ***********************************************************************/

        this (char[] url)
        {
                this (new Uri(url));
        }

        /***********************************************************************

                Create a client with the provided Uri instance. The Uri should
                be fully qualified with an "http:" or "https:" scheme, or an
                explicit port should be provided.

        ***********************************************************************/

        this (Uri uri)
        {
                super (HttpClient.Post, uri);

                // enable header duplication
                getResponseHeaders.retain (true);
        }

        /***********************************************************************

                Send query params only

        ***********************************************************************/

        void[] write ()
        {
                return write (null);
        }

        /***********************************************************************

                Send raw data via the provided pump, and no query
                params. You have full control over headers and so
                on via this method.

        ***********************************************************************/

        void[] write (HttpClient.Pump pump)
        {
                auto buffer = super.open (pump);
                try {
                    // check return status for validity
                    auto status = super.getStatus;
                    if (status is HttpResponseCode.OK ||
                        status is HttpResponseCode.Created ||
                        status is HttpResponseCode.Accepted)
                        buffer.load (getResponseHeaders.getInt (HttpHeader.ContentLength));
                    } finally {close;}

                return buffer.slice;
        }

        /***********************************************************************

                Send content and no query params. The contentLength header
                will be set to match the provided content, and contentType
                set to the given type.

        ***********************************************************************/

        void[] write (void[] content, char[] type)
        {
                auto headers = super.getRequestHeaders;

                headers.add    (HttpHeader.ContentType, type);
                headers.addInt (HttpHeader.ContentLength, cast(int) content.length);

                return write ((OutputBuffer b){b.append(content);});
        }
}

