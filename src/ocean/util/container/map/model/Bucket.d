/*******************************************************************************

    Template for a struct implementing a single bucket in a set (see
    ocean.util.container.map.model.BucketSet). A bucket contains a set of
    elements which can be added to, removed from and searched.

    Each element in a bucket has a unique key with which it can be identified.
    The elements' key type is templated, but defaults to hash_t. A bucket can
    only contain one element with a given key - if a duplicate is added it will
    replace the original. The elements in the bucket are stored as a linked
    list, for easy removal and insertion.

    Note that the bucket does not own its elements, these must be managed from
    the outside in a pool. The bucket itself simply keeps a pointer to the first
    element which it contains.

    Two element structs exist in this module, one for a basic bucket element,
    and one for a bucket element which contains a value in addition to a key.

    Usage:
        See ocean.util.container.map.model.BucketSet,
        ocean.util.container.map.HashMap & ocean.util.container.map.HashSet

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.map.model.Bucket;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.core.Traits: isStaticArrayType;

/*******************************************************************************

    Template to be mixed in to a bucket element. Contains the shared core
    members of a bucket element.

    This template mixin is used so that we can use structs for the bucket
    elements rather than classes, thus avoiding the memory overhead of class
    instances. In the case of bucket elements, which could exist in quantities
    of many thousands, this is significant.

    Using structs instead of classes means that we can't use an interface or
    base class, and the Bucket struct (below) has to simply assume that the
    Element struct has certain members. As it's purely internal, we can live
    with this.

    Template_Params:
        V = value size (.sizeof of the value type), may be 0 to store no value
        K = key type

*******************************************************************************/

public struct Bucket ( size_t V, K = hash_t )
{
    /**************************************************************************

        Bucket element type

     **************************************************************************/

    struct Element
    {
        /**********************************************************************

            Element value, may be a dummy of zero size if no value is stored.

            !!! WARNING !!!

            Is extremely important that this "val" is at the top of the struct,
            otherwise the struct can get into alignment issues that can cause
            the GC to miss the pointers in the data.

         **********************************************************************/

        public alias ubyte[V] Val;

        public Val val;

        /**********************************************************************

            Make sure val is properly aligned.

            See http://www.digitalmars.com/d/1.0/attribute.html#align

         **********************************************************************/

        static assert(val.offsetof == 0);

        /**********************************************************************

            Add padding bytes to the struct to make sure the key is aligned too.

         **********************************************************************/

        private ubyte[V % size_t.sizeof] _padding;

        /**********************************************************************

            Key = bucket element key type

         **********************************************************************/

        public alias K Key;

        /**********************************************************************

            Element key

         **********************************************************************/

        public Key key;

        /**********************************************************************

            Make sure key is properly aligned.

         **********************************************************************/

        static assert(key.offsetof % size_t.sizeof == 0);

        /**********************************************************************

            Next and previous element. For the first/last bucket element
            next/prev is null, respectively.

         **********************************************************************/

        package Element* next = null;

        debug (HostingArrayMapBucket) private Bucket!(V, K)* bucket;
    }

    /**************************************************************************

        First bucket element

     **************************************************************************/

    package Element* first = null;

    /**************************************************************************

        Tells whether there is at least one element in this bucket.

        Returns:
            false if the bucket is empty or true otherwise.

     **************************************************************************/

    public bool has_element ( )
    {
        return this.first !is null;
    }

    /**************************************************************************

        Looks up the element whose key equals key.

        Params:
            key = element key

        Returns:
            the element whose key equals key or null if not found.

     **************************************************************************/

    public Element* find ( Element.Key key )
    out (element)
    {
        debug (HostingArrayMapBucket) if (element)
        {
            assert (element.bucket, "bucket not set in found element");
            assert (element.bucket is this,
                    "element found is not from this bucket");
        }
    }
    body
    {
        for (Element* element = this.first; element; element = element.next)
        {
            if (element.key == key)
            {
                return element;
            }
        }

        return null;
    }


    /**************************************************************************

        Adds a bucket element with key as key.

        The element is inserted as the first bucket element.

        Params:
            key = key for the new element
            new_element = expression returning a new element, evaluated exactly
                once, if the key to be added does not already exist in the
                bucket

        Returns:
            pointer to inserted element

        Out:
            The returned pointer is never null.

     **************************************************************************/

    public Element* add ( Element.Key key, lazy Element* new_element )
    out (element)
    {
        assert (element !is null);
    }
    body
    {
        Element* element = this.find(key);

        if (!element)
        {
            element = this.add(new_element);

            static if (isStaticArrayType!(K))
            {
                element.key[] = key;
            }
            else
            {
                element.key = key;
            }
        }

        return element;
    }


