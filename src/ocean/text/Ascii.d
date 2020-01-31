/*******************************************************************************

    Placeholder for a selection of ASCII utilities. These generally will
    not work with utf8, and cannot be easily extended to utf16 or utf32

    Copyright:
        Copyright (c) 2006 Kris Bell.
        Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

    Version: Dec 2006: Initial release

    Authors: Kris

*******************************************************************************/

module ocean.text.Ascii;

import ocean.meta.types.Qualifiers;

import ocean.core.Array;

import ocean.core.Verify;

import ocean.stdc.string: strncasecmp, memcmp;
private alias strncasecmp memicmp;

version (unittest) import ocean.core.Test;

/******************************************************************************

    Convert to lowercase. Performs in-place conversion.

    Params:
        src = text to convert

    Returns:
        slice of src after conversion

*******************************************************************************/


public mstring toLower ( mstring src )
{
    foreach (ref c; src)
        if (c>= 'A' && c <= 'Z')
            c = cast(char)(c + 32);
    return src;
}

/******************************************************************************

    Convert to lowercase. Result is written to resized buffer.

    Params:
        src = text to convert
        dst = buffer to write result to

    Returns:
        slice of dst after conversion

*******************************************************************************/

public mstring toLower ( cstring src, ref mstring dst )
{
    dst.copy(src);
    return toLower(dst);
}

/******************************************************************************

    Convert to uppercase. Performs in-place conversion.

    Params:
        src = text to convert

    Returns:
        slice of src after conversion

*******************************************************************************/

public mstring toUpper ( mstring src )
{
    foreach (ref c; src)
        if (c>= 'a' && c <= 'z')
            c = cast(char)(c - 32);
    return src;
}

/******************************************************************************

    Convert to uppercase. Result is written to resized buffer.

    Params:
        src = text to convert
        dst = buffer to write result to

    Returns:
        slice of dst after conversion

*******************************************************************************/

public mstring toUpper ( cstring src, ref mstring dst )
{
    dst.copy(src);
    return toUpper(dst);
}

/******************************************************************************

  Compare two char[] ignoring case. Returns 0 if equal

 ******************************************************************************/

int icompare (cstring s1, cstring s2)
{
    auto len = s1.length;
    if (s2.length < len)
        len = s2.length;

    auto result = memicmp (s1.ptr, s2.ptr, len);

    if (result is 0)
        result = cast(int) (s1.length - s2.length);
    return result;
}


/******************************************************************************

  Compare two char[] with case. Returns 0 if equal

 ******************************************************************************/

int compare (cstring s1, cstring s2)
{
    auto len = s1.length;
    if (s2.length < len)
        len = s2.length;

    auto result = memcmp (s1.ptr, s2.ptr, len);

    if (result is 0)
        result = cast(int) (s1.length - s2.length);
    return result;
}



/******************************************************************************

  Return the index position of a text pattern within src, or
  src.length upon failure.

  This is a case-insensitive search (with thanks to Nietsnie)

 ******************************************************************************/

static int isearch (in cstring src, in cstring pattern)
{
    static  char[] _caseMap = [
        '\000','\001','\002','\003','\004','\005','\006','\007',
        '\010','\011','\012','\013','\014','\015','\016','\017',
        '\020','\021','\022','\023','\024','\025','\026','\027',
        '\030','\031','\032','\033','\034','\035','\036','\037',
        '\040','\041','\042','\043','\044','\045','\046','\047',
        '\050','\051','\052','\053','\054','\055','\056','\057',
        '\060','\061','\062','\063','\064','\065','\066','\067',
        '\070','\071','\072','\073','\074','\075','\076','\077',
        '\100','\141','\142','\143','\144','\145','\146','\147',
        '\150','\151','\152','\153','\154','\155','\156','\157',
        '\160','\161','\162','\163','\164','\165','\166','\167',
        '\170','\171','\172','\133','\134','\135','\136','\137',
        '\140','\141','\142','\143','\144','\145','\146','\147',
        '\150','\151','\152','\153','\154','\155','\156','\157',
        '\160','\161','\162','\163','\164','\165','\166','\167',
        '\170','\171','\172','\173','\174','\175','\176','\177',
        '\200','\201','\202','\203','\204','\205','\206','\207',
        '\210','\211','\212','\213','\214','\215','\216','\217',
        '\220','\221','\222','\223','\224','\225','\226','\227',
        '\230','\231','\232','\233','\234','\235','\236','\237',
        '\240','\241','\242','\243','\244','\245','\246','\247',
        '\250','\251','\252','\253','\254','\255','\256','\257',
        '\260','\261','\262','\263','\264','\265','\266','\267',
        '\270','\271','\272','\273','\274','\275','\276','\277',
        '\300','\341','\342','\343','\344','\345','\346','\347',
        '\350','\351','\352','\353','\354','\355','\356','\357',
        '\360','\361','\362','\363','\364','\365','\366','\367',
        '\370','\371','\372','\333','\334','\335','\336','\337',
        '\340','\341','\342','\343','\344','\345','\346','\347',
        '\350','\351','\352','\353','\354','\355','\356','\357',
        '\360','\361','\362','\363','\364','\365','\366','\367',
        '\370','\371','\372','\373','\374','\375','\376','\377',
    ];


    verify(src.ptr !is null);
    verify(pattern.ptr !is null);

    for (int i1=0, i2; i1 <= cast(int)(src.length - pattern.length); ++i1)
    {
        for (i2=0; i2 < pattern.length; ++i2)
            if (_caseMap[src[i1 + i2]] != _caseMap[pattern[i2]])
                break;

        if (i2 is pattern.length)
            return i1;
    }
    return cast(int) src.length;
}



/******************************************************************************

 ******************************************************************************/

unittest
{
    char[] tmp;

    test (toLower("1bac", tmp) == "1bac");
    test (toLower("1BAC", tmp) == "1bac");
    test (toUpper("1bac", tmp) == "1BAC");
    test (toUpper("1BAC", tmp) == "1BAC");
    test (icompare ("ABC", "abc") is 0);
    test (icompare ("abc", "abc") is 0);
    test (icompare ("abcd", "abc") > 0);
    test (icompare ("abc", "abcd") < 0);
    test (icompare ("ACC", "abc") > 0);

    test (isearch ("ACC", "abc") is 3);
    test (isearch ("ACC", "acc") is 0);
    test (isearch ("aACC", "acc") is 1);
}

debug (Ascii)
{
    void main() {}
}
