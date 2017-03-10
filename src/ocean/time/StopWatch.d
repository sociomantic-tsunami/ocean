/*******************************************************************************

        Copyright:
            Copyright (c) 2007 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Feb 2007: Initial release

        Authors: Kris

*******************************************************************************/

module ocean.time.StopWatch;

// CLOCK_MONOTONIC and clock_gettime will be added to core.sys.posix.time in
// tangort v1.7.0, see tangort issue #6.
import core.sys.posix.time; // clockid_t, timespec
extern (C) private
{
    enum: clockid_t
    {
        CLOCK_MONOTONIC = 1
    }

    int clock_gettime(clockid_t clk_id, timespec* t);
}

/*******************************************************************************

        Timer for measuring small intervals, such as the duration of a
        subroutine or other reasonably small period.
        ---
        StopWatch elapsed;

        elapsed.start;

        // do something
        // ...

        double i = elapsed.stop;
        ulong us = elapsed.microsec;
        ---

        The measured interval is either an integer value in units of
        microseconds -- returned by `microsec` -- or a floating-point value in
        units of seconds with fractions -- returned by `stop`.
        The integer value has always a precision of 1µs and is recommended if
        you want to compare it with reference values such as checking if it's
        below or above 1ms (e.g. `elapsed.microsec <= 1000`).
        Although floating-point representation seems often more convenient, bear
        in mind that
          - The precision is relative to the value (i.e. the greater the values
            the lower the absolute precision).
          - Comparing fractions can yield unexpected results due to rounding and
            because decimal fractions have no exact binary floating-point
            representation. To avoid surprises like this using the integer
            represenation of time spans is in general recommended.

        There is some minor overhead in using StopWatch, so take that into
        account

*******************************************************************************/

public struct StopWatch
{
         // TODO: From tangort v1.7.0 import clock_gettime and CLOCK_MONOTONIC.
        import core.sys.posix.time: timespec;

        import ocean.core.Exception_tango: PlatformException;

        private ulong  started;
        private const double multiplier = 1.0 / 1_000_000.0;

        /***********************************************************************

                Start the timer

        ***********************************************************************/

        void start ()
        {
                started = timer;
        }

        /***********************************************************************

                Stop the timer and return elapsed duration since start()

        ***********************************************************************/

        double stop ()
        {
                return multiplier * (timer - started);
        }

        /***********************************************************************

                Return elapsed time since the last start() as microseconds

        ***********************************************************************/

        ulong microsec ()
        {
                 return (timer - started);
        }

        /***********************************************************************

                Return the current time as an Interval

        ***********************************************************************/

        private static ulong timer ()
        {
                timespec t;
                if (clock_gettime(CLOCK_MONOTONIC, &t))
                    throw new PlatformException ("Timer :: CLOCK_MONOTONIC is not available");

                return t.tv_sec * 1_000_000UL + t.tv_nsec / 1_000UL;
        }
}


/*******************************************************************************

*******************************************************************************/

debug (StopWatch)
{
        import ocean.io.Stdout_tango;

        void main()
        {
                StopWatch t;
                t.start;

                for (int i=0; i < 100_000_000; ++i)
                    {}
                Stdout.format ("{:f9}", t.stop).newline;
        }
}
