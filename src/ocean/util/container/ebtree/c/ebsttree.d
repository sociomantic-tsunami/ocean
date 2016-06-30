/*******************************************************************************

    Bindings for Elastic Binary Trees library's operations on String data nodes.

    This module contains the D binding of the library functions of ebsttree.h.
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

/* These functions and macros rely on Multi-Byte nodes */

module ocean.util.container.ebtree.c.ebsttree;

import ocean.util.container.ebtree.c.ebtree;
import ocean.util.container.ebtree.c.ebmbtree;

extern (C):

/// See original's library documentation for details.
ebmb_node* ebst_lookup(eb_root* root, char* x);

/// See original's library documentation for details.
ebmb_node* ebst_lookup_len(eb_root* root, char* x, uint len);

/// See original's library documentation for details.
ebmb_node* ebst_insert(eb_root* root, ebmb_node* neww);
