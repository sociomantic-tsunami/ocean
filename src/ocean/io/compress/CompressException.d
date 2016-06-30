/******************************************************************************

    Compress Exception

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.io.compress.CompressException;

import ocean.core.Exception;

/******************************************************************************

    CompressException

*******************************************************************************/

class CompressException : Exception
{
    mixin DefaultExceptionCtor!();

    static void opCall ( Args ... ) ( Args args )
    {
        throw new CompressException(args);
    }
}
