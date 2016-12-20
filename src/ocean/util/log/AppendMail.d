/*******************************************************************************

        Copyright:
            Copyright (c) 2004 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: May 2004

        Authors: Kris

*******************************************************************************/

deprecated module ocean.util.log.AppendMail;

import ocean.transition;

import ocean.util.log.Log;

import ocean.io.stream.Buffered;

import ocean.net.device.Socket,
       ocean.net.InternetAddress;

/*******************************************************************************

        Appender for sending formatted output to a Mail server. Thanks
        to BCS for posting how to do this.

*******************************************************************************/

deprecated public class AppendMail : Appender
{
        private char[]          to,
                                from,
                                subj;
        private Mask            mask_;
        private InternetAddress server;

        /***********************************************************************

                Create with the given layout and server address

        ***********************************************************************/

        this (InternetAddress server, char[] from, char[] to, char[] subj, Appender.Layout how = null)
        {
                layout (how);

                this.to = to;
                this.from = from;
                this.subj = subj;
                this.server = server;

                // Get a unique fingerprint for this appender
                mask_ = register (to ~ subj);
        }

        /***********************************************************************

                Send an event to the mail server

        ***********************************************************************/

        final override void append (LogEvent event)
        {
                auto conduit = new Socket;
                scope (exit)
                       conduit.close;

                conduit.connect (server);
                auto emit = new Bout (conduit);

                emit.append ("HELO none@anon.org\r\nMAIL FROM:<")
                    .append (from)
                    .append (">\r\nRCPT TO:<")
                    .append (to)
                    .append (">\r\nDATA\r\nSubject: ")
                    .append (subj)
                    .append ("\r\nContent-Type: text/plain; charset=us-ascii\r\n\r\n");

                layout.format (event, &emit.write);
                emit.append ("\r\n.\r\nQUIT\r\n");
                emit.flush;
        }

        /***********************************************************************

                Return the fingerprint for this class

        ***********************************************************************/

        final override Mask mask ()
        {
                return mask_;
        }

        /***********************************************************************

                Return the name of this class

        ***********************************************************************/

        final override istring name ()
        {
                return this.classinfo.name;
        }
}
