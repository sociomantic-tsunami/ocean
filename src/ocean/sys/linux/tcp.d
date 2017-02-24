/*******************************************************************************

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

deprecated module ocean.sys.linux.tcp;
pragma(msg, "Please use core.sys.linux.sys.netinet.tcp instead");

public import core.sys.linux.sys.netinet.tcp;
