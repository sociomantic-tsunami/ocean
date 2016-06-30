/*******************************************************************************

       D binding for the POSIX iconv library.

       The iconv library is used to convert from one character encoding to
       another.

       See_Also:
           http://pubs.opengroup.org/onlinepubs/009695399/functions/iconv_open.html

       Copyright:
           Copyright (c) 2009-2016 Sociomantic Labs GmbH.
           All rights reserved.

       License:
           Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
           Alternatively, this file may be distributed under the terms of the Tango
           3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.text.util.c.iconv;

import ocean.transition;

extern (C)
{
	mixin(Typedef!(void*, "ConversionDescriptor"));

	ConversionDescriptor iconv_open ( in char* tocode, in char* fromcode );

	ptrdiff_t iconv ( ConversionDescriptor cd, Const!(char)** inbuf, size_t* inbytesleft, char** outbuf, size_t* outbytesleft );

	int iconv_close (ConversionDescriptor cd);
}
