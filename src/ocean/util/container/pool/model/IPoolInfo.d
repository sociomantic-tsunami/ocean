/*******************************************************************************

    Informational interface to an object pool, which only provides methods to
    get info about the state of the pool, no methods to modify anything.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.pool.model.IPoolInfo;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.pool.model.IFreeList;
import ocean.util.container.pool.model.ILimitable;



public interface IPoolInfo : IFreeListInfo, ILimitableInfo
{
    /**************************************************************************

        Returns the number of items in pool.

        Returns:
            the number of items in pool

     **************************************************************************/

    size_t length ( );

    /**************************************************************************

        Returns the number of busy items in pool.

        Returns:
            the number of busy items in pool

     **************************************************************************/

    size_t num_busy ( );
}
