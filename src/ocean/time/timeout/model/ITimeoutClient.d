/*******************************************************************************

    Interface for a class whose instances can time out.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.time.timeout.model.ITimeoutClient;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;


/******************************************************************************/

interface ITimeoutClient
{
    /***************************************************************************

        Invoked when the client times out.

    ***************************************************************************/

    void timeout ( );

    /***************************************************************************

        Identifier string for debugging.

    ***************************************************************************/

    debug cstring id ( );
}
