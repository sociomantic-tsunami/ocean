/*******************************************************************************

    IP socket that memorises its address

    TODO: Add an AddressIPSocket subclass with host resolution.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.sys.socket.AddressIPSocket;

import ocean.sys.socket.model.IAddressIPSocketInfo;

import ocean.sys.socket.IPSocket,
       ocean.sys.socket.InetAddress,
       ocean.sys.socket.AddrInfo;

import ocean.transition;

import ocean.io.device.Conduit: ISelectable;

import ocean.stdc.string: strlen;


/******************************************************************************

    IP socket class, memorises the address most recently passed to bind() or
    connect() or obtained by accept().

    Template_Params:
        IPv6 = true: use IPv6, false: use IPv4

 ******************************************************************************/

class AddressIPSocket ( bool IPv6 = false ) : IPSocket!(IPv6), IAddressIPSocketInfo
{
    /**************************************************************************

        Internet address

     **************************************************************************/

    private InetAddress in_address;

    /**************************************************************************

        Internet address string buffer, passed to inet_pton()/inet_ntop().

     **************************************************************************/

    private char[in_address.addrstrlen] ip_address_;

    /**************************************************************************

        Number of valid characters in address_.

     **************************************************************************/

    private size_t ip_address_len = 0;

    /**************************************************************************

        Obtains the IP address most recently passed to bind() or connect() or
        obtained by accept().

        Returns:
            the current IP address.

     **************************************************************************/

    public cstring address ( )
    {
        return this.ip_address_[0 .. this.ip_address_len];
    }

    /***************************************************************************

        Asks the operating system what address & port this socket is actually
        bound to and updates the internal buffers accordingly.

        This can be useful when you bind to port 0 which means that the OS will
        choose a random port for you and you want to find out which one was
        chosen.

        Returns:
            0 on success, -1 on failure

    ***************************************************************************/

    public int updateAddress ( )
    {
        return this.getsockname(this.in_address.addr);
    }

    /**************************************************************************

        Obtains the port number most recently passed to bind() or connect() or
        obtained by accept().

        Returns:
            the current port number.

     **************************************************************************/

    public ushort port ( )
    {
        return this.in_address.port;
    }

    /***************************************************************************

        Returns:
            true if a client connection is currently established or false if
            not.

    ***************************************************************************/

    public bool connected ( )
    {
        return this.fileHandle >= 0;
    }

    /***************************************************************************

        IAddressIPSocketInfo interface method. Wrapper for method implemented by
        super class.

        Returns:
            I/O device instance (file descriptor under linux)

    ***************************************************************************/

    public override Handle fileHandle ( )
    {
        return super.fileHandle();
    }

    /**************************************************************************

        Obtains the address most recently passed to bind() or connect() or
        obtained by accept().

        Returns:
            the current address.

     **************************************************************************/

    public InAddr in_addr ( )
    {
        return this.in_address.addr;
    }

    /**************************************************************************

        Assigns a local address and optionally a port to this socket and
        memorises address and port. This socket needs to have been created by
        socket().

        Params:
            local_ip_address = local IP address
            local_port       = local port or 0 to use the wildcard "any" port

        Returns:
            0 on success or -1 on failure. On failure errno is set
            appropriately.

        Errors:
            as the overridden method but also sets errno to EINVAL if the
            address does not contain a valid IP address string.

     **************************************************************************/

    public override int bind ( cstring local_ip_address, ushort local_port = 0 )
    {
        if (auto a = this.in_address(local_ip_address, local_port))
        {
            scope (exit) this.setAddress();
            return super.bind(a);
        }
        else
        {
            return -1;
        }
    }

    /**************************************************************************

        Assigns the wildcard "any" local address and optionally a port to this
        socket and memorises address and port. This socket needs to have been
        created by socket().

        Params:
            local_port = local port or 0 to use the wildcard "any" port

        Returns:
            0 on success or -1 on failure. On failure errno is set
            appropriately.

     **************************************************************************/

    public override int bind ( ushort local_port )
    {
        scope (exit) this.setAddress();

        return super.bind(this.in_address(local_port));
    }

    /**************************************************************************

        Connects this socket the specified address and port and memorises
        address and port. This socket needs to have been created by socket().

        Params:
            remote_ip_address = remote IP address
            remote_port       = remote port

        Returns:
            0 on success or -1 on failure. On failure errno is set
            appropriately.

        Errors:
            as the overridden method but also sets errno to EINVAL if the
            address does not contain a valid IP address string.

     **************************************************************************/

    public override int connect ( cstring remote_ip_address, ushort remote_port )
    {
        if (auto a = this.in_address(remote_ip_address, remote_port))
        {
            scope (exit) this.setAddress();
            return super.connect(a);
        }
        else
        {
            return -1;
        }
    }

    /**************************************************************************

        Connects this socket the specified address memorises and it. This socket
        needs to have been created by socket().

        Params:
            remote_address = remote address

        Returns:
            0 on success or -1 on failure. On failure errno is set
            appropriately.

        Errors:
            as above.

     **************************************************************************/

    public override int connect ( InAddr remote_address )
    {
        scope (exit) this.setAddress();

        return super.connect(this.in_address = remote_address);
    }

    /**************************************************************************

        Calls accept() to accept a connection from a listening socket, sets
        this.fd to the accepted socket file descriptor and memorises the remote
        address and port.

        Params:
            listening_socket = the listening socket to accept the new connection
                               from
            remote_address   = filled in with the address of the peer socket, as
                               known to the communications layer
            flags            = socket flags, see description above

        Returns:
            the file descriptor of the accepted socket on success or -1 on
            failure. On failure errno is set appropriately.

     **************************************************************************/

