/*******************************************************************************

    Elastic binary tree node struct template

    Used as mixin in the EBTree classes.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.ebtree.model.Node;

/*******************************************************************************

    Node struct template

    Template parameters:
        eb_node   = libebtree's internal node type
        Key       = key type (signed/unsigned integer)
        eb_getkey = Key ( eb_node* node ); returns the key of node.

        eb_next = eb_node* ( eb_node* n ); returns the next node for n or null
                  if n is the last node in the tree.
        eb_prev = eb_node* ( eb_node* n ); returns the previous node for n or
                  null if n is the first node in the tree.

        eb_next_unique = same as eb_next but skips key duplicates.
        eb_prev_unique = same as eb_prev but skips key duplicates.

        eb_delete = void ( eb_node* n ); removes n from the tree.

*******************************************************************************/

struct Node ( eb_node, Key, alias eb_getkey, alias eb_next, alias eb_prev,
              alias eb_prev_unique, alias eb_next_unique, alias eb_delete )
{
    /**************************************************************************

        Node data content.

     **************************************************************************/

    private eb_node node_;

    /**************************************************************************

        Obtains the key of this node.

        Returns:
            key

     **************************************************************************/

    public Key key ( )
    {
        // TODO: Check if this works with signed keys.

//        return this.node_.key_;
        return eb_getkey(&this.node_);
    }

    /**************************************************************************

        Obtains the next node in the tree to which this node is associated.

        Returns:
            the next node or null if this is the last.

     **************************************************************************/

    public typeof (this) next ( )
    {
        return this.ebCall!(eb_next);
    }

    /**************************************************************************

        Obtains the previous node in the tree to which this node is associated.

        Returns:
            the previous node or null if this is the first.

     **************************************************************************/

    public typeof (this) prev ( )
    {
        return this.ebCall!(eb_prev);
    }

    /**************************************************************************

        Obtains the next node in the tree to which this node is associated,
        skipping key duplicates.

        Returns:
            the next node with a unique key or null if this is the last.

     **************************************************************************/

    public typeof (this) next_unique ( )
    {
        return this.ebCall!(eb_next_unique);
    }

    /**************************************************************************

        Obtains the previous node in the tree to which this node is associated,
        skipping key duplicates.

        Returns:
            the previous node with a unique key or null if this is the
            first.

     **************************************************************************/

    public typeof (this) prev_unique ( )
    {
        return this.ebCall!(eb_prev_unique);
    }

    /**************************************************************************

        Removes this node from the tree to which this it is associated.

        Returns:
            this instance

     **************************************************************************/

    private typeof (this) remove ( )
    {
        eb_delete(&this.node_);

        return this;
    }

    /**************************************************************************

        Library function call wrapper. Invokes eb_func with this instance as
        first argument.

        Template_Params:
            eb_func = library function

        Returns:
            passes through the return value of eb_func, which may be null.

     **************************************************************************/

    private typeof (this) ebCall ( alias eb_func ) ( )
    {
        static assert (is (typeof (eb_func(&this.node_)) == eb_node*));

        return cast (typeof (this)) eb_func(&this.node_);
    }
}

