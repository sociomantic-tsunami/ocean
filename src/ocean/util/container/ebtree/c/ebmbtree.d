/*******************************************************************************

    Bindings for Elastic Binary Trees library's operations on Multi-Byte data
    nodes.

    This module contains the D binding of the library functions of ebmbtree.h.
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

module ocean.util.container.ebtree.c.ebmbtree;

import ocean.util.container.ebtree.c.ebtree;

/// See original's library documentation for details.
struct ebmb_node
{
    eb_node node;
    char[0] key;
}


extern (C):

/// See original's library documentation for details.
ebmb_node* ebmb_first(eb_root* root);

/// See original's library documentation for details.
ebmb_node* ebmb_last(eb_root* root);

/// See original's library documentation for details.
ebmb_node* ebmb_next(ebmb_node* ebmb);

/// See original's library documentation for details.
ebmb_node* ebmb_prev(ebmb_node* ebmb);

/// See original's library documentation for details.
ebmb_node* ebmb_next_unique(ebmb_node* ebmb);

/// See original's library documentation for details.
ebmb_node* ebmb_prev_unique(ebmb_node* ebmb);

/// See original's library documentation for details.
void ebmb_delete(ebmb_node* ebmb);

/// See original's library documentation for details.
ebmb_node* ebmb_lookup(eb_root* root, void* x, uint len);
/// See original's library documentation for details.
ebmb_node* ebmb_insert(eb_root* root, ebmb_node* neww, uint len);
/// See original's library documentation for details.
ebmb_node* ebmb_lookup_longest(eb_root* root, void* x);
/// See original's library documentation for details.
ebmb_node* ebmb_lookup_prefix(eb_root* root, void* x, uint pfx);
/// See original's library documentation for details.
ebmb_node* ebmb_insert_prefix(eb_root* root, ebmb_node* neww, uint len);
