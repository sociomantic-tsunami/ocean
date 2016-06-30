/*******************************************************************************

    A priority cache which stores a limited amount of items defined at the
    instantiation tine of the class. When the cache is full and a new object is
    added the item with the least priority gets dropped.


    To create a new cache class you have to specify the maximum of items that
    can be stored:
    ---

        const NUM_ITEM = 10;
        auto cache = new PriorityCache!(char[])(NUM_ITEM);

    ---

    To store an item in the cache you should use 'getOrCreate()` method.
    The method takes a key and a priority value, if the key already exists then
    the item associated with the key is returned, if it didn't exist then the
    class will attempt to create to create a new key with the given priority:
    ---

        auto key = 1;
        ulong priority = 20;
        bool item_existed_before;
        char[]* item = cache.getOrCreate(key, priority, item_existed_before);

        if (item)
        {
            *item = "ABC";
        }
        assert(item_existed_before is false);

    ---

    Notice that if the item already existed then the priority won't be used
    (but you still can assign the item to a new value) .
    ---

        ulong no_effect_priority = 70;
        item = cache.getOrCreate(key, no_effect_priority, item_existed_before);

        if (item)
        {
            *item = "DEF";
        }
        assert(item_existed_before is true);

        ulong retrieved_priority;
        item = cache.getPriority(key, retrieved_priority);
        assert(item !is null);
        assert(*item == "DEF");
        assert(retrieved_priority == priority); // Not no_effect_priority

    ---

    Notice that in all the previous example we have always to check if item is
    not null (even though we call `getOrCreate()`), if you are using this class
    directory then there should be no need to check for null as always a new
    item will be created. If you are using a class which inherits this class
    then the subclass might override the `whenNewAndLeastPriority()` method.
    This method decides which item to keep if the cache is full and the a newly
    added item has a lower priority than the existing item in the cache with the
    least priority. If the method decided to keep the current item and not t
    add the new one then the `getOrCreate()` method will return null as no item
    was found or created.

    A useful method to be used when the user wants to store an item with a given
    priority regardless of whether the item is a new item or already existing
    one but with a different priority is to use `getUpdateOrCreate()` method:
    ---

        auto new_priority = 10;
        item = cache.getUpdateOrCreate(key, new_priority, item_existed_before);

        cache.getPriority(key, retrieved_priority);
        assert(item_existed_before is true);
        assert(item !is null);
        assert(retrieved_priority == new_priority);
    ---

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.cache.PriorityCache;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.cache.model.ICacheInfo;

import ocean.util.container.cache.model.containers.TimeToIndex;
import ocean.util.container.cache.model.containers.KeyToNode;

import core.memory;
import ocean.stdc.time: time_t, time;

/*******************************************************************************

    Stores a maximum number of items keeping only items with the highest
    priority.

*******************************************************************************/

class PriorityCache(T) : ICacheInfo
{
    /***************************************************************************

        A wrapper around the stored item

    ***************************************************************************/

    protected struct CacheItem
    {
        /***********************************************************************

            The object itself to be stored in the cache

        ***********************************************************************/

        T value;

        /***********************************************************************

            The item's key.
            Used to retrieve the nodes when two items are swapped to update the
            nodes with the new indices.

        ***********************************************************************/

        hash_t key;
    }

    /***************************************************************************

        Insert position into array of items.

    ***************************************************************************/

    private size_t insert;

    /***************************************************************************

        Mapping from access time to the index of an item in the items array. The
        map is implemented with an EBTree, so that it is sorted in order of
        access times.

        The time-to-index mapping records are stored in time_to_index as
        so-called EBTree "nodes" of type TimeToIndex.Node. Each node contains a
        so-called "key" of type TimeToIndex.Key which consists of two uint
        values, "lo" and "hi".
        The sort order is ascending by "hi"; records with the same "hi" value
        are sorted by "lo". Therefore, since the time-to-index mapping records
        should be sorted by access time, time and cache index are stored as

            TimeToIndex.Key.hi = access time,
            TimeToIndex.Key.lo = cache index.

    ***************************************************************************/

    private TimeToIndex time_to_index;

    /***************************************************************************

        Mapping from key to TimeToIndex.Mapping struct (which contains a mapping
        from an access time to the index of an elements in this.items).

    ***************************************************************************/

    private KeyToNode key_to_node;

