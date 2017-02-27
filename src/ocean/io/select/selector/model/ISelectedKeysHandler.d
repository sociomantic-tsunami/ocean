/*******************************************************************************

    Interface for SelectedKeysHandler.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.select.selector.model.ISelectedKeysHandler;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.sys.Epoll: epoll_event_t;

/******************************************************************************/

interface ISelectedKeysHandler
{
    /***************************************************************************

        Handles the clients in selected_set.

        Params:
            selected_set = the result list of epoll_wait()
            unhandled_exception_hook = delegate to call for client exceptions

    ***************************************************************************/

    void opCall ( epoll_event_t[] selected_set,
        void delegate (Exception) unhandled_exception_hook );
}
