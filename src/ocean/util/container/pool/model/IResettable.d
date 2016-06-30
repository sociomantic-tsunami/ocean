/*******************************************************************************

    TODO: description of module

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.pool.model.IResettable;



/*******************************************************************************

    Interface for pool items that offer a reset method. For each object stored
    in the object pool which implements this interface reset() is called when
    it is recycled or removed.

*******************************************************************************/

public interface Resettable
{
    void reset ( );
}

