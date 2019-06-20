/*******************************************************************************

    EBtree based map.

    Compared to a standard HashMap, a tree-based map is useful in situations
    where the number of elements in the map is hard to predict. The overhead
    of an ebtree is very low compared to a hash map, as the overhead of a hash
    map is the whole bucket set array, while for an ebtree is only a little
    struct. Additionally, any tree modification is permitted during the
    iteration.

    The map internally allocates internal nodes which contain elements
    using `malloc`, so they are invisible to the GC.

    Copyright: Copyright (c) 2016-2018 dunnhumby Germany GmbH. All rights reserved

    License:
        Boost Software License Version 1.0. See LICENSE.txt for details.

*******************************************************************************/

module ocean.util.container.map.TreeMap;

import ocean.util.container.ebtree.c.eb64tree;
import ocean.util.container.ebtree.c.ebtree;

/*******************************************************************************

    Params:
        T = user value type to store

*******************************************************************************/

struct TreeMap ( T )
{
    import ocean.transition;

    /***************************************************************************

        Internal node structure.

    ***************************************************************************/

    private struct Node
    {
        /***********************************************************************

            Internal ebtree node

        ***********************************************************************/

        eb64_node node;

        /**********************************************************************

            User's value

        **********************************************************************/

        T value;
    }

    /***************************************************************************

        The `malloc` allocator.

    ***************************************************************************/

    private static MallocAllocator allocator;

    /***************************************************************************

        The ebtree root.

    ***************************************************************************/

    private eb_root root = empty_unique_ebtroot;

    /***************************************************************************

        Returns:
            true if the map is empty or false if it contains elements.

    ***************************************************************************/

    public bool is_empty ( ) // const
    {
        return (&this).root.is_empty();
    }

    /***************************************************************************

        Reinitialises the internal tree struct.

        This method should be called only if it is known that the tree is empty,
        otherwise pointers to malloc-allocated nodes are lost so they cannot be
        deallocated.

    ***************************************************************************/

    public void reinit ( )
    {
        (&this).root = eb_root.init;
        (&this).root.unique = true;
    }

    /***************************************************************************

        Adds a new node to the map for key or obtains the existing if already in
        the map.

        Params:
            key   = the key to add a new node for or obtain the existing one
            added = outputs true a new node was added or false if key was found
                    in the map so that the existing node is returned

        Returns:
            the node associated with key. If added is true then it was newly
            created and added, otherwise it is the already existing node in the
            tree.

    ***************************************************************************/

    public T* put ( ulong key, out bool added )
    {
        return &((&this).put_(key, added).value);
    }

    /***********************************************************************

        Looks up the value for key in the map.

        Params:
            key = the key to look up node for

        Returns:
            the value associated with key or null if not found.

    ***********************************************************************/

    private T* opIn_r ( ulong key )
    {
        return &((cast(Node*)eb64_lookup(&(&this).root, key)).value);
    }

    /***********************************************************************

        Obtains the first value in the map.

        Returns:
            the first value or `null` if the map is empty.

    ***********************************************************************/

    public T* first ()
    {
        return (&this).getBoundary!(true)();
    }

    /***********************************************************************

        Obtains the last value in the map.

        Returns:
            the last value or `null` if the map is empty.

    ***********************************************************************/

    public T* last ()
    {
        return (&this).getBoundary!(false)();
    }

    /***********************************************************************

        foreach iterator over nodes in the tree. Any tree modification is
        permitted during iteration.

    ***********************************************************************/

    public int opApply ( scope int delegate ( ref ulong key, ref T* value ) dg )
    {
        int stop = 0;

        for (auto eb_node = eb64_first(&(&this).root); eb_node && !stop;)
        {
            // Backup node.next here because dg() may change or delete node!
            auto next = eb_node.next;
            auto node = cast(Node*)eb_node;
            auto value_ptr = &node.value;
            stop = dg(node.node.key, value_ptr);
            eb_node = next;
        }

        return stop;
    }


    /***********************************************************************

        Removes the element pointed by `key` from the map and deallocates it.

        All pointers tied to this element are no longer valid from this
        point.

        Params:
            key = the key of the  node to remove

        Returns:
            true if the element with the key was found,
            false if not.

    ***********************************************************************/

    public bool remove ( ulong key )
    {
        if (auto node = (&this).nodeForKey(key))
        {
            (&this).remove_(*node);
            return true;
        }
        else
        {
            return false;
        }
    }

    /***********************************************************************

        Removes node from the map and deallocates it.

        DO NOT USE node from this point!

        Params:
            node = the node to remove

    ***********************************************************************/

    private static void remove_ ( ref Node node )
    {
        static if (is(Node == eb64_node))
            eb64_delete(&node);
        else
            eb64_delete(&node.tupleof[0]);

        allocator.deallocate(&node);
    }

