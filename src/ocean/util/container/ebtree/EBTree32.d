/*******************************************************************************

    Elastic binary tree class

    Fast 32-bit value binary tree class based on the ebtree library from
    HAProxy.

    You need to have the library installed and link with -lebtree.

    Usage example:

    ---

        import ocean.util.container.ebtree.EBTree64;

        // Create a tree
        auto tree = new EBTree32!();

        // Add some values to the tree
        for ( uint i; i < 100; i++ )
        {
            tree.add(i);
        }

        // Get the lowest value in the tree
        auto lowest = tree.first;

        // Get the highest value in the tree
        auto lowest = tree.last;

        // Iterate over all nodes in the key whose values are <= 50
        foreach ( node; tree.lessEqual(50) )
        {
            // node value is node.key
        }

        // Empty the tree
        tree.clear;

    ---

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.ebtree.EBTree32;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.util.container.ebtree.model.IEBTree,
       ocean.util.container.ebtree.model.Node,
       ocean.util.container.ebtree.model.KeylessMethods,
       ocean.util.container.ebtree.model.Iterators;

import ocean.util.container.ebtree.nodepool.NodePool;

import ocean.util.container.ebtree.c.ebtree: eb_node, eb_root;

/*******************************************************************************

    EBTree32 class template.

    Template_Params:
        signed = false: use 'uint' as key type, true: use 'int'.

*******************************************************************************/

class EBTree32 ( bool signed = false ) : IEBTree
{
    /**************************************************************************

        false if 'uint' is the key type or true if it is 'int'.

     **************************************************************************/

    public const signed_key = signed;

    /**************************************************************************

        Key type alias

     **************************************************************************/

    static if (signed)
    {
        public alias int Key;
    }
    else
    {
        public alias uint Key;
    }

    /**************************************************************************

        Dual32Key struct, allows the usage of two 32-bit integer values as a
        combined 64-bit key.

     **************************************************************************/

    struct Dual16Key
    {
        /**********************************************************************

            false if 'ushort' is the type of hi (below) or true if it is
            'short'.

         **********************************************************************/

        public const is_signed = signed;

        /**********************************************************************

            lo: Carries the lower 16 bits of the key.

         **********************************************************************/

        public ushort lo;

        /**********************************************************************

            hi: Carries the higher 16 bits of the key.

         **********************************************************************/

        static if (signed)
        {
            public short hi;
        }
        else
        {
            public ushort hi;
        }

        /**********************************************************************

            Compares this instance with other.

            Params:
                rhs = instance to compare with this

            Returns:
                a value less than 0 if this < rhs,
                a value greater than 0 if this > rhs
                or 0 if this == rhs.

         **********************************************************************/

        public mixin (genOpCmp(
        `{
            return (this.hi > rhs.hi)? +1 :
                   (this.hi < rhs.hi)? -1 :
                   (this.lo >= rhs.lo)? (this.lo > rhs.lo) : -1;
        }`));

        /**********************************************************************

            Obtains the key to store in the ebtree from this instance.

            Returns:
                key

         **********************************************************************/

        private EBTree32!(signed).Key opCast ( )
        {
            return ((cast (int) this.hi) << 0x10) | this.lo;
        }
    }

    /**************************************************************************

        Obtains the key of node_; required by the Node mixin.

        Params:
            node_ = node to obtain key

        Returns:
            node key

     **************************************************************************/

    private static Key getKey ( eb32_node* node_ )
    in
    {
        assert (node_ !is null);
    }
    body
    {
        return node_.key_;
    }

    /***************************************************************************

        Node struct mixin. Elements of Node are stored in the tree.
        @see ocean.util.container.ebtree.model.KeylessMethods.

    ***************************************************************************/

    mixin Node!(eb32_node, Key, getKey,
                eb32_next, eb32_prev, eb32_prev_unique, eb32_next_unique,
                eb32_delete);

    /***************************************************************************

        Mixin of iterators. @see ocean.util.container.ebtree.model.KeylessMethods.

    ***************************************************************************/

    mixin Iterators!(Node);

    /**************************************************************************

        Node pool interface type alias

     **************************************************************************/

    public alias .INodePool!(Node) INodePool;

    /**************************************************************************

        Node pool instance

     **************************************************************************/

    private const INodePool node_pool;

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

    /***************************************************************************

        Mixin of methods. @see ocean.util.container.ebtree.model.KeylessMethods.

    ***************************************************************************/

    mixin KeylessMethods!(Node, eb32_first, eb32_last);

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

        Adds a value to the tree, automatically inserting a new node in the
        correct location to keep the tree sorted.

