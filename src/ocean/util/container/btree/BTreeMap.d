/********************************************************************************

    B-Tree data structure and operations on it.

    Copyright:
        Copyright (c) 2017 sociomantic labs GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.btree.BTreeMap;

import ocean.transition;
import ocean.util.container.mem.MemManager;

/******************************************************************************

    BTree structure.


    BTree is a rooted tree, with the following properties:

    - A BTree has characteristic called "degree". This indicates branching
      factor of the tree, so that maximum number of the subtrees for a single
      node is `2 * degree`. Having a high degree makes the tree shorter, and,
      because the node contains large number of elements, it allows prefetching
      many elements from the memory in one go.

    - The layout of one node of the tree is as follows:

      -----------------------------------------------------------------
      | p1 | element1 | p2 | element2 | ... | pn-1 | element n-1 | pn |
      -----------------------------------------------------------------

      Every element (a key/value pair) in the node (for the non-leaf nodes) is
      surrounded by two pointers. We call these pointers child nodes.

    - Each pointer is a root of a subtree, for which the following holds true:
      all the elements' keys in a tree pointed by p(i-1) (pointer left of the
      elements) are smaller (in respect to the ordering defined by the key's
      type) of the element(i), and all the elements' keys in a subtree pointed by
      p(i) are larger than a element(i).

    - Every node may contain at most 2*degree - 1 elements. Therefore, an internal
      node may be root for at most 2*degree subtrees.

    - Every node other than root must have at least (degree-1) elements.

    - Every internal node other than the root has at least degree children.

    - Every node has the following attributes:

        node.number_of_elements = number of elements node currently contains
            (as nodes are statically allocated block, the number of the elements
             may not necessarily be maximal).
        node.elements = the elements themselves
        node.is_leaf = indicator if the node is a leaf.
        node.child_nodes = number_of_elements+1 pointers to the subtrees whose
            roots are this node. We refer to these nodes as child-nodes (this
            node is a direct parent of them).

    - All leaves have the same depth

    Other than insert and delete operations, inorder traversal method is provided,
    which traverses the tree in inorder order (left subtree is visited first,
    then the element separating these subtrees, then the right subtree, then
    the next element, etc.). This provides sequential access to the tree.
    There's a recursive and range-based implementation of the inorder
    traversal.

    Range-based traversal is supported through `BTreeMapRange` structure, found in
    in ocean.util.container.btree.BTreeMapRange.

    CPU complexity of the operations (n is number of the elements, t is degree,
    h is the tree height):

        - Searching: O(th) = O(t * log_t(n))
        - Inserting: O(th) = O(t * log_t(n))
        - Deleting:  O(th) = O(t * log_t(n))

    Complexity of the memory access (to read/write the node from/in memory):

        - Searching O(h) = O(log_t(n))
        - Inserting O(h) = O(log_t(n))
        - Deleting: O(h) = O(log_t(n))

    References:
        - https://en.wikipedia.org/wiki/B-tree
        - Thomas H. Cormen et al. "Introduction to Algorithms, 3rd edition"

    Params:
        TreeKeyType = type of the key.
        TreeValueType = type of the element to store.
        tree_degree = degree of the tree (refer to the documentation)

******************************************************************************/

struct BTreeMap(TreeKeyType, TreeValueType, int tree_degree)
{
    import ocean.util.container.btree.Implementation;

    static assert (tree_degree > 0);

    /**************************************************************************

        Constructor.

        Params:
            allocator = memory manager to use to allocate/deallocate memory

    ***************************************************************************/

    package void initialize (IMemManager allocator = mallocMemManager)
    {
        (&this).impl.initialize(allocator);
    }

    // Disable constructor, so user always needs to use the makeBTreeMap method
    version (D_Version2)
    {
        mixin("@disable this();");
    }

    /**************************************************************************

        Inserts the (key, value) in the tree. This is passing the copy of the
        value into the tree, so it's not necessary to manually create copy of
        it.  Note that for the reference types, this will just copy the
        reference.

        Params:
            key = key to insert
            value = value associated to the key to insert.

        Returns:
            true if the element with the given key did not exist and it
            was inserted, false otherwise

        Complexity:
            CPU: O(degree * log_degree(n))
            Memory:O(log_degree(n))

    ***************************************************************************/

    public bool insert (KeyType key, ValueType value)
    {
        return (&this).impl.insert(key, value);
    }

