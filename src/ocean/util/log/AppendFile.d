/*******************************************************************************

   Copyright:
       Copyright (c) 2004 Kris Bell.
       Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
       All rights reserved.

   License:
       Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
       See LICENSE_TANGO.txt for details.

   Version: Initial release: May 2004

   Authors: Kris

*******************************************************************************/

module ocean.util.log.AppendFile;

import ocean.io.device.File;
import ocean.io.model.IFile;
import ocean.io.model.IConduit;
import ocean.io.stream.Buffered;
import ocean.meta.types.Qualifiers;
import ocean.util.log.Appender;
import ocean.util.log.Event;

/*******************************************************************************

    Append log messages to a file. This basic version has no rollover support,
    so it just keeps on adding to the file.

    There is also an AppendFiles that may suit your needs.

*******************************************************************************/

public class AppendFile : Filer
{
   private Mask mask_;

    /// File to append to
    private File    file_;

    /***************************************************************************

        Create a basic FileAppender to a file with the specified path.

    ***************************************************************************/

    public this (istring fp, Appender.Layout how = null)
    {
        // Get a unique fingerprint for this instance
        this.mask_ = register(fp);

        // make it shareable for read
        File.Style style = File.WriteAppending;
        style.share = File.Share.Read;
        this.file_ = new File(fp, style);
        configure (this.file_);
        this.layout(how);
    }

    /***************************************************************************

        Returns:
            the fingerprint for this class

    ***************************************************************************/

    final override Mask mask ()
    {
        return mask_;
    }

    /***************************************************************************

        Return the name of this class

    ***************************************************************************/

    final override istring name ()
    {
        return this.classinfo.name;
    }

    /***********************************************************************

            File that this appender appends to.

    ***********************************************************************/

    File file ()
    {
        return this.file_;
    }

    /***********************************************************************

        Append an event to the output.

    ***************************************************************************/

    final override void append (LogEvent event)
    {
        this.layout.format(event, (cstring v) { this.buffer.write(v); });
        this.buffer.append(FileConst.NewlineString).flush;
    }
}


/// Base class for file appenders
public class Filer : Appender
{
    package Bout            buffer;
    private IConduit        conduit_;

    /***************************************************************************

        Return the conduit

    ***************************************************************************/

    final IConduit conduit ()
    {
        return this.conduit_;
    }

    /***************************************************************************

        Close the file associated with this Appender

    ***************************************************************************/

    final override void close ()
    {
        if (this.conduit_)
        {
            this.conduit_.detach;
            this.conduit_ = null;
        }
    }

    /***************************************************************************

        Set the conduit

    ***************************************************************************/

    package final Bout configure (IConduit conduit)
    {
        // create a new buffer upon this conduit
        this.conduit_ = conduit;
        return (this.buffer = new Bout(conduit));
    }
}
