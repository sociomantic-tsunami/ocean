/*******************************************************************************

    Counts how often a certain type of logger has been used

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.log.CounterAppender;

import ocean.transition;

import ocean.util.log.Appender;
import ocean.util.log.Event;

/*******************************************************************************

    Counts how often a certain type of logger has been used

*******************************************************************************/

public class CounterAppender : Appender
{
        private Mask mask_;

        /***********************************************************************

                Arraymap containing the counters

        ***********************************************************************/

        private static size_t[istring] counter;

        /***********************************************************************


        ***********************************************************************/

        this ( )
        {
                mask_ = register (name);
        }

        /***********************************************************************

                Return the fingerprint for this class

        ***********************************************************************/

        final override Mask mask ()
        {
                return mask_;
        }

        /***********************************************************************

                Return the name of this class

        ***********************************************************************/

        final override cstring name ()
        {
                return this.classinfo.name;
        }

        /***********************************************************************

                Append an event to the output.

        ***********************************************************************/

        final override void append (LogEvent event)
        {
              counter[event.name]++;
        }

        /***********************************************************************

            Returns the value of the counter of the given logger.
            Resets the value before returning it.

            Params:
                name = name of the logger

            Returns:
                the value of the counter

        ***********************************************************************/

        static public size_t opIndex ( istring name )
        {
            auto v = name in counter;

            if ( v is null ) return 0;

            auto ret = *v;

            *v = 0;

            return ret;
        }

        /***********************************************************************

            Returns the value of the counter of the given logger

            Params:
                name = name of the logger
                reset = whether to reset the counter

            Returns:
                the value of the counter

        ***********************************************************************/

        static public size_t get ( istring name, bool reset = true )
        {
            auto v = name in counter;

            if ( v is null ) return 0;

            auto ret = *v;

            if ( reset ) *v = 0;

            return ret;
        }

}
