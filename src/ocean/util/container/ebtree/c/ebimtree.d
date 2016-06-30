/*******************************************************************************

    Bindings for Elastic Binary Trees library's operations on Indirect
    Multi-Byte data nodes.

    This module contains the D binding of the library functions of ebimtree.h.
    Please consult the original header documentation for details.

    You need to have the library installed and link with -lebtree.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

        Bear in mind this module provides bindings to an external library that
        has its own license, which might be more restrictive. Please check the
        external library license to see which conditions apply for linking.

*******************************************************************************/

module ocean.util.container.ebtree.c.ebimtree;

import ocean.util.container.ebtree.c.ebtree;
import ocean.util.container.ebtree.c.ebpttree;

extern (C):

/// See original's library documentation for details.
ebpt_node* ebim_lookup(ebpt_node* root, void *x, uint len);

/// See original's library documentation for details.
ebpt_node* ebim_insert(ebpt_node* root, ebpt_node* neww, uint len);