    public override int accept ( ISelectable listening_socket,
                                 ref InAddr remote_address,
                                 SocketFlags flags = SocketFlags.None )
    {
        scope (exit) this.setAddress(remote_address);

        return super.accept(listening_socket, remote_address, flags);
    }

    /**************************************************************************

        Calls accept() to accept a connection from a listening socket, sets
        this.fd to the accepted socket file descriptor and memorises the remote
        address and port.

        Params:
            listening_socket = the listening socket to accept the new connection
                               from
            remote_address   = filled in with the address of the peer socket, as
                               known to the communications layer
            nonblocking      = true: make the accepted socket nonblocking
                               false: leave it blocking

        Returns:
            the file descriptor of the accepted socket on success or -1 on
            failure. On failure errno is set appropriately.

     **************************************************************************/

    public override int accept ( ISelectable listening_socket,
                                 ref InAddr remote_address, bool nonblocking )
    {
        scope (exit) this.setAddress(remote_address);

        return super.accept(listening_socket, remote_address, nonblocking);
    }


    /**************************************************************************

        Calls accept() to accept a connection from a listening socket, sets
        this.fd to the accepted socket file descriptor and memorises the remote
        address and port.

        Params:
            listening_socket = the listening socket to accept the new connection
                               from
            flags            = socket flags, see description above

        Returns:
            the file descriptor of the accepted socket on success or -1 on
            failure. On failure errno is set appropriately.

     **************************************************************************/

    public override int accept ( ISelectable listening_socket,
                                 SocketFlags flags = SocketFlags.init )
    {
        scope (exit) this.setAddress();

        return super.accept(listening_socket, this.in_address.addr, flags);
    }

    /**************************************************************************

        Calls accept() to accept a connection from a listening socket, sets
        this.fd to the accepted socket file descriptor and memorises the remote
        address and port.

        Params:
            listening_socket = the listening socket to accept the new connection
                               from
            nonblocking      = true: make the accepted socket nonblocking,
                               false: leave it blocking

        Returns:
            the file descriptor of the accepted socket on success or -1 on
            failure. On failure errno is set appropriately.

     **************************************************************************/


    public override int accept ( ISelectable listening_socket,
                                 bool nonblocking )
    {
        scope (exit) this.setAddress();

        return super.accept(listening_socket,
                            this.in_address.addr, nonblocking);
    }

    /**************************************************************************

        Sets this.in_address to address and updates this.ip_address_.

        Params:
            address = input address

     **************************************************************************/

    private void setAddress ( InAddr address )
    {
        this.in_address = address;
        this.setAddress();
    }

    /**************************************************************************

        Updates this.ip_address_.

     **************************************************************************/

    private void setAddress ( )
    {
        this.ip_address_len = this.in_address.inet_ntop(this.ip_address_).length;
    }
}

// Test that methods that accept IP addresses in presentation notation
// correctly accept valid and reject invalid addresses.

version (UnitTest)
{
    import ocean.core.Test;
    import core.stdc.errno: errno, EINVAL, EBADF;
}

unittest
{
    {
        scope s = new AddressIPSocket!();
        // With s.fd == -1 the connect(2) call should fail with EBADF if the
        // inet_pton(3) call succeeds.
        assert(s.fd == -1);

        errno = 0;
        test!("==")(s.bind("127.0.0.1", 12345), -1);
        test!("==")(errno, EBADF);
        test!("==")(s.address, "127.0.0.1");
        test!("==")(s.port, 12345);

        errno = 0;
        test!("==")(s.bind("Hello World!", 6789), -1);
        test!("==")(errno, EINVAL);
        test!("==")(s.address, "127.0.0.1");
        test!("==")(s.port, 12345);

        errno = 0;
        test!("==")(s.connect("127.0.0.2", 9876), -1);
        test!("==")(errno, EBADF);
        test!("==")(s.address, "127.0.0.2");
        test!("==")(s.port, 9876);

        errno = 0;
        test!("==")(s.connect("Hello World!", 54321), -1);
        test!("==")(errno, EINVAL);
        test!("==")(s.address, "127.0.0.2");
        test!("==")(s.port, 9876);
    }

    {
        scope s = new AddressIPSocket!(true);
        assert(s.fd == -1);

        errno = 0;
        // IP address taken from the Linux manual page for inet_pton(3).
        test!("==")(s.bind("::ffff:204.152.189.116", 12345), -1);
        test!("==")(errno, EBADF);
        test!("==")(s.address, "::ffff:204.152.189.116");
        test!("==")(s.port, 12345);

        errno = 0;
        test!("==")(s.bind("Hello World!", 6789), -1);
        test!("==")(errno, EINVAL);
        test!("==")(s.address, "::ffff:204.152.189.116");
        test!("==")(s.port, 12345);

        errno = 0;
        test!("==")(s.connect("::ffff:204.152.189.117", 9876), -1);
        test!("==")(errno, EBADF);
        test!("==")(s.address, "::ffff:204.152.189.117");
        test!("==")(s.port, 9876);

        errno = 0;
        test!("==")(s.connect("Hello World!", 54321), -1);
        test!("==")(errno, EINVAL);
        test!("==")(s.address, "::ffff:204.152.189.117");
        test!("==")(s.port, 9876);
    }
}
