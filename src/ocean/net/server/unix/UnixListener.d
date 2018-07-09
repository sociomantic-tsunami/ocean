/*******************************************************************************

    Unix domain socket listener.

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.net.server.unix.UnixListener;


import ocean.net.server.unix.UnixConnectionHandler;
import ocean.net.server.SelectListener;
import ocean.io.select.EpollSelectDispatcher;

import ocean.transition;

/// Provides default functionality for handling unix socket commands.
public class UnixListener : UnixSocketListener!( BasicCommandHandler )
{
    /// Provide basic command handling functionality.
    public BasicCommandHandler handler;

    /***********************************************************************

        Constructor to create the basic command handler directly from
        an array of handlers.

        Params:
            address_path = the file path i.e. addreBasicCommandHandlerss of the Unix domain
                            server socket
            epoll        = the `EpollSelectDispatcher` instance to use for
                            I/O (connection handler parameter)
            handlers     = Array of command to handler delegate.

        Throws:
        `Exception` if
            - `path` is too long; `path.length` must be less than
            `UNIX_PATH_MAX`,
            - an error occurred creating or binding the server socket.

    ***********************************************************************/

    public this ( istring address_path, EpollSelectDispatcher epoll,
                  BasicCommandHandler.Handler[istring] handlers )
    {
        this.handler = new BasicCommandHandler(handlers);
        super(address_path, epoll, this.handler);
    }
}

/*******************************************************************************

    Params:
        CommandHandlerType = The request handler to use when processing commands.
                             The type is passed as the template argument of
                             UnixConnectionHandler and is assumed to have a
                             callable member `void handle ( cstring, cstring,
                             void delegate ( cstring ))`.

*******************************************************************************/

public class UnixSocketListener ( CommandHandlerType ) : SelectListener!(
    UnixSocketConnectionHandler!(CommandHandlerType), EpollSelectDispatcher,
    CommandHandlerType,
    istring // address_path
)
{
    import ocean.sys.socket.UnixSocket;
    import ocean.stdc.posix.sys.un: sockaddr_un;
    import ocean.stdc.posix.sys.socket: AF_UNIX, sockaddr;

    import core.sys.posix.unistd: unlink;
    import core.stdc.errno: errno;

    import ocean.stdc.string: strerror_r, strlen;

    import ocean.core.Enforce;

    import ocean.util.log.Logger;

    import core.sys.posix.sys.stat: umask;

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
            handler      = Command handler.

        Throws:
            `Exception` if
              - `path` is too long; `path.length` must be less than
                `UNIX_PATH_MAX`,
              - an error occurred creating or binding the server socket.

    ***************************************************************************/

    public this ( istring address_path, EpollSelectDispatcher epoll,
                  CommandHandlerType handler )
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

            // The socket should be opened with rw-rw-r-- permissions,
            // so the owner and group could connect to it by default.
            auto old_umask = umask(Octal!("002"));
            scope (exit)
                umask(old_umask);

            super(cast(sockaddr*)&address, new UnixSocket,
                  epoll, handler, address_path);

            log.info("Listening on \"{}\"", address_path);
        }
        catch (Exception e)
        {
            log.error("Unable to bind to or listen on \"{}\": {}",
                      address_path, e.message());
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
