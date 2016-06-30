/*******************************************************************************

    Xml entities.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.text.entities.XmlEntitySet;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.core.Array;

import ocean.text.entities.model.IEntitySet;

import ocean.transition;

/*******************************************************************************

    Xml entity set class.

*******************************************************************************/

public class XmlEntitySet : IEntitySet
{
    /***************************************************************************

        This alias.

    ***************************************************************************/

    public alias typeof(this) This;


    /***************************************************************************

        Xml character entities

    ***************************************************************************/

    public const Entity[] xml_entities =
    [
        {"amp",    0x0026}, // '&'
        {"quot",   0x0022}, // '"'
        {"lt",     0x003C}, // '<'
        {"gt",     0x003E}, // '>'
        {"apos",   0x0027}, // '''
    ];


    /***************************************************************************

        Returns the list of entities.

    ***************************************************************************/

    public override Const!(Entity)[] entities ( )
    {
        return This.xml_entities;
    }


    /***************************************************************************

        Gets the fully encoded form of an entity.

        Params:
            unicode = unicode of entity to encode
            output = output buffer

        Returns:
            the fully encoded form of the entity, or "" if the unicode value
            passed is not an encodable entity

    ***************************************************************************/

    public override char[] getEncodedEntity ( dchar unicode, ref char[] output )
    {
        auto name = this.getName(unicode);
        if ( name.length )
        {
            output.concat("&"[], name, ";"[]);
        }
        else
        {
            output.length = 0;
        }

        return output;
    }
}

