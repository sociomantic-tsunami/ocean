/*******************************************************************************

    Structure holding a user-specified context in the form of a pointer, a class
    reference or a platform-dependant unsigned integer (a hash_t).

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.core.ContextUnion;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.core.SmartUnion;



/*******************************************************************************

    Context.

*******************************************************************************/

private union ContextUnion_
{
    hash_t  integer;
    Object  object;
    void*   pointer;
}

public alias SmartUnion!(ContextUnion_) ContextUnion;

