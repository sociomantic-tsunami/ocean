/*******************************************************************************

  Copyright:
      Copyright (c) 2006 Juan Jose Comellas.
      Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
      All rights reserved.

  License:
      Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
      See LICENSE_TANGO.txt for details.

  Authors: Juan Jose Comellas <juanjo@comellas.com.ar>

*******************************************************************************/

module ocean.sys.Pipe;

import ocean.meta.types.Qualifiers;

import ocean.sys.Common;
import ocean.io.device.Device;

import ocean.core.ExceptionDefinitions;

import core.sys.posix.unistd;

debug (PipeConduit)
{
    import ocean.io.Stdout;
}

private enum {DefaultBufferSize = 8 * 1024}


/**
 * Conduit for pipes.
 *
 * Each PipeConduit can only read or write, depending on the way it has been
 * created.
 */

class PipeConduit : Device
{
    private uint _bufferSize;


    /**
     * Create a PipeConduit with the provided handle and access permissions.
     *
     * Params:
     * handle       = handle of the operating system pipe we will wrap inside
     *                the PipeConduit.
     * style        = access flags for the pipe (readable, writable, etc.).
     * bufferSize   = buffer size.
     */
    private this(Handle handle, uint bufferSize = DefaultBufferSize)
    {
        this.handle = handle;
        _bufferSize = bufferSize;
    }

    /**
     * Destructor.
     */
    public ~this()
    {
        close();
    }

    /**
     * Returns the buffer size for the PipeConduit.
     */
    public override size_t bufferSize()
    {
        return _bufferSize;
    }

    /**
     * Returns the name of the device.
     */
    public override istring toString()
    {
        return "<pipe>";
    }
}

/**
 * Factory class for Pipes.
 */
class Pipe
{
    private PipeConduit _source;
    private PipeConduit _sink;

    /**
     * Create a Pipe.
     */
    public this(uint bufferSize = DefaultBufferSize)
    {
        int[2] fd;

        if (pipe(fd) == 0)
        {
            _source = new PipeConduit(cast(ISelectable.Handle) fd[0], bufferSize);
            _sink = new PipeConduit(cast(ISelectable.Handle) fd[1], bufferSize);
        }
        else
        {
            error();
        }
    }

    /* Replaces the old pipe with a new one. No memory allocation is performed.
    */
    public void recreate(uint bufferSize = DefaultBufferSize)
    {
        int[2] fd;

        if (pipe(fd) == 0)
        {
            _source.reopen(cast(ISelectable.Handle) fd[0]);
            _source._bufferSize = bufferSize;
            _sink.reopen(cast(ISelectable.Handle) fd[1]);
            _sink._bufferSize = bufferSize;
        }
        else
        {
            error();
        }
    }

    /**
     * Return the PipeConduit that you can write to.
     */
    public PipeConduit sink()
    {
        return _sink;
    }

    /**
     * Return the PipeConduit that you can read from.
     */
    public PipeConduit source()
    {
        return _source;
    }

    /**
     * Closes source and sink conduits.
     */
    public void close()
    {
        _source.close();
        _sink.close();
    }

    /**
     *
     */
    private final void error ()
    {
        throw new IOException("Pipe error: " ~ SysError.lastMsg);
    }
}

