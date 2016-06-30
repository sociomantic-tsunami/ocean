/*******************************************************************************

    Interfaces to manage and get information about a limitable pool. A limitable
    pool has a maximum size (i.e. number of items) which cannot be exceeded.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.pool.model.ILimitable;



/*******************************************************************************

    Informational interface to a limitable pool.

*******************************************************************************/

public interface ILimitableInfo
{
    /***************************************************************************

        Returns:
            limit of items in pool

    ***************************************************************************/

    size_t limit ( );


    /***************************************************************************

        Returns:
            true if the number of items in the pool is limited or fase otherwise

    ***************************************************************************/

    bool is_limited ( );
}


/*******************************************************************************

    Management interface to a limitable pool.

*******************************************************************************/

public interface ILimitable : ILimitableInfo
{
    /**************************************************************************

        Magic limit value indicating no limitation

     **************************************************************************/

    const size_t unlimited = size_t.max;


    /***************************************************************************

        Sets the limit of number of items in pool or disables limitation for
        limit = unlimited. When limiting the pool, any excess idle items are
        reset and deleted.

        Params:
            limit = new limit of number of items in pool; unlimited disables
               limitation

        Returns:
            new limit

    ***************************************************************************/

    size_t setLimit ( size_t limit );
}

