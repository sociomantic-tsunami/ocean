/*******************************************************************************

    glibc string functions.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.stdc.gnu.string;

version (GLIBC):


import core.stdc.stddef: wchar_t;


extern (C):

size_t   strnlen(char* s, size_t maxlen);
size_t   wcsnlen(wchar_t* ws, size_t maxlen);
void*    mempcpy(void* to, void *from, size_t size);
wchar_t* wmempcpy(wchar_t* wto, wchar_t* wfrom, size_t size);
wchar_t* wcsdup (wchar_t* ws);
char*    strndup(char* s, size_t size);
int      strverscmp(char* s1, char* s2);
void*    rawmemchr(void* block, int c);
void*    memrchr(void* block, int c, size_t size);
char*    strchrnul(char* string, int c);
wchar_t* wcschrnul(wchar_t* wstring, wchar_t wc);
void*    memmem(void* haystack, size_t hlen, void *needle, size_t nlen);

static if (__VERSION__ < 2070)
{
    char*    strerror_r(int errnum, char *buf, size_t buflen);
}
