/*******************************************************************************

    Bindings for Elastic Binary Trees library's operations on pointer nodes.

    This module contains the D binding of the library functions of ebpttree.h.
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

module ocean.util.container.ebtree.c.ebpttree;

import ocean.util.container.ebtree.c.ebtree;
import ocean.util.container.ebtree.c.eb32tree;
import ocean.util.container.ebtree.c.eb64tree;

/// See original's library documentation for details.
struct ebpt_node
{
    eb_node node;
    void* key;
}

extern (C):


/// See original's library documentation for details.
ebpt_node* ebpt_first(eb_root *root);

/// See original's library documentation for details.
ebpt_node* ebpt_last(eb_root* root);

/// See original's library documentation for details.
ebpt_node* ebpt_next(ebpt_node* ebpt);

/// See original's library documentation for details.
ebpt_node* ebpt_prev(ebpt_node* ebpt);

/// See original's library documentation for details.
ebpt_node* ebpt_next_unique(ebpt_node* ebpt);

/// See original's library documentation for details.
ebpt_node* ebpt_prev_unique(ebpt_node* ebpt);

/// See original's library documentation for details.
void ebpt_delete(ebpt_node* ebpt);

/// See original's library documentation for details.
ebpt_node* ebpt_lookup(eb_root* root, void* x);

/// See original's library documentation for details.
ebpt_node* ebpt_lookup_le(eb_root* root, void* x);

/// See original's library documentation for details.
ebpt_node* ebpt_lookup_ge(eb_root* root, void* x);

/// See original's library documentation for details.
ebpt_node* ebpt_insert(eb_root* root, ebpt_node* neww);


/// See original's library documentation for details.
void ebpt_delete(ebpt_node* ebpt);

/// See original's library documentation for details.
ebpt_node* ebpt_lookup(eb_root* root, void* x);

/// See original's library documentation for details.
ebpt_node* ebpt_insert(eb_root* root, ebpt_node* neww);
