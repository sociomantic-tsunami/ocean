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

import ocean.core.ExceptionDefinitions;

/*******************************************************************************

*******************************************************************************/

version (Posix)
{
        import ocean.stdc.posix.sys.time;
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
        ---

        The measured interval is in units of seconds, using floating-
        point to represent fractions. This approach is more flexible
        than integer arithmetic since it migrates trivially to more
        capable timer hardware (there no implicit granularity to the
        measurable intervals, except the limits of fp representation)

        StopWatch is accurate to the extent of what the underlying OS
        supports. On linux systems, this accuracy is typically 1 us at
        best. Win32 is generally more precise.

        There is some minor overhead in using StopWatch, so take that into
        account

*******************************************************************************/

public struct StopWatch
{
        private ulong  started;
        private static double multiplier = 1.0 / 1_000_000.0;

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
                version (Posix)
                         return (timer - started);
        }

        /***********************************************************************

                Return the current time as an Interval

        ***********************************************************************/

        private static ulong timer ()
        {
                version (Posix)
                {
                        timeval tv;
                        if (gettimeofday (&tv, null))
                            throw new PlatformException ("Timer :: linux timer is not available");

                        return (cast(ulong) tv.tv_sec * 1_000_000) + tv.tv_usec;
                }
        }
}


/*******************************************************************************

*******************************************************************************/

debug (StopWatch)
{
        import ocean.io.Stdout;

        void main()
        {
                StopWatch t;
                t.start;

                for (int i=0; i < 100_000_000; ++i)
                    {}
                Stdout.format ("{:f9}", t.stop).newline;
        }
}