    /**************************************************************************

        Adds an element to the bucket.

        The element is inserted as the first bucket element.

        Params:
            element = element to add

        Returns:
            element

     **************************************************************************/

    public Element* add ( Element* element )
    in
    {
        debug (HostingArrayMapBucket) element.bucket = this;
    }
    out
    {
        debug (HostingArrayMapBucket)
        {
            // Check for cyclic links using 2 pointers, one which traverse
            // twice as fast as the first one
            auto ptr1 = this.first;
            auto ptr2 = ptr1;

            // Find meeting point
            while(ptr2 !is null)
            {
                ptr1 = ptr1.next;
                if (ptr2.next == null)
                    break; // We reached end of the list, no loop
                else
                    ptr2 = ptr2.next.next;

                assert(ptr1 !is ptr2, "Cyclic linked-list found");
            }
        }
    }
    body
    {
        element.next = this.first;
        this.first   = element;

        return element;
    }

    /**************************************************************************

        Looks up the element corresponding to key in this bucket and removes it,
        if found.

        The removed element must be recycled by the owner of the bucket.

        Params:
            key = key of the element to remove

        Returns:
            removed element or null if not found.

     **************************************************************************/

    public Element* remove ( K key )
    out (removed)
    {
        if (removed !is null)
        {
            assert (removed.next is null, "remove: forgot to clear removed.next");

            debug (HostingArrayMapBucket) if (removed)
            {
                assert (removed.bucket is this,
                        "element to remove is not from this bucket");

                removed.bucket = null;
            }
        }
    }
    body
    {
        if (this.first !is null)
        {
            if (this.first.key == key)
            {
                Element* removed = this.first;

                this.first   = this.first.next;
                removed.next = null;

                return removed;
            }
            else
            {
                Element* element = this.first.next;

                for (Element* prev = this.first; element;)
                {
                    if (element.key == key)
                    {
                        Element* removed = element;

                        prev.next    = element.next;
                        removed.next = null;

                        return removed;
                    }
                    else
                    {
                        prev    = element;
                        element = element.next;
                    }
                }
            }
        }

        return null;
    }
}

version (none):

/**
Order the provided members to minimize size while preserving alignment.
Returns a declaration to be mixed in.

Example:
---
struct Banner {
mixin(alignForSize!(byte[6], double)(["name", "height"]));
}
---

Alignment is not always optimal for 80-bit reals, nor for structs declared
as align(1).
*/
char[] alignForSize(E...)(string[] names...)
{
  // Sort all of the members by .alignof.
  // BUG: Alignment is not always optimal for align(1) structs
  // or 80-bit reals or 64-bit primitives on x86.
  // TRICK: Use the fact that .alignof is always a power of 2,
  // and maximum 16 on extant systems. Thus, we can perform
  // a very limited radix sort.
  // Contains the members with .alignof = 64,32,16,8,4,2,1

  assert(E.length == names.length,
      "alignForSize: There should be as many member names as the types");

  char[][7] declaration = ["", "", "", "", "", "", ""];

  foreach (i, T; E) {
      auto a = T.alignof;
      auto k = a>=64? 0 : a>=32? 1 : a>=16? 2 : a>=8? 3 : a>=4? 4 : a>=2? 5 : 6;
      declaration[k] ~= T.stringof ~ " " ~ names[i] ~ ";\n";
  }

  auto s = "";
  foreach (decl; declaration)
      s ~= decl;
  return s;
}

unittest {
  const x = alignForSize!(int[], char[3], short, double[5])("x", "y","z", "w");
  struct Foo{ int x; }
  const y = alignForSize!(ubyte, Foo, cdouble)("x", "y","z");

  static if(size_t.sizeof == uint.sizeof)
  {
      const passNormalX = x == "double[5u] w;\nint[] x;\nshort z;\nchar[3u] y;\n";
      const passNormalY = y == "cdouble z;\nFoo y;\nubyte x;\n";

      const passAbnormalX = x == "int[] x;\ndouble[5u] w;\nshort z;\nchar[3u] y;\n";
      const passAbnormalY = y == "Foo y;\ncdouble z;\nubyte x;\n";
      // ^ blame http://d.puremagic.com/issues/show_bug.cgi?id=231

      static assert(passNormalX || double.alignof <= (int[]).alignof && passAbnormalX);
      static assert(passNormalY || double.alignof <= int.alignof && passAbnormalY);
  }
  else
  {
      static assert(x == "int[] x;\ndouble[5LU] w;\nshort z;\nchar[3LU] y;\n");
      static assert(y == "cdouble z;\nFoo y;\nubyte x;\n");
  }
}
