/*******************************************************************************

    As linux on 64 machines is using only up to 56 bits for the user address
    space (see https://www.kernel.org/doc/Documentation/x86/x86_64/mm.txt) we
    can use bits from at least 56 to 63 for stuffing in the least significant 8
    bits of the fd into the epoll registration. This can be used to check if
    the ISelectClient's registration triggering in epoll wait is made for the
    previous usage of the ISelectClient (for the wrong fd). This is not 100%
    accurate, as the file descriptors could be reused but it can be in general
    this is the best we can to find out expired registrations that are not
    unregistered from epoll.

    This module provides FdObjEpollData structure that binds fd
    and the object used at the registration time, so that they both can
    be registered with epoll and returned with epoll_wait to the user.

    Copyright:
        Copyright (c) 2017 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.select.selector.EpollFdSanity;

version (UnitTest)
{
    import ocean.core.Test;
}

/*******************************************************************************

    Struct binding fd and a Object.

*******************************************************************************/

public struct FdObjEpollData
{
    /// Number of bits to store address in
    private enum address_bits = 56;

    /// Mask for the user-space address
    private enum address_mask = (1UL << address_bits) - 1;

    /// Mask for the storing part of the fd
    private enum fd_mask = ~address_mask;

    static assert(address_mask + fd_mask == ulong.max);

    /// Object instance
    public Object obj;

    /// client's fd at the time of the registration (least significant byte)
    private ubyte fd;

    /***************************************************************************

        Encodes the Object's address and the fd's least significant byte
        into a ulong, suitable to register with epoll.

        Params:
            obj = Object to store in the epoll_data instance
            fd = file descriptor to store the least significant byte of in
                the epoll_data instance.

        Returns:
            combination of the Objects's current address and part of the fd
            to register with the epoll.

    ***************************************************************************/

    public static ulong encode (Object obj, int fd)
    {
        return cast(ulong)(
               (cast(ulong)cast(void*)obj & address_mask) |
               (cast(ulong)(fd & 0xFF) << address_bits));
    }

    /***************************************************************************

        Parses the registration to extract the Object and the fd part
        from it. Reverses the process of encode

        Params:
            registration = registration containing Object and accompanying
            fd.

        Returns:
            FdObjEpollData struct containing Object and accompanying fd.

    ***************************************************************************/

    public static FdObjEpollData decode (ulong registration)
    {
        FdObjEpollData data;
        data.obj = cast(Object)cast(void*)(registration & address_mask);
        data.fd = cast(ubyte)((registration & fd_mask) >> address_bits);
        return data;
    }

    /***************************************************************************

        Compares the appropriate byte of the given fd with the instance
        of this struct.

        Params:
            fd = fd which we want to confirmed if it was registered with
                 the epoll.

        Returns:
            true if fd's lowest byte and the byte stored in the registration
            match, false otherwise

    ***************************************************************************/

    public bool verifyFd (int fd)
    {
        return (&this).fd == (fd & 0xFF);
    }
}

///
unittest
{
    auto client = new Object;
    int fd = 100;
    auto r = FdObjEpollData.decode(FdObjEpollData.encode(client, fd));

    test!("is")(client, r.obj);
    test!("==")(r.verifyFd(fd), true);
}
