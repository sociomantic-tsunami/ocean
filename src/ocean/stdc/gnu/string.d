/*******************************************************************************

    glibc string functions.

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.stdc.gnu.string;

import ocean.meta.types.Qualifiers;
import core.stdc.stddef: wchar_t;
public import core.sys.posix.string : strnlen, strndup;
public import core.sys.linux.string : memmem;

extern (C):

size_t   wcsnlen(in wchar_t* ws, size_t maxlen);
void*    mempcpy(void* to, void *from, size_t size);
wchar_t* wmempcpy(wchar_t* wto, wchar_t* wfrom, size_t size);
wchar_t* wcsdup (in wchar_t* ws);
int      strverscmp(in char* s1, in char* s2);
inout(void)* rawmemchr(inout(void)* block, int c);
inout(void)* memrchr(inout(void)* block, int c, size_t size);
inout(char)* strchrnul(inout(char)* str, int c);
inout(wchar_t)* wcschrnul(inout(wchar_t)* wstr, wchar_t wc);
