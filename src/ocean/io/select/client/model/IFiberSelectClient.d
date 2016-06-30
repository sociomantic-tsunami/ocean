/******************************************************************************

    Base class for fiber based registrable client objects for the
    SelectDispatcher

    Contains the five things that the fiber based SelectDispatcher needs:
        1. the I/O device instance,
        2. the I/O events to register the device for,
        3. the event handler to invoke when an event occured for the device,
        4. the finalizer that resumes the fiber,
        5. the error handler that kills the fiber.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.io.select.client.model.IFiberSelectClient;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.io.select.client.model.ISelectClient;

import ocean.io.select.fiber.SelectFiber;

import ocean.io.select.EpollSelectDispatcher;

import ocean.core.Exception_tango: IOException;


/******************************************************************************

    IFiberSelectClient abstract class

 ******************************************************************************/

abstract class IFiberSelectClient : IAdvancedSelectClient
{
    /**************************************************************************

        Type alias for subclass constructors

     **************************************************************************/

    public alias .SelectFiber SelectFiber;

    /**************************************************************************

        Fiber instance

        Note that the instance is not const, as it is occasionally useful to be
        able to change the select client's fiber after construction. An example
        of this use case would be when a select client instance is created for
        use with a socket connection (i.e. fd, i.e. fiber), but then, some time
        later, needs to be re-used for a different socket connection -
        necessitating a fiber switch.

     **************************************************************************/

    public SelectFiber fiber;

    /**************************************************************************

        The fiber must always be non-null.

     **************************************************************************/

    invariant ( )
    {
        assert(this.fiber !is null, typeof(this).stringof ~ " fiber is null");
    }

    /**************************************************************************

        Flag set to true when the error_() method is called due to an I/O error
        event. The flag is always reset in the finalize() method.

     **************************************************************************/

    public bool io_error;

    /**************************************************************************

        Constructor

        Params:
            fiber   = fiber to resume on finalize() or kill on error()

     **************************************************************************/

    protected this ( SelectFiber fiber )
    {
        this.fiber = fiber;
    }

    /**************************************************************************

        Finalize method, called after this instance has been unregistered from
        the Dispatcher; kills the fiber and calls the super-class' finalize()
        method (which calls a finalizer delegate, if one has been set).

        The fiber must be waiting or finished as it is ought to be when in
        Dispatcher context.

        Params:
            status = status why this method is called

     **************************************************************************/

    public override void finalize ( FinalizeStatus status )
    {
        assert (!this.fiber.running);

        try
        {
            if (this.fiber.waiting)
            {
                this.fiber.kill();
            }

            this.fiber.clear();
            super.finalize(status);
        }
        finally
        {
            this.io_error = false;
        }
    }

    /**************************************************************************

        Error reporting method, called when either an Exception is caught from
        handle() or an error event is reported; kills the fiber.

        Params:
            e = Exception thrown by handle()
            event     = Selector event while exception was caught

     **************************************************************************/

    protected override void error_ ( Exception e, Event event )
    {
        this.io_error = cast(IOException)e !is null;

        if (this.fiber.waiting)
        {
            this.fiber.kill(__FILE__, __LINE__);
        }

        super.error_(e, event);
    }


    /**************************************************************************

        Timeout method, called after this a timeout has occurred in the
        SelectDispatcher; kills the fiber.

     **************************************************************************/

    override public void timeout ( )
    {
        if (this.fiber.waiting)
        {
            this.fiber.kill(__FILE__, __LINE__);
        }

        super.timeout();
    }
}

