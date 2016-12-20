/*******************************************************************************

        Copyright:
            Copyright (c) 2004 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version:
            Mar 2004: Initial release
            Jan 2005: RedShodan patch for timeout query
            Dec 2006: Outback release
            Apr 2009: revised for asynchronous IO

        Authors: Kris

*******************************************************************************/

module ocean.net.device.Socket;

import ocean.transition;

import ocean.sys.Common;

import ocean.io.device.Conduit;

import ocean.net.device.Berkeley;

/*******************************************************************************

        A wrapper around the Berkeley API to implement the IConduit
        abstraction and add stream-specific functionality.

*******************************************************************************/

deprecated class Socket : Conduit, ISelectable
{
        public alias native socket;             // backward compatibility

        private SocketSet pending;              // synchronous timeouts
        private Berkeley  berkeley;             // wrap a berkeley socket


        /***********************************************************************

                Create a streaming Internet socket

        ***********************************************************************/

        this ()
        {
                this (AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
        }

        /***********************************************************************

                Create an Internet Socket with the provided characteristics

        ***********************************************************************/

        this (Address addr)
        {
                this (addr.addressFamily, SocketType.STREAM, ProtocolType.TCP);
        }

        /***********************************************************************

                Create an Internet socket

        ***********************************************************************/

        this (AddressFamily family, SocketType type, ProtocolType protocol)
        {
                berkeley.open (family, type, protocol);
        }

        /***********************************************************************

                Return the name of this device

        ***********************************************************************/

        override istring toString()
        {
                return "<socket>";
        }

        /***********************************************************************

                Models a handle-oriented device.

                TODO: figure out how to avoid exposing this in the general
                case

        ***********************************************************************/

        Handle fileHandle ()
        {
                return cast(Handle) berkeley.sock;
        }

        /***********************************************************************

                Return the socket wrapper

        ***********************************************************************/

        Berkeley* native ()
        {
                return &berkeley;
        }

        /***********************************************************************

                Return a preferred size for buffering conduit I/O

        ***********************************************************************/

        override size_t bufferSize ()
        {
                return 1024 * 8;
        }

        /***********************************************************************

                Connect to the provided endpoint

        ***********************************************************************/

        Socket connect (istring address, uint port)
        {
                assert(port < ushort.max);
                scope addr = new IPv4Address (address, cast(ushort) port);
                return connect (addr);
        }

        /***********************************************************************

                Connect to the provided endpoint

        ***********************************************************************/

        Socket connect (Address addr)
        {
                native.connect (addr);
                return this;
        }

        /***********************************************************************

                Bind this socket. This is typically used to configure a
                listening socket (such as a server or multicast socket).
                The address given should describe a local adapter, or
                specify the port alone (ADDR_ANY) to have the OS assign
                a local adapter address.

        ***********************************************************************/

        Socket bind (Address address)
        {
                berkeley.bind (address);
                return this;
        }

        /***********************************************************************

                Inform other end of a connected socket that we're no longer
                available. In general, this should be invoked before close()

                The shutdown function shuts down the connection of the socket:

                    -   stops receiving data for this socket. If further data
                        arrives, it is rejected.

                    -   stops trying to transmit data from this socket. Also
                        discards any data waiting to be sent. Stop looking for
                        acknowledgement of data already sent; don't retransmit
                        if any data is lost.

        ***********************************************************************/

        Socket shutdown ()
        {
                berkeley.shutdown (SocketShutdown.BOTH);
                return this;
        }

        /***********************************************************************

                Release this Socket

                Note that one should always disconnect a Socket under
                normal conditions, and generally invoke shutdown on all
                connected sockets beforehand

        ***********************************************************************/

        override void detach ()
        {
                berkeley.detach;
        }

       /***********************************************************************

                Read content from the socket. Note that the operation
                may timeout if method setTimeout() has been invoked with
                a non-zero value.

                Returns the number of bytes read from the socket, or
                IConduit.Eof where there's no more content available.

        ***********************************************************************/

        override size_t read (void[] dst)
        {
                int x = Eof;
                if (wait (true))
                   {
                   x = native.receive (dst);
                   if (x <= 0)
                       x = Eof;
                   }
                return x;
        }

        /***********************************************************************

        ***********************************************************************/

        override size_t write (Const!(void)[] src)
        {
                int x = Eof;
                if (wait (false))
                   {
                   x = native.send (src);
                   if (x < 0)
                       x = Eof;
                   }
                return x;
        }

        /***********************************************************************

                Transfer the content of another conduit to this one. Returns
                the dst OutputStream, or throws IOException on failure.

                Does optimized transfers

        ***********************************************************************/

        override OutputStream copy (InputStream src, size_t max = -1)
        {
                auto x = cast(ISelectable) src;
                super.copy (src, max);
                return this;
        }

        /***********************************************************************

                Manage socket IO under a timeout

        ***********************************************************************/

        package final bool wait (bool reading)
        {
                // did user enable timeout checks?
                if (timeout != -1)
                   {
                   SocketSet read, write;

                   // yes, ensure we have a SocketSet
                   if (pending is null)
                       pending = new SocketSet (1);
                   pending.reset.add (native.sock);

                   // wait until IO is available, or a timeout occurs
                   if (reading)
                       read = pending;
                   else
                      write = pending;
                   int i = pending.select (read, write, null, timeout * 1000);
                   if (i <= 0)
                      {
                      if (i is 0)
                          super.error ("Socket :: request timeout");
                      return false;
                      }
                   }
                return true;
        }

        /***********************************************************************

                Throw an IOException noting the last error

        ***********************************************************************/

        final void error ()
        {
                super.error (this.toString ~ " :: " ~ SysError.lastMsg);
        }
}



/*******************************************************************************


*******************************************************************************/

deprecated class ServerSocket : Socket
{
        /***********************************************************************

        ***********************************************************************/

        this (uint port, int backlog=32, bool reuse=false)
        {
                scope addr = new IPv4Address (cast(ushort) port);
                this (addr, backlog, reuse);
        }

        /***********************************************************************

        ***********************************************************************/

        this (Address addr, int backlog=32, bool reuse=false)
        {
                super (addr);
                berkeley.addressReuse(reuse).bind(addr).listen(backlog);
        }

        /***********************************************************************

                Return the name of this device

        ***********************************************************************/

        override istring toString()
        {
                return "<accept>";
        }

        /***********************************************************************

        ***********************************************************************/

        Socket accept (Socket recipient = null)
        {
                if (recipient is null)
                    recipient = new Socket;

                berkeley.accept (recipient.berkeley);

                recipient.timeout = timeout;
                return recipient;
        }
}
