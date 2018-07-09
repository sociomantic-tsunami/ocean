/*******************************************************************************

    Key exception -- thrown when an error event was reported for a selected key.

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.select.selector.EpollException;


import ocean.sys.ErrnoException;

/******************************************************************************/

class EpollException : ErrnoException
{
}
