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

module ocean.net.http.HttpGet;

public import ocean.net.Uri;

import ocean.net.http.HttpClient,
       ocean.net.http.HttpHeaders;

/*******************************************************************************

    Supports the basic needs of a client making requests of an HTTP
    server. The following is a usage example:
    ---
    // open a web-page for reading (see HttpPost for writing)
    auto page = new HttpGet ("http://www.digitalmars.com/d/intro.html");

    // retrieve and flush display content
    Cout (cast(char[]) page.read) ();
    ---

*******************************************************************************/

class HttpGet : HttpClient
{
        alias HttpClient.read read;

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
                super (HttpClient.Get, uri);

                // enable header duplication
                getResponseHeaders.retain (true);
        }

        /***********************************************************************

        ***********************************************************************/

        void[] read ()
        {
                auto buffer = super.open;
                try {
                    if (super.isResponseOK)
                        buffer.load (getResponseHeaders.getInt(HttpHeader.ContentLength));
                    } finally {super.close;}
                return buffer.slice;
        }
}


/*******************************************************************************

*******************************************************************************/

debug (HttpGet)
{
        import ocean.io.Console;

        void main()
        {
                // open a web-page for reading (see HttpPost for writing)
                auto page = new HttpGet ("http://www.digitalmars.com/d/intro.html");

                // retrieve and flush display content
                Cout (cast(char[]) page.read) ();

                foreach (header; page.getResponseHeaders)
                         Cout (header.name.value) (header.value).newline;
        }
}
