/*******************************************************************************

    Html entities. Built on the basis of the xml entities.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.text.entities.HtmlEntitySet;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.text.entities.model.IEntitySet;

import ocean.text.entities.XmlEntitySet;

import ocean.transition;

/*******************************************************************************

    Html entity set class - extends XmlEntitySet

*******************************************************************************/

public class HtmlEntitySet : XmlEntitySet
{
    /***************************************************************************

        This alias.

    ***************************************************************************/

    public alias typeof(this) This;


    /***************************************************************************

        ISO 8859-1 (Latin 1) character entities. Uses the basic xml entities,
        plus the ISO8859_1_extra entities defined below.

    ***************************************************************************/

    protected const Entity[] ISO8859_1 = xml_entities ~ ISO8859_1_extra;


    /***************************************************************************

        All html entities. Union of ISO 8859-1 (Latin 1) and -15 (Latin 9)
        character entities.

    ***************************************************************************/

    public const Entity[] html_entities = ISO8859_1 ~ ISO8859_15_extra;


    /***************************************************************************

        Extra characters of ISO 8859-1 (Latin 1) (in addition to the xml
        entities)

    ***************************************************************************/

    protected const Entity[] ISO8859_1_extra =
    [
        {"nbsp",   0x00A0}, // ' '
        {"iexcl",  0x00A1}, // '¡'
        {"cent",   0x00A2}, // '¢'
        {"pound",  0x00A3}, // '£'
        {"curren", 0x00A4}, // '¤'
        {"yen",    0x00A5}, // '¥'
        {"brvbar", 0x00A6}, // '¦'
        {"sect",   0x00A7}, // '§'
        {"uml",    0x00A8}, // '¨'
        {"copy",   0x00A9}, // '©'
        {"ordf",   0x00AA}, // 'ª'
        {"laquo",  0x00AB}, // '«'
        {"not",    0x00AC}, // '¬'
        {"shy",    0x00AD}, // '­'
        {"reg",    0x00AE}, // '®'
        {"macr",   0x00AF}, // '¯'
        {"deg",    0x00B0}, // '°'
        {"plusmn", 0x00B1}, // '±'
        {"sup2",   0x00B2}, // '²'
        {"sup3",   0x00B3}, // '³'
        {"acute",  0x00B4}, // '´'
        {"micro",  0x00B5}, // 'µ'
        {"para",   0x00B6}, // '¶'
        {"middot", 0x00B7}, // '·'
        {"cedil",  0x00B8}, // '¸'
        {"sup1",   0x00B9}, // '¹'
        {"ordm",   0x00BA}, // 'º'
        {"raquo",  0x00BB}, // '»'
        {"frac14", 0x00BC}, // '¼'
        {"frac12", 0x00BD}, // '½'
        {"frac34", 0x00BE}, // '¾'
        {"iquest", 0x00BF}, // '¿'
        {"Agrave", 0x00C0}, // 'À'
        {"Aacute", 0x00C1}, // 'Á'
        {"Acirc",  0x00C2}, // 'Â'
        {"Atilde", 0x00C3}, // 'Ã'
        {"Auml",   0x00C4}, // 'Ä'
        {"Aring",  0x00C5}, // 'Å'
        {"AElig",  0x00C6}, // 'Æ'
        {"Ccedil", 0x00C7}, // 'Ç'
        {"Egrave", 0x00C8}, // 'È'
        {"Eacute", 0x00C9}, // 'É'
        {"Ecirc",  0x00CA}, // 'Ê'
        {"Euml",   0x00CB}, // 'Ë'
        {"Igrave", 0x00CC}, // 'Ì'
        {"Iacute", 0x00CD}, // 'Í'
        {"Icirc",  0x00CE}, // 'Î'
        {"Iuml",   0x00CF}, // 'Ï'
        {"ETH",    0x00D0}, // 'Ð'
        {"Ntilde", 0x00D1}, // 'Ñ'
        {"Ograve", 0x00D2}, // 'Ò'
        {"Oacute", 0x00D3}, // 'Ó'
        {"Ocirc",  0x00D4}, // 'Ô'
        {"Otilde", 0x00D5}, // 'Õ'
        {"Ouml",   0x00D6}, // 'Ö'
        {"times",  0x00D7}, // '×'
        {"Oslash", 0x00D8}, // 'Ø'
        {"Ugrave", 0x00D9}, // 'Ù'
        {"Uacute", 0x00DA}, // 'Ú'
        {"Ucirc",  0x00DB}, // 'Û'
        {"Uuml",   0x00DC}, // 'Ü'
        {"Yacute", 0x00DD}, // 'Ý'
        {"THORN",  0x00DE}, // 'Þ'
        {"szlig",  0x00DF}, // 'ß'
        {"agrave", 0x00E0}, // 'à'
        {"aacute", 0x00E1}, // 'á'
        {"acirc",  0x00E2}, // 'â'
        {"atilde", 0x00E3}, // 'ã'
        {"auml",   0x00E4}, // 'ä'
        {"aring",  0x00E5}, // 'å'
        {"aelig",  0x00E6}, // 'æ'
        {"ccedil", 0x00E7}, // 'ç'
        {"egrave", 0x00E8}, // 'è'
        {"eacute", 0x00E9}, // 'é'
        {"ecirc",  0x00EA}, // 'ê'
        {"euml",   0x00EB}, // 'ë'
        {"igrave", 0x00EC}, // 'ì'
        {"iacute", 0x00ED}, // 'í'
        {"icirc",  0x00EE}, // 'î'
        {"iuml",   0x00EF}, // 'ï'
        {"eth",    0x00F0}, // 'ð'
        {"ntilde", 0x00F1}, // 'ñ'
        {"ograve", 0x00F2}, // 'ò'
        {"oacute", 0x00F3}, // 'ó'
        {"ocirc",  0x00F4}, // 'ô'
        {"otilde", 0x00F5}, // 'õ'
        {"ouml",   0x00F6}, // 'ö'
        {"divide", 0x00F7}, // '÷'
        {"oslash", 0x00F8}, // 'ø'
        {"ugrave", 0x00F9}, // 'ù'
        {"uacute", 0x00FA}, // 'ú'
        {"ucirc",  0x00FB}, // 'û'
        {"uuml",   0x00FC}, // 'ü'
        {"yacute", 0x00FD}, // 'ý'
        {"yuml",   0x00FF}, // 'ÿ'
        {"thorn",  0x00FE}, // 'þ'
    ];


    /***************************************************************************

        Extra characters of ISO 8859-15 (Latin 9) which are not in ISO 8859-1
        (Latin 1)

    ***************************************************************************/

    protected const Entity[] ISO8859_15_extra =
    [
        {"OElig",  0x0152}, // 'Œ'
        {"OElig",  0x0153}, // 'œ'
        {"Scaron", 0x0160}, // 'Š'
        {"scaron", 0x0161}, // 'š'
        {"Zcaron", 0x017D}, // 'Ž'
        {"zcaron", 0x017E}, // 'ž'
        {"euro",   0x20AC}, // '€'
    ];


    /***************************************************************************

        Returns the list of entities.

    ***************************************************************************/

    public override Const!(Entity)[] entities ( )
    {
        return This.html_entities;
    }
}