    /***************************************************************************

        Array of cached items.

    ***************************************************************************/

    private CacheItem[] items;

    /***************************************************************************

        Maximum number of items in the cache.

    ***************************************************************************/

    private size_t max_items;

    /***************************************************************************

        Counters for the cache lookups and misses.

    ***************************************************************************/

    protected uint n_lookups = 0,
                   n_misses  = 0;


    /***************************************************************************

        Constructor.

        Params:
            max_items = maximum number of items in the cache, set once, cannot
                be changed

    ***************************************************************************/

    public this ( size_t max_items)
    {
        this.insert = 0;

        this.max_items     = max_items;
        this.time_to_index = new TimeToIndex(max_items);
        this.key_to_node   = new KeyToNode(max_items);
        this.items = new CacheItem[max_items];
    }

    /***************************************************************************

        Obtains the item that corresponds a key. Returns null if the key doesn't
        exist.

        Params:
            key = the item key
            track_misses = flags whether not finding the item should count as
                a cache miss

        Returns:
            the corresponding cache item or null if the key didn't exist.

    ***************************************************************************/

    public T* get(hash_t key, bool track_misses = true)
    {
        if (TimeToIndex.Node** node = this.getNode(key, track_misses))
        {
            return &this.items[this.getNodeIndex(**node)].value;
        }
        else
            return null;
    }


    /***************************************************************************

        Get an item with a given key if it already existed or creates a new item
        with the given priority if it didn't exist.

        Beware that in case an item didn't exist it is still possible that a new
        item will NOT be created if whenNewAndLeastPriority() implementation
        prefers the already existing item over the new one. The default
        implementation of whenNewAndLeastPriority() always creates a new one.

        Params:
            key = item's key
            priority = the priority to update to assign to the new item if no
                item already exists
            existed = will be assigned to true if the item already existed and
                wasn't created
            tracK_get_miss = flags whether not finding the item should count as
                a cache miss

        Returns:
            The existing or created item or null if no item was found or
            created.

    ***************************************************************************/

    public T* getOrCreate (hash_t key, lazy ulong priority, out bool existed, bool tracK_get_miss = true)
    {
        T* item = this.get(key, tracK_get_miss);
        existed = item !is null;
        return item ? item : this.create(key, priority);
    }

    /***************************************************************************

        Updates the priority of an item if it already existed or creates a new
        item with the given priority if it didn't exist.

        Beware that in case an item didn't exist it is still possible that a new
        item will NOT be created if whenNewAndLeastPriority() implementation
        prefers the already existing item over the new one. The default
        implementation of whenNewAndLeastPriority() always creates a new one.

        Params:
            key = item's key
            priority = the priority to update for the existing item or to assign
                to the new item
            existed = will be assigned to true if the item already existed and
                wasn't created
            tracK_get_miss = flags whether not finding the item should count as
                a cache miss

        Returns:
            The existing or created item or null if no item was found or
            created.

        Out:
            if the item existed then the pointer is not null

    ***************************************************************************/

    public T* getUpdateOrCreate (hash_t key, ulong priority, out bool existed, bool tracK_get_miss = true)
    out (val)
    {
        if (existed)
        {
            assert(val !is null, "Null return value although item exists");
        }
    }
    body
    {
        T* item = this.updatePriority(key, priority, tracK_get_miss);
        existed = item !is null;
        return item ? item : this.create(key, priority);
    }

    /***************************************************************************

        Updates an existing item's priority.

        Params:
            key = item's key
            new_priority = node's new priority
            tracK_get_miss = flags whether not finding the item should count as
                a cache miss

        Returns:
            A pointer to the item that was updated or null if the key didn't
            exist.

    ***************************************************************************/

    public T* updatePriority(hash_t key, lazy ulong new_priority, bool tracK_get_miss = true)
    {
        if (TimeToIndex.Node** node = this.getNode(key, tracK_get_miss))
        {
            auto new_index = this.updatePriority(**node, new_priority);
            return &this.items[new_index].value;
        }
        else
            return null;
    }

    /***************************************************************************

        Retrieves an item's priority if it exists.

        Params:
            key = the key to look up
            priority = the variable that will be assigned the item's priority,
                the variable contain unknown value if the item doesn't exist

        Returns:
            Returns an pointer to the updated item or null if it didn't exist

    ***************************************************************************/

