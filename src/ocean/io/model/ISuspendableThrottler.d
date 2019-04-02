/*******************************************************************************

    Abstract base classes for suspendable throttlers.

    Provides a simple mechanism for throttling a set of one or more suspendable
    processes based on some condition (as defined by a derived class).

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.model.ISuspendableThrottler;

import ocean.transition;


/*******************************************************************************

    Abstract base class for suspendable throttlers.

    Provides the following functionality:
        * Maintains a set of ISuspendables which are suspended / resumed
          together.
        * A throttle() method, to be called when the suspension state should be
          updated / reassessed.
        * Abstract suspend() and resume() methods which define the conditions
          for suspension and resumption of the set of ISuspendables.
        * A suspended() method to tell whether the ISuspendables are suspended.

*******************************************************************************/

abstract public class ISuspendableThrottler
{
    import ocean.io.model.ISuspendable;

    import ocean.core.array.Mutation : moveToEnd;
    import ocean.core.array.Search : contains;

    /***************************************************************************

        List of suspendables which are to be throttled. Suspendables are added
        to the list with the addSuspendable() method, and can be cleared by clear().

    ***************************************************************************/

    private ISuspendable[] suspendables;


    /***************************************************************************

        Flag set to true when the suspendables are suspended.

    ***************************************************************************/

    private bool suspended_;


    /***************************************************************************

        Adds a suspendable to the list of suspendables which are to be
        throttled if it's not already in there.
        Also ensures that the state of the added suspendable is consistent
        with the state of the throttler.

        Params:
            s = suspendable

    ***************************************************************************/

    public void addSuspendable ( ISuspendable s )
    {
        if (!this.suspendables.contains(s))
        {
            this.suspendables ~= s;
        }

        if (this.suspended_ != s.suspended())
        {
            if (this.suspended_)
                s.suspend();
            else
                s.resume();
        }
    }

    unittest
    {
        import ocean.core.Test;

        static class SuspendableThrottler : ISuspendableThrottler
        {
            override protected bool suspend ( )
            {
                return false;
            }

            override protected bool resume ( )
            {
                return false;
            }
        }

        static class Suspendable : ISuspendable
        {
            bool suspended_ = false;

            public void suspend ( )
            {
                this.suspended_ = true;
            }

            public void resume ( )
            {
                this.suspended_ = false;
            }

            public bool suspended ( )
            {
                return this.suspended_;
            }
        }

        auto suspendable_throttler = new SuspendableThrottler;
        auto suspendable = new Suspendable;

        // add a suspended ISuspendable to a non suspended throttler
        suspendable.suspend();
        suspendable_throttler.addSuspendable(suspendable);

        test!("==")(suspendable.suspended(), false,
            "Suspended suspendable not resumed.");

        suspendable_throttler.suspendAll();

        // add a resumed ISuspendable to a suspended throttler
        suspendable.resume();
        suspendable_throttler.addSuspendable(suspendable);

        test!("==")(suspendable.suspended(), true,
            "Resumed suspendable not suspended.");
    }

    /***************************************************************************

        Removes a suspendable from the list of suspendables if it exists.

        Params:
            s = suspendable

    ***************************************************************************/

    public void removeSuspendable ( ISuspendable s )
    {
        this.suspendables =
            this.suspendables[0 .. this.suspendables.moveToEnd(s)];
        enableStomping(suspendables);
    }

    unittest
    {
        class Throttler : ISuspendableThrottler
        {
            override protected bool suspend ( )
            {
                return false;
            }

            override protected bool resume ( )
            {
                return true;
            }
        }

        class Suspendable : ISuspendable
        {
            public void suspend ( ) { }
            public void resume ( ) { }
            public bool suspended ( )
            {
                return false;
            }

        }

        auto throttler = new Throttler;
        auto suspendable = new Suspendable;

        throttler.addSuspendable(suspendable);
        throttler.removeSuspendable(suspendable);
        throttler.addSuspendable(suspendable);
    }

    /***************************************************************************

        Returns:
            true if the suspendables are currently suspended.

    ***************************************************************************/

    public bool suspended ( )
    {
        return this.suspended_;
    }


    /***************************************************************************

        Clears the list of suspendables.

    ***************************************************************************/

    public void clear ( )
    {
        this.suspendables.length = 0;
        enableStomping(this.suspendables);
        this.suspended_ = false;
    }

    /***************************************************************************

        Checks if the suspend limit has been reached and the suspendables need
        to be suspended.

    ***************************************************************************/

    public void throttledSuspend ( )
    {
        if (!this.suspended_ && this.suspend())
            this.suspendAll();
    }

    /***************************************************************************

        Checks if resume limit has been reached and the suspendables need to be
        resumed.

    ***************************************************************************/

    public void throttledResume ( )
    {
        if (this.suspended_ && this.resume())
            this.resumeAll();
    }

    /***************************************************************************

        Decides whether the suspendables should be suspended. Called by
        throttledSuspend() when not suspended.

        Returns:
            true if the suspendables should be suspeneded

    ***************************************************************************/

    abstract protected bool suspend ( );


    /***************************************************************************

        Decides whether the suspendables should be resumed. Called by
        throttledResume() when suspended.

        Returns:
            true if the suspendables should be resumed

    ***************************************************************************/

    abstract protected bool resume ( );


    /***************************************************************************

        Resumes all suspendables and sets the suspended_ flag to false.

        Note that the suspended_ flag is set before resuming the suspendables
        in order to avoid a race condition when the resumption of a suspendable
        performs actions which would cause the throttle() method to be
        called again.

    ***************************************************************************/

    private void resumeAll ( )
    {
        this.suspended_ = false;
        foreach ( s; this.suspendables )
        {
            s.resume();
        }
    }


    /***************************************************************************

        Suspends all suspendables and sets the suspended_ flag to true.

        Note that the suspended_ flag is set before suspending the suspendables
        in order to avoid a race condition when the suspending of a suspendable
        performs actions which would cause the throttle() method to be
        called again.

    ***************************************************************************/

    private void suspendAll ( )
    {
        this.suspended_ = true;
        foreach ( s; this.suspendables )
        {
            s.suspend();
        }
    }
}
