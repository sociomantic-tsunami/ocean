/*******************************************************************************

    Interface to obtain cache statistics from an expiring cache.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.cache.model.IExpiringCacheInfo;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.cache.model.ICacheInfo;

interface IExpiringCacheInfo : ICacheInfo
{
    /***************************************************************************

        Returns:
            the number of cache lookups  since instantiation or the last call of
            resetStats() where the element could be found but was expired.

    ***************************************************************************/

    uint num_expired ( );
}