    public T* getPriority (hash_t key, out ulong priority)
    {
        if (TimeToIndex.Node** node = this.getNode(key))
        {
            priority = this.getNodePriority(**node);
            return &this.items[this.getNodeIndex(**node)].value;
        }
        else
            return null;
    }

    /***************************************************************************

        Checks whether an item exists in the cache.

        Params:
            key = key to lookup

        Returns:
            true if item exists in cache

    ***************************************************************************/

    public bool exists ( hash_t key )
    {
        return this.getNode(key) !is null;
    }

    /***************************************************************************

        Removes an item from the cache.

        Params:
            key = key of item to remove

        Returns:
            returns true if removed, false if not in cache

    ***************************************************************************/

    public bool remove ( hash_t key )
    {
        TimeToIndex.Node** node = this.getNode(key);
        if (node)
        {
            this.remove_(key, **node);
            return true;
        }
        else
        {
            return false;
        }
    }

    /***************************************************************************

        Returns the item with highest priority.

        Params:
            key = set to the key of highest priority item
            priority = set to the priority of the highest priority item

        Returns:
            returns a pointer to the highest priority item or null if the cache
            is empty

    ***************************************************************************/

    public T* getHighestPriorityItem ( out hash_t key, out ulong priority )
    {
        if ( !this.length )
            return null;

        auto highest_node = this.time_to_index.last;
        priority = this.getNodePriority(*highest_node);
        auto item = &this.items[this.getNodeIndex(*highest_node)];
        key = item.key;
        return &item.value;
    }

    /***************************************************************************

        Returns the item with lowest priority.

        Params:
            key = set to the key of lowest priority item
            priority = set to the priority of the lowest priority item

        Returns:
            returns a pointer to the lowest priority item or null if the cache
            is empty

    ***************************************************************************/

    public T* getLowestPriorityItem ( out hash_t key, out ulong priority )
    {
        if ( !this.length )
            return null;

        auto lowest_node = this.time_to_index.first;
        priority = this.getNodePriority(*lowest_node);
        auto item = &this.items[this.getNodeIndex(*lowest_node)];
        key = item.key;
        return &item.value;
    }

    /***************************************************************************

        The signature for the delegate to be used in a foreach loop:

            foreach(hash_t key, ref T item, ulong item_priority; cache)
            {
                // You can change the value of item if it was ref
                item = new_value;
            }

        Params:
            key = the item key, cannot be changed (even if passed by ref)
            item = the stored item, can be changed if passed by ref
            priority = the item's priority, cannot be changed (even if
                passed by ref)

        Returns:
            the return value of a foreach delegate

    ***************************************************************************/

    public alias int delegate (ref hash_t key, ref T item, ref ulong priority) ForeachDg;

    /***************************************************************************

        A foreach-iterator for iterating over the items in the tree.

        The items are passed in a descending order of priority (highest priority
        first followed by lower priority).

        Parmas:
            dg = the foreach delegate

        Returns:
            If dg returns a nonzero value then the method return that value,
            returns zero otherwise

    ***************************************************************************/

    public int opApply ( ForeachDg dg )
    {
        int ret = 0;

        scope iterator = this.time_to_index.new Iterator;

        foreach_reverse (ref node; iterator)
        {
            auto node_item_index = this.getNodeIndex(node);
            CacheItem* cache_item =  &this.items[node_item_index];

            auto key = cache_item.key; // Copy it so it can't be changed by ref
            auto priority = this.getNodePriority(node);
            ret = dg(key, cache_item.value, priority);
            if (ret)
                break;
        }

        return ret;
    }

    /***************************************************************************

        A foreach-iterator for iterating over the items in the tree.

        The items are passed in a ascending order of priority (lowest priority
        first followed by higher priority).

        Parmas:
            dg = the foreach delegate

        Returns:
            If dg returns a nonzero value then the method return that value,
            returns zero otherwise

    ***************************************************************************/

    public int opApplyReverse ( ForeachDg dg )
    {
        int ret = 0;

        scope iterator = this.time_to_index.new Iterator;

        foreach (ref node; iterator)
        {
            auto node_item_index = this.getNodeIndex(node);
            CacheItem* cache_item =  &this.items[node_item_index];

            auto key = cache_item.key; // Copy it so it can't be changed by ref
            auto priority = this.getNodePriority(node);
            ret = dg(key, cache_item.value, priority);
            if (ret)
                break;
        }

        return ret;
    }


