/*******************************************************************************

    Test for EpollSelectDispatcher.unregister behaviour

    Copyright:
        Copyright (c) 2018 sociomantic labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module integrationtest.unregisterclient.main;

import ocean.transition;

import ocean.io.select.EpollSelectDispatcher;
import ocean.io.select.client.SelectEvent;
import ocean.core.Test;

private EpollSelectDispatcher epoll;

private SelectEvent event1, event2;
private int count;

// Corrupts the SelectEvent object. This should make test
// segfault at access
private void corruptEventObject (SelectEvent client)
{
    version (D_Version2)
    {
        auto initializer = client.classinfo.initializer();
    }
    else
    {
        auto initializer = client.classinfo.init;
    }

    ubyte* ptr = cast(ubyte*)client;
    ptr[0..initializer.length] = 0;
}

version(UnitTest) {} else
void main(istring[] args)
{
    bool handler1()
    {
        .count++;

        // unregister and delete the other instance
        .epoll.unregister(.event2, true);
        corruptEventObject(.event2);

        return false;
    }

    bool handler2()
    {
        .count++;

        // unregister and delete the other instance
        .epoll.unregister(.event1, true);
        corruptEventObject(.event1);

        return false;
    }

    .epoll = new EpollSelectDispatcher();

    .event1 = new SelectEvent(&handler1);
    .event2 = new SelectEvent(&handler2);

    .epoll.register(.event1);
    .epoll.register(.event2);

    // trigger them both
    .event1.trigger();
    .event2.trigger();

    // Do a select loop
    .epoll.eventLoop();

    // Make sure only one was handled.
    test!("==")(.count, 1);
}
