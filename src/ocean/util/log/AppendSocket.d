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

module ocean.util.log.AppendSocket;

import ocean.transition;

import ocean.util.log.Log;

import ocean.io.Console;

import ocean.io.stream.Buffered;

import ocean.net.device.Socket,
       ocean.net.InternetAddress;

/*******************************************************************************

        Appender for sending formatted output to a Socket.

*******************************************************************************/

public class AppendSocket : Appender
{
        private char[]          eol;
        private Mask            mask_;
        private Bout            buffer;
        private Socket          conduit;
        private InternetAddress address;
        private bool            connected;

        /***********************************************************************

                Create with the given Layout and address. Specify an end-
                of-line string if you want that appended to each message

        ***********************************************************************/

        this (InternetAddress address, Appender.Layout how = null, char[] eol=null)
        {
                layout (how);

                this.eol     = eol;
                this.address = address;
                this.conduit = new Socket;
                this.buffer  = new Bout (conduit);

                // Get a unique fingerprint for this class
                mask_ = register (address.toString);
        }

        /***********************************************************************

                Return the fingerprint for this class

        ***********************************************************************/

        override Mask mask ()
        {
                return mask_;
        }

        /***********************************************************************

                Return the name of this class

        ***********************************************************************/

        override istring name ()
        {
                return this.classinfo.name;
        }

        /***********************************************************************

                Append an event to the output. If the operations fails
                we have to revert to an alternative logging strategy,
                which will probably require a backup Appender specified
                during construction. For now we simply echo to Cerr if
                the socket has become unavailable.

        ***********************************************************************/

        override void append (LogEvent event)
        {
                auto layout = layout();

                if (buffer)
                   {
                   try {
                       if (! connected)
                          {
                          conduit.connect (address);
                          connected = true;
                          }

                       layout.format (event, &buffer.write);
                       if (eol.length)
                           buffer.write (eol);
                       buffer.flush;
                       return;
                       } catch (Exception e)
                               {
                               connected = false;
                               Cerr ("SocketAppender.append :: "~e.toString).newline;
                               }
                   }

                Cerr (event.toString).newline;
        }

        /***********************************************************************

                Close the socket associated with this Appender

        ***********************************************************************/

        override void close ()
        {
                if (conduit)
                    conduit.detach;
                conduit = null;
        }
}