    /***************************************************************************

        Removes all items from the cache.

    ***************************************************************************/

    public void clear ( )
    {
        this.time_to_index.clear();
        this.key_to_node.clearErase();
        this.insert = 0;
        this.items[] = this.items[0].init;
    }

    /***************************************************************************

        Returns:
            the number of items currently in the cache.

    ***************************************************************************/

    public size_t length ( )
    {
        return this.insert;
    }

    /***************************************************************************

        Returns:
            the maximum number of items the cache can have.

    ***************************************************************************/

    public size_t max_length ( )
    {
        return this.max_items;
    }

    /***************************************************************************

        Returns:
            the number of cache lookups since instantiation or the last call of
            resetStats().

    ***************************************************************************/

    public uint num_lookups ( )
    {
        return this.n_lookups;
    }

    /***************************************************************************

        Returns:
            the number of cache lookups since instantiation or the last call of
            resetStats().

    ***************************************************************************/

    public uint num_misses ( )
    {
        return this.n_misses;
    }

    /***************************************************************************

        Resets the statistics counter values.

    ***************************************************************************/

    public void resetStats ( )
    {
        this.n_lookups = this.n_misses = 0;
    }

    /***************************************************************************

        A notifier which is fired and an item is removed from the cache.

        The notifier is called after the item has already been removed.
        The default implementation of the notifier inits the value of the item
        to remove any references to it.

        When overriding this method, make sure this cache is not manipulated
        while this method is executing (i.e. don't add or remove items) so make
        sure that:
        - neither the overriding method nor a callee manipulates this cache and
        - if using fibers which can be suspended while this method is running,
        that this cache cannot be manipulated by another fiber in this case.

        Params:
            key = the key of the dropped item
            value = the dropped item

    ***************************************************************************/

    protected void itemDropped (hash_t key, ref T value)
    {
        value = value.init;
    }

    /***************************************************************************

        Called by attemptCreateNode() when the cache is full and the new item
        to be added has a lower priority than the already existing lowest
        priority item. The method decides which of the two items should be
        stored.

        This implementation favors the new element over the existing element.
        The user can override this method to implement a different behavior.

        Params:
            new_item_lowest_priority = the priority of new item to be added
            current_lowest_priority = the priority of the lowest existing
                item

        Returns:
            true if the new item with lower priority should replace the current
            existing lowest priority item, false otherwise.

    ***************************************************************************/

