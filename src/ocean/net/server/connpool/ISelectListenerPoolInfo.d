/*******************************************************************************

    Informational (i.e. non-destructive) interface to a select listener
    connection pool.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.net.server.connpool.ISelectListenerPoolInfo;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.net.server.connection.IConnectionHandlerInfo;

import ocean.util.container.pool.model.IPoolInfo;



public interface ISelectListenerPoolInfo : IPoolInfo
{
    /***************************************************************************

        Convenience alias for implementing classes.

    ***************************************************************************/

    alias .IConnectionHandlerInfo IConnectionHandlerInfo;


    /***************************************************************************

        foreach iterator over informational interfaces to the active connections
        in the pool.

    ***************************************************************************/

    int opApply ( int delegate ( ref IConnectionHandlerInfo ) dg );


    /***************************************************************************

        foreach iterator over informational interfaces to the active connections
        in the pool, and their indices.

    ***************************************************************************/

    int opApply ( int delegate ( ref size_t, ref IConnectionHandlerInfo ) dg );
}

