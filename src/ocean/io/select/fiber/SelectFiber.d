/******************************************************************************

    Fiber that can register select clients in a dispatcher, optimizing
    re-registrations and event changes.

    MessageFiber that includes a select dispatcher and memorizes the last client
    it has registered to optimize registrations by skipping unnecessary
    register() or unregister() calls.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.io.select.fiber.SelectFiber;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.core.MessageFiber;

import core.thread;

import ocean.io.select.client.model.ISelectClient;
import ocean.io.select.client.model.ISelectClientInfo;

import ocean.io.select.EpollSelectDispatcher;

debug ( SelectFiber) import ocean.io.Stdout : Stderr;


/******************************************************************************/

public class SelectFiber : MessageFiber
{
    /**************************************************************************

        Epoll instance to use

     **************************************************************************/

    public EpollSelectDispatcher epoll;

    /**************************************************************************

        Currently registered select client

     **************************************************************************/

    private ISelectClient current = null;

    /**************************************************************************

        Constructor

        Params:
           epoll = EpollSelectDispatcher instance
           fiber = already created core.thread.Fiber

     **************************************************************************/

    this ( EpollSelectDispatcher epoll, Fiber fiber )
    {
        this.epoll = epoll;

        super(fiber);
    }

    /**************************************************************************

        Constructor

        Params:
           epoll = EpollSelectDispatcher instance
           coroutine = fiber coroutine

     **************************************************************************/

    this ( EpollSelectDispatcher epoll, void delegate ( ) coroutine )
    {
        this.epoll = epoll;

        super(coroutine);
    }

    /**************************************************************************

        Constructor

        Params:
            epoll = EpollSelectDispatcher instance
            coroutine = fiber coroutine
            sz      = fiber stack size

     **************************************************************************/

    this ( EpollSelectDispatcher epoll, void delegate ( ) coroutine, size_t sz )
    {
        this.epoll = epoll;

        super(coroutine, sz);
    }

    /**************************************************************************

        Allows to change underlying core.thread.Fiber instance. Unregisters
        the ISelectClient if necessary.

        Params:
            fiber = new fiber instance to use

    **************************************************************************/

    override public void reset ( Fiber fiber )
    {
        this.unregister();
        super.reset(fiber);
    }

    /**************************************************************************

        Registers client in epoll and sets client to the current client.

        Params:
            client = select client to register

        Returns:
            true if an epoll registration was actually added or modified or
            false if the client was the currently registered client.

     **************************************************************************/

    public bool register ( ISelectClient client )
    in
    {
        assert(client !is null);
    }
    body
    {
        debug ( SelectFiber) Stderr.formatln("{}.register fd {}:",
                typeof(this).stringof, client.fileHandle);

        if ( this.current is null )
        {
            // No client is currently registered: Add an epoll registration for
            // the a new client.

            debug ( SelectFiber) Stderr.formatln("   Register new {}", client);

            this.epoll.register(this.current = client);

            return true;
        }
        else if ( this.current is client )
        {
            // The currently registered client is used for another I/O
            // operation: Only refresh the timeout registration of the client,
            // no need to change the epoll registration.

            debug ( SelectFiber)
            {
                Stderr.formatln("   Leaving registered {}", this.current);
            }

            // As there is not way to modify a registration with the
            // timeout manager, it is necessary to call unregistered(), then
            // registered() even if this.current and client are identical. This
            // ensures that, even if the epoll registration doesn't need to be
            // updated, that the timeout timeout registration is updated
            // correctly.

            this.current.unregistered();
            client.registered();

            return false;
        }
        else if ( this.current.fileHandle == client.fileHandle )
        {
            // The currently registered client and the new client share the same
            // I/O device: Update the epoll registration of the I/O device to
            // the new client.

            debug ( SelectFiber)
            {
                Stderr.formatln("   Changing event registration {}",
                    this.current);
                Stderr.formatln("   Register {}", client);
            }

            this.epoll.changeClient(this.current, client);

            this.current = client;

            return true;
        }
        else
        {
            // The currently registered client and the new client have different
            // I/O devices: Unregister the epoll registration of the current
            // client and register the new client instead.

            debug ( SelectFiber) Stderr.formatln("   Unregister {}",
                this.current);

            this.epoll.unregister(this.current);

            debug ( SelectFiber) Stderr.formatln("   Register {}", client);

            this.epoll.register(this.current = client);

            return true;
        }
    }

    /**************************************************************************

        Unegisters the current client from epoll and clears it, if any.

        Returns:
            true if the current client was unregistered or false if there was
            no current client.

     **************************************************************************/

    public bool unregister ( )
    {
        if ( this.current !is null )
        {
            debug ( SelectFiber) Stderr.formatln("{}.unregister fd {}",
                    typeof(this).stringof, this.current.fileHandle);

            this.epoll.unregister(this.current);
            this.current = null;

            return true;
        }
        else
        {
            return false;
        }
    }

    /**************************************************************************

        Checks if client is identical to the current client.
        Note that the client instance is compared, not the client conduit,
        file descriptor or events.

        Params:
            client = client to compare for identity with the current client,
                     pass null to check if there is no current client.

        Returns:
            true if client is the current client or false otherwise.

     **************************************************************************/

    public bool isRegistered ( ISelectClient client )
    {
        return this.current is client;
    }

    /**************************************************************************

        Clears the current client; usually called from the client finalizer.

        Note that the client does not need to be unregistered here, as the epoll
        selector always unregisters the client after calling its finalizer.

        Returns:
            true if there actually was a current client or false otherwise.

     **************************************************************************/

    public bool clear ( )
    {
        scope (success) this.current = null;

        return this.current !is null;
    }

    /**************************************************************************

        Returns:
            informational interface to currently registered client (null if no
            client is registered)

     **************************************************************************/

    public ISelectClientInfo registered_client ( )
    {
        return this.current;
    }
}


