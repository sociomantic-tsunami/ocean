/*******************************************************************************

    Linux timer event file descriptor.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.sys.TimerFD;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.sys.ErrnoException;

import ocean.core.Traits;

import ocean.io.model.IConduit: ISelectable;

import ocean.stdc.posix.time: time_t, timespec, itimerspec, CLOCK_REALTIME;

import ocean.stdc.posix.sys.types: ssize_t;

import ocean.stdc.posix.unistd: read, close;

import ocean.stdc.errno: EAGAIN, EWOULDBLOCK, errno;



/*******************************************************************************

    Definitions of external constants and functions required to manage timer
    events.

*******************************************************************************/

/// <sys/timerfd.h>

const TFD_TIMER_ABSTIME = 1,
      TFD_CLOEXEC       = 0x80000, // octal 02000000
      TFD_NONBLOCK      = 0x800;   // octal 04000

/// <linux/time.h>

const CLOCK_MONOTONIC = 1;

// TODO: move into C bindings

extern (C)
{
    /**************************************************************************

        Creates a new timer object.

        The file descriptor supports the following operations:

        read(2)
               If  the timer has already expired one or more times since its
               settings were last modified using timerfd_settime(), or since the
               last successful read(2), then the buffer given to read(2) returns
               an unsigned 8-byte integer (uint64_t) containing  the  number of
               expirations that have occurred.  (The returned value is in host
               byte order, i.e., the native byte order for integers on the host
               machine.)

               If no timer expirations have occurred at the time of the read(2),
               then the call either blocks until the next timer  expiration, or
               fails with the error EAGAIN if the file descriptor has been made
               non-blocking (via the use of the fcntl(2) F_SETFL operation to
               set the O_NONBLOCK flag).

               A read(2) will fail with the error EINVAL if the size of the
               supplied buffer is less than 8 bytes.

        poll(2), select(2) (and similar)
               The file descriptor is readable (the select(2) readfds argument;
               the poll(2) POLLIN flag) if one or more timer expirations have
               occurred.

               The file descriptor also supports the other file-descriptor
               multiplexing APIs: pselect(2), ppoll(2), and epoll(7).

        close(2)
               When  the  file descriptor is no longer required it should be
               closed.  When all file descriptors associated with the same timer
               object have been closed, the timer is disarmed and its resources
               are freed by the kernel.

        fork(2) semantics
            After a fork(2), the child inherits a copy of the file descriptor
            created by timerfd_create().  The file descriptor refers to the same
            underlying  timer  object  as the corresponding file descriptor in
            the parent, and read(2)s in the child will return information about
            expirations of the timer.

        execve(2) semantics
            A file descriptor created by timerfd_create() is preserved across
            execve(2), and continues to generate timer expirations if the  timer
            was armed.

        Params:
            clockid = Specifies the clock  that is used to mark the progress of
                      the timer, and must be either CLOCK_REALTIME or
                      CLOCK_MONOTONIC.
                      - CLOCK_REALTIME is a settable system-wide clock.
                      - CLOCK_MONOTONIC is a non-settable clock that is not
                          affected by discontinuous changes in the system clock
                          (e.g., manual changes to system time). The current
                          value of each of these clocks can be retrieved using
                          clock_gettime(2).

            flags   = Starting with Linux 2.6.27: 0 or a bitwise OR combination
                      of
                      - TFD_NONBLOCK: Set the O_NONBLOCK file status flag on the
                            new open file description.
                      - TFD_CLOEXEC: Set the close-on-exec (FD_CLOEXEC) flag on
                            the new file descriptor. (See the description of the
                            O_CLOEXEC  flag  in open(2) for reasons why this may
                            be useful.)

                      Up to Linux version 2.6.26: Must be 0.

        Returns:
            a file descriptor that refers to that timer

     **************************************************************************/

    int timerfd_create(int clockid, int flags = 0);


    /**************************************************************************

        Sets next expiration time of interval timer source fd to new_value.

        Params:
            fd        = file descriptor referring to the timer

            flags     = 0 starts a relative timer using new_value.it_interval;
                        TFD_TIMER_ABSTIME starts an absolute timer using
                        new_value.it_value.

            new_value = - it_value: Specifies the initial expiration of the
                            timer. Setting either field to a non-zero value arms
                            the timer. Setting both fields to zero disarms the
                            timer.
                        - it_interval: Setting one or both fields to non-zero
                            values specifies the period for repeated timer
                            expirations after the initial expiration. If both
                            fields are zero, the timer expires just once, at the
                            time specified by it_value.

            old_value = Returns the old expiration time as timerfd_gettime().

        Returns:
            0 on success or -1 on error. Sets errno in case of error.

     **************************************************************************/

    int timerfd_settime(int fd, int flags,
                        itimerspec* new_value,
                        itimerspec* old_value);


    /**************************************************************************

        Returns the next expiration time of fd.

        Params:
            fd         = file descriptor referring to the timer
            curr_value = - it_value:
                             Returns the amount of time until the timer will
                             next expire. If both fields are zero, then the
                             timer is currently disarmed. Contains always a
                             relative value, regardless of whether the
                             TFD_TIMER_ABSTIME flag was specified when setting
                             the timer.
                        - it_interval: Returns the interval of the timer. If
                             both fields are zero, then the timer is set to
                             expire just once, at the time specified by
                             it_value.

        Returns:
            0 on success or -1 on error. Sets errno in case of error.

     **************************************************************************/

    int timerfd_gettime(int fd, itimerspec* curr_value);
}



/*******************************************************************************

    Timer fd class -- can be used in an allocation-free context if instantiated
    with the ctor which accepts an exception instance.

*******************************************************************************/

public class TimerFD : ISelectable
{
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
        this.fd = this.e.enforceRet!(.timerfd_create)(&verify)
            .call(realtime ? CLOCK_REALTIME : CLOCK_MONOTONIC, TFD_NONBLOCK);
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
        this.e.enforceRetCode!(timerfd_gettime)().call(this.fd, &t);
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

        this.e.enforceRetCode!(timerfd_settime)().call(
            this.fd,
            this.absolute? TFD_TIMER_ABSTIME : 0,
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
