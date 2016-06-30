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

module ocean.util.log.AppendFile;

import ocean.transition;

import ocean.util.log.Log;

import ocean.io.device.File;

import ocean.io.stream.Buffered;

import ocean.io.model.IFile,
       ocean.io.model.IConduit;

/*******************************************************************************

        Append log messages to a file. This basic version has no rollover
        support, so it just keeps on adding to the file. There is also an
        AppendFiles that may suit your needs.

*******************************************************************************/

class AppendFile : Filer
{
        private Mask    mask_;

        /***********************************************************************

                Create a basic FileAppender to a file with the specified
                path.

        ***********************************************************************/

        this (istring fp, Appender.Layout how = null)
        {
                // Get a unique fingerprint for this instance
                mask_ = register (fp);

                // make it shareable for read
                File.Style style = File.WriteAppending;
                style.share = File.Share.Read;
                configure (new File (fp, style));
                layout (how);
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

        /***********************************************************************

                Append an event to the output.

        ***********************************************************************/

        final override void append (LogEvent event)
        {
            layout.format (event, &buffer.write);
            buffer.append (FileConst.NewlineString)
                  .flush;
        }
}


/*******************************************************************************

        Base class for file appenders

*******************************************************************************/

class Filer : Appender
{
        package Bout            buffer;
        private IConduit        conduit_;

        /***********************************************************************

                Return the conduit

        ***********************************************************************/

        final IConduit conduit ()
        {
                return conduit_;
        }

        /***********************************************************************

                Close the file associated with this Appender

        ***********************************************************************/

        final override void close ()
        {
            if (conduit_)
               {
               conduit_.detach;
               conduit_ = null;
               }
        }

        /***********************************************************************

                Set the conduit

        ***********************************************************************/

        package final Bout configure (IConduit conduit)
        {
                // create a new buffer upon this conduit
                conduit_ = conduit;
                return (buffer = new Bout(conduit));
        }
}


