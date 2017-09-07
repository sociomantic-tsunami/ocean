/*******************************************************************************

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/


module ocean.stdc.posix.sys.time;

public import core.sys.posix.sys.time;

deprecated ("ocean.stdc.posix.sys.time.timeradd is deprecated. Use core.sys.posix.sys.time.timeradd instead.")
void timeradd(timeval* a, timeval* b, timeval* result)
{
    result.tv_sec = a.tv_sec + b.tv_sec;
    result.tv_usec = a.tv_usec + b.tv_usec;
    if (result.tv_usec >= 1000000)
    {
        ++result.tv_sec;
        result.tv_usec -= 1000000;
    }
}

deprecated ("ocean.stdc.posix.sys.time.timersub is deprecated. Use core.sys.posix.sys.time.timersub instead.")
void timersub(timeval* a, timeval* b, timeval *result)
{
    result.tv_sec = a.tv_sec - b.tv_sec;
    result.tv_usec = a.tv_usec - b.tv_usec;
    if (result.tv_usec < 0) {
        --result.tv_sec;
        result.tv_usec += 1000000;
    }
}

deprecated ("ocean.stdc.posix.sys.time.timerclear is deprecated. Use core.sys.posix.sys.time.timerclear instead.")
void timerclear(timeval* tvp)
{
    (tvp.tv_sec = tvp.tv_usec = 0);
}

deprecated ("ocean.stdc.posix.sys.time.timerisset is deprecated. Use core.sys.posix.sys.time.timerisset instead.")
int timerisset(timeval* tvp)
{
    return cast(int) (tvp.tv_sec || tvp.tv_usec);
}

deprecated ("ocean.stdc.posix.sys.time.timercmp is deprecated. Use core.sys.posix.sys.time.timercmp instead.")
int timercmp (char[] CMP) (timeval* a, timeval* b)
{
    return cast(int)
           mixin("((a.tv_sec == b.tv_sec) ?" ~
                 "(a.tv_usec" ~ CMP ~ "b.tv_usec) :" ~
                 "(a.tv_sec"  ~ CMP ~ "b.tv_sec))");
}