    /******************************************************************************

        Deletes the element from the BTreeMap.

        Params:
            key = key of the element to delete.

        Returns:
            true if the element was found and deleted, false otherwise.

        Complexity:
            CPU: O(degree * log_degree(n))
            Memory:O(log_degree(n))

     ******************************************************************************/

    public bool remove (KeyType key)
    {
        return (&this).impl.remove(key);
    }

    /******************************************************************************

        Searches the tree for the element with the given key and returns the
        associated value.

        Params:
            key =  key to find in a tree.
            found_element = indicator if the element with the given key has been
                found in the map.

        Returns:
            copy of the value associated with the key, if found, ValueType.init
            otherwise.

        Complexity:
            CPU: O(degree * log_degree(n))
            Memory:O(log_degree(n))

    *******************************************************************************/

    public ValueType get (KeyType key, out bool found_element)
    {
        return (&this).impl.get(key, found_element);
    }

    /***********************************************************************

        Recursive inorder iteration over keys and values. Note that, in case
        the tree is changed during the iteration, iteration will halt.

        Params:
            dg = opApply's delegate

        Returns:
            return value of dg

    ***********************************************************************/

    public int opApply (scope int delegate (ref KeyType value, ref ValueType) dg)
    {
        return (&this).impl.inorder(dg);
    }

    /***********************************************************************

        Recursive inorder iteration over values only. Note that, in case the
        tree is changed during the iteration, iteration will halt.

        Params:
            dg = opApply's delegate

        Returns:
            return value of dg

    ***********************************************************************/

    public int opApply (scope int delegate (ref ValueType) dg)
    {
        return (&this).impl.inorder(dg);
    }


    /// Convenience alias for the implementation
    package alias BTreeMapImplementation!(KeyType, ValueType, tree_degree)
        Implementation;

    /// Convenience alias for the key type
    package alias TreeKeyType KeyType;

    /// Convenience alias for the element type
    package alias TreeValueType ValueType;

    /// Private implementation
    package Implementation impl;
}

/*******************************************************************************

    Constructor-like method. Constructs the BTreeMap and initializes it.

    Params:
        KeyType = type of the key.
        ValueType = type of the value to store.
        tree_degree = degree of the tree (refer to the documentation)
        memManager = memory management strategy to use

    Returns:
        empty BTreeMap which maps KeyType to ValueType of a given degree
        which sues memManager allocation strategy.

******************************************************************************/

public BTreeMap!(KeyType, ValueType, tree_degree) makeBTreeMap
    (KeyType, ValueType, int tree_degree)(IMemManager allocator = mallocMemManager)
{
    auto tree = BTreeMap!(KeyType, ValueType, tree_degree).init;
    tree.initialize(allocator);
    return tree;
}

version (UnitTest)
{
    import ocean.util.container.btree.BTreeMapRange;
}

///
unittest
{
    // import ocean.util.container.btree.BTreeMapRange;
    struct MyVal
    {
        int x;
    }

    auto map = makeBTreeMap!(int, MyVal, 2);

    for (int i = 0; i <= 10; i++)
    {
        map.insert(i, MyVal(i*2));
    }

    // find the element by key
    bool found;
    auto val = map.get(5, found);
    test!("==")(found, true);
    test!("==")(val.x, 10);

    // remove the element
    map.remove(10);
    map.get(10, found);
    test!("==")(found, false);

    // iterate over using opApply
    foreach (key, val; map)
    {
        test!("==")(key * 2, val.x);
    }

    // iterate over using range
    void[] buff;
    for(auto range = byKeyValue(map, &buff);
            !range.empty; range.popFront())
    {
        test!("==")(range.front.key * 2, range.front.value.x);
    }

    // Let's check that the memory is ready to be reused
    test(buff.ptr !is null);
}

/*

    Unittests. Compile with -debug=BTreeMapSanity to turn on
    the invariant checks for the tree.

*/

version (UnitTest)
{
    import ocean.core.Test;
}

unittest
{
    BTreeMap!(int, File, 2) tree = makeBTreeMap!(int, File, 2);
    bool found_element;

    File f;

    f.setName("5");
    tree.insert(5, f);

    f.setName("9");
    tree.insert(9, f);

    f.setName("3");
    tree.insert(3, f);

    f.setName("7");
    tree.insert(7, f);

    size_t index;
    auto res = tree.get(7, found_element);

    test!("==")(found_element, true);
    test!("==")(res, f);

    f.setName("1");
    tree.insert(1, f);

    f.setName("2");
    tree.insert(2, f);

    f.setName("8");
    tree.insert(8, f);

    f.setName("6");
    tree.insert(6, f);

    f.setName("0");
    tree.insert(0, f);

    f.setName("4");
    tree.insert(4, f);
}

