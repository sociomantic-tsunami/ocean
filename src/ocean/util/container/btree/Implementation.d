/********************************************************************************

    Internal (non-user facing) implementation of BTreeMap.

    Copyright:
        Copyright (c) 2017 sociomantic labs GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.btree.Implementation;

import ocean.transition;

/*******************************************************************************

    Internal (non-user facing) implementation of BTreeMap.

    Params:
        KeyType = type of the key
        ValueType = type of the value
        tree_degree = degree of the tree.

*******************************************************************************/

package struct BTreeMapImplementation (KeyType, ValueType, int tree_degree)
{
    import ocean.core.array.Mutation;
    import ocean.core.array.Search;
    import ocean.core.Enforce;
    import ocean.core.Traits;
    import ocean.core.Tuple;
    import ocean.core.Verify;
    import ocean.util.container.mem.MemManager;

    /**************************************************************************

        Node of the tree. Contains at most (degree * 2 - 1) elements and
        (degree * 2) subtrees.

    **************************************************************************/

    package struct BTreeMapNode
    {
        /**********************************************************************

            KeyValue structure which binds key and a value to be stored in the
            node.

            NOTE: In addition of ordering notion, this is really the only thing
            that makes this an implementation of the map, not of the set. If we're
            going to add set support, we should probably do it via templating
            this implementation on the actual content of the node's element
            (replace KeyValue with just a value) and with the ordering operation
            inserted as a policy (to compare the values, and not the nodes).

        ***********************************************************************/

        private struct KeyValue
        {
            KeyType key;
            // Storing the unqual ValueType here, as we need to reorder
            // the elements in the node without creating new nodes. User
            // facing API never sees unqualed type.
            Unqual!(ValueType) value;
        }

        /// Number of the elements currently in the node
        int number_of_elements;

        /// Indicator if the given node is a leaf
        bool is_leaf;

        /// Array of the elements
        package KeyValue[tree_degree * 2 - 1] elements;

        /// Array of the pointers to the subtrees
        package BTreeMapNode*[tree_degree * 2] child_nodes;
    }

    /**************************************************************************

        Root of the tree.

    ***************************************************************************/

    package BTreeMapNode* root;

    /***************************************************************************

        Type of the element actually stored in the node. The type stored in the
        node is unqualed version of the type that's accessible to the user, since
        the container needs to change the content of the actual array, without
        a need to always allocate a new one.

    ***************************************************************************/

    private alias typeof(BTreeMapNode.elements[0].value) StoredValueType;

    /***************************************************************************

        Convenience constant describing the tree's degree.

    ***************************************************************************/

    private enum degree = tree_degree;

    /***************************************************************************

        Memory manager used for allocating and deallocating memory. Refer to
        ocean.util.container.mem.MemManager for potential options.

    ***************************************************************************/

    package IMemManager allocator;


    /***************************************************************************

        "version" of the tree's state. Will be incremented on any removal/adding
        the element. On the iteration's start, range will record the current 
        "version" of the tree, and, and before proceeding with the iteration,
        it will check if any changes were performed on the tree, to prevent
        iteration over an undefined region.

     ***************************************************************************/

    package ulong content_version;

    /***************************************************************************

        Constructor-like method (as a workaround of a fact that D1 doesn't provide
        struct constructors).

        Params:
            allocator = memory manager to use to allocate/deallocate memory

    ***************************************************************************/

    package void initialize (IMemManager allocator = mallocMemManager)
    {
        verify ((&this).allocator is null);
        (&this).allocator = allocator;
    }


    /**************************************************************************

        Inserts the element in the tree.

        Params:
            key = key to insert
            value = associated value to insert.

        Returns:
            true if the element with the given key did not exist and it
            was inserted, false otherwise

    ***************************************************************************/

    package bool insert (KeyType key, ValueType el)
    {
        verify((&this).allocator !is null);

        if ((&this).root is null)
        {
            (&this).root = (&this).insertNewNode();
        }

        size_t dummy_index;
        if ((&this).get(key, dummy_index))
        {
            return false;
        }

        // unqualed for internal storage only. User will never access it as
        // unqualed reference.
        auto unqualed_el = cast(Unqual!(ValueType))el;
        auto r = (&this).root;
        if ((&this).root.number_of_elements == (&this).root.elements.length)
        {
            auto node = (&this).insertNewNode();
            // this is a new root
            (&this).root = node;
            node.is_leaf = false;
            node.number_of_elements = 0;

            // Old root node is the first child
            node.child_nodes[0] = r;

            (&this).splitChild(node, 0, r);
            auto ret = (&this).insertNonFull(node, key, unqualed_el);
            debug (BTreeMapSanity) check_invariants(*(&this));
            if (ret)
                (&this).content_version++;
            return ret;
        }
        else
        {
            auto ret = (&this).insertNonFull((&this).root, key, unqualed_el);
            debug (BTreeMapSanity) check_invariants(*(&this));
            if (ret)
                (&this).content_version++;
            return ret;
        }
    }

    /******************************************************************************

        Removes the element with the given key from the BTreeMap.

        Params:
            key = key associated with the element to delete.

        Returns:
            true if the element with the given key was found and deleted,
            false otherwise.

     ******************************************************************************/

    package bool remove (KeyType key)
    {
        verify((&this).allocator !is null);

        BTreeMapNode* parent = null;

        bool rebalance_parent;
        auto res = (&this).deleteFromNode((&this).root,
                parent, key, rebalance_parent);

        // can't rebalance the root node here, as they should all be
        // rebalanced internally by deleteFromNode
        verify(rebalance_parent == false);

        debug (BTreeMapSanity) check_invariants(*(&this));

        if (res)
            (&this).content_version++;

        return res;
    }

    /***************************************************************************

        Returns:
            true if the tree is empty, false otherwise.

    ***************************************************************************/

    package bool empty ()
    {
        return (&this).root is null;
    }

    /******************************************************************************

        Searches the tree for the element with the given key and returns its
        value if found.

        Params:
            key = key to find in the tree.
            found = indicator if the element was found

        Returns:
            value associated with the key, or ValueType.init if not found.

    *******************************************************************************/

    package ValueType get (KeyType key, out bool found_element)
    {
        size_t index;
        auto node = (&this).get(key, index);
        if (!node) return ValueType.init;

        found_element = true;
        return node.elements[index].value;
    }

    // implementation

    /***************************************************************************

        Finds the requested element in the tree.

        Params:
          key = key associated with the element to return
          index = out parameter, holding the index of the element in the node

        Returns:
            pointer to the node holding `element`, null otherwise

    ***************************************************************************/

    private BTreeMapNode* get (KeyType key,
        out size_t index)
    {
        /// internal function for recursion
        /// which does the actual search (outer function just accepts the tree)
        static BTreeMapNode* getImpl (BTreeMapNode* root,
            KeyType key, out size_t index)
        {
            auto pos = 0;

            // TODO: binary search
            while (pos < root.number_of_elements
                && key > root.elements[pos].key)
            {
                pos++;
            }

            // now pos is the least index in the key array such
            // that f < elements[pos]
            if (pos < root.number_of_elements
                && key == root.elements[pos].key)
            {
                index = pos;
                return root;
            }

            // Nowhere to descend
            if (root.is_leaf)
            {
                return null;
            }

            return getImpl(root.child_nodes[pos], key, index);
        }

        if ((&this).root is null)
        {
            return null;
        }

        return getImpl((&this).root, key, index);
    }

    /******************************************************************************

        Does the necessary traversal to delete an element and rebalance parents
        in the process.

        Params:
            node = node currently being inspected for the removal (as we go down
                     the tree, this parameter is being updated).
            parent = parent of the node (needed when merging the neighbour nodes)
            to_delete = key of the element to remove
            rebalance_parent = indicator if while traversing back to the root, the
                               parent node should be rebalanced

         Returns: true if the current node needs to be rebalanced

    ******************************************************************************/

    private bool deleteFromNode ( BTreeMapNode* node, BTreeMapNode* parent,
        KeyType to_delete, out bool rebalance_parent)
    {
        // does this node contain the element we want to delete? Or is it one of it's children?
        foreach (i, ref element; node.elements[0..node.number_of_elements])
        {
            if (element.key > to_delete)
            {
                // not found if it's the leaf
                if (node.is_leaf)
                    return false;

                auto delete_result = deleteFromNode(node.child_nodes[i],
                                                    node, to_delete, rebalance_parent);
                if (rebalance_parent)
                {
                    (&this).rebalanceAfterDeletion(node, parent, rebalance_parent);
                }

                return delete_result;
            }
            else if (element.key == to_delete)
            {
                auto element_index = i;
                if (node.is_leaf)
                {
                    deleteFromLeaf(node, i);
                    (&this).rebalanceAfterDeletion(node, parent, rebalance_parent);

                    return true;
                }
                else
                {
                    // if we have the element in the internal node, then
                    // the highest element in the left subtree is still
                    // smaller than this element, so this element could just
                    // be replaced with it, and then that element in the
                    // left subtree should be removed.
                    auto victim_node = node.child_nodes[element_index];

                    // find the highest element:
                    size_t highest_index;
                    auto highest_node = findMaximum(victim_node, highest_index);
                    auto highest_element = &highest_node.elements[highest_index];
                    node.elements[element_index] = *highest_element;

                    auto delete_result = deleteFromNode(victim_node,
                                            node, highest_element.key, rebalance_parent);

                    // The deletion of the element in the internal node is very simple:
                    // we need to find the largest element in the left subtree, put it
                    // instead of the element we want to delete, remove it from the subtree
                    // and rebalance the tree starting from that node.
                    if (rebalance_parent)
                    {
                        (&this).rebalanceAfterDeletion(node, parent, rebalance_parent);
                    }
                    return delete_result;
                }
            }
        }

        // no left subtree was found that it could contain this key.
        // we need to check only for the most-right subtree. If it doesn't
        // exists, there's no such key
        if (node.is_leaf)
        {
            return false;
        }
        else
        {
            auto delete_result = deleteFromNode(node.child_nodes[node.number_of_elements],
                                                 node, to_delete, rebalance_parent);

            if (rebalance_parent)

            {
                (&this).rebalanceAfterDeletion(node, parent, rebalance_parent);
            }

            return delete_result;
        }
    }

    /******************************************************************************

        Allocates and initializes new node.

    *******************************************************************************/

    private BTreeMapNode* insertNewNode()
    {
        auto node = cast(BTreeMapNode*)(&this).allocator.create(BTreeMapNode.sizeof).ptr;
        *node = BTreeMapNode.init;

        node.is_leaf = true;
        node.number_of_elements = 0;
        return node;
    }

    /**************************************************************************

        Insert the element into the non-full node. If the node is leaf and not
        full, then no spliting will be done, the element will simply be inserted
        into it.

        If the target node is non-leaf node, we also know that even if the
        child node is split, there will be bplace to split it.

        Params:
            node = non-full node to insert the element into
            key = key to insert
            value = value to insert

        Returns:
            true if the element was inserted, false otherwise.

    ***************************************************************************/

    private bool insertNonFull
        (BTreeMapNode* node, KeyType key, StoredValueType value)
    {
        if (node.is_leaf)
        {
            return insertIntoLeaf(node, key, value);
        }
        else
        {
            int i = node.number_of_elements - 1;

            // find the child where new key belongs:
            while (i >= 0 && key < node.elements[i].key)
                i--;

            // if the file should be in children[i], then f < elements[i]
            // Well go back to the last key where we found this to be true,
            // and get that child node
            i++;

            if (node.child_nodes[i].number_of_elements == node.child_nodes[i].elements.length)
            {
                splitChild(node, i, node.child_nodes[i]);

                // now children[i] and children[i+] are the new
                // children, and the elements[i] might been changed (we got it from the
                // split child)
                // we'll see if k belongs in the first or the second
                if (key > node.elements[i].key)
                    i++;
            }

            // call ourself recursively to do the insertion
            return insertNonFull(node.child_nodes[i], key, value);
        }
    }

    /**************************************************************************

        Splits the full child, so it can accept the new element.

        New node is allocated and it gets the half of the elements from the
        previous node, and the median element from the old node is moved into
        the parent, separating these two child nodes.

        Params:
            parent = parent node
            child_index = index of the subtree in the parent
            child = the root of the subtree

    ***************************************************************************/

    private void splitChild (BTreeMapNode* parent,
        int child_index,
        BTreeMapNode* child)
    {
        auto new_node = (&this).insertNewNode();
        // new node is a leaf if old node was
        new_node.is_leaf = child.is_leaf;
        moveElementsAt(new_node, 0, child, degree);

        // Now put the median element in the parent, and insert the new
        // node in the parent
        shiftElements(parent, child_index, 1);
        parent.elements[child_index] = child.elements[degree-1];
        parent.child_nodes[child_index+1] = new_node;
        child.number_of_elements--;
    }

    /***************************************************************************


        Rebalances the tree after removal of the element.
        Makes sure that the tree is still holding the invariants.

        Params:
            node = node from where the element was removed
            parent = parent of the node.
            rebalance_parent = indicator if the parent is now due to rebalancing.

    ***************************************************************************/

    private void rebalanceAfterDeletion (
        BTreeMapNode* node, BTreeMapNode* parent, out bool rebalance_parent)
    {
        // check for the underflow. If the node now contains
        // less than `degree-1` entries, we need to borrow the
        // element from the neighbouring nodes
        // note that the root is the only node which is allowed to have
        // more than a minimum elements, so we will never rebalance it
        if (node != (&this).root && node.number_of_elements < (&this).degree - 1)
        {
            long position_in_parent = -1;

            for (auto i = 0; i < parent.number_of_elements + 1; i++)
            {
                if (parent.child_nodes[i] == node)
                {
                    position_in_parent = i;
                    break;
                }
            }

            verify (position_in_parent >= 0);

            // case 1 - the neighbouring node contains more than
            // (2 * degree - 1) - can't have less because of the invariant
            // - in which case we join the node into the new one,
            // and split it into the two, where the median element
            // goes into the parent node.
            if (parent.number_of_elements > position_in_parent)
            {
                auto next_neighbour =
                    parent.child_nodes[position_in_parent+1];

                // Now, either this exists or not, and if it exists,
                // it has the spare elements, or it does't (in which case
                // it's merged with the parent

                if (next_neighbour && next_neighbour.number_of_elements > (&this).degree -1)
                {
                    // copy the separator from the parent node
                    // into the deficient node
                    node.elements[node.number_of_elements] = parent.elements[position_in_parent];
                    node.number_of_elements++;
                    node.child_nodes[node.number_of_elements] = next_neighbour.child_nodes[0];

                    // replace the separator in the parent with the first
                    // element of the right sibling
                   parent.elements[position_in_parent] = popFromNode(next_neighbour, 0);

                    return;
                }
            }

            // let's try with the left sibling
            if (position_in_parent > 0)
            {
                // do the same thing but with the left sibling
                auto previous_neighbour =
                    parent.child_nodes[position_in_parent-1];

                // Now, either this exists or not, and if it exists,
                // it has the spare elements, or it does't (in which case
                // it's merged with the parent

                if (previous_neighbour.number_of_elements > (&this).degree -1)
                {
                    shiftElements(node, 0, 1);
                    // copy the separator from the parent node
                    // into the deficient node
                    //
                    node.elements[0] = parent.elements[position_in_parent-1];

                    // replace the separator in the parent with the last
                    // element of the left sibling
                    parent.elements[position_in_parent-1] =
                        previous_neighbour.elements[previous_neighbour.number_of_elements-1];

                    // and move the top-right child of the left neighbourhood as the first
                    // child of the new one
                    node.child_nodes[0] = previous_neighbour.child_nodes[previous_neighbour.number_of_elements];

                    previous_neighbour.number_of_elements--;
                    return;
                }
            }

            // both immediate siblings have the only the minimum
            // number of elements. Merge with a sibling then.
            // this merging causes the parent to loose the element
            // (because there will be no need for separating) two nodes,
            // so we need to rebalance it with the neighbouring nodes

            // Node that will accept everything afer the merge
            BTreeMapNode* remaining_node;

            // The edge cases are top-left or top-right nodes
            // Note: Although these two cases are very same,
            // it's easier to follow them if the code is slightly duplicated
            if (position_in_parent < parent.number_of_elements)
            {
                auto next_neighbour =
                    parent.child_nodes[position_in_parent+1];

                node.elements[node.number_of_elements] = popFromNode(parent, position_in_parent);
                node.number_of_elements++;

                // parent.pop removed the node from it's list, put it now there
                parent.child_nodes[position_in_parent] = node;

                moveElementsAt(node,
                    node.number_of_elements, next_neighbour, 0);

                remaining_node = node;

                (&this).allocator.destroy(cast(ubyte[])(next_neighbour[0..1]));
            }
            else
            {
                auto previous_neighbour =
                    parent.child_nodes[position_in_parent-1];

                previous_neighbour.elements[previous_neighbour.number_of_elements] = popFromNode(parent, position_in_parent-1);
                previous_neighbour.number_of_elements++;

                // parent.pop removed the node from it's list, put it now there
                parent.child_nodes[position_in_parent-1] = previous_neighbour;

                moveElementsAt(previous_neighbour,
                    previous_neighbour.number_of_elements, node, 0);

                remaining_node = previous_neighbour;

                (&this).allocator.destroy(cast(ubyte[])((node)[0..1]));
            }

            // TODO: comment this
            if (parent == (&this).root && parent.number_of_elements == 0)
            {
                (&this).allocator.destroy(cast(ubyte[])(parent[0..1]));
                (&this).root = remaining_node;
                return;
            }
            else if (parent != (&this).root && parent.number_of_elements < (&this).degree - 1)
            {
                rebalance_parent = true;
                return;
            }
            else
            {
                // either is root, or it has enough elements
                return;
            }

            assert(false);
        }
        // else - nothing to rebalance, node from which we've removed
        // the element still has the right amount of the elements
    }

    /***************************************************************************

        Inserts the element into the leaf.

        The simpliest version of the insertion - it just moves the elements
        to create space for the new one and inserts it.

        Params:
            node = leaf node to insert the element into
            key = key to insert
            value = value to insert

    ***************************************************************************/

    private static bool insertIntoLeaf(BTreeMapNode* node, KeyType key,
            StoredValueType value)
    {
        verify(node.is_leaf);

        // shift all elements to make space for it
        auto i = node.number_of_elements;

        // shift everything over to the "right", up to the
        // point where the new element should go
        for (; i > 0 && key < node.elements[i-1].key; i--)
        {
            node.elements[i] = node.elements[i-1];
        }

        node.elements[i].key = key;
        node.elements[i].value = value;
        node.number_of_elements++;

        return true;
    }

    /***************************************************************************

        Removes the element from the leaf.

        The simpliest version of the removal - it just removes the element
        by moving all the elements next to it by one step.

        Params:
            node = pointer to the leaf node to remove the element from.
            element_index = index of the element in the node to remove.

    ***************************************************************************/

    private static void deleteFromLeaf(BTreeMapNode* node, size_t element_index)
    {
        verify(node.is_leaf);

        // deletion from the leaf is easy - just remove it
        // and shift all the ones left
        foreach (j, ref el; node.elements[element_index..node.number_of_elements-1])
        {
            el = node.elements[element_index + j + 1];
        }

        node.number_of_elements--;
    }

    /***************************************************************************

        Shifts the element and subtree pointers inside a node starting from
        `position` by `count`.

        Params:
            node = node to edit.
            position = position to start shifting on
            count = count of the shifts to perform.;

    ***************************************************************************/

    private static void shiftElements (BTreeMapNode* node, int position, int count)
    {
        for (auto i = node.number_of_elements+count; i > position; i--)
        {
            node.child_nodes[i] = node.child_nodes[i-count];
        }

        for (auto i = node.number_of_elements+count-1; i > position; i--)
        {
            node.elements[i] = node.elements[i-count];
        }

        node.number_of_elements += count;
    }

    /***************************************************************************

        Moves the elements from one node to another.

        In case we need to merge/split the nodes, we need to move the elements
        and their subtrees to the new node. Remember that each element in the
        node is dividing the subtrees to the one less than it is and the other
        that's higher than it, so simply moving elements is not possible.

        Params:
            dest = destination node
            destination_start = first index in the dest. node to copy to
            source = source node
            source_start = first index in the source node to copy from.

    ***************************************************************************/

    private static void moveElementsAt (BTreeMapNode* dest, int destination_start,
        BTreeMapNode* source, int source_start)
    {
        int end = source.number_of_elements;
        verify(source.number_of_elements >= end - source_start);

        auto old_number = dest.number_of_elements;
        dest.number_of_elements += end - source_start;

        // Move the elements from the source to this
        foreach (i, ref el; dest.elements[old_number..dest.number_of_elements])
        {
            el = source.elements[source_start + i];
        }

        if (!dest.is_leaf)
        {
            // TODO: assert (!souce.is_leaf)
            foreach (i, ref child_node;
                    dest.child_nodes[old_number..dest.number_of_elements+1])
            {
                child_node = source.child_nodes[source_start + i];
            }
        }

        source.number_of_elements = source_start;
    }

    /***************************************************************************

        Removes the element from the node. This removes the element from the node
        and reorganizes the subtrees.

        Params:
            node = node to remove from
            position = position of the element to remove.

        Returns:
            the removed element.

    ***************************************************************************/

    private static BTreeMapNode.KeyValue popFromNode (BTreeMapNode* node, size_t position)
    {
        auto element = node.elements[position];

        // rotate the next neighbour elements
        for (auto i = position; i < node.number_of_elements-1; i++)
        {
            node.elements[i] = node.elements[i+1];
        }

        if (!node.is_leaf)
        {
            for (auto i = position; i < node.number_of_elements; i++)
            {
                node.child_nodes[i] = node.child_nodes[i+1];
            }
        }

        node.number_of_elements--;
        return element;
    }

    /******************************************************************************

        Finds the maxima in the subtree.

        Params:
            node = root of the (sub)tree
            index = element index in the node.

        Returns:
            pointer to the node containing the maximum element

    ******************************************************************************/

    private static BTreeMapNode* findMaximum (BTreeMapNode* node,
        out size_t index)
    {
        if (node.is_leaf)
        {
            index = node.number_of_elements - 1;
            return node;
        }
        else
        {
            return findMaximum(node.child_nodes[node.number_of_elements], index);
        }
    }

    /******************************************************************************

        Visits the tree in the inorder order.

        Params:
            tree = tree to visit
            dg = delegate to call for each visited element. Delegate should return
                 non-zero value if the visiting should be aborted.

        Returns:
            return value of the last dg call.

    ******************************************************************************/

    package int inorder (scope int delegate(ref KeyType key, ref ValueType value) dg)
    {
        if ((&this).root is null)
        {
            return 0;
        }

        return inorderImpl((&this).content_version, *(&this).root, dg);
    }

    /******************************************************************************

        Visits the tree in the inorder order.

        Params:
            tree = tree to visit
            dg = delegate to call for each visited element. Delegate should return
                 non-zero value if the visiting should be aborted.

        Returns:
            return value of the last dg call.

    ******************************************************************************/

    package int inorder (scope int delegate(ref ValueType value) dg)
    {
        if ((&this).root is null)
        {
            return 0;
        }

        return inorderImpl((&this).content_version, *(&this).root, dg);
    }

    /***************************************************************************

        Traverses the BTreeMap in the inorder, starting from the root.

        Params:
            version = "version" of the tree at the time of starting the visit
            root = root of a (sub)tree to visit
            dg = delegate to call with the key/value

        Returns:
            return value of the delegate dg

    ***************************************************************************/

    private int inorderImpl (UserDg)(ulong start_version, ref BTreeMapNode root,
                UserDg dg)
        {
            for (int i = 0; i < root.number_of_elements; i++)
            {
                int res;
                if (!root.is_leaf)
                {
                    res = inorderImpl(start_version, *root.child_nodes[i], dg);
                    if (res) return res;
                }

                static if (is(ReturnAndArgumentTypesOf!(UserDg) ==
                            Tuple!(int, ValueType)))
                {
                    res = dg (root.elements[i].value);
                }
                else static if (is(ReturnAndArgumentTypesOf!(UserDg) ==
                            Tuple!(int, KeyType, ValueType)))
                {
                    res = dg (root.elements[i].key, root.elements[i].value);
                }
                else
                {
                    static assert(false);
                }

                // check if the tree is valid
                if (start_version != (&this).content_version) return 1;

                if (res)
                    return res;
            }

            if (!root.is_leaf)
            {
                auto res = inorderImpl(start_version,
                       *root.child_nodes[root.number_of_elements], dg);
                if (res)
                    return res;
            }

            return 0;
        }
}

