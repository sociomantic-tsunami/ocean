/*******************************************************************************

    Contains the Unix Socket class.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.sys.socket.UnixSocket;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.core.Enforce;
import ocean.sys.socket.model.ISocket;

import ocean.net.device.LocalSocket;
import ocean.stdc.posix.sys.socket;
import ocean.stdc.posix.sys.un: UNIX_PATH_MAX;
import ocean.stdc.posix.unistd;
import ocean.text.convert.Format;


/*******************************************************************************

    Unix Socket class.

*******************************************************************************/

public class UnixSocket : ISocket
{

    /***************************************************************************

        Path to the unix domain socket.

    ***************************************************************************/

    private char[UNIX_PATH_MAX] path;


    /***************************************************************************

        Number of valid characters in path.

    ***************************************************************************/

    private size_t path_len = 0;


    /***************************************************************************

        Constructor.

    ***************************************************************************/

    public this ()
    {
        super(LocalAddress.sockaddr_un.sizeof);
    }


    /***************************************************************************

        Creates a socket endpoint for communication and sets this.fd to the
        corresponding file descriptor.

        Params:
            type = desired socket type, which specifies the communication
                   semantics. Defaults to SOCK_STREAM.

                   For Unix Sockets the valid types are:

                     - SOCK_STREAM, for a stream-oriented socket.

                     - SOCK_DGRAM, for a datagram-oriented socket that preserves
                       message boundaries (as on most UNIX implemen‐tations,
                       UNIX domain datagram sockets are always reliable and don't
                       reorder datagrams).

                     - SOCK_SEQPACKET (since Linux 2.6.4), for a connection-oriented
                       socket that preserves message boundaries and delivers messages
                       in the order that they were sent.

        Returns:
            The socket descriptor or -1 on error.
            See the ISocket socket() implementation for details.

    ***************************************************************************/

    public int socket ( int type = SOCK_STREAM )
    {
        return super.socket(AF_UNIX, type, 0);
    }


    /***************************************************************************

        Assigns a local address to this socket.
        socket() must have been called previously.

        address = The LocalAddress instance to use. Must be non-null.

        Returns:
            0 on success or -1 on failure.
            On failure errno is set appropriately.
            See the ISocket bind() implementation for details.

    ***************************************************************************/

    public int bind ( LocalAddress address )
    in
    {
        assert(address !is null);
    }
    body
    {
        auto path = address.path;
        this.path_len = path.length;
        this.path[0 .. this.path_len] = path;

        // note: cast due to duplicate but separate definitions of sockaddr
        // in Tango
        return super.bind(cast(sockaddr*)address.name());
    }


    /***************************************************************************

        Connects this socket the specified address and port.
        socket() must have been called previously.

        address = The LocalAddress instance to use. Must be non-null.

    ***************************************************************************/

    public int connect ( LocalAddress address )
    in
    {
        assert(address !is null);
    }
    body
    {
        auto path = address.path;
        this.path_len = path.length;
        this.path[0 .. this.path_len] = path;

        // note: cast due to duplicate but separate definitions of sockaddr
        // in Tango
        return super.connect(cast(sockaddr*)address.name());
    }


    /**************************************************************************

        Formats information about the socket into the provided buffer.

        Params:
            buf      = buffer to format into
            io_error = true if an I/O error has been reported

     **************************************************************************/

    override public void formatInfo ( ref char[] buf, bool io_error )
    {
        Format.format(buf, "fd={}, unix_path={}, ioerr={}",
            this.fileHandle, this.path[0 .. this.path_len], io_error);
    }
}
