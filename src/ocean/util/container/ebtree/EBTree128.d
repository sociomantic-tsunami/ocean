/*******************************************************************************

    Elastic binary tree class

    Fast 128-bit value binary tree class based on the ebtree library from
    HAProxy.

    You need to have the library installed and link with -lebtree.

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.ebtree.EBTree128;


import ocean.transition;

import ocean.util.container.ebtree.model.IEBTree,
       ocean.util.container.ebtree.model.Node,
       ocean.util.container.ebtree.model.KeylessMethods,
       ocean.util.container.ebtree.model.Iterators;

import ocean.util.container.ebtree.nodepool.NodePool;

public import ocean.util.container.ebtree.c.eb128tree;
import ocean.util.container.ebtree.c.ebtree: eb_node, eb_root;

import ocean.core.Test;

/*******************************************************************************

    EBTree64 class template.

    Params:
        signed = false: use the 'ucent' surrogate as key type, true: 'cent'.

*******************************************************************************/

class EBTree128 ( bool signed = false ) : IEBTree
{
    import ocean.core.Verify;

    /**************************************************************************

        false if the 'ucent' surrogate is the key type or true if 'cent'.

     **************************************************************************/

    public static immutable signed_key = signed;

    /**************************************************************************

        Key struct, acts as a 'ucent'/'cent' surrogate, using two 64-bit integer
        values as a combined 128-bit key.

     **************************************************************************/

    struct Key
    {
        /**********************************************************************

            false if 'uint' is the type of hi (below) or true if it is 'int'.

         **********************************************************************/

        public enum is_signed = signed;

        /**********************************************************************

            lo: Carries the lower 64 bits of the key.

         **********************************************************************/

        public ulong lo;

        /**********************************************************************

            hi: Carries the higher 64 bits of the key.

         **********************************************************************/

        static if (signed)
        {
            public long hi;
        }
        else
        {
            public ulong hi;
        }

        /**********************************************************************

            Compares this instance with rhs.

            Params:
                rhs = instance to compare with this

            Returns:
                a value less than 0 if this < rhs,
                a value greater than 0 if this > rhs
                or 0 if this == rhs.

         **********************************************************************/

        public mixin(genOpCmp(
        `{
            static if (signed)
            {
                return eb128i_cmp_264(this.lo, this.hi, rhs.lo, rhs.hi);
            }
            else
            {
                return eb128_cmp_264(this.lo, this.hi, rhs.lo, rhs.hi);
            }
        }`));

        public equals_t opEquals(Key rhs)
        {
            return (&this).opCmp(rhs) == 0;
        }
    }

    /**********************************************************************

        Obtains the key of this node.

        Returns:
            key

     **********************************************************************/

    private static Key getKey ( eb128_node* node_ )
    {
        Key result;

        static if (signed)
        {
            eb128i_node_getkey_264(node_, &result.lo, &result.hi);
        }
        else
        {
            eb128_node_getkey_264(node_, &result.lo, &result.hi);
        }

        return result;
    }

    /**************************************************************************

        Node struct, Node instances are stored in the ebtree.

     **************************************************************************/

    mixin Node!(eb128_node, Key, getKey,
                eb128_next, eb128_prev, eb128_prev_unique, eb128_next_unique,
                eb128_delete);

    mixin Iterators!(Node);

    /**************************************************************************

        Node pool interface type alias

     **************************************************************************/

    public alias .INodePool!(Node) INodePool;

    /**************************************************************************

        Node pool instance

     **************************************************************************/

    private INodePool node_pool;

    /**************************************************************************

        Constructor

     **************************************************************************/

    public this ( )
    {
        this(new NodePool!(Node));
    }

    /**************************************************************************

        Constructor

        Params:
            node_pool = node pool instance to use

     **************************************************************************/

    public this ( INodePool node_pool )
    {
        this.node_pool = node_pool;
    }

    mixin KeylessMethods!(Node, eb128_first, eb128_last);

