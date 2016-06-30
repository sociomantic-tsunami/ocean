/*******************************************************************************

    Informational interface to an EpollSelectDispatcher instance.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.select.selector.IEpollSelectDispatcherInfo;



public interface IEpollSelectDispatcherInfo
{
    /***************************************************************************

        Returns:
            the number of currently registered clients

    ***************************************************************************/

    size_t num_registered ( );


    version ( EpollCounters )
    {
        /***********************************************************************

            Returns:
                the number of select calls (epoll_wait()) since the instance was
                created (or since the ulong counter wrapped)

        ***********************************************************************/

        ulong selects ( );


        /***********************************************************************

            Returns:
                the number of select calls (epoll_wait()) which exited due to a
                timeout (as opposed to a client firing) since the instance was
                created (or since the ulong counter wrapped)

        ***********************************************************************/

        ulong timeouts ( );


        /***********************************************************************

            Resets the counters returned by selects() and timeouts().

        ***********************************************************************/

        void resetCounters ( );
    }
}

