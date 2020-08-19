/*******************************************************************************

    Linux timer event file descriptor.

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.sys.TimerFD;

import ocean.io.model.IConduit: ISelectable;
import ocean.meta.codegen.Identifier;
import ocean.sys.ErrnoException;

import core.stdc.errno: EAGAIN, EWOULDBLOCK, errno;
import Upstream = core.sys.linux.timerfd;
import core.sys.posix.time: time_t, timespec, itimerspec, CLOCK_REALTIME;
import core.sys.posix.sys.types: ssize_t;
import core.sys.posix.unistd: read, close;

/*******************************************************************************

    Timer fd class -- can be used in an allocation-free context if instantiated
    with the ctor which accepts an exception instance.

*******************************************************************************/

public class TimerFD : ISelectable
{
    import ocean.sys.CloseOnExec;

    /***************************************************************************

        Set to true to use an absolute or false for a relative timer. On default
        a relative timer is used.

    ***************************************************************************/

    public bool absolute = false;


    /***************************************************************************

        Exception class, thrown on errors with timer functions

    ***************************************************************************/

    static public class TimerException : ErrnoException { }

    /***************************************************************************

        Timer exception instance.

    ***************************************************************************/

    private TimerException e;


    /***************************************************************************

        Integer file descriptor provided by the operating system and used to
        manage the timer event.

    ***************************************************************************/

    private int fd;


    /***************************************************************************

        Constructor.

        Params:
            realtime = true:  use a settable system-wide clock.
                       false: use a non-settable clock that is not affected by
                       discontinuous changes in the system clock (e.g., manual
                       changes to system time).

        Throws:
            upon failure to create a timer fd

    ***************************************************************************/

    public this ( bool realtime = false )
    {
        this(new TimerException, realtime);
    }


    /***************************************************************************

        Constructor. Creates a timer event file descriptor.

        Params:
            e = timer exception instance to be used internally
            realtime = true:  use a settable system-wide clock.
                       false: use a non-settable clock that is not affected by
                       discontinuous changes in the system clock (e.g., manual
                       changes to system time).

        Throws:
            upon failure to create a timer fd

    ***************************************************************************/

    public this ( TimerException e, bool realtime = false )
    {
        this.e = e;
        static bool verify (int fd) { return fd >= 0; }
        this.fd = this.e.enforceRet!(Upstream.timerfd_create)(&verify).call(
            realtime ? Upstream.CLOCK_REALTIME : Upstream.CLOCK_MONOTONIC,
            setCloExec(Upstream.TFD_NONBLOCK, Upstream.TFD_CLOEXEC)
        );
    }

    /***************************************************************************

        Destructor. Destroys the timer event file descriptor.

    ***************************************************************************/

    ~this ( )
    {
        .close(this.fd);
    }


    /***************************************************************************

        Required by ISelectable interface.

        Returns:
            file descriptor used to manage timer event

    ***************************************************************************/

    public Handle fileHandle ( )
    {
        return cast(Handle)this.fd;
    }


    /***************************************************************************

        Returns the next expiration time.

        Returns:
            itimerspec instance containing the next expiration time.
            - it_value: the amount of time until the timer will next expire. If
                 both fields are zero, then the timer is currently disarmed.
                 Contains always a relative value.
            - it_interval: the interval of the timer. If both fields are zero,
                 then the timer is set to expire just once, at the time
                 specified by it_value.

        Throws:
            upon failure to get the time from the timer fd

    ***************************************************************************/

    public itimerspec time ( )
    {
        itimerspec t;
        this.e.enforceRetCode!(Upstream.timerfd_gettime)().call(this.fd, &t);
        return t;
    }


    /***************************************************************************

        Sets next expiration time of interval timer.

        Params:
            first =    Specifies the initial expiration of the timer. Setting
                       either field to a non-zero value arms the timer. Setting
                       both fields to zero disarms the timer.

            interval = Setting one or both fields to non-zero values specifies
                       the period for repeated timer expirations after the
                       initial expiration. If both fields are zero, the timer
                       expires just once, at the time specified by it_value.

        Returns:
            the previous expiration time as time().

        Throws:
            upon failure to set the time

    ***************************************************************************/

    public itimerspec set ( timespec first, timespec interval = timespec.init )
    {
        itimerspec t_new = itimerspec(interval, first);
        itimerspec t_old;

        this.e.enforceRetCode!(Upstream.timerfd_settime)().call(
            this.fd,
            this.absolute? Upstream.TFD_TIMER_ABSTIME : 0,
            &t_new,
            &t_old
        );

        return t_old;
    }


    /***************************************************************************

        Sets next expiration time of interval timer.

        Setting first_s or first_ms to a non-zero value arms the timer. Setting
        both to zero disarms the timer.
        If both interval_s and interval_ms are zero, the timer expires just
        once, at the time specified by first_s and first_ms.

        Params:
            first_s     = Specifies the number of seconds of the initial
                          expiration of the timer.

            first_ms    = Specifies an amount of milliseconds that will be added
                          to first_s.

            interval_s = Specifies the number of seconds of the period for
                          repeated timer expirations after the initial
                          expiration.

            interval_ms = Specifies an amount of milliseconds that will be added
                          to interval_ms.

        Returns:
            the previous expiration time as time().

        Throws:
            upon failure to set the time

    ***************************************************************************/

    public itimerspec set ( time_t first_s,        uint first_ms,
                            time_t interval_s = 0, uint interval_ms = 0 )
    {
        return this.set(timespec(first_s,    first_ms    * 1_000_000),
                        timespec(interval_s, interval_ms * 1_000_000));
    }


    /***************************************************************************

        Resets/disarms the timer.

        Returns:
            Returns the previous expiration time as time().

        Throws:
            upon failure to set the time

    ***************************************************************************/

    public itimerspec reset ( )
    {
        return this.set(timespec.init);
    }


    /***************************************************************************

        Should be called when the timer event has fired.

        Returns:
            the number of times the event has been triggered since the last call
            to handle().

    ***************************************************************************/

    public ulong handle ( )
    {
        ulong n;

        if (.read(this.fd, &n, n.sizeof) < 0)
        {
            scope (exit) errno = 0;

            int errnum = errno;

            switch (errnum)
            {
                case EAGAIN:
                static if (EAGAIN != EWOULDBLOCK) case EWOULDBLOCK:
                    return true;

                default:
                    throw this.e.set(errnum, identifier!(.read));
            }
        }
        else
        {
            return n;
        }
    }
}
