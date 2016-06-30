/******************************************************************************

    Bindings for Elastic Binary Trees library's operations on 128bit nodes.

    This module contains the D binding of the library functions of eb128tree.h.
    Please consult the original header documentation for details.

    eb128tree.h uses a 128-bit integer type for the node keys, which is not a
    part of the standard C language but provided as an extension by GCC 4.6 and
    later for targets that support it. These targets include x86-64 but not x86.

    @see http://gcc.gnu.org/onlinedocs/gcc-4.6.2/gcc/_005f_005fint128.html
    @see http://gcc.gnu.org/gcc-4.6/changes.html

    Since cent/ucent are currently not implemented, they need to be emulated
    by two 64-bit integer values (int + uint for cent, uint + uint for ucent).
    eb128tree.c provides dual-64-bit functions to interchange the 128-bit keys.

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

module ocean.util.container.ebtree.c.eb128tree;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;
import ocean.util.container.ebtree.c.ebtree: eb_root, eb_node;


/******************************************************************************

    ucent emulator struct

 ******************************************************************************/

struct UCent
{
    /**************************************************************************

        lo contains the lower, hi the higher 64 bits of the ucent value.

     **************************************************************************/

    ulong lo, hi;

    /**************************************************************************

        Compares this instance to other in the same way as the libebtree does.

        Params:
            rhs = instance to compare against this

        Returns:
            a value less than 0 if this < rhs,
            a value greater than 0 if this > rhs
            or 0 if this == rhs.

     **************************************************************************/

    public mixin (genOpCmp(
    `{
        return eb128_cmp_264(this.tupleof, rhs.tupleof);
    }`));

    public equals_t opEquals(UCent rhs)
    {
        return this.opCmp(rhs) == 0;
    }
}

/******************************************************************************

    cent emulator struct

 ******************************************************************************/

struct Cent
{
    /**************************************************************************

        lo contains the lower, hi the higher 64 bits of the ucent value.

     **************************************************************************/

    ulong lo;
    long  hi;

    /**************************************************************************

        Compares this instance to other in the same way as the libebtree does.

        Params:
            rhs = instance to compare against this

        Returns:
            a value less than 0 if this < rhs,
            a value greater than 0 if this > rhs
            or 0 if this == rhs.

     **************************************************************************/

    public mixin(genOpCmp(
    `{
        return eb128i_cmp_264(this.tupleof, rhs.tupleof);
    }`));

    public equals_t opEquals(Cent rhs)
    {
        return this.opCmp(rhs) == 0;
    }
}

/// See original's library documentation for details.
struct eb128_node
{
    eb_node node; // the tree node, must be at the beginning
    private ubyte[16] key_;

    /**************************************************************************

        Evaluates to Cent if signed is true or to UCent otherwise.

     **************************************************************************/

    template UC ( bool signed )
    {
        static if (signed)
        {
            alias Cent UC;
        }
        else
        {
            alias UCent UC;
        }
    }

    /**************************************************************************

        Sets the key.

        Params:
            key_ = new key

        Returns:
            new key.

     **************************************************************************/

    UCent key ( ) ( UCent key_ )
    {
        eb128_node_setkey_264(this, key_.lo, key_.hi);

        return key_;
    }

    /**************************************************************************

        ditto

     **************************************************************************/

    Cent key ( ) ( Cent key_ )
    {
        eb128i_node_setkey_264(this, key_.lo, key_.hi);

        return key_;
    }

    /**************************************************************************

        Gets the key.

        Template_Params:
            signed = true: the key was originally a Cent, false: it was a UCent

        Returns:
            the current key.

     **************************************************************************/

    UC!(signed) key ( bool signed = false ) ( )
    {
        static if (signed)
        {
            Cent result;

            eb128i_node_getkey_264(this, &result.lo, &result.hi);
        }
        else
        {
            UCent result;

            eb128_node_getkey_264(this, &result.lo, &result.hi);
        }

        return result;
    }

    /// Return next node in the tree, skipping duplicates, or NULL if none

    typeof (this) next ( )
    {
        return eb128_next(this);
    }

    /// Return previous node in the tree, or NULL if none

    typeof (this) prev ( )
    {
        return eb128_prev(this);
    }

    /// Return next node in the tree, skipping duplicates, or NULL if none

    typeof (this) next_unique ( )
    {
        return eb128_next_unique(this);
    }

    /// Return previous node in the tree, skipping duplicates, or NULL if none

    typeof (this) prev_unique ( )
    {
        return eb128_prev_unique(this);
    }
}

extern (C):

/// Return leftmost node in the tree, or NULL if none
eb128_node* eb128_first(eb_root* root);

/// Return rightmost node in the tree, or NULL if none
eb128_node* eb128_last(eb_root* root);

