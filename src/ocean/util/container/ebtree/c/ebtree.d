/*******************************************************************************

    Bindings for Elastic Binary Trees library's generic operations and
    structures.

    This module contains the D binding of the library functions of ebtree.h.
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

module ocean.util.container.ebtree.c.ebtree;


import ocean.transition;


/// See original's library documentation for details.
alias void eb_troot_t;

/// See original's library documentation for details.
struct eb_root
{
    const BITS          = 1;
    const BRANCHES      = (1 << BITS);

    const RGHT   = 1;
    const NORMAL = cast(eb_troot_t*)0;
    const UNIQUE = cast(eb_troot_t*)1;

    eb_troot_t*[BRANCHES] b;

    bool is_empty ( )
    {
        return !!eb_is_empty(this);
    }

    /***************************************************************************

        Tells whether this tree is configured so that the `eb*_insert` functions
        allow adding unique nodes only or if they allow adding duplicates.

        Returns:
            true if only unique nodes are added for this tree or false if
            duplicates can be added.

    ***************************************************************************/

    bool unique ( )
    {
        return this.b[RGHT] is UNIQUE;
    }

    /***************************************************************************

        Configures this tree so that the `eb*_insert` functions either allow
        adding unique nodes only or allow adding duplicates.

        This configuration can be changed at any time and affects subsequent
        `eb*_insert` function calls.

        Params:
            enable = true: only allow unique nodes;
                     false: allow adding duplicates

        Returns:
            enable

    ***************************************************************************/

    bool unique ( bool enable )
    {
        this.b[RGHT] = enable? UNIQUE : NORMAL;
        return enable;
    }
}

/// See original's library documentation for details.
struct eb_node
{
    eb_root     branches;
    eb_troot_t* node_p,
                leaf_p;
    short       bit;
    short       pfx;

    alias .eb_first first;

    alias .eb_last last;

    typeof (this) prev( )
    {
        return eb_prev(this);
    }

    typeof (this) next ( )
    {
        return eb_next(this);
    }

    typeof (this) prev_unique ( )
    {
        return eb_prev_unique(this);
    }

    typeof (this) next_unique ( )
    {
        return eb_next_unique(this);
    }

    void remove ( )
    {
        eb_delete(this);
    }
};


extern (C):

/// See original's library documentation for details.
int eb_is_empty(eb_root* root);

/// See original's library documentation for details.
eb_node* eb_first(eb_root* root);

/// See original's library documentation for details.
eb_node* eb_last(eb_root* root);

/// See original's library documentation for details.
eb_node* eb_prev(eb_node* node);

/// See original's library documentation for details.
eb_node* eb_next(eb_node* node);

/// See original's library documentation for details.
eb_node* eb_prev_unique(eb_node* node);

/// See original's library documentation for details.
eb_node* eb_next_unique(eb_node* node);

/// See original's library documentation for details.
void eb_delete(eb_node* node);

/// See original's library documentation for details.
int equal_bits(char* a, char* b, int ignore, int len);

/// See original's library documentation for details.
int check_bits(char* a, char* b, int skip, int len);

/// See original's library documentation for details.
int string_equal_bits(char* a, char* b, int ignore);

/// See original's library documentation for details.
int cmp_bits(char* a, char* b, uint pos);

/// See original's library documentation for details.
int get_bit(char* a, uint pos);
