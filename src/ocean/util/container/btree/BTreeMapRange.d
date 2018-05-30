/********************************************************************************

    Range traversal support for BTreeMap.

    Copyright:
        Copyright (c) 2017 sociomantic labs GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.btree.BTreeMapRange;

import ocean.transition;
import ocean.util.container.btree.BTreeMap;

/*******************************************************************************

    Exception thrown from the BTreeMapRange if a tree is modified during iteration.

*******************************************************************************/

class RangeInvalidatedException: Exception
{
    import ocean.core.Exception: DefaultExceptionCtor;
    mixin DefaultExceptionCtor;
}

// shared between different ranges
private RangeInvalidatedException range_exception;

static this ()
{
    .range_exception = new RangeInvalidatedException(
            "Container has been changed during iteration, please restart.");
}

/*******************************************************************************

    Returns a range that performs an inorder iteration over the specified tree.

    If tree has changed during the iteration, range will throw an
    RangeInvalidatedException. In case user knows that the tree can be changed
    any time, it is possible to call BTreeMapRange.isValid before performing any
    action on the range to check if fetching the front element, or moving to
    the next one is guaranteed to success. This is only true for the
    single-threaded environment.

    Params:
        tree = tree to iterate over
        buff = buffer for storing the state of the iteration. Useful
               for the reusable-memory management strategy. The buffer size
               is proportional to the height of the tree, so in most cases
               it should be at most the size of the several pointers.
               If the allocations are not a concern, null can passed for buff,
               and range will allocate a buffer on its own.

    Returns:
        BTreeMapRange performing the full inorder iteration of the tree.

*******************************************************************************/

public BTreeMapRange!(BTreeMap) byKeyValue (BTreeMap) (ref BTreeMap tree, void[]* buff)
{
    if (buff is null)
    {
        // Struct wrapper is used to woraround D inability to allocate slice
        // itself on heap via new
        static struct Buffer
        {
            void[] data;
        }

        auto buf = new Buffer;
        buff = &buf.data;
    }
    else
    {
        (*buff).length = 0;
        enableStomping(*buff);
    }

    auto range = BTreeMapRange!(BTreeMap)(&tree.impl);
    range.stack = cast(typeof(range.stack))buff;

    range.start();
    return range;
}


/*******************************************************************************

    key/value pair. Akin to runtime's byKeyValue
    NOTE: ideally, this should be optional. One might choose not to
    care about keys at all. However, making this work without copying
    entire code and without crashing dmd1 seems to be impossible.

*******************************************************************************/

private struct Pair(KeyType, ValueType)
{
    void* keyp;
    void* valp;

    KeyType key () { return *cast(KeyType*)keyp; }
    ValueType value () { return *cast(ValueType*)valp; }
}

/*******************************************************************************

    Structure representing an inorder range over a BTreeMap.

    If tree has changed during the iteration, range will throw an
    RangeInvalidatedException. If the user knows that the tree will not change
    during the range traversal, it is safe to call range's methods - it will throw
    an exception if this promise is broken. In case user knows that the tree
    can be changed any time, it is possible to call BTreeMapRange.isValid before
    performing any action on the range to check if the accessing is safe. This
    is only true for the single-threaded environment.

*******************************************************************************/

public struct BTreeMapRange(BTreeMap)
{
    import ocean.core.Verify;
    import ocean.core.array.Mutation;

    /// (key, value) pair to return to the caller
    alias Pair!(BTreeMap.KeyType, BTreeMap.ValueType) KeyValue;

    /// Root node of a tree
    private BTreeMap.Implementation* tree;


    /// Copy of the content_version field of the tree at the time iteration began
    private ulong tree_version;

    /// Pair of the node/index for which we've paused iteration and pushed
    /// to stack
    private struct NodeElement
    {
        BTreeMap.Implementation.BTreeMapNode* node;
        size_t index;

        BTreeMap.ValueType* value ()
        {
            return &(node.elements[index].value);
        }

        BTreeMap.KeyType* key ()
        {
            return &(node.elements[index].key);
        }
    }

    /// When IterationStep() moves from a node to iterate over its children,
    /// the parent node is pushed to this stack, and popped upon completion
    /// of traversal over the nodes.
    private NodeElement[]* stack;

    /// Next (node, element_index) pair we're should walk over
    private NodeElement item;

    /// Value of the current key to return with .front
    private BTreeMap.KeyType* current_key;

    /// Value of the current value to return with .front
    private BTreeMap.ValueType* current_value;

    invariant ()
    {
        verify((&this).stack !is null);
    }


    /***************************************************************************

        Returns:
            the current element in the range.

        Throws:
           RangeInvalidatedException if the underlying tree has changed

    ***************************************************************************/

    public KeyValue front ()
    {
        (&this).enforceValid();
        return Pair!(BTreeMap.KeyType, BTreeMap.ValueType)((&this).current_key, (&this).current_value);
    }

