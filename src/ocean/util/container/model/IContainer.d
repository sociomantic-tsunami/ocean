/*******************************************************************************

        Copyright:
            Copyright (c) 2008 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Apr 2008: Initial release

        Authors: Kris

*******************************************************************************/

module ocean.util.container.model.IContainer;

/*******************************************************************************

        Generic container

*******************************************************************************/

interface IContainer (V)
{
        size_t size ();

        bool isEmpty ();

        IContainer dup ();

        IContainer clear ();

        IContainer reset ();

        IContainer check ();

        bool contains (V value);

        bool take (ref V element);

        V[] toArray (V[] dst = null);

        size_t remove (V element, bool all);

        int opApply (int delegate(ref V value) dg);

        size_t replace (V oldElement, V newElement, bool all);
}


/*******************************************************************************

        Comparator function

*******************************************************************************/

template Compare (V)
{
        alias int function (ref V a, ref V b) Compare;
}

