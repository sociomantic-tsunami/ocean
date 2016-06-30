/******************************************************************************

    Bindings for Elastic Binary Trees library's operations on 64bit nodes.

    This module contains the D binding of the library functions of eb64tree.h.
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

 ******************************************************************************/

module ocean.util.container.ebtree.c.eb64tree;

import ocean.util.container.ebtree.c.ebtree: eb_root, eb_node;

/// See original's library documentation for details.
struct eb64_node
{
    eb_node node; // the tree node, must be at the beginning
    ulong   key;

    /// Return next node in the tree, skipping duplicates, or NULL if none

    typeof (this) next ( )
    {
        return eb64_next(this);
    }

    /// Return previous node in the tree, or NULL if none

    typeof (this) prev ( )
    {
        return eb64_prev(this);
    }

    /// Return next node in the tree, skipping duplicates, or NULL if none

    typeof (this) next_unique ( )
    {
        return eb64_next_unique(this);
    }

    /// Return previous node in the tree, skipping duplicates, or NULL if none

    typeof (this) prev_unique ( )
    {
        return eb64_prev_unique(this);
    }
}

extern (C):

///// Return leftmost node in the tree, or NULL if none
eb64_node* eb64_first(eb_root* root);

/// Return rightmost node in the tree, or NULL if none
eb64_node* eb64_last(eb_root* root);

/// Return next node in the tree, or NULL if none
eb64_node* eb64_next(eb64_node* eb64);

/// Return previous node in the tree, or NULL if none
eb64_node* eb64_prev(eb64_node* eb64);

/// Return next node in the tree, skipping duplicates, or NULL if none
eb64_node* eb64_next_unique(eb64_node* eb64);

/// Return previous node in the tree, skipping duplicates, or NULL if none
eb64_node* eb64_prev_unique(eb64_node* eb64);

/// See original's library documentation for details.
void eb64_delete(eb64_node* eb64);

/// See original's library documentation for details.
eb64_node* eb64_lookup(eb_root* root, ulong x);

/// See original's library documentation for details.
eb64_node* eb64i_lookup(eb_root* root, long x);

/// See original's library documentation for details.
eb64_node* eb64_lookup_le(eb_root* root, ulong x);

/// See original's library documentation for details.
eb64_node* eb64_lookup_ge(eb_root* root, ulong x);

/// See original's library documentation for details.
eb64_node* eb64_insert(eb_root* root, eb64_node* neww);

/// See original's library documentation for details.
eb64_node* eb64i_insert(eb_root* root, eb64_node* neww);
