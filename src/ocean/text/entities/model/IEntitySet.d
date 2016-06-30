/*******************************************************************************

    An abstract class encapsulating a set of entities for en/decoding. A typical
    example is the various html entities which are required to be encoded, for
    example:

        '&' should be encoded as "&amp;"

    The class should be implemented, and the entities() methods made to return
    the list of entities to be handled.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.text.entities.model.IEntitySet;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.text.utf.UtfString : InvalidUnicode, utf_match;

import ocean.transition;

/*******************************************************************************

    Abstract entity set class.

*******************************************************************************/

public abstract class IEntitySet
{
    /***************************************************************************

        An entity. Simply a tuple of a name and a unicode value (eg "amp", '&').

    ***************************************************************************/

    public struct Entity
    {
        istring name;
        dchar unicode;
    }


    /***************************************************************************

        Abstract method to return the list of entities.

    ***************************************************************************/

    public abstract Const!(Entity)[] entities ( );


    /***************************************************************************

        Abstract method to get the encoded form of an entity.

    ***************************************************************************/

    abstract public char[] getEncodedEntity ( dchar unicode, ref char[] output );


    /***************************************************************************

        Gets the unicode character associated with the passed name.

        Template_Params:
            Char = character type of name

        Params:
            name = name to check

        Returns:
            unicode corresponding to name, or InvalidUnicode if name is not in
            the entity list

    ***************************************************************************/

    public dchar getUnicode ( Char ) ( Char[] name )
    {
        foreach ( check_name, unicode; this )
        {
            if ( utf_match(name, check_name) )
            {
                return unicode;
            }
        }

        return InvalidUnicode;
    }


    /***************************************************************************

        Gets the name associated with the passed unicode character.

        Params:
            unicode = unicode value to check

        Returns:
            name corresponding to unicode, or "" if unicode is not in the entity
            list

    ***************************************************************************/

    public istring getName ( dchar unicode )
    {
        foreach ( name, check_unicode; this )
        {
            if ( check_unicode == unicode )
            {
                return name;
            }
        }

        return "";
    }


    /***************************************************************************

        Checks whether the passed name is in the list of entities.

        Params:
            name = name to check

        Returns:
            true if name is an entity

    ***************************************************************************/

    public bool opIn_r ( char[] name )
    {
        foreach ( ref entity; this.entities )
        {
            if ( utf_match(name, entity.name) )
            {
                return true;
            }
        }

        return false;
    }


    /***************************************************************************

        Checks whether the passed name is in the list of entities.

        Params:
            name = name to check

        Returns:
            true if name is an entity

    ***************************************************************************/

    public bool opIn_r ( wchar[] name )
    {
        foreach ( ref entity; this.entities )
        {
            if ( utf_match(name, entity.name) )
            {
                return true;
            }
        }

        return false;
    }


    /***************************************************************************

        Checks whether the passed name is in the list of entities.

        Params:
            name = name to check

        Returns:
            true if name is an entity

    ***************************************************************************/

    public bool opIn_r ( dchar[] name )
    {
        foreach ( ref entity; this.entities )
        {
            if ( utf_match(name, entity.name) )
            {
                return true;
            }
        }

        return false;
    }


    /***************************************************************************

        Checks whether the passed unicode is in the list of entities.

        Params:
            unicode = unicode value to check

        Returns:
            true if unicode is an entity

    ***************************************************************************/

    public bool opIn_r ( dchar unicode )
    {
        foreach ( ref entity; this.entities )
        {
            if ( entity.unicode == unicode )
            {
                return true;
            }
        }

        return false;
    }


    /***************************************************************************

        Checks whether the passed unicode is in the list of entities.

        Params:
            unicode = unicode value to check

        Returns:
            true if unicode is an entity

    ***************************************************************************/

    public bool opIn_r ( wchar unicode )
    {
        return (cast(dchar)unicode) in this;
    }


    /***************************************************************************

        Checks whether the passed unicode is in the list of entities.

        Params:
            unicode = unicode value to check

        Returns:
            true if unicode is an entity

    ***************************************************************************/

    public bool opIn_r ( char unicode )
    {
        return (cast(dchar)unicode) in this;
    }


    /***************************************************************************

        foreach iterator over the list of entities.

        foreach arguments exposed:
            char[] name = entity name
            dchar unicode = entity unicode value


    ***************************************************************************/

    public int opApply ( int delegate ( ref Const!(istring), ref Const!(dchar) ) dg )
    {
        int res;
        foreach ( ref entity; this.entities )
        {
            res = dg(entity.name, entity.unicode);
            if ( res )
            {
                break;
            }
        }

        return res;
    }
}