    /***********************************************************************

        Obtains the first or last value in the map.

        Params:
            first = `true`: obtain the first node,
                    `false`: obtain the last node

        Returns:
            the first or last value or `null` if the map is empty.

    ***********************************************************************/

    private T* getBoundary ( bool first = true ) ( )
    {
        static if (first)
            alias eb64_first eb64_function;
        else
            alias eb64_last eb64_function;

        return &((cast(Node*)eb64_function(&(&this).root)).value);
    }

    /***********************************************************************

        Looks up the node for key in the map.

        Params:
            key = the key to look up node for

        Returns:
            the node associated with key or null if not found.

    ***********************************************************************/

    private Node* nodeForKey ( ulong key )
    {
        return cast(Node*)eb64_lookup(&(&this).root, key);
    }

    /***************************************************************************

        Adds a new node to the map for key or obtains the existing if already in
        the map.

        Params:
            key   = the key to add a new node for or obtain the existing one
            added = outputs true a new node was added or false if key was found
                    in the map so that the existing node is returned

        Returns:
            the node associated with key. If added is true then it was newly
            created and added, otherwise it is the already existing node in the
            tree.

    ***************************************************************************/

    private Node* put_ ( ulong key, out bool added )
    {
        Node* node = allocator.allocate();

        static if (is(Node == eb64_node))
            alias node ebnode;
        else
            eb64_node* ebnode = &node.tupleof[0];

        ebnode.key = key;
        eb64_node* added_ebnode = eb64_insert(&(&this).root, ebnode);
        added = added_ebnode is ebnode;

        if (!added)
            allocator.deallocate(node);

        return cast(Node*)added_ebnode;
    }

    /***************************************************************************

        `malloc` allocator for `Node`. Deallocating keeps a spare item as an
        optimisation for the frequent situation of allocating an item, then
        noticing it isn't actually needed and freeing it (this happens in
        `put()` when a duplicate is detected).

    ***************************************************************************/

    private struct MallocAllocator
    {
        import core.stdc.stdlib: malloc, free, exit, EXIT_FAILURE;
        import core.stdc.stdio: stderr, fputs;

        /***********************************************************************

            The spare node, set by `deallocate()` and used by `allocate()`.

        ***********************************************************************/

        Node* spare = null;

        /***********************************************************************

            Allocates a new or reuses the spare node. The returned node should
            be deallocated by `deallocate()` when not used any more.

            If `malloc` fails, prints out an error message and terminates the
            process with `EXIT_FAILURE`.

            Returns:
                an initialised node ready to use.

        ***********************************************************************/

        Node* allocate ( )
        {
            if (auto node = (&this).spare)
            {
                (&this).spare = null;
                return node;
            }

            if (auto node = cast(Node*)malloc(Node.sizeof))
            {
                *node = (*node).init;
                return node;
            }
            else
            {
                enum istring msg = "malloc(" ~ Node.sizeof.stringof ~
                                   ") failed: Out of memory\n\0";
                fputs(msg.ptr, stderr);
                exit(EXIT_FAILURE);
                assert(false);
            }
        }

        /***********************************************************************

            Deallocates node or stores it in the spare item.

            Params:
                node = the item to deallocate, previously obtained by
                       `allocate()`

        ***********************************************************************/

        void deallocate ( Node* node )
        {
            if ((&this).spare is null)
            {
                *node = (*node).init;
                (&this).spare = node;
            }
            else
            {
                free(node);
            }
        }
    }
}

version (UnitTest)
{
    import ocean.core.Test;
}

///
unittest
{
    TreeMap!(char[2]) map;

    bool added;
    auto value_ptr = map.put(1, added);
    test!("==")(added, true);

    (*value_ptr)[] = "AA";
    (*map.put(2, added))[] = "AB";
    (*map.put(3, added))[] = "AC";

    foreach (id, value; map)
    {
        switch (id)
        {
            case 1:
                test!("==")((*value)[], "AA");
                break;

            case 2:
                test!("==")((*value)[], "AB");
                break;

            case 3:
                test!("==")((*value)[], "AC");
                break;

            default:
                test(false);
                break;
        }
    }

    map.remove(2);
    foreach (id, value; map)
    {
        switch (id)
        {
            case 1:
                test!("==")((*value)[], "AA");
                break;

            case 3:
                test!("==")((*value)[], "AC");
                break;

            default:
                test(false);
                break;
        }
    }

    test!("==")((*map.first)[], "AA");
    test!("==")((*map.last)[], "AC");
}

/*******************************************************************************

    An empty unique ebtree root.

    The value is generated via CTFE.

*******************************************************************************/

private static immutable eb_root empty_unique_ebtroot =
    function ( )
    {
        eb_root root;
        root.unique = true;
        return root;
    }();