    /***************************************************************************

        Adds a new node to the tree, automatically inserting it in the correct
        location to keep the tree sorted.

        Params:
            key = key of node to add

        Returns:
            pointer to the newly added node

    ***************************************************************************/

    public Node* add ( Key key )
    out (node_out)
    {
        assert (node_out !is null);
    }
    body
    {
        scope (success) ++this;

        return this.add_(this.node_pool.get(), key);
    }

    /***************************************************************************

        Sets the key of node to key, keeping the tree sorted.

        Params:
            node = node to update key
            key  = new key for node

        Returns:
            updated node

    ***************************************************************************/

    public Node* update ( ref Node node, Key key )
    out (node_out)
    {
        assert (node_out !is null);
    }
    body
    {
        return (node.key != key)? this.add_(node.remove(), key) : &node;
    }

    /***************************************************************************

        Recycles the nodes back to the node pool and call the super class
        clear()

    ***************************************************************************/

    public override void clear()
    {
        foreach(ref node; this)
        {
            this.node_pool.recycle(&node);
        }
        super.clear();
    }

    /***************************************************************************

        Searches the tree for the first node whose key is <= the specified key,
        and returns it.

        Params:
            key = key to search for

        Returns:
            first node <= than specified key, may be null if no node found

    ***************************************************************************/

    public Node* firstLessEqual ( Key key )
    {
        return this.ebCall!(eb128_lookup_le_264)(key.lo, cast (ulong) key.hi);
    }


    /***************************************************************************

        Searches the tree for the first node whose key is >= the specified key,
        and returns it.

        Params:
            key = key to search for

        Returns:
            first node >= than specified key, may be null if no node found

    ***************************************************************************/

    public Node* firstGreaterEqual ( Key key )
    {
        return this.ebCall!(eb128_lookup_ge_264)(key.lo, cast (ulong) key.hi);
    }


    /***************************************************************************

        Searches the tree for the specified key, and returns the first node with
        that key.

        Params:
            key = key to search for

        Returns:
            pointer to first node in tree with specified key, may be null if no
            nodes found

    ***************************************************************************/

    public Node* opIn_r ( Key key )
    {
        static if (signed)
        {
            return this.ebCall!(eb128i_lookup_264)(key.lo, key.hi);
        }
        else
        {
            return this.ebCall!(eb128_lookup_264)(key.lo, key.hi);
        }
    }

    /***************************************************************************

        Adds node to the tree, automatically inserting it in the correct
        location to keep the tree sorted.

        Params:
            node = node to add
            key  = key for node

        Returns:
            node

    ***************************************************************************/

    private Node* add_ ( Node* node, Key key )
    out (node_out)
    {
        assert (node_out !is null);
    }
    body
    {
        verify (node !is null, "attempted to add null node (node pool returned null?)");

        static if (signed)
        {
            eb128i_node_setkey_264(&node.node_, key.lo, key.hi);

            return this.ebCall!(eb128i_insert)(&node.node_);
        }
        else
        {
            eb128_node_setkey_264(&node.node_, key.lo, key.hi);

            return this.ebCall!(eb128_insert)(&node.node_);
        }
    }
}

unittest
{
    EBTree128!(true).Key signed_a;
    signed_a.hi = 0xFFFF_FFFF_FFFF_FFFF;
    signed_a.lo = 0x1FFF_FFFF_FFFF_FFFF;

    EBTree128!(true).Key signed_b;
    signed_b.hi = 0x1;
    signed_b.lo = 0x0;


    // In signed arithmetics, a should be less than b
    test!("<")(signed_a, signed_b);


    EBTree128!().Key unsigned_a;
    unsigned_a.hi = 0xFFFF_FFFF_FFFF_FFFF;
    unsigned_a.lo = 0x1FFF_FFFF_FFFF_FFFF;

    EBTree128!().Key unsigned_b;
    unsigned_b.hi = 0x1;
    unsigned_b.lo = 0x0;

    // In unsigned arithmetics, a should be greatereater than b
    test!(">")(unsigned_a, unsigned_b);
}
