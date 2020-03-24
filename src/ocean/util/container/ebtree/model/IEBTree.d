/*******************************************************************************

    Elastic binary tree base class

    Base class for EBTree32/64/128. Hosts eb_root and the node counter.

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.ebtree.model.IEBTree;


import ocean.util.container.ebtree.c.ebtree: eb_root;

/******************************************************************************/

abstract class IEBTree
{
    import ocean.core.Verify;

    /***************************************************************************

        Tree root node.

    ***************************************************************************/

    protected eb_root root;


    /***************************************************************************

        Number of nodes in the tree.

    ***************************************************************************/

    private size_t count;


    /***************************************************************************

        Returns:
            the number of records currently in the tree.

    ***************************************************************************/

    public size_t length ( )
    {
        return this.count;
    }

    /***************************************************************************

        Removes all values from the tree.

    ***************************************************************************/

    public void clear ( )
    {
        this.count = 0;
        this.root  = this.root.init;
    }

    /***************************************************************************

        Increases the record counter by n.

        Params:
            n = amount to add to the record counter value

        Returns:
            new record counter value

    ***************************************************************************/

    protected size_t increaseNodeCount ( size_t n )
    {
        return this.count += n;
    }

    /***************************************************************************

        Decreases the record counter by n.

        Params:
            n = amount to subtract from the record counter value

        Returns:
            new record counter value

        In:
            n must be at most the current record counter value.

    ***************************************************************************/

    protected size_t decreaseNodeCount ( size_t n )
    {
        verify (this.count >= n);
        return this.count -= n;
    }
}