unittest
{
    bool found_element;
    auto number_tree = makeBTreeMap!(int, int, 2);

    for (int i = -1; i < 9; i++)
    {
        number_tree.insert(i, i);
    }

    // find "random" element
    int i = 3;
    auto xres = number_tree.get(i, found_element);
    number_tree.remove(i);
    number_tree.get(i, found_element);
    test!("==")(found_element, false);

    i = 7;
    number_tree.remove(i);
    number_tree.get(i, found_element);
    test!("==")(found_element, false);

    i = 9;
    number_tree.remove(i);

    i = 0;
    number_tree.remove(i);

    i = 1;
    number_tree.remove(i);

    i = 2;
    number_tree.remove(i);

    for (i = 0; i < 9; i++)
    {
        number_tree.remove(i);
        number_tree.get(i, found_element);
        test!("==")(found_element, false);
    }

    for (i = 0; i < 9; i++)
    {
        number_tree.insert(i, i);
    }

    for (i = 9; i > 0; i--)
    {
        number_tree.remove(i);
        number_tree.get(i, found_element);
        test!("==")(found_element, false);
    }

    i = 0;
    number_tree.insert(i, i);
    i = 1;
    number_tree.insert(i, i);
    i = 2;
    number_tree.insert(i, i);

    for (i = 0; i < 100000; i++)
    {
        number_tree.insert(i, i);
    }

    i = 0;
    number_tree.remove(i);

    i = 1;
    number_tree.remove(i);

    i = 2;
    number_tree.remove(i);

    for (i = 0; i < 100000; i++)
    {
        number_tree.remove(i);
        number_tree.get(i, found_element);
        test!("==")(found_element, false);
    }

    // remove reverse
    for (i = 0; i < 100000; i++)
    {
        number_tree.insert(i, i);
    }

    for (i = 100000; i >= 0; i--)
    {
        number_tree.remove(i);
        number_tree.get(i, found_element);
        test!("==")(found_element, false);
    }

    // remove reverse from half
    for (i = 0; i < 100000; i++)
    {
        number_tree.insert(i, i);
    }


    for (i = 5000; i >= 0; i--)
    {
        number_tree.remove(i);
        number_tree.get(i, found_element);
        test!("==")(found_element, false);
    }


    // random deletion
    for (i = 0; i < 5000; i++)
    {
        number_tree.insert(i, i);
    }

    bool started;
    int previous_value;
    int counter;
    foreach (value; number_tree)
    {
        counter++;

        if (!started)
        {
            previous_value = value;
            started = true;
            continue;
        }

        test!("<")(previous_value, value);
        previous_value = value;
    }
    test!("==")(counter, 100000);

    foreach (key, value; number_tree)
    {
        test!("==")(key, value);
    }

    // Randomized tests

    auto random = new Random();
    int to_remove = 5864;
    number_tree.remove(to_remove);
    test(!number_tree.get(to_remove, found_element));

    for (i = 0; i < 100000; i++)
    {
        to_remove = random.uniform!(int);
        number_tree.remove(to_remove);
        test(!number_tree.get(to_remove, found_element));
    }
}

unittest
{
    class X
    {
        int x;

        version (D_Version2)
        {
            mixin("immutable this () {}");
        }
    }

    // Test immutable support
    auto const_tree = makeBTreeMap!(void*, Const!(X), 2);

    version (D_Version2)
    {
        mixin("Immut!(X) a = new immutable X;");
    }
    else
    {
        Immut!(X) a = new X;
    }

    const_tree.insert(cast(void*)&a, a);
    bool found;
    auto res = const_tree.get(cast(void*)&a, found);
    test(found);
    test(res == a);
    test(const_tree.remove(cast(void*)&a));
}

version (UnitTest)
{
    import ocean.core.Test;
    import ocean.core.Enforce;
    import ocean.math.random.Random;

    /// File structure - represents a directory or a file
    /// For testing if the BTreeMap works with other value types
    public struct File
    {
        /// Name of the directory/file
        char[48] name_buf;
        ubyte name_length;

        cstring name () const
        {
            return name_buf[0..name_length];
        }

        void setName (cstring name)
        {
            //logger.error("setting name: {}", name);
            enforce (name.length <= ubyte.max);
            (&this).name_length = cast(ubyte)name.length;
            (&this).name_buf[0..(&this).name_length] = name[];
        }
   }
}
