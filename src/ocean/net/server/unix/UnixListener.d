/*******************************************************************************

    Unix domain socket listener.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.net.server.unix.UnixListener;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.net.server.unix.UnixConnectionHandler;
import ocean.net.server.SelectListener;
import ocean.io.select.EpollSelectDispatcher;

import ocean.transition;

/******************************************************************************/

class UnixListener: SelectListener!(
    UnixConnectionHandler, EpollSelectDispatcher,
    UnixConnectionHandler.Handler[istring], // handlers
    istring // address_path
)
{
    import ocean.sys.socket.UnixSocket;
    import ocean.stdc.posix.sys.un: sockaddr_un;
    import ocean.stdc.posix.sys.socket: AF_UNIX, sockaddr;

    import ocean.stdc.posix.unistd: unlink;
    import ocean.stdc.errno: errno;

    import ocean.stdc.string: strerror_r, strlen;

    import ocean.core.Enforce;

    import ocean.util.log.Log;

    /***************************************************************************

        '\0'-terminated socket address path

    ***************************************************************************/

    private istring address_pathnul;

    /***************************************************************************

        Constructor.

        `address_path` is a file path that serves as the Unix domain server
        socket address. If it exists, it will be deleted and recreated.

        Params:
            address_path = the file path i.e. address of the Unix domain server
                           socket
            epoll        = the `EpollSelectDispatcher` instance to use for I/O
                           (connection handler parameter)
            handlers     = the map of request handlers by command, see
                           `UnixConnectionHandler` for details

        Throws:
            `Exception` if
              - `path` is too long; `path.length` must be less than
                `UNIX_PATH_MAX`,
              - an error occurred creating or binding the server socket.

    ***************************************************************************/

    public this ( istring address_path, EpollSelectDispatcher epoll,
                  UnixConnectionHandler.Handler[istring] handlers )
    {
        enforce(address_path.length < sockaddr_un.sun_path.length,
                "Unix socket path too long: " ~ address_path);

        this.address_pathnul = address_path ~ '\0';

        auto log = Log.lookup("ocean.net.server.unixsocket");

        // Don't report an error if unlink() fails. In any case success or
        // failure is solely up to the super constructor.
        if (!unlink(this.address_pathnul.ptr))
        {
            log.warn("Deleted existing socket \"{}\"", address_path);
        }

        try
        {
            sockaddr_un address;
            address.sun_family = AF_UNIX;
            address.sun_path[0 .. this.address_pathnul.length] =
                this.address_pathnul;

            super(cast(sockaddr*)&address, new UnixSocket,
                  epoll, handlers, address_path);

            log.info("Listening on \"{}\"", address_path);
        }
        catch (Exception e)
        {
            log.error("Unable to bind to or listen on \"{}\": {}",
                      address_path, getMsg(e));
            throw e;
        }
    }

    /***************************************************************************

        Deletes the socket file on shutdown.

    ***************************************************************************/

    override public void shutdown ( )
    {
        super.shutdown();

        auto log = Log.lookup("ocean.net.server.unixsocket");

        if (unlink(this.address_pathnul.ptr))
        {
            char[0x100] buf;
            auto msgnul = strerror_r(errno, buf.ptr, buf.length);
            log.error("Unable to delete socket \"{}\": {}",
                      this.address_pathnul[0 .. $ - 1],
                      msgnul[0 .. strlen(msgnul)]);
        }
        else
        {
            log.info("Deleted socket \"{}\"", this.address_pathnul[0 .. $ - 1]);
        }
    }
}
