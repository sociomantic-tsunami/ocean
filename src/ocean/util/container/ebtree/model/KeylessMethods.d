/*******************************************************************************

    Elastic binary tree methods

    Used as mixin in the EBTree classes, contains the methods that do not use
    keys.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.ebtree.model.KeylessMethods;

/*******************************************************************************

    Template with keyless methods.

    Template parameters:
        Node = tree node struct type; expected to be an instance of the Node
               struct template in ocean.util.container.ebtree.model.Node.

        eb_first = eb_node* ( eb_root* root ); returns the first node
        eb_last  = eb_node* ( eb_root* root ); returns the last node

*******************************************************************************/

template KeylessMethods ( Node, alias eb_first, alias eb_last )
{
    /***************************************************************************

        Removes a node from the tree.

        Params:
            node = pointer to node to remove

    ***************************************************************************/

    public void remove ( ref Node node )
    {
        this.node_pool.recycle(node.remove());

        --this;
    }

    /***************************************************************************

        Returns:
            pointer to node with lowest value in the tree

    ***************************************************************************/

    public Node* first ( )
    out (node)
    {
        if (this.length)
        {
            assert (node, typeof (this).stringof ~
                    ".first: got a null node but the tree is not empty");
        }
        else
        {
            assert (!node, typeof (this).stringof ~
                           ".first: got a node but the tree is empty");
        }
    }
    body
    {
        return this.ebCall!(eb_first)();
    }


    /***************************************************************************

        Returns:
            pointer to node with highest value in the tree

    ***************************************************************************/

    public Node* last ( )
    out (node)
    {
        if (this.length)
        {
            assert (node, typeof (this).stringof ~
                    ".last: got a null node but the tree is not empty");
        }
        else
        {
            assert (!node, typeof (this).stringof ~
                           ".last: got a node but the tree is empty");
        }
    }
    body
    {
        return this.ebCall!(eb_last)();
    }


    /***************************************************************************

        foreach iterator over nodes in the tree. Any tree modification is
        permitted during iteration.

    ***************************************************************************/

    public int opApply ( int delegate ( ref Node node ) dg )
    {
        int ret = 0;

        for (Node* node = this.first; node && !ret; node = node.next)
        {
            ret = dg(*node);
        }

        return ret;
    }

    /***************************************************************************

        foreach_reverse iterator over nodes in the tree. Any tree modification
        is permitted during iteration.

    ***************************************************************************/

    public int opApply_reverse ( int delegate ( ref Node node ) dg )
    {
        int ret = 0;

        for (Node* node = this.last; node && !ret; node = node.prev)
        {
            ret = dg(*node);
        }

        return ret;
    }

    /**********************************************************************

        Library function call wrapper. Invokes eb_func with this &this.root
        as first argument.

        Template_Params:
            eb_func = library function

        Params:
            args = additional eb_func arguments

        Returns:
            passes through the return value of eb_func, which may be null.

     **********************************************************************/

    private Node* ebCall ( alias eb_func, T ... ) ( T args )
    {
        static assert (is (typeof (eb_func(&this.root, args)) ==
                           typeof (&Node.init.node_)));

        return cast (Node*) eb_func(&this.root, args);
    }
}
