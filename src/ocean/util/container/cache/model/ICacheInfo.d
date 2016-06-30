/*******************************************************************************

    Cache info interface.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.cache.model.ICacheInfo;

interface ICacheInfo
{
    /***************************************************************************

        Returns:
            the maximum number of items the cache can have.

    ***************************************************************************/

    public size_t max_length ( );

    /***************************************************************************

        Returns:
            the number of items currently in the cache.

    ***************************************************************************/

    public size_t length ( );

    /***************************************************************************

        Returns:
            the number of cache lookups since instantiation or the last call of
            resetStats().

    ***************************************************************************/

    uint num_lookups ( );

    /***************************************************************************

        Returns:
            the number of cache lookups since instantiation or the last call of
            resetStats() where the element could not be found.

    ***************************************************************************/

    uint num_misses  ( );

    /***************************************************************************

        Resets the statistics counter values.

    ***************************************************************************/

    void resetStats ( );
}