    /***************************************************************************

        Pops the next element from the tree.

        Throws:
           RangeInvalidatedException if the underlying tree has changed

    ***************************************************************************/

    public void popFront ()
    {
        (&this).enforceValid();
        (&this).iterationStep();
    }

    /***************************************************************************

        Returns:
            true if there are no more elements to iterate over

        Throws:
           RangeInvalidatedException if the underlying tree has changed

    ***************************************************************************/

    public bool empty ()
    {
        (&this).enforceValid();
        return (&this).tree.root is null ||
            ((&this).item.node is null && (&this).stack.length == 0);
    }

    /***************************************************************************

        Returns:
            true if the underlying tree has not changed and it's safe
            to use front/popFront/empty methods.

    ***************************************************************************/

    public bool isValid ()
    {
        return tree_version == (&this).tree.content_version;
    }

    /***************************************************************************

        Ensures that a tree has not changed since the creation of this range.

        Throws:
           RangeInvalidatedException if the underlying tree has changed

    ***************************************************************************/

    private void enforceValid ()
    {
        if (!(&this).isValid())
        {
            throw .range_exception;
        }
    }

    /***************************************************************************

        Prepares the range over the tree.

    ***************************************************************************/

    private void start ()
    {
        if ((&this).tree.root !is null)
        {
            (&this).tree_version = (&this).tree.content_version;
            (&this).item = NodeElement((&this).tree.root, 0);
            (&this).iterationStep();
        }
    }

    /***************************************************************************

        Goes to the next element in the tree.

    ***************************************************************************/

    private void iterationStep ()
    {
        while (true)
        {
            if ((&this).item.node.is_leaf)
            {
                // Leaf doesn't have subtrees, we can just iterate over it
                if ((&this).item.index < (&this).item.node.number_of_elements)
                {
                    (&this).current_value = (&this).item.value;
                    (&this).current_key = (&this).item.key;
                    (&this).item.index++;
                    return;
                }
            }
            else
            {
                // do we have a subtree in the child_elements[index]?
                if ((&this).item.index <= (&this).item.node.number_of_elements)
                {
                    *(&this).stack ~= NodeElement((&this).item.node, (&this).item.index);
                    (&this).item = NodeElement(item.node.child_nodes[(&this).item.index], 0);
                    continue;
                }
            }

            if ((*(&this).stack).pop((&this).item) == false)
            {
                return;
            }

            // We got the item from the stack, and we should see if we
            // have any more elements to call the delegate on it
            if ((&this).item.index < (&this).item.node.number_of_elements)
            {
                (&this).current_value = (&this).item.value;
                (&this).current_key = (&this).item.key;
                (&this).item.index++;
                return;
            }
            // There's no more elements, just skip to the next one
            (&this).item.index++;
        }
    }
}

version (UnitTest)
{
    import ocean.math.random.Random;
    import ocean.core.Test;
}

unittest
{
    // Build a random tree, and use the range over it
    auto random = new Random();
    bool found;
    int res;

    BTreeMap!(int, int, 3) random_tree = BTreeMap!(int, int, 3).init;
    random_tree.initialize();

    int removed_count;
    int total_elements;
    int to_insert = 10_000;
    size_t my_index;

    // create completely random tree and remove completely random values
    for (int i = 0; i < to_insert; i++)
    {
        int element = random.uniformR(to_insert);
        // don't count double elements (they are not inserted)
        total_elements += random_tree.insert(element, element)? 1 : 0;
        res = random_tree.get(element, found);
        test(found);
        test!("==")(res, element);
    }

    for (int i = 0; i < to_insert; i++)
    {
        int element = random.uniformR(to_insert);
        removed_count += random_tree.remove(element)? 1 : 0;
        res = random_tree.get(element, found);
        test(!found);
    }

    void testRange(void[]* buffer_ptr)
    {
        bool started;
        int previous_value;
        int remaining_elements;

        for (
            auto range = byKeyValue(random_tree, buffer_ptr);
            !range.empty; range.popFront())
        {
            if (!started)
            {
                previous_value = range.front.value;
                started = true;
                remaining_elements++;
                continue;
            }

            // enforce that the order is preserved
            test!(">")(range.front.value, previous_value);
            previous_value = range.front.value;
            test!("==")(range.front.value, range.front.key);
            remaining_elements++;
        }

        test!("==")(total_elements - remaining_elements, removed_count);
    }

    void[] buff;
    testRange(&buff);
    testRange(null);

    // test invalidation
    auto range = byKeyValue(random_tree, &buff);
    auto first = range.front;

    bool insert_res;
    do
    {
        auto val = random.uniformR(2 * to_insert);
        insert_res = random_tree.insert(val, val);
    }
    while (!insert_res);
    testThrown!(RangeInvalidatedException)(range.popFront());
}
