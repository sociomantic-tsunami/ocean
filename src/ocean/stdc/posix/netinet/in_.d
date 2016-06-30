/*******************************************************************************

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/


module ocean.stdc.posix.netinet.in_;

public import core.sys.posix.netinet.in_;

static if (__VERSION__ < 2067)
{
    enum
    {
        IPPROTO_PUP = 12, /* PUP protocol.  */
        IPPROTO_IGMP = 2, /* Internet Group Management Protocol. */
        IPPROTO_IDP = 22, /* XNS IDP protocol.  */
    }
}
