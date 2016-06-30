/*******************************************************************************

    Map template with a fixed set of keys.

    Map template with a fixed set of keys, specified in the class' constructor.
    If an item is added whose key is not in the fixed set, an exception is
    thrown.

    Such a map can be faster than a standard hash map, as the fixed set of
    possible keys means that a fast binary search can be used to find the index
    of the corresponding value. This of course only holds true when the time
    taken to generate a hash from a key would be slower than the time taken to
    do a binary search over the key. In the case of char[] keys, tests have
    shown that for keys of 5 characters or longer, the FixedKeyMap starts to be
    faster than the StandardKeyHashingMap, and that in the case of long keys
    (100 characters) it is an order of magnitude faster.

    Usage example:

    ---

        import ocean.util.container.FixedKeyMap;

        // Create map instance
        auto map = new FixedKeyMap!(char[], char[])("first", "second", "third");

        // Add and check an entry
        map["first"] = "hello";
        assert(map["first"] == "hello");

        // Example of adding an entry which will be rejected
        try
        {
            map["fifth"] = "should fail";
        }
        catch ( map.FixedKeyMapException e )
        {
            // expected
        }

        // Example of checking if a key is in the map (this does not throw an
        // exception if the key is not found)
        auto nine = "ninth" in map;

    ---

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.FixedKeyMap;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;
import ocean.core.Array;
import ocean.core.Array: copy, bsearch;
import ocean.core.Enforce;

debug import ocean.io.Stdout;



/*******************************************************************************

    Fixed key map class template.

    Template_Params:
        K = mapping key type
        V = mapping value type

*******************************************************************************/

public class FixedKeyMap ( K, V )
{
    /***************************************************************************

        List of keys in mapping.

        The keys are set once (in the constructor) and sorted.

    ***************************************************************************/

    private K[] keys;


    /***************************************************************************

        List of values in mapping. This list is always the same length as the
        keys array, and has the same ordering (i.e. the value in values[0] is
        associated with the key in keys[0]).

    ***************************************************************************/

    private V[] values;


    /***************************************************************************

        Exception instance

    ***************************************************************************/

    static public class FixedKeyMapException : Exception
    {
        public this ()
        {
            super(null);
            super.file = __FILE__;
        }

        public typeof(this) set ( istring msg, long line = __LINE__ )
        {
            super.msg = msg;
            super.line = line;
            return this;
        }
    }

    private FixedKeyMapException exception;


    /***************************************************************************

        Constructor. The passed list of allowed keys is shallow copied into the
        keys class member.

        Params:
            keys = list of allowed keys

    ***************************************************************************/

    public this ( Const!(K[]) keys )
    {
        this.keys.copy(keys);
        sort(this.keys);

        this.values.length = this.keys.length;

        this.exception = new FixedKeyMapException;
    }


    /***************************************************************************

        Returns:
            length of mapping (the number of keys)

    ***************************************************************************/

    public size_t length ( )
    {
        return this.keys.length;
    }


    /***************************************************************************

        Gets a value for a key.

        Params:
            key = key to look up

        Returns:
            value corresponding to key

        Throws:
            if key is not in map (see this.keyIndex)

    ***************************************************************************/

    public V opIndex ( Const!(K) key )
    {
        return this.values[this.keyIndex(key, true)];
    }


    /***************************************************************************

        Sets a value for a key.

        Params:
            value = value to set
            key = key to set value for

        Throws:
            if key is not in map (see this.keyIndex)

    ***************************************************************************/

    public void opIndexAssign ( V value, Const!(K) key )
    {
        this.values[this.keyIndex(key, true)] = value;
    }


    /***************************************************************************

        Checks whether a key is in the map, and returns a pointer to the
        corresponding value, or null if the key does not exist.

        Params:
            key = key to look up

        Returns:
            pointer to value corresponding to key, or null if key not in map

    ***************************************************************************/

    public V* opIn_r ( Const!(K) key )
    {
        auto pos = this.keyIndex(key, false);
        auto found = pos < this.keys.length;

        return found ? &this.values[pos] : null;
    }


    /***************************************************************************

        foreach operator over keys in the map.

    ***************************************************************************/

    public int opApply ( int delegate ( ref K ) dg )
    {
        int res;
        foreach ( key; this.keys )
        {
            res = dg(key);
            if ( res ) break;
        }
        return res;
    }


    /***************************************************************************

        foreach operator over keys and values in the map.

    ***************************************************************************/

    public int opApply ( int delegate ( ref K, ref V ) dg )
    {
        int res;
        foreach ( i, key; this.keys )
        {
            res = dg(key, this.values[i]);
            if ( res ) break;
        }
        return res;
    }


    /***************************************************************************

        foreach operator over keys, values and indices in the map.

    ***************************************************************************/

    public int opApply ( int delegate ( ref size_t, ref K, ref V ) dg )
    {
        int res;
        foreach ( i, key; this.keys )
        {
            res = dg(i, key, this.values[i]);
            if ( res ) break;
        }
        return res;
    }


    /***************************************************************************

        Finds a key in the keys array.

        Params:
            key = key to look up
            throw_if_not_found = if true, an exception is thrown when looking up
                a key which isn't in the array

        Returns:
            index of key in array, or keys.length if throw_if_not_found is false
                and key is not found

        Throws:
            if throw_if_not_found is true and the key is not in the array

    ***************************************************************************/

    private size_t keyIndex ( Const!(K) key, bool throw_if_not_found )
    {
        size_t pos;
        auto found = ocean.core.Array.bsearch(this.keys, key, pos);

        if ( !found )
        {
            if ( throw_if_not_found )
            {
                throw this.exception.set("Key not in map");
            }
            else
            {
                pos = this.keys.length;
            }
        }

        return pos;
    }
}



unittest
{
    auto map = new FixedKeyMap!(istring, istring)(["first", "second", "third"]);
    assert(("first" in map) !is null);
    assert(("second" in map) !is null);
    assert(("third" in map) !is null);
    assert(("fourth" in map) is null);

    assert(*("first" in map) == "");
    assert(*("second" in map) == "");
    assert(*("third" in map) == "");

    map["first"] = "hello";
    assert(("first" in map) !is null);
    assert(*("first" in map) == "hello");
    assert(map["first"] == "hello");

    map["first"] = "world";
    assert(("first" in map) !is null);
    assert(*("first" in map) == "world");
    assert(map["first"] == "world");

    bool caught;
    try
    {
        map["fifth"];
    }
    catch ( map.FixedKeyMapException e )
    {
        caught = true;
    }
    assert(caught);
}