/// Checks if all invariants of the tree are still valid
debug (BTreeMapSanity)
{
    /// Confirms if the invariants of btree stands:
    /// 1. All leaves have the same height - h
    /// 2. Every node other than the root must have at least degree - 1
    ///    keys. If the tree is nonempty, the root must have at least one
    ///    key.
    /// 3. Every node may contain at most 2degree - 1 keys - enforced through
    ///    the array range exception
    /// 4. The root must have at least two keys if it's not a leaf.
    /// 5. The elements stored in a given subtree all have keys that are
    ///    between the keys in the parent node on either side of the subtree
    ///    pointer.

    void check_invariants(BTreeMap)(ref BTreeMap tree)
    {
        verify(tree.root.is_leaf || tree.root.number_of_elements >= 1);

        /// Traverses the BTreeMap in the inorder, starting from root,
        /// and returns the btree's node.
        static void traverse (BTreeMap.BTreeMapNode* root, ref int current_height,
                            scope void delegate(BTreeMap.BTreeMapNode* b, int current_height) dg)
        {
            for (int i = 0; i < root.number_of_elements; i++)
            {
                if (!root.is_leaf)
                {
                    current_height += 1;
                    traverse(root.child_nodes[i], current_height, dg);
                    current_height -= 1;
                }
            }

            dg (root, current_height);
        }

        int tree_height = -1;
        int current_height;

        // traverse the tree and inspect other invariants
        traverse(tree.root, current_height,
            (BTreeMap.BTreeMapNode* node, int height)
            {
                if (node.is_leaf)
                {
                    // all leaves must have the same level
                    if (tree_height == -1)
                    {
                        tree_height = height;
                    }
                    verify(tree_height == height);
                }
                else
                {
                    // every node must have at least degree - 1 keys
                    if (node != tree.root)
                    {
                        verify(node.number_of_elements >= tree.degree - 1);
                    }

                    // and if we get into each one of them, we will not find keys
                    // equal or larger/smaller (depending on the side) of the keys
                    for (int i = 0; i < node.number_of_elements; i++)
                    {
                        auto current_value = &node.elements[i];

                        // let's traverse into each the left one and assert they are
                        // all smaller
                        int dummy;

                        traverse(node.child_nodes[i], dummy, (BTreeMap.BTreeMapNode* b, int height){
                            for (int j = 0; j < b.number_of_elements; j++)
                            {
                                verify(b.elements[j] < *current_value);
                            }
                        });

                        // and traverse to the right subtree and inspect it
                        traverse(node.child_nodes[i+1], dummy, (BTreeMap.BTreeMapNode* b, int height){
                            for (int j = 0; j < b.number_of_elements; j++)
                            {
                                verify(b.elements[j] > *current_value);
                            }
                        });
                    }
                }
            });
    }
}