    protected bool whenNewAndLeastPriority ( ulong new_item_lowest_priority,
                                             ulong current_lowest_priority )
    {
        return true;
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

            delete this.key_to_node;
            delete this.time_to_index;
            delete this.items;
        }
    }

    /***************************************************************************

        Creates a new item with the given priority.
        The key must be not existing in the cache or else an unexpected behavior
        can occur.

        Params:
            key = the key to create
            priority = the priority to assign to the key

        Returns:
            The item that was created or null if the item wasn't added.

    ***************************************************************************/

    private T* create ( hash_t key, ulong priority )
    body
    {
        bool item_added;
        auto index = this.attemptCreateNode(key, priority, item_added);

        if (item_added)
        {
            return &this.items[index].value;
        }
        else
            return null;
    }

    /***************************************************************************

        Return the priority of an item.

        Params:
            node = node to lookup

        Returns:
            item's priority

    ***************************************************************************/

    private ulong getNodePriority ( ref TimeToIndex.Node node )
    {
        return node.key.hi;
    }

    /***************************************************************************

        Return the index of an item.

        Params:
            node = node to lookup

        Returns:
            item's priority

    ***************************************************************************/

    private size_t getNodeIndex ( TimeToIndex.Node node )
    {
        return node.key.lo;
    }

    /***************************************************************************

        Updates an item's priority and returns the new index of the in the tree.

        Params:
            node = time-to-index tree node
            new_priority = node's new priority

        Returns:
            the new index of the corresponding cache item.

        Out:
            the returned index is less than length.

    ***************************************************************************/

    private size_t updatePriority(ref TimeToIndex.Node node, ulong new_priority)
    out (index)
    {
        assert(&node, "ref argument is a dereferenced null pointer");
        assert (index < this.insert, "cache index out of bounds");
    }
    body
    {
        TimeToIndex.Key node_key = node.key;

        // A call to update() cause a remove() then an add(), so skip it if no
        // change in priority
        if (node_key.hi != new_priority)
        {
            node_key.hi = new_priority;
            this.time_to_index.update(node, node_key);
        }

        return node_key.lo;
    }

    /***************************************************************************

        Obtains the time-to-index node for key.

        Params:
            key = key to lookup

        Returns:
            pointer to the time-to-index node for key or null if not found.
            track_misses = flags whether not finding the item should count as
                a cache miss

        Out:
            If found, it is safe to dereference the pointer to which the
            returned pointer points (*node is not null).

    ***************************************************************************/

    private TimeToIndex.Node** getNode (hash_t key, bool track_misses = true)
    out (node)
    {
        if (node) assert (*node !is null, "null pointer value was stored in key_to_node");
    }
    body
    {
        TimeToIndex.Node** node = key in this.key_to_node;
        if (track_misses)
        {
            this.n_lookups++;
            this.n_misses += (node is null);
        }
        return node;
    }

    /***************************************************************************

        Registers a new cache item and obtains the item's index in this.items
        for it.

        If the cache is full and whenEarlierThanOldestItem() returns true, the
        oldest cache element is replaced.

        Params:
            key = item's key
            priority = item's priority
            item_added = set to true if the item was added, false otherwise

        Returns:
            the index that should be used in this.items which corresponds to the
            newly registered item.

        Out:
            the returned index is below length.

    ***************************************************************************/

    private size_t attemptCreateNode (hash_t key, ulong priority, out bool item_added)
    out (index)
    {
        assert (index < this.max_length);

        if (item_added)
        {
            assert(this.items[index].key == key, "keys mismatch");
        }
    }
    body
    {
        size_t index;

        auto is_key_removed = false;
        hash_t removed_key;

        if ( this.insert < this.max_length )
        {
            index = this.insert++;
        }
        else
        {
            // Find the item with lowest (ie oldest) update time.
            TimeToIndex.Node* oldest_time_node = this.time_to_index.first;

            assert (oldest_time_node !is null);

            // Get the item index and check if the time of the last access is
            // less than the current time. If not, notify the subclass because
            // we are about to replace the oldest record with an even older one.

            with (oldest_time_node.key)
            {
                index = lo;

                if (priority < hi)
                {
                    if ( !this.whenNewAndLeastPriority(priority, hi) )
                    {
                        item_added = false;
                        return index;
                    }
                }
            }

            // Call the notifier at the end of the method so that the old key is
            // already removed and the new key is added
            is_key_removed = true;
            removed_key = this.items[index].key;

            // Remove old item in tree map
            this.time_to_index.remove(*oldest_time_node);
            this.key_to_node.remove(removed_key);
        }

        auto node_key = TimeToIndex.Key(index, priority);
        *this.key_to_node.put(key) = this.time_to_index.add(node_key);
        this.items[index].key = key;
        item_added = true;

        if (is_key_removed)
        {
            this.itemDropped(removed_key, this.items[index].value);
        }

        return index;
    }

    /***************************************************************************

        Removes the cache item that corresponds to dst_key and dst_node.

        Params:
            dst_key  = key of item to remove
            dst_node = time-to-index tree node to remove

    ***************************************************************************/

    private void remove_ ( hash_t dst_key, ref TimeToIndex.Node dst_node )
    in
    {
        /*
         * If the caller passes a dereferenced pointer as dst_node the
         * implementation of `ref` function arguments postpones dereferencing
         * this pointer to the places where dst_node is used in this function:
         * ---
         *   hash_t dst_key;
         *   TimeToIndex.Node* dst_node = null;
         *   remove(dst_key, *dst_node); // null isn't deferenced here but when
         *                               // actually used inside remove().
         * ---
         * If that happens &dst_node is `null` in this function.
         */

        assert(&dst_node, "ref argument is a dereferenced null pointer");
    }
    body
    {
        /*
         * Remove item in items list by copying the last item to the item to
         * remove and decrementing the insert index which reflects the
         * actual number of items.
         */

        this.insert--;

        size_t index = this.getNodeIndex(dst_node);

        // Remove the tree map entry of the removed cache item.
        this.time_to_index.remove(dst_node);

        // Remove key -> item mapping
        this.key_to_node.remove(dst_key);

        if ( index != this.insert )
        {
            // Swap the content of the two array items
            CacheItem tmp = this.items[this.insert];
            this.items[this.insert] = this.items[index];
            this.items[index] = tmp;

            hash_t src_key = tmp.key;

            /*
             * Obtain the time-to-mapping entry for the copied cache item.
             * Update it to the new index and update the key-to-mapping
             * entry to the updated time-to-mapping entry.
             */

            TimeToIndex.Node** src_node_in_map = src_key in this.key_to_node;

            assert (src_node_in_map !is null, "Null src_node_in_map found");

            TimeToIndex.Node* src_node = *src_node_in_map;

            assert (src_node !is null, "Null src_node found");

            TimeToIndex.Key src_node_key = src_node.key;

            src_node_key.lo = index;

            *src_node_in_map = this.time_to_index.update(*src_node, src_node_key);
        }

        this.itemDropped(dst_key, this.items[this.insert].value);
    }
}

