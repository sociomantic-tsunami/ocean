/*******************************************************************************

    Extends ICache by tracking the creation time of each cache element.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.cache.model.ITrackCreateTimesCache;

import ocean.util.container.cache.model.ICache;

import ocean.stdc.time: time_t;

/******************************************************************************/

abstract class ITrackCreateTimesCache : ICache
{
    /***************************************************************************

        Constructor.

        Params:
            max_items = maximum number of items in the cache, set once, cannot
                be changed

    ***************************************************************************/

    public this ( size_t max_items )
    {
        super(max_items);
    }

    /*******************************************************************************

        Obtains the creation time for the cache element corresponding to key.

        Params:
            key = cache element key

        Returns:
            the creation time of the corresponding element or 0 if not found.

    *******************************************************************************/

    abstract public time_t createTime ( hash_t key );
}
