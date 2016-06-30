/*******************************************************************************

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.sys.linux.tcp;

extern (C):

/* TCP socket options */
enum
{
    TCP_NODELAY              = 1,  /* Turn off Nagle's algorithm. */
    TCP_MAXSEG               = 2,  /* Limit MSS */
    TCP_CORK                 = 3,  /* Never send partially complete segments */
    TCP_KEEPIDLE             = 4,  /* Start keeplives after this period */
    TCP_KEEPINTVL            = 5,  /* Interval between keepalives */
    TCP_KEEPCNT              = 6,  /* Number of keepalives before death */
    TCP_SYNCNT               = 7,  /* Number of SYN retransmits */
    TCP_LINGER2              = 8,  /* Life time of orphaned FIN-WAIT-2 state */
    TCP_DEFER_ACCEPT         = 9,  /* Wake up listener only when data arrive */
    TCP_WINDOW_CLAMP         = 10, /* Bound advertised window */
    TCP_INFO                 = 11, /* Information about this connection. */
    TCP_QUICKACK             = 12, /* Block/reenable quick acks */
    TCP_CONGESTION           = 13, /* Congestion control algorithm */
    TCP_MD5SIG               = 14, /* TCP MD5 Signature (RFC2385) */
    TCP_COOKIE_TRANSACTIONS  = 15, /* TCP Cookie Transactions */
    TCP_THIN_LINEAR_TIMEOUTS = 16, /* Use linear timeouts for thin streams*/
    TCP_THIN_DUPACK          = 17, /* Fast retrans. after 1 dupack */
    TCP_USER_TIMEOUT         = 18, /* How long for loss retry before timeout */
}

