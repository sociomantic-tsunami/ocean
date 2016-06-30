/*******************************************************************************

        Copyright:
            Copyright (c) 2009 Tango contributors.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Nov 2009: Initial release

        Authors: Lukas Pinkowski, Kris

*******************************************************************************/

module ocean.net.device.LocalSocket;

import ocean.transition;

import ocean.net.device.Socket;
import ocean.net.device.Berkeley;

import ocean.stdc.posix.sys.un; // : sockaddr_un, UNIX_PATH_MAX;


/*******************************************************************************

        A wrapper around the Berkeley API to implement the IConduit
        abstraction and add stream-specific functionality.

*******************************************************************************/

class LocalSocket : Socket
{
        /***********************************************************************

                Create a streaming local socket

        ***********************************************************************/

        private this ()
        {
                super (AddressFamily.UNIX, SocketType.STREAM, ProtocolType.IP);
        }

        /***********************************************************************

                Create a streaming local socket

        ***********************************************************************/

        this (cstring path)
        {
                this (new LocalAddress (path));
        }

        /***********************************************************************

                Create a streaming local socket

        ***********************************************************************/

        this (LocalAddress addr)
        {
                this();
                super.connect (addr);
        }

        /***********************************************************************

                Return the name of this device

        ***********************************************************************/

        override istring toString()
        {
                return "<localsocket>";
        }
}

/*******************************************************************************


*******************************************************************************/

class LocalServerSocket : LocalSocket
{
        /***********************************************************************

        ***********************************************************************/

        this (cstring path, int backlog=32, bool reuse=false)
        {
                auto addr = new LocalAddress (path);
                native.addressReuse(reuse).bind(addr).listen(backlog);
        }

        /***********************************************************************

                Return the name of this device

        ***********************************************************************/

        override istring toString()
        {
                return "<localaccept>";
        }

        /***********************************************************************

        ***********************************************************************/

        Socket accept (Socket recipient = null)
        {
                if (recipient is null)
                    recipient = new LocalSocket;

                native.accept (*recipient.native);
                recipient.timeout = timeout;
                return recipient;
        }
}

/*******************************************************************************

*******************************************************************************/

class LocalAddress : Address
{
        alias .sockaddr_un sockaddr_un;

        protected
        {
                sockaddr_un sun;
                cstring _path;
                size_t _pathLength;
        }

        /***********************************************************************

            -path- path to a unix domain socket (which is a filename)

        ***********************************************************************/

        this (cstring path)
        {
                assert (path.length < UNIX_PATH_MAX);

                sun.sun_family = AddressFamily.UNIX;
                sun.sun_path [0 .. path.length] = path;
                sun.sun_path [path.length .. $] = 0;

                _pathLength = path.length;
                _path = sun.sun_path [0 .. path.length];
        }

        /***********************************************************************

        ***********************************************************************/

        final override sockaddr* name ()
        {
                return cast(sockaddr*) &sun;
        }

        /***********************************************************************

        ***********************************************************************/

        final override int nameLen ()
        {
                assert (_pathLength + ushort.sizeof <= int.max);
                return cast(int) (_pathLength + ushort.sizeof);
        }

        /***********************************************************************

        ***********************************************************************/

        final override AddressFamily addressFamily ()
        {
                return AddressFamily.UNIX;
        }

        /***********************************************************************

        ***********************************************************************/

        final override istring toString ()
        {
                if (isAbstract)
                {
                    auto s = "unix:abstract=" ~ _path[1..$];
                    return assumeUnique(s);
                }
                else
                {
                   auto s = "unix:path=" ~ _path;
                   return assumeUnique(s);
                }
        }

        /***********************************************************************

        ***********************************************************************/

        final cstring path ()
        {
                return _path;
        }

        /***********************************************************************

        ***********************************************************************/

        final bool isAbstract ()
        {
                return _path[0] == 0;
        }
}

/******************************************************************************

******************************************************************************/

version (UnitTest)
{
    import ocean.core.Test;
    import ocean.stdc.string; // : strnlen
    import ocean.stdc.posix.sys.socket; // : AF_UNIX
}

unittest
{
    istring path = "I do not exist";
    auto addr = new LocalAddress(path);
    auto saddr = (cast(sockaddr_un*) addr.name);
    test!("==")(saddr.sun_family, AF_UNIX, "Family not properly set");
    test!("==")(strnlen(saddr.sun_path.ptr, UNIX_PATH_MAX), path.length,
                "Path length incorrect");
    test!("==")(saddr.sun_path.ptr[0 .. path.length], path,
                "Path not properly set");
}
