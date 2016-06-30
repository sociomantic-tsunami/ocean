/*******************************************************************************

    Elastic binary tree node pool

    Simple struct pool for node struct instances

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.ebtree.nodepool.NodePool;

import ocean.transition;

/*******************************************************************************

    Node pool interface

*******************************************************************************/

interface INodePool ( Node )
{
    Node* get ( );

    void recycle ( Node* );
}

/*******************************************************************************

    Default node pool implementation

*******************************************************************************/

class NodePool ( Node ) : INodePool!(Node)
{
    static assert (is (Node == struct));

    /***************************************************************************

        List of free nodes. When a node is removed it is added to this list, so
        that it can be re-used when a new node is added.

    ***************************************************************************/

    private Node*[] free_nodes;

    /***************************************************************************

        Obtains a Node instance. If there are currently free nodes, one of these
        is used, otherwise a new Node instance is created.

        Returns:
            Node instance

    ***************************************************************************/

    public Node* get ( )
    {
        if ( this.free_nodes.length )
        {
            scope (success)
            {
                this.free_nodes.length = this.free_nodes.length - 1;
                enableStomping(this.free_nodes);
            }

            return this.free_nodes[$ - 1];
        }
        else
        {
            return this.newNode();
        }
    }

    /***************************************************************************

        Adds node to the list of free nodes.

        Params:
            node = free node instance

    ***************************************************************************/

    public void recycle ( Node* node )
    {
        this.free_nodes.length = this.free_nodes.length + 1;
        enableStomping(this.free_nodes);
        this.free_nodes[$ - 1] = node;
    }

    /***************************************************************************

        Creates a new node.
        May be overridden by a subclass to use a different allocation method.

        Returns:
            a newly created node.

        Out:
            The returned node pointer is an integer multiple of 16 as required
            by the libebtree.

    ***************************************************************************/

    protected Node* newNode ( )
    out (node)
    {
        assert((cast(size_t)node) % 16 == 0,
               "the node pointer must be an integer multiple of 16");
    }
    body
    {
        return new Node;
    }
}
