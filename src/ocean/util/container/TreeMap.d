/*******************************************************************************

    EBtree based map.

    By default the map uses plain `eb64_node` nodes.
    To attach values to an ebtree node, create a struct, say, `Node`, whose
    first field is of type `eb64_node`, followed by any number of other fields,
    and pass this struct as the `TreeMap` template parameter.
      - Do not manipulate the first `eb64_node` field (or the plain node if not
        passing an own struct). Reading may be useful as it contains the key.
      - Instances of this struct handed out by `TreeMap` are malloc-allocated so
        they are invisible to the GC.

    We are using an ebtree with malloc-allocated nodes, rather than a hash map,
    because both the number of elements in the map and the number of maps is
    hard to predict, and the overhead of an ebtree is very low compared to a
    hash map.
    In the client request set one map per active all-nodes request is needed,
    and the map contains as many elements as there are nodes. Depending on the
    particular client, the number of nodes differs between 1 and a few hundred.
    The number of active all-nodes requests depends on the clients behaviour:
    Mostly should be around 10 but as much as several thousands are allowed. The
    overhead of a hash map is the whole bucket set array while for an ebtree it
    is only a little struct. In the client connection set there is one map with
    one element per node, but again the number of nodes depends very strongly
    across clients and may change many times during the very long run time of
    the client process.

    Copyright: Copyright (c) 2016-2017 dunnhumby Germany GmbH. All rights reserved

    License:
        Boost Software License Version 1.0. See LICENSE.txt for details.

*******************************************************************************/

module ocean.util.container.TreeMap;

/******************************************************************************/

import ocean.util.container.ebtree.c.eb64tree;
import ocean.util.container.ebtree.c.ebtree;

/*******************************************************************************

    Template params:
        Node = custom struct, the first field must be of type `eb64_node`.
        object_pool_index = set to true to add a `size_t object_pool_index`
                            field.

*******************************************************************************/

struct TreeMap ( Node = eb64_node )
{
    import ocean.transition;

    static if (!is(Node == eb64_node))
    {
        static assert(is(Node == struct));
        static assert(is(typeof(Node.tupleof[0]) == eb64_node));
        static assert(!Node.tupleof[0].offsetof);
    }

    /***************************************************************************

        The `malloc` allocator.

    ***************************************************************************/

    private static Allocator allocator;

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

        It is possible to have an interface that gets only user elements passed,
        not `eb64_node*` ebtree nodes. To use it, define the node item struct as
        follows:
         - Add a user element of some aggregate reference type (class or struct
           pointer) to the node item struct and name it
           `user_element_with_treemap_backlink`.
         - To that class or struct add a public pointer to the node item struct
           and name it `treemap_backlink`.

        Example:
        ---
            class MyClass
            {
                struct MyTreeMapElement
                {
                    eb64_node ebnode; // mandatory
                    MyClass user_element_with_treemap_backlink;
                }

                public MyTreeMapElement* treemap_backlink;
            }


            TreeMap!(MyTreeMapElement) map;

            bool added;
            MyClass obj  = map.put(12345, added, new MyClass);
            MyClass obj2 = map.getUserElement(12345);
            map.remove(obj);
        ---

    ***************************************************************************/

