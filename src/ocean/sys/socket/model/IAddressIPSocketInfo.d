/*******************************************************************************

    Informational (i.e. non-destructive) interface to an address IP socket.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.sys.socket.model.IAddressIPSocketInfo;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;
import ocean.io.device.Conduit: ISelectable;



public interface IAddressIPSocketInfo
{
    /***************************************************************************

        Returns:
            true if a client connection is currently established or false if not

    ***************************************************************************/

    bool connected ( );


    /***************************************************************************

        Returns:
            I/O device instance (file descriptor under linux)

    ***************************************************************************/

    ISelectable.Handle fileHandle ( );


    /***************************************************************************

        Obtains the IP address most recently passed to bind() or connect() or
        obtained by accept().

        Returns:
            the current IP address.

    ***************************************************************************/

    cstring address ( );


    /***************************************************************************

        Obtains the port number most recently passed to bind() or connect() or
        obtained by accept().

        Returns:
            the current port number.

    ***************************************************************************/

    ushort port ( );
}
