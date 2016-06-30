/*******************************************************************************

    The pool of connections handled by a SelectListener.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.net.server.connpool.SelectListenerPool;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.net.server.connpool.ISelectListenerPoolInfo;

import ocean.net.server.connection.IConnectionHandler;

import ocean.util.container.pool.ObjectPool : AutoCtorPool;



/*******************************************************************************

    SelectListenerPool class template.

    Extends AutoCtorPool with the additional methods demanded by
    ISelectListenerPoolInfo.

    The additional T constructor argument parameters must appear after those for
    the mandatory IConnectionHandler constructor.

    Template_Params:
        T    = connection handler class
        Args = additional constructor arguments for T

*******************************************************************************/

public class SelectListenerPool ( T, Args ... ) :
    AutoCtorPool!(T, IConnectionHandler.FinalizeDg, Args), ISelectListenerPoolInfo
{
    /***************************************************************************

        Constructor.

        Params:
            finalize_dg = delegate for a connection to call when finished
                (should recycle it into this pool)
            args = T constructor arguments to be used each time an
                   object is created

    ***************************************************************************/

    public this ( IConnectionHandler.FinalizeDg finalize_dg, Args args )
    {
        super(finalize_dg, args);
    }


    /***************************************************************************

        foreach iterator over informational interfaces to the active connections
        in the pool.

    ***************************************************************************/

    public int opApply ( int delegate ( ref IConnectionHandlerInfo ) dg )
    {
        int ret;
        scope it = this.new BusyItemsIterator;
        foreach ( conn; it )
        {
            auto conn_info = cast(IConnectionHandlerInfo)conn;
            ret = dg(conn_info);
            if ( ret ) break;
        }
        return ret;
    }


    /***************************************************************************

        foreach iterator over informational interfaces to the active connections
        in the pool, and their indices.

    ***************************************************************************/

    public int opApply ( int delegate ( ref size_t, ref IConnectionHandlerInfo ) dg )
    {
        int ret;
        scope it = this.new BusyItemsIterator;
        foreach ( i, conn; it )
        {
            auto conn_info = cast(IConnectionHandlerInfo)conn;
            ret = dg(i, conn_info);
            if ( ret ) break;
        }
        return ret;
    }


    /***************************************************************************

        IPoolInfo method, wrapper to super class implementation.

        Returns:
            limit of items in pool

    ***************************************************************************/

    public override size_t limit ( )
    {
        return super.limit();
    }


    /***************************************************************************

        IPoolInfo method, wrapper to super class implementation.

        Returns:
            true if the number of items in the pool is limited or fase otherwise

    ***************************************************************************/

    public override bool is_limited ( )
    {
        return super.is_limited();
    }
}