/// Return next node in the tree, or NULL if none
eb128_node* eb128_next(eb128_node* eb128);

/// Return previous node in the tree, or NULL if none
eb128_node* eb128_prev(eb128_node* eb128);

/// Return next node in the tree, skipping duplicates, or NULL if none
eb128_node* eb128_next_unique(eb128_node* eb128);

/// Return previous node in the tree, skipping duplicates, or NULL if none
eb128_node* eb128_prev_unique(eb128_node* eb128);

/// Delete node from the tree if it was linked in. Mark the node unused.
void eb128_delete(eb128_node* eb128);

/// See original's library documentation for details.
eb128_node* eb128_lookup_264 ( eb_root* root, ulong lo, ulong hi );

/// See original's library documentation for details.
eb128_node* eb128i_lookup_264 ( eb_root* root, ulong lo, long hi );

/// See original's library documentation for details.
eb128_node* eb128_lookup_le_264 ( eb_root* root, ulong lo, ulong hi );

/// See original's library documentation for details.
eb128_node* eb128_lookup_ge_264 ( eb_root* root, ulong lo, ulong hi );

/// See original's library documentation for details.
eb128_node* eb128_insert ( eb_root* root, eb128_node* neww );

/// See original's library documentation for details.
eb128_node* eb128i_insert ( eb_root* root, eb128_node* neww );

/******************************************************************************

    Tells whether a is less than b. a and b are uint128_t values composed from
    alo and ahi or blo and bhi, respectively.

    Params:
        alo = value of the lower 64 bits of a
        ahi = value of the higher 64 bits of a
        blo = value of the lower 64 bits of b
        ahi = value of the higher 64 bits of b

    Returns:
        true if a < b or false otherwise.

 ******************************************************************************/

bool eb128_less_264 ( ulong alo, ulong ahi, ulong blo, ulong bhi );

/******************************************************************************

    Tells whether a is less than or equal to b. a and b are uint128_t values
    composed from alo and ahi or blo and bhi, respectively.

    Params:
        alo = value of the lower 64 bits of a
        ahi = value of the higher 64 bits of a
        blo = value of the lower 64 bits of b
        ahi = value of the higher 64 bits of b

    Returns:
        true if a <= b or false otherwise.

 ******************************************************************************/

bool eb128_less_or_equal_264 ( ulong alo, ulong ahi, ulong blo, ulong bhi );

/******************************************************************************

    Tells whether a is equal to b. a and b are uint128_t values
    composed from alo and ahi or blo and bhi, respectively.

    Params:
        alo = value of the lower 64 bits of a
        ahi = value of the higher 64 bits of a
        blo = value of the lower 64 bits of b
        ahi = value of the higher 64 bits of b

    Returns:
        true if a == b or false otherwise.

 ******************************************************************************/

bool eb128_equal_264 ( ulong alo, ulong ahi, ulong blo, ulong bhi );

/******************************************************************************

    Tells whether a is greater than or equal to b. a and b are uint128_t values
    composed from alo and ahi or blo and bhi, respectively.

    Params:
        alo = value of the lower 64 bits of a
        ahi = value of the higher 64 bits of a
        blo = value of the lower 64 bits of b
        ahi = value of the higher 64 bits of b

    Returns:
        true if a >= b or false otherwise.

 ******************************************************************************/

bool eb128_greater_or_equal_264 ( ulong alo, ulong ahi, ulong blo, ulong bhi );

/******************************************************************************

    Tells whether a is greater than b. a and b are uint128_t values
    composed from alo and ahi or blo and bhi, respectively.

    Params:
        alo = value of the lower 64 bits of a
        ahi = value of the higher 64 bits of a
        blo = value of the lower 64 bits of b
        ahi = value of the higher 64 bits of b

    Returns:
        true if a <= b or false otherwise.

 ******************************************************************************/

bool eb128_greater_264 ( ulong alo, ulong ahi, ulong blo, ulong bhi );

/******************************************************************************

    Compares a and b in a qsort callback/D opCmp fashion. a and b are uint128_t
    values composed from alo and ahi or blo and bhi, respectively.

    Params:
        alo = value of the lower 64 bits of a
        ahi = value of the higher 64 bits of a
        blo = value of the lower 64 bits of b
        ahi = value of the higher 64 bits of b

    Returns:
        a value less than 0 if a < b,
        a value greater than 0 if a > b
        or 0 if a == b.

 ******************************************************************************/

int  eb128_cmp_264 ( ulong alo, ulong ahi, ulong blo, ulong bhi );

