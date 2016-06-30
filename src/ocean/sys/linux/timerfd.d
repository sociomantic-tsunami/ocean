/*******************************************************************************

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.sys.linux.timerfd;

import ocean.stdc.posix.time: itimerspec, clockid_t;

// based on sys/timerfd.h

extern (C) version (linux):

/* Bits to be set in the FLAGS parameter of `timerfd_create'.  */
enum
{
    TFD_CLOEXEC  = 0x80000, // octal 02000000
    TFD_NONBLOCK = 0x800,   // octal 04000
}

/* Bits to be set in the FLAGS parameter of `timerfd_settime'.  */
enum
{
    TFD_TIMER_ABSTIME = 1, // 1 << 0
}

/* Return file descriptor for new interval timer source.  */
int timerfd_create (clockid_t __clock_id, int __flags);

/* Set next expiration time of interval timer source UFD to UTMR.  If
   FLAGS has the TFD_TIMER_ABSTIME flag set the timeout value is
   absolute.  Optionally return the old expiration time in OTMR.  */
int timerfd_settime (int __ufd, int __flags, itimerspec* __utmr,
                     itimerspec* __otmr);

/* Return the next expiration time of UFD.  */
int timerfd_gettime (int __ufd, itimerspec *__otmr);

