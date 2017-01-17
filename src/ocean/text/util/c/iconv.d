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

deprecated module ocean.text.util.c.iconv;

import ocean.transition;

extern (C)
{

    deprecated("Use core.sys.posix.iconv.iconv_t instead")
	mixin(Typedef!(void*, "ConversionDescriptor"));

    deprecated("Use core.sys.posix.iconv.iconv_open instead")
	ConversionDescriptor iconv_open ( in char* tocode, in char* fromcode );

    deprecated("Use core.sys.posix.iconv.iconv instead")
	ptrdiff_t iconv ( ConversionDescriptor cd, Const!(char)** inbuf, size_t* inbytesleft, char** outbuf, size_t* outbytesleft );

    deprecated("Use core.sys.posix.iconv.iconv_close instead")
	int iconv_close (ConversionDescriptor cd);
}