        Params:
            key = value to add

        Returns:
            pointer to newly added node

    ***************************************************************************/

    public Node* add ( Dual16Key key )
    out (node_out)
    {
        assert (node_out !is null);
    }
    body
    {
        return this.add(cast (Key) key);
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
        return (node.node_.key_ != cast (ulong) key)?
                this.add_(node.remove(), key) : &node;
    }

    /***************************************************************************

        Sets the key of node to key, keeping the tree sorted.

        Params:
            node = node to update key
            key  = new key for node

        Returns:
            updated node

    ***************************************************************************/

    public Node* update ( ref Node node, Dual16Key key )
    out (node_out)
    {
        assert (node_out !is null);
    }
    body
    {
        return this.update(node, cast (Key) key);
    }

    /***************************************************************************

        Adds a value to the tree, automatically inserting a new node in the
        correct location to keep the tree sorted.

        Params:
            key = value to add

        Returns:
            pointer to newly added node

    ***************************************************************************/

    public Node* add ( Dual16Key key )
    out (node_out)
    {
        assert (node_out !is null);
    }
    body
    {
        return this.add(cast (Key) key);
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
        return this.ebCall!(eb32_lookup_le)(cast (uint) key);
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
        return this.ebCall!(eb32_lookup_ge)(cast (uint) key);
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
            return this.ebCall!(eb32i_lookup)(key);
        }
        else
        {
            return this.ebCall!(eb32_lookup)(key);
        }
    }

    /***************************************************************************

        Adds a value to the tree, automatically inserting a new node in the
        correct location to keep the tree sorted.

        Params:
             key_in = value to add

        Returns:
            pointer to newly added node

    ***************************************************************************/

    private Node* add_ ( Node* node, Key key )
    in
    {
        assert (node !is null, "attempted to add null node (node pool returned null?)");
    }
    out (node_out)
    {
        assert (node_out !is null);
    }
    body
    {
        node.node_.key_ = key;

        static if (signed)
        {
            return this.ebCall!(eb32i_insert)(&node.node_);
        }
        else
        {
            return this.ebCall!(eb32_insert)(&node.node_);
        }
    }
}

private:

/******************************************************************************

    This structure carries a node, a leaf, and a key.

 ******************************************************************************/

struct eb32_node
{
    private eb_node node; /* the tree node, must be at the beginning */
    private uint key_;
}

extern (C):

/* Return leftmost node in the tree, or NULL if none */
eb32_node* eb32_first(eb_root* root);

/* Return rightmost node in the tree, or NULL if none */
eb32_node* eb32_last(eb_root* root);

/* Return next node in the tree, or NULL if none */
eb32_node* eb32_next(eb32_node* eb32);

/* Return previous node in the tree, or NULL if none */
eb32_node* eb32_prev(eb32_node* eb32);

/* Return next node in the tree, skipping duplicates, or NULL if none */
eb32_node* eb32_next_unique(eb32_node* eb32);

/* Return previous node in the tree, skipping duplicates, or NULL if none */
eb32_node* eb32_prev_unique(eb32_node* eb32);

/* Delete node from the tree if it was linked in. Mark the node unused. Note
 * that this function relies on a non-inlined generic function: eb_delete.
 */
void eb32_delete(eb32_node* eb32);

/*
 * Find the first occurence of a key in the tree <root>. If none can be
 * found, return NULL.
 */
eb32_node* eb32_lookup(eb_root* root, uint x);

/*
 * Find the first occurence of a signed key in the tree <root>. If none can
 * be found, return NULL.
 */
eb32_node* eb32i_lookup(eb_root* root, int x);

/*
 * Find the last occurrence of the highest key in the tree <root>, which is
 * equal to or less than <x>. NULL is returned is no key matches.
 */
eb32_node* eb32_lookup_le(eb_root* root, uint x);

/*
 * Find the first occurrence of the lowest key in the tree <root>, which is
 * equal to or greater than <x>. NULL is returned is no key matches.
 */
eb32_node* eb32_lookup_ge(eb_root* root, uint x);

/* Insert eb32_node <new> into subtree starting at node root <root>.
 * Only new->key needs be set with the key. The eb32_node is returned.
 * If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */
eb32_node* eb32_insert(eb_root* root, eb32_node* neww);

/* Insert eb32_node <new> into subtree starting at node root <root>, using
 * signed keys. Only new->key needs be set with the key. The eb32_node
 * is returned. If root->b[EB_RGHT]==1, the tree may only contain unique keys.
 */
eb32_node* eb32i_insert(eb_root* root, eb32_node* neww);
