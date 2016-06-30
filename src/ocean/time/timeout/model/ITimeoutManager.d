/*******************************************************************************

    Timeout manager interface

    The reason for this interface is to avoid requiring an application to be
    linked against the libebtree, which is required by TimeoutManager and
    ExpiryRegistration, when it uses a library module that supports a timeout
    functionality as an optional feature.
    Therefore, library modules that support a timeout functionality as an
    optional feature should always use this interface and not import
    TimeoutManager/ExpiryRegistration.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.time.timeout.model.ITimeoutManager;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.time.timeout.model.ITimeoutClient,
       ocean.time.timeout.model.IExpiryRegistration : IExpiryRegistration;

/******************************************************************************/

interface ITimeoutManager
{
    /***************************************************************************

        Tells the wall clock time time when the next client will expire.

        Returns:
            the wall clock time when the next client will expire as UNIX time
            in microseconds or ulong.max if no client is currently registered.

    ***************************************************************************/

    ulong next_expiration_us ( );

    /***************************************************************************

        Tells the time until the next client will expire.

        Returns:
            the time left until next client will expire in microseconds or
            ulong.max if no client is currently registered. 0 indicates that
            there are timed out clients that have not yet been notified and
            unregistered.

    ***************************************************************************/

    ulong us_left ( );

    /***************************************************************************

        Checks for timed out clients. For any timed out client its timeout()
        method is called, then it is unregistered, finally dg() is called with
        it as argument.

        This method should be called when the timeout set by setTimeout() has
        expired.

        If dg returns false to cancel, the clients iterated over so far are
        removed. To remove the remaining clients, call this method again.

        Params:
            dg = optional callback delegate that will be called with each timed
                 out client and must return true to continue or false to cancel.

        Returns:
            the number of expired clients.

    ***************************************************************************/

    size_t checkTimeouts ( bool delegate ( ITimeoutClient client ) dg );

    /***************************************************************************

        Registers client with the timeout manager and returns the expiry
        registration object which the registered client is associated to.

        Note: Depending on the implementation, this method may return a newly
              created object that should be kept and reused by the application.
              It is also application dependent whether the client remains
              associated to the expiry registration object after it has been
              unregistered from the timeout manager or not.

        Params:
            client = client to register

        Returns:
            expiry registration object.

    ***************************************************************************/

    IExpiryRegistration getRegistration ( ITimeoutClient client );
}