/******************************************************************************

    Tells whether a is less than b. a and b are int128_t values composed from
    alo and ahi or blo and bhi, respectively.

    Params:
        alo = value of the lower 64 bits of a
        ahi = value of the higher 64 bits of a
        blo = value of the lower 64 bits of b
        ahi = value of the higher 64 bits of b

    Returns:
        true if a < b or false otherwise.

 ******************************************************************************/

bool eb128i_less_264 ( ulong alo, long  ahi, ulong blo, long  bhi );

/******************************************************************************

    Tells whether a is less than or equal to b. a and b are int128_t values
    composed from alo and ahi or blo and bhi, respectively.

    Params:
        alo = value of the lower 64 bits of a
        ahi = value of the higher 64 bits of a
        blo = value of the lower 64 bits of b
        ahi = value of the higher 64 bits of b

    Returns:
        true if a <= b or false otherwise.

 ******************************************************************************/

bool eb128i_less_or_equal_264 ( ulong alo, long  ahi, ulong blo, long  bhi );

/******************************************************************************

    Tells whether a is equal to b. a and b are int128_t values composed from
    alo and ahi or blo and bhi, respectively.

    Params:
        alo = value of the lower 64 bits of a
        ahi = value of the higher 64 bits of a
        blo = value of the lower 64 bits of b
        ahi = value of the higher 64 bits of b

    Returns:
        true if a == b or false otherwise.

 ******************************************************************************/

bool eb128i_equal_264 ( ulong alo, long  ahi, ulong blo, long  bhi );

/******************************************************************************

    Tells whether a is greater or equal to than b. a and b are int128_t values
    composed from alo and ahi or blo and bhi, respectively.

    Params:
        alo = value of the lower 64 bits of a
        ahi = value of the higher 64 bits of a
        blo = value of the lower 64 bits of b
        ahi = value of the higher 64 bits of b

    Returns:
        true if a >= b or false otherwise.

 ******************************************************************************/

bool eb128i_greater_or_equal_264 ( ulong alo, long  ahi, ulong blo, long  bhi );

/******************************************************************************

    Tells whether a is greater than b. a and b are int128_t values composed from
    alo and ahi or blo and bhi, respectively.

    Params:
        alo = value of the lower 64 bits of a
        ahi = value of the higher 64 bits of a
        blo = value of the lower 64 bits of b
        ahi = value of the higher 64 bits of b

    Returns:
        true if a > b or false otherwise.

 ******************************************************************************/

bool eb128i_greater_264 ( ulong alo, long  ahi, ulong blo, long  bhi);

/******************************************************************************

    Compares a and b in a qsort callback/D opCmp fashion. a and b are int128_t
    values composed from alo and ahi or blo and bhi, respectively.

    Params:
        alo = value of the lower 64 bits of a
        ahi = value of the higher 64 bits of a
        blo = value of the lower 64 bits of b
        ahi = value of the higher 64 bits of b

    Returns:
        a value less than 0 if a < b,
        a value greater than 0 if a > b
        or 0 if a == b.

 ******************************************************************************/

int  eb128i_cmp_264 ( ulong alo, long  ahi, ulong blo, long  bhi );

/******************************************************************************

    Sets node->key to an uint128_t value composed from lo and hi.

    Params:
        node = node to set the key
        lo   = value of the lower 64 value bits of node->key
        hi   = value of the higher 64 value bits of node->key

    Returns:
        node

 ******************************************************************************/

eb128_node* eb128_node_setkey_264 ( eb128_node* node, ulong lo, ulong hi );

/******************************************************************************

    Sets node->key to an int128_t value composed from lo and hi.

    Params:
        node = node to set the key
        lo   = value of the lower 64 value bits of node->key
        hi   = value of the higher 64 value bits of node->key

    Returns:
        node

 ******************************************************************************/

eb128_node* eb128i_node_setkey_264 ( eb128_node* node, long lo, ulong hi );

/******************************************************************************

    Obtains node->key,and decomposes it into two uint64_t values. This assumes
    that the key was originally unsigned, e.g. set by eb128_node_setkey_264().

    Params:
        node = node to obtain the key
        lo   = output of the value of the lower 64 value bits of node->key
        hi   = output of the value of the higher 64 value bits of node->key

 ******************************************************************************/

void eb128_node_getkey_264 ( eb128_node* node, ulong* lo, ulong* hi );

/******************************************************************************

    Obtains node->key,and decomposes it into an int64_t and an uint64_t value.
    This assumes that the key was originally signed, e.g. set by
    eb128i_node_setkey_264().

    Params:
        node = node to obtain the key
        lo   = output of the value of the lower 64 value bits of node->key
        hi   = output of the value of the higher 64 value bits of node->key

******************************************************************************/

void eb128i_node_getkey_264 ( eb128_node* node, ulong* lo, long* hi );