version (UnitTest) import ocean.core.Test;

// Test documentation example
unittest
{
    auto t = new NamedTest("Documentation example");

    const NUM_ITEM = 10;
    auto cache = new PriorityCache!(char[])(NUM_ITEM);

    auto key = 1;
    ulong priority = 20;
    bool item_existed_before;
    char[]* item = cache.getOrCreate(key, priority, item_existed_before);

    if (item)
    {
        *item = "ABC".dup;
    }
    t.test!("==")(item_existed_before, false);

    ulong no_effect_priority = 70;
    item = cache.getOrCreate(key, no_effect_priority, item_existed_before);

    if (item)
    {
        *item = "DEF".dup;
    }
    t.test!("==")(item_existed_before, true);

    ulong retrieved_priority;
    item = cache.getPriority(key, retrieved_priority);
    t.test!("!is")(item, null);
    t.test!("==")(*item, "DEF");
    t.test!("==")(retrieved_priority, priority); // Not no_effect_priority


    auto new_priority = 10;
    item = cache.getUpdateOrCreate(key, new_priority, item_existed_before);

    cache.getPriority(key, retrieved_priority);
    t.test!("==")(item_existed_before, true);
    t.test!("!is")(item, null);
    t.test!("==")(retrieved_priority, new_priority);
}

// Test adding and removing
unittest
{
    auto t = new NamedTest("Adding and removing items to the cache");

    const NUM_OF_ITEMS = 150;

    auto test_cache = new PriorityCache!(int)(NUM_OF_ITEMS);

    const PRIORITY = 10;
    const VALUE = 50;

    for (int i = 0; i < NUM_OF_ITEMS; i++)
    {
        bool existed;
        auto int_ptr = test_cache.getOrCreate(i, i + PRIORITY, existed);
        t.test!("!is")(int_ptr, null, "unexpectedly item was not created");
        t.test!("==")(existed, false, "item previously existed");
        *int_ptr = i + VALUE;
    }


    foreach(j, value; test_cache.items)
    {
        t.test(test_cache.remove(j), "Removing non-existing item");
    }
}

// Test getting highest and lowest items
unittest
{
    auto t = new NamedTest("Retrieving highest and lowest priority items");

    const NUM_OF_ITEMS = 150;

    auto test_cache = new PriorityCache!(int)(NUM_OF_ITEMS);

    const PRIORITY = 10;
    const VALUE = 50;

    bool existed;
    hash_t key;
    ulong priority;

    // Test that nothing is returned when cache is empty
    t.test!("==")(test_cache.getLowestPriorityItem(key, priority), null);
    t.test!("==")(test_cache.getHighestPriorityItem(key, priority), null);

    // Populate the cache with some items
    for (int i = 0; i < NUM_OF_ITEMS; i++)
    {
        auto int_ptr = test_cache.getOrCreate(i, i + PRIORITY, existed);
        *int_ptr = i + VALUE;
    }

    // Test the cache after items has been added to it
    t.test!("==")(*test_cache.getLowestPriorityItem(key, priority), VALUE);
    t.test!("==")(key, 0);
    t.test!("==")(priority, PRIORITY);

    t.test!("==")(*test_cache.getHighestPriorityItem(key, priority),
                  NUM_OF_ITEMS - 1 + VALUE);
    t.test!("==")(key, NUM_OF_ITEMS - 1);
    t.test!("==")(priority, NUM_OF_ITEMS - 1 + PRIORITY);
}

