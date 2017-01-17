/*******************************************************************************

    Mapping from access time to the index of an item in the cache items array.
    Limits the number of available mappings to a fixed value and preallocates
    all nodes in an array buffer.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.cache.model.containers.TimeToIndex;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.ebtree.EBTree128;
import ocean.util.container.ebtree.nodepool.NodePool;
import ocean.util.container.cache.model.containers.ArrayPool;

/******************************************************************************/

class TimeToIndex: EBTree128!()
{
    /***************************************************************************

        Node wrapper struct, the node pool element type which must have a size
        that is an integer multiple of 16. This is because the libebtree
        requires that the pointers to the nodes passed to it are integer
        multiples of 16.

    ***************************************************************************/

    struct PaddedNode
    {
        /***********************************************************************

            Actual node.

        ***********************************************************************/

        Node node;

        /***********************************************************************

            Pad bytes.

        ***********************************************************************/

        private ubyte[Node.sizeof % 16] pad;

        /**********************************************************************/

        static assert(typeof(*this).sizeof % 16 == 0,
                      typeof(*this).stringof ~ ".sizeof must be an integer "
                    ~ "multiple of 16, not " ~ typeof(*(&this)).sizeof.stringof);
    }

    /**************************************************************************/

    static class ArrayNodePool: NodePool!(Node)
    {
        /***********************************************************************

            Array of bucket elements.

        ***********************************************************************/

        private ArrayPool!(PaddedNode) elements;

        /***********************************************************************

            Constructor.

            Params:
                n = maximum number of elements in mapping

        ***********************************************************************/

        public this ( size_t n )
        {
            this.elements = new typeof(this.elements)(n);
        }


        version (D_Version2) {}
        else
        {
            /*******************************************************************

                Destructor.

            *******************************************************************/

            protected override void dispose ( )
            {
                super.dispose();
                delete this.elements;
            }
        }

        /***********************************************************************

            Obtains a new node from the array node pool.

            Returns:
                a new node.

            Out:
                The returned node pointer is an integer multiple of 16 as
                required by the libebtree (inherited postcondition).

        ***********************************************************************/

        protected override Node* newNode ( )
        {
            return &(this.elements.next.node);
        }

        /***********************************************************************

            Marks all pool items as unused.

        ***********************************************************************/

        public void clear ()
        {
            this.resetFreeList();
            this.elements.clear();
        }
    }

    /***************************************************************************

        Array pool of nodes.

    ***************************************************************************/

    private ArrayNodePool nodes;

    /***************************************************************************

        Constructor.

        Params:
            n = maximum number of elements in mapping

    ***************************************************************************/

    public this ( size_t n )
    {
        super(this.nodes = new typeof(this.nodes)(n));
    }

    /***************************************************************************

        Removes all values from the tree.

    ***************************************************************************/

    public override void clear ( )
    {
        super.clear();
        this.nodes.clear();
    }


    version (D_Version2) {}
    else
    {
        /***********************************************************************

            Disposer.

        ***********************************************************************/

        protected override void dispose ( )
        {
            super.dispose();
            delete this.nodes;
        }
    }
}
