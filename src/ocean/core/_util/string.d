/*******************************************************************************

        Various char[] utilities

        Copyright:
            Copyright (c) 2004 Tango group.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: July 2006

*******************************************************************************/

module ocean.core._util.string;

// D1 has it in runtime
version (D_Version2):

import ocean.stdc.string : memcmp;

// convert uint to char[], within the given buffer
// Returns a valid slice of the populated buffer
char[] intToUtf8 (char[] tmp, uint val)
in {
   assert (tmp.length > 9, "atoi buffer should be more than 9 chars wide");
   }
body
{
    char* p = tmp.ptr + tmp.length;

    do {
       *--p = cast(char)((val % 10) + '0');
       } while (val /= 10);

    return tmp [cast(size_t)(p - tmp.ptr) .. $];
}

// convert uint to char[], within the given buffer
// Returns a valid slice of the populated buffer
char[] ulongToUtf8 (char[] tmp, ulong val)
in {
   assert (tmp.length > 19, "atoi buffer should be more than 19 chars wide");
   }
body
{
    char* p = tmp.ptr + tmp.length;

    do {
       *--p = cast(char)((val % 10) + '0');
       } while (val /= 10);

    return tmp [cast(size_t)(p - tmp.ptr) .. $];
}


// function to compare two strings
int stringCompare (char[] s1, char[] s2)
{
    auto len = s1.length;

    if (s2.length < len)
        len = s2.length;

    int result = memcmp(s1.ptr, s2.ptr, len);

    if (result == 0)
        result = (s1.length<s2.length)?-1:((s1.length==s2.length)?0:1);

    return result;
}
