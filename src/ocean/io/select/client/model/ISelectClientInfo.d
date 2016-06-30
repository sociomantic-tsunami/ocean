/*******************************************************************************

    Informational (i.e. non-destructive) interface to an ISelectClient.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.select.client.model.ISelectClientInfo;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.io.model.IConduit: ISelectable;

import ocean.sys.Epoll;



public interface ISelectClientInfo
{
    /**************************************************************************

        Returns:
            I/O device instance (file descriptor under linux)

     **************************************************************************/

    ISelectable.Handle fileHandle ( );


    /**************************************************************************

        Returns:
            bitfield of events which the client should be registered for

     **************************************************************************/

    Epoll.Event events ( );


    /***************************************************************************

        Returns:
            I/O timeout value of client in microseconds. A value of 0 means that
            no timeout is set for this client

    ***************************************************************************/

    ulong timeout_value_us ( );


    /***************************************************************************

        Returns:
            true if this client has timed out or false otherwise

    ***************************************************************************/

    bool timed_out ( );


    /**************************************************************************

        Returns true if the client's file handle is registered with epoll for
        the events specified with the client reference as attachment. Returns
        false if the client's file handle is not registered with epoll or, when
        multiple instances of the implementing class share the same file handle,
        if it is registered with another instance.

        Note that the returned value can be true by mistake when epoll
        unexpectedly unregistered the file descriptor as it happens when the
        file descriptor is closed (e.g. on error). However, the returned value
        cannot be true by mistake.

        Returns:
            true if the client's file handle is registered with epoll for the
            events specified with the client reference as attachment

     **************************************************************************/

    bool is_registered ( );


    /**************************************************************************

        Returns an identifier string of this instance. Defaults to the name of
        the class, but may be overridden if more detailed information is
        required.

        Returns:
             identifier string of this instance

     **************************************************************************/

    debug cstring id ( );


    /***************************************************************************

        Returns a string describing this client, for use in debug messages.

        Returns:
            string describing client

    ***************************************************************************/

    debug istring toString ( );
}