// Test clearing
unittest
{
    auto t = new NamedTest("Clearing the cache");

    const NUM_OF_ITEMS = 150;

    auto test_cache = new PriorityCache!(int)(NUM_OF_ITEMS);

    const VALUE = 50;
    const PRIORITY = 8;
    const INDEX = 20;

    // Create some items
    for (int i = 0; i < NUM_OF_ITEMS; i++)
    {
        bool existed;
        auto int_ptr = test_cache.getOrCreate(i + INDEX, i + PRIORITY, existed);
        *int_ptr = i + VALUE;
    }

    // After clearing we shouldn't find anything
    test_cache.clear();

    for (int i = 0; i < NUM_OF_ITEMS; i++)
    {
        auto is_removed = test_cache.remove(i + INDEX);
        t.test(!is_removed, "Should fail removing non-existing item");
    }
}

// Test opApply
unittest
{
    auto t = new NamedTest("opApply foreach loops");

    const NUM_OF_ITEMS = 150;

    auto test_cache = new PriorityCache!(int)(NUM_OF_ITEMS);

    const PRIORITY = 10;
    const ORIGINAL_VALUE = 50;
    const NEW_VALUE = 80;

    for (int i = 0; i < NUM_OF_ITEMS; i++)
    {
        bool existed;
        auto int_ptr = test_cache.getOrCreate(i, i + PRIORITY, existed);
        *int_ptr = i + ORIGINAL_VALUE;
    }

    int counter = NUM_OF_ITEMS;
    foreach (key, ref item, ulong priority; test_cache)
    {
        counter--;
        t.test!("==")(key, counter, "Unexpected key");
        t.test!("==")(priority, counter + PRIORITY, "Unexpected item priority");
        item = counter + NEW_VALUE;
    }

    // Confirm that the new assigned values weren't lost
    for (int i = 0; i < NUM_OF_ITEMS; i++)
    {
        auto int_ptr = test_cache.get(i);
        t.test(int_ptr, "item unexpectedly null");
        t.test!("==")(*int_ptr, i + NEW_VALUE, "Unexpected item value");
    }

    foreach_reverse (key, ref item, ulong priority; test_cache)
    {
        t.test!("==")(key, counter, "Unexpected key");
        t.test!("==")(priority, counter + PRIORITY, "Unexpected item priority");
        item = counter - NEW_VALUE;
        counter++;
    }

    // Confirm that the new assigned values weren't lost
    for (int i = 0; i < NUM_OF_ITEMS; i++)
    {
        auto int_ptr = test_cache.get(i);
        t.test(int_ptr, "item unexpectedly null");
        t.test!("==")(*int_ptr, i - NEW_VALUE, "Unexpected item value");
    }
}


// Test dropped items are correctly reported
unittest
{
    auto t = new NamedTest("Dropped items are correctly reported");

    const CACHE_SIZE = 10;
    const ITEMS_INSERTED = 150;

    uint items_removed_count;

    class PriorityNotify : PriorityCache!(uint)
    {
        public this (size_t max_items)
        {
            super(max_items);
        }

        protected override void itemDropped (hash_t key, ref uint value)
        {
            t.test!("==")(key, value, "Wrong key/value are reported");
            items_removed_count++;
        }
    }

    auto test_cache = new PriorityNotify(CACHE_SIZE);
    for (uint i = 0; i < ITEMS_INSERTED; i++)
    {
        bool existed;
        auto int_ptr = test_cache.getOrCreate(i, i, existed);
        *int_ptr = i;
    }

    t.test!("==")(items_removed_count, ITEMS_INSERTED - CACHE_SIZE,
                  "Not all dropped items were reported");
}


// Test dropped items are passed by ref
unittest
{
    auto t = new NamedTest("Dropped items are passed by ref to notifier");

    const CACHE_SIZE = 10;
    bool item_dropped = false;

    class PriorityNotify2 : PriorityCache!(uint)
    {
        public this (size_t max_items)
        {
            super(max_items);
        }

        protected override void itemDropped (hash_t key, ref uint value)
        {
            item_dropped = true;
            value = 10;
        }
    }

    auto test_cache = new PriorityNotify2(CACHE_SIZE);
    bool existed;
    auto new_value = test_cache.getOrCreate(20, 20, existed);
    *new_value = 50;
    test_cache.remove(20);

    t.test(item_dropped, "Item was not dropped");
    t.test!("==")(*new_value, 10, "Item was not dropped by ref");
}