unittest
{
    foreach (allocator; [mallocMemManager, gcMemManager])
    {
        testRandomTree(allocator);
    }
}

version (UnitTest)
{
    import ocean.util.container.mem.MemManager;
    import ocean.math.random.Random;
    import ocean.core.Test;
    import ocean.core.Tuple;

    // Workaround for the D1 issue where we can't have the
    // delegate used in the static foreach
    private void testRandomTree(IMemManager allocator)
    {
        auto random = new Random();
        bool found;

        for (int count = 0; count < 5; count++)
        {
            auto random_tree = BTreeMapImplementation!(int, int, 3).init;
            random_tree.initialize(allocator);

            int removed_count;
            int remaining_elements;
            int total_elements;
            int to_insert = 10_000;
            size_t my_index;

            // create completely random tree and remove completely random values
            for (int i = 0; i < to_insert; i++)
            {
                int element = random.uniformR(to_insert);
                // don't count double elements (they are not inserted)
                total_elements += random_tree.insert(element, element)? 1 : 0;
                auto res = random_tree.get(element, found);
                test(found);
                test!("==")(res, element);
            }

            // reseed, so that the difference two random number generated sets
            // is not zero

            for (int i = 0; i < to_insert; i++)
            {
                int element = random.uniformR(to_insert);
                removed_count += random_tree.remove(element)? 1 : 0;
                test(random_tree.get(element, found) == int.init && !found);
            }

            int previous_value;
            bool started;

            random_tree.inorder((ref int value)
            {
                if (!started)
                {
                    previous_value = value;
                    started = true;
                    remaining_elements++;
                    return 0;
                }

                // enforce that the order is preserved
                test!(">")(value, previous_value);
                previous_value = value;
                remaining_elements++;
                return 0;
            });

            test!("==")(total_elements - remaining_elements, removed_count);

            // Test the iterative version
            started = false;
            previous_value = previous_value.init;
            remaining_elements = 0;
        }
    }
}