    static if (is(typeof(Node.user_element_with_treemap_backlink) UserElement))
    {
        import ocean.core.Traits: isReferenceType;
        static assert(isReferenceType!(UserElement));

        /***********************************************************************

            Adds a new node to the map for key, storing new_element in it, or
            obtains the user element of an existing one if already in the map.

            Params:
                key   = the key to add a new node for or obtain the existing one
                added = outputs true a new node was added or false if key was
                        found in the map so that the user element existing node
                        is returned
                new_element = the user element to place in the node if adding,
                        evaluated once if adding a new node

            Returns:
                the user item from the node associated with key. If added is
                true then it is new_element, otherwise it is the user eleme of
                an already existing node in the tree.

        ***********************************************************************/

        public UserElement put ( ulong key, out bool added, lazy UserElement new_element )
        {
            auto node = (&this).put_(key, added);

            if (added)
            {
                auto user_element = new_element;
                assert(user_element !is null);
                assert(user_element.treemap_backlink is null);
                user_element.treemap_backlink = node;
                node.user_element_with_treemap_backlink = user_element;
                return user_element;
            }
            else
            {
                auto user_element = node.user_element_with_treemap_backlink;
                assert(user_element.treemap_backlink is node);
                return user_element;
            }
        }

        /***********************************************************************

            Looks up the node for key in the map and returns its user element if
            found.

            Params:
                key = the key to look up the node for

            Returns:
                the user element from the node associated with key or null if
                not found.

        ***********************************************************************/

        public UserElement opIn_r ( ulong key )
        {
            return nodeToUserElement(cast(Node*)eb64_lookup(&(&this).root, key));
        }

         /**********************************************************************

            Looks up the node in the map whose key is equal to or next to `key`,
            and returns its user element if found.

            Template_Params:
                greater = if a node for `key` was not found, return
                           - `true`: the next node with a greater key
                           - `false`: the next node with a lesser key

            Params:
                key = the key to look up the node or next node for

            Returns:
                the user element from the matching node or `null` if no matching
                node was found.

        ***********************************************************************/

        public UserElement getThisOrNext ( bool greater = true ) ( ulong key )
        {
            static if (greater)
                alias eb64_lookup_ge eb64_function;
            else
                alias eb64_lookup_le eb64_function;

            return nodeToUserElement(cast(Node*)eb64_function(&(&this).root, key));
        }

        /***********************************************************************

            Obtains the user element of the first or last node in the map.

            Template_Params:
                first = `true`: obtain the first node,
                        `false`: obtain the last node

            Returns:
                the user element of the matching node or `null` if the map is
                empty.

        ***********************************************************************/

        public UserElement getBoundary ( bool first = true ) ( )
        {
            static if (first)
                alias eb64_first eb64_function;
            else
                alias eb64_last eb64_function;

            return nodeToUserElement(cast(Node*)eb64_function(&(&this).root));
        }

        /***********************************************************************

            Obtains the user element of the node next to the node associated
            with user_element`.

            Template_Params:
                ascend = `true`: use the next node,
                         `false`: use the previous node

            Returns:
                the user element of the next node or `null` if the map is empty.

        ***********************************************************************/

        public static UserElement iterate
            ( bool ascend = true )
            ( UserElement user_element )
        in
        {
            assert(user_element.treemap_backlink !is null);
        }
        body
        {
            static if (ascend)
                return nodeToUserElement(cast(Node*)user_element.treemap_backlink.tupleof[0].next);
            else
                return nodeToUserElement(cast(Node*)user_element.treemap_backlink.tupleof[0].prev);
        }

        /***********************************************************************

            foreach iterator over user elements in the tree. Any tree map
            modification is permitted during iteration.
            There is no need for `ref` iteration because `UserElement` is
            guaranteed to be a reference type.

        ***********************************************************************/

        public int opApply ( scope int delegate ( ref UserElement user_element ) dg )
        {
            int stop = 0;

            for (auto node = eb64_first(&(&this).root); node && !stop;)
            {
                // Backup node.next here because dg() may change or delete node!
                auto next         = node.next,
                     user_element = nodeToUserElement(cast(Node*)node);
                stop = dg(user_element);
                node = next;
            }

            return stop;
        }

        /***********************************************************************

            Removes the node that contains user_element.

            Params:
                user_element = the user element that is in the node to remove

        ***********************************************************************/

        public static void remove ( UserElement user_element )
        in
        {
            assert(user_element.treemap_backlink !is null);
            assert(
                user_element.treemap_backlink.user_element_with_treemap_backlink
                is user_element
            );
        }
        body
        {
            auto node = user_element.treemap_backlink;
            user_element.treemap_backlink = null;
            eb64_delete(&node.tupleof[0]);
            allocator.deallocate(node);
        }

        /***********************************************************************

            Obtains the user element associated with `node`.

            Params:
                node = a tree map node or `null`

            Returns:
                the user element associated with `node` or `null` if `node` is
                `null`.

        ***********************************************************************/

        public static UserElement nodeToUserElement ( Node* node )
        {
            if (node !is null)
            {
                auto user_element = node.user_element_with_treemap_backlink;
                assert(user_element !is null);
                assert(user_element.treemap_backlink is node);
                return user_element;
            }
            else
            {
                return null;
            }
        }
    }
    else
    {
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

        public Node* put ( ulong key, out bool added )
        {
            return (&this).put_(key, added);
        }

        /***********************************************************************

            Looks up the node for key in the map.

            Params:
                key = the key to look up node for

            Returns:
                the node associated with key or null if not found.

        ***********************************************************************/

        public Node* opIn_r ( ulong key )
        {
            return cast(Node*)eb64_lookup(&(&this).root, key);
        }

        /***********************************************************************

            Obtains the first or last node in the map.

            Params:
                first = `true`: obtain the first node,
                        `false`: obtain the last node

            Returns:
                the first or last node or `null` if the map is empty.

        ***********************************************************************/

        public Node* getBoundary ( bool first = true ) ( )
        {
            static if (first)
                alias eb64_first eb64_function;
            else
                alias eb64_last eb64_function;

            return cast(Node*)eb64_function(&(&this).root);
        }

        /***********************************************************************

            foreach iterator over nodes in the tree. Any tree modification is
            permitted during iteration.

        ***********************************************************************/

        public int opApply ( scope int delegate ( ref Node node ) dg )
        {
            int stop = 0;

            for (auto node = eb64_first(&(&this).root); node && !stop;)
            {
                // Backup node.next here because dg() may change or delete node!
                auto next = node.next;
                stop = dg(*cast(Node*)node);
                node = next;
            }

            return stop;
        }


        /***********************************************************************

            Removes node from the map and deallocates it.

            DO NOT USE node from this point!

            Params:
                node = the node to remove

        ***********************************************************************/

        public static void remove ( ref Node node )
        {
            static if (is(Node == eb64_node))
                eb64_delete(&node);
            else
                eb64_delete(&node.tupleof[0]);

            allocator.deallocate(&node);
        }
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

    private struct Allocator
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
