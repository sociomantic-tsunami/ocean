/*******************************************************************************

    Cache base class, implements the cache logic that is not related to values.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.cache.model.ICache;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.cache.model.ICacheInfo;

import ocean.util.container.cache.model.containers.TimeToIndex;
import ocean.util.container.cache.model.containers.KeyToNode;

import core.stdc.time: time_t, time;

/******************************************************************************/

abstract class ICache : ICacheInfo
{
    /***************************************************************************

        Alias required by the subclasses.

    ***************************************************************************/

    protected alias .TimeToIndex TimeToIndex;

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

    protected TimeToIndex time_to_index;


    /***************************************************************************

        Mapping from key to TimeToIndex.Mapping struct (which contains a mapping
        from an access time to the index of an elements in this.items).

    ***************************************************************************/

    protected KeyToNode key_to_node;


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

    protected this ( size_t max_items )
    {
        this.insert = 0;

        this.max_items     = max_items;
        this.time_to_index = new TimeToIndex(max_items);
        this.key_to_node   = new KeyToNode(max_items);
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
        }
    }

    /***************************************************************************

        Removes all items from the cache.

    ***************************************************************************/

    public void clear ( )
    {
        this.time_to_index.clear();
        this.key_to_node.clear();
        this.insert = 0;
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

        Checks whether an item exists in the cache.

        Params:
            key = key to lookup

        Returns:
            true if item exists in cache

    ***************************************************************************/

    public bool exists ( hash_t key )
    {
        return (key in this) !is null;
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
        TimeToIndex.Node** node = key in this;

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

        Checks whether an item exists in the cache and returns the last time it
        was accessed.

        Params:
            key = key to lookup

        Returns:
            item's last access time, or 0 if the item doesn't exist

    ***************************************************************************/

    public time_t accessTime ( hash_t key )
    {
        TimeToIndex.Node** node = key in this;

        return node? (*node).key.hi : 0;
    }

    /***************************************************************************

        Obtains the index of the cache item that corresponds to node and updates
        the access time.
        If realtime is enabled, access_time is expected to be equal to or
        greater than the time stored in node. If disabled and the access time is
        less, the node will not be updated and a value of at least length
        returned.


        Params:
            node        = time-to-index tree node
            access_time = access time

        Returns:
            the index of the corresponding cache item or a value of at least
            length if realtime is disabled and the access time is less than the
            access time in the node.

        Out:
            If realtime is enabled, the returned index is less than length.

    ***************************************************************************/

    protected size_t accessIndex ( ref TimeToIndex.Node node, out time_t access_time )
    out (index)
    {
        assert (index < this.insert, "cache index out of bounds");
    }
    body
    {
        TimeToIndex.Key key = node.key;

        access_time = key.hi = this.now;

        this.time_to_index.update(node, key);

        return key.lo;
    }

    /***************************************************************************

        Obtains the current time. By default this is the wall clock time in
        seconds.
        This time value is used to find the least recently updated cache item
        and stored as create time. A subclass may override this method to use a
        different time unit or clock.


        Returns:
            the current time in seconds.

    ***************************************************************************/

    protected time_t now ( )
    {
        return .time(null);
    }

    /***************************************************************************

        Obtains the index of the cache item that corresponds to key and updates
        the access time.
        If realtime is enabled and key could be found, access_time is expected
        to be at least the time value stored in node. If disabled and
        access_time is less, the result is the same as if key could not be
        found.


        Params:
            key         = time-to-index tree key
            access_time = access time

        Returns:
            the index of the corresponding cache item or a value of at least
            this.length if key could not be found.

    ***************************************************************************/

    protected size_t get_ ( hash_t key, out time_t access_time )
    {
        TimeToIndex.Node** node = key in this;

        return node? this.accessIndex(**node, access_time) : size_t.max;
    }

    /***************************************************************************

        Obtains the time-to-index node for key.

        Params:
            key = key to lookup

        Returns:
            pointer to the time-to-index node for key or null if not found.

        Out:
            If found, it is safe to dereference the pointer to which the
            returned pointer points (*node is not null).

    ***************************************************************************/

    protected TimeToIndex.Node** opIn_r ( hash_t key )
    out (node)
    {
        if (node) assert (*node !is null, "null pointer value was stored in key_to_node");
    }
    body
    {
        TimeToIndex.Node** node = key in this.key_to_node;

        this.n_lookups++;
        this.n_misses += (node is null);

        return node;
    }

    /***************************************************************************

        Registers a new cache element and obtains the cache item index for it.
        If the cache is full, the oldest cache element is replaced.
        If realtime is enabled, time is expected to be at least the time value
        of the most recent cache element.
        If realtime is disabled and time is less than the time value of the most
        recent cache element, nothing is done and a value of at least length is
        returned.

        Params:
            key  = cache element key
            access_time = cache element creation time

        Returns:
            the index of the cache item that corresponds to the newly registered
            cache element or a value of at least length if realtime is disabled
            and time is less than the time value of the most recent cache
            element.

        In:
            If realtime is enabled, time must bebe at least the time value of
            the most recent cache element.

        Out:
            If realtime is enabled, the returned index is below length.

    ***************************************************************************/

    protected size_t register ( hash_t key, out time_t access_time )
    out (index)
    {
        assert (index < this.max_length);
    }
    body
    {
        size_t index;

        access_time = this.now;

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

                if (access_time < hi)
                {
                    this.whenEarlierThanOldestItem(access_time, hi);
                }
            }

            // Call the notifier method before actual removal
            this.whenCacheItemDropped(index);

            // Remove old item in tree map
            this.time_to_index.remove(*oldest_time_node);

            this.key_to_node.remove(this.keyByIndex(index));
        }


        *this.key_to_node.put(key) = this.time_to_index.add(TimeToIndex.Key(index, access_time));


        return index;
    }

    /***************************************************************************

        Called when the time value returned by now() is less than the time of
        last access of the oldest record in the cache; may be overridden by a
        subclass to be notified if this happens.
        With the system time as external data source this can theoretically
        happen and is at least not a program bug so in this class assert() would
        be inappropriate.

        Params:
            now    = time value reported by now()
            oldest = last access time of the oldest record in the cache

    ***************************************************************************/

    protected void whenEarlierThanOldestItem ( time_t now, time_t oldest ) { }

    /***************************************************************************

        Called when the oldest item is replaced in cache with a new one
        because cache is full.
        When the cache gets full, the oldest item will be replaced with the
        new value. Before that happens, this method will be called, having
        the item index passed as a argument.

        Params:
            index = index of the cache item that will be dropped.

    ***************************************************************************/

    protected void whenCacheItemDropped ( size_t index ) { }

    /***************************************************************************

        Obtains the key of the cache item corresponding to index.

        Params:
            index = cache item index, guaranteed to be below length

        Returns:
            cache item key

    ***************************************************************************/

    abstract protected hash_t keyByIndex ( size_t index );

    /***************************************************************************

        Removes the cache item that corresponds to dst_key and dst_node.

        Params:
            dst_key  = key of item to remove
            dst_node = time-to-index tree node to remove

    ***************************************************************************/

    protected void remove_ ( hash_t dst_key, ref TimeToIndex.Node dst_node )
    {
        /*
         * Remove item in items list by copying the last item to the item to
         * remove and decrementing the insert index which reflects the
         * actual number of items.
         */

        this.insert--;

        size_t index = dst_node.key.lo;

        // Remove the tree map entry of the removed cache item.
        this.time_to_index.remove(dst_node);

        // Remove key -> item mapping
        this.key_to_node.remove(dst_key);

        if ( index != this.insert )
        {
            hash_t src_key = this.replaceRemovedItem(index, this.insert);

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
    }

    /***************************************************************************

        Called when a cache element is removed, replaces the cache items at
        index "replaced"" with the one at index "replace".

        The "replace" and "replaced" indices are guaranteed to be different and
        valid cache item indices, i.e. less than this.length.

        When this method has returned, the cache item at index "replace" won't
        be used until a new cache element is added; a subclass is free to do
        with it as it pleases but should be aware that it will be reused later
        on.

        Params:
            replaced = index of the cache item that is to be replaced
            replace  = index of the cache item that will replace the replaced
                       item

        Returns:
            the key of the cache item that was at index "replace"" before and is
            at index "replaced" now.

    ***************************************************************************/

    protected hash_t replaceRemovedItem ( size_t replaced, size_t replace );
}
