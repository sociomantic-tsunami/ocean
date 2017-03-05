/*******************************************************************************

    Manages ITimeoutClient instances where each one has an individual timeout
    value.

    To use the timeout manager, create a TimeoutManager subclass capable of
    these two things:
        1. It implements setTimeout() to set a timer that expires at the wall
           clock time that is passed to setTimeout() as argument.
        2. When the timer is expired, it calls checkTimeouts().

    Objects that can time out, the so-called timeout clients, must implement
    ITimeoutClient. For each client create an ExpiryRegistration instance and
    pass the object to the ExpiryRegistration constructor.
    Call ExpiryRegistration.register() to set a timeout for the corresponding
    client. When checkTimeouts() is called, it calls the timeout() method of
    each timed out client.


    Link with:
        -Llibebtree.a

    Build flags:
        -debug=TimeoutManager = verbose output

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.time.timeout.TimeoutManager;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.time.timeout.model.ITimeoutManager,
       ocean.time.timeout.model.ITimeoutClient,
       ocean.time.timeout.model.IExpiryRegistration,
       ocean.time.timeout.model.ExpiryRegistrationBase;                 // ExpiryTree, Expiry, ExpiryRegistrationBase

import ocean.time.MicrosecondsClock;

import ocean.util.container.AppendBuffer;


import ocean.util.container.map.Map,
       ocean.util.container.map.model.StandardHash,
       ocean.util.container.map.model.IAllocator;

import ocean.transition;

debug
{
    import ocean.io.Stdout;
    import core.stdc.time: time_t, ctime;
    import core.stdc.string: strlen;
}

/*******************************************************************************

    Timeout manager

*******************************************************************************/

class TimeoutManager : TimeoutManagerBase
{
    /***************************************************************************

        Expiry registration class for an object that can time out.

    ***************************************************************************/

    public class ExpiryRegistration : ExpiryRegistrationBase
    {
        /***********************************************************************

            Constructor

            Params:
                client = object that can time out

        ***********************************************************************/

        public this ( ITimeoutClient client )
        {
            super(this.outer.new TimeoutManagerInternal);
            super.client = client;
        }

        /***********************************************************************

            Identifier string for debugging.

        ***********************************************************************/

        debug public override cstring id ( )
        {
            return super.client.id;
        }
    }


    /***************************************************************************

        Constructor.

            n = expected number of elements in expiry registration to
                ISelectClient map
            allocator = use this bucket element allocator for the expiry
                registration to ISelectClient map. If it is null the default map
                allocator (BucketElementGCAllocator) is used.

    ***************************************************************************/

    public this ( size_t n = 1024, IAllocator allocator = null )
    {
        super(n, allocator);
    }

    /***************************************************************************

        Creates a new expiry registration instance, associates client with it
        and registers client with this timeout manager.
        The returned object should be reused. The client will remain associated
        to the expiry registration after it has been unregistered from the
        timeout manager.

        Params:
            client = client to register

        Returns:
            new expiry registration object with client associated to.

    ***************************************************************************/

    public IExpiryRegistration getRegistration ( ITimeoutClient client )
    {
        return this.new ExpiryRegistration(client);
    }
}

/*******************************************************************************

    Timeout manager base class. Required for derivation because inside a
    TimeoutManager subclass a nested ExpiryRegistration subclass is impossible.

*******************************************************************************/

abstract class TimeoutManagerBase : ITimeoutManager
{
    /***************************************************************************

        Enables IExpiryRegistration to access TimeoutManager internals.

    ***************************************************************************/

    protected class TimeoutManagerInternal : ExpiryRegistrationBase.ITimeoutManagerInternal
    {
        /***********************************************************************

            Registers registration and sets the timeout for its client.

            Params:
                registration = IExpiryRegistration instance to register
                timeout_us   = timeout in microseconds from now

            Returns:
                expiry token: required for unregister(); the "key" member is the
                wall clock time of expiration as UNIX time in microseconds.

        ***********************************************************************/

        Expiry* register ( IExpiryRegistration registration, ulong timeout_us )
        {
            return this.outer.register(registration, timeout_us);
        }

        /***********************************************************************

            Unregisters IExpiryRegistration instance corresponding to expiry.

            Params:
                expiry = expiry token returned by register() when registering
                         the IExpiryRegistration instance to unregister

            In:
                Must not be called from within timeout().

        ***********************************************************************/

        void unregister ( ref Expiry expiry )
        {
            this.outer.unregister(expiry);
        }

        /***********************************************************************

            Returns:
                the current wall clock time as UNIX time in microseconds.

        ***********************************************************************/

        ulong now ( )
        {
            return this.outer.now();
        }
    }

    /***************************************************************************

        EBTree storing expiry time of registred clients in terms of microseconds
        since the construction of this object (for direct comparison against
        this.now_).

    ***************************************************************************/

    private ExpiryTree expiry_tree;


    /***************************************************************************

        Array map mapping from an expiry registration ( a node in the tree of
        expiry times) to an ISelectClient.

    ***************************************************************************/

    static class ExpiryToClient : Map!(IExpiryRegistration, Expiry*)
    {
        /***********************************************************************

            Constructor.

            Params:
                n = expected number of elements in mapping
                allocator = use this bucket element allocator for the map. If it
                    is null the default allocator is used.

        ***********************************************************************/

        public this ( size_t n, IAllocator allocator = null )
        {
            // create the map with the default allocator
            // BucketElementGCAllocator
            if ( allocator is null )
            {
                super(n);
            }
            else
            {
                super(allocator, n);
            }
        }

        protected override hash_t toHash ( Expiry* expiry )
        {
            return StandardHash.fnv1aT(expiry);
        }
    }


    private ExpiryToClient expiry_to_client;

    /***************************************************************************

        List of expired registrations. Used by the checkTimeouts() method.

    ***************************************************************************/

    private AppendBuffer!(IExpiryRegistration) expired_registrations;

    /***************************************************************************

        Constructor.

            n = expected number of elements in expiry registration to
                ISelectClient map
            allocator = use this bucket element allocator for the expiry
                registration to ISelectClient map. If it is null the default
                allocator (BucketElementGCAllocator) is used.

    ***************************************************************************/

    protected this ( size_t n = 1024, IAllocator allocator = null )
    {
        this.expiry_tree           = new ExpiryTree;
        this.expiry_to_client      = new ExpiryToClient(n, allocator);
        this.expired_registrations = new AppendBuffer!(IExpiryRegistration)(n);
    }


    /***************************************************************************

        Tells the wall clock time time when the next client will expire.

        Returns:
            the wall clock time when the next client will expire as UNIX time
            in microseconds or ulong.max if no client is currently registered.

    ***************************************************************************/

    public ulong next_expiration_us ( )
    {
        Expiry* expiry = this.expiry_tree.first;

        ulong us = expiry? expiry.key : ulong.max;

        debug ( TimeoutManager ) if (!this.next_expiration_us_called_from_internal)
        {
            this.next_expiration_us_called_from_internal = false;

            Stderr("next expiration: ");

            if (us < us.max)
            {
                this.printTime(us);
            }
            else
            {
                Stderr("∞\n").flush();
            }
        }

        return us;
    }

    /***************************************************************************

        Tells the time left until the next client will expire.

        Returns:
            the time left until next client will expire in microseconds or
            ulong.max if no client is currently registered. 0 indicates that
            there are timed out clients that have not yet been notified and
            unregistered.

    ***************************************************************************/

    public ulong us_left ( )
    {
        Expiry* expiry = this.expiry_tree.first;

        if (expiry)
        {
            ulong next_expiration_us = expiry.key,
                  now                = this.now;

            debug ( TimeoutManager )
            {
                ulong us = next_expiration_us > now? next_expiration_us - now : 0;

                this.printTime(now, false);
                Stderr(": ")(us)(" µs left\n").flush();

                return us;
            }
            else
            {
                return next_expiration_us > now? next_expiration_us - now : 0;
            }
        }
        else
        {
            return ulong.max;
        }
    }

    /***************************************************************************

        Returns:
            the number of registered clients.

    ***************************************************************************/

    public size_t pending ( )
    {
        return this.expiry_tree.length;
    }

    /***************************************************************************

        Returns the current wall clock time according to gettimeofday().

        Returns:
            the current wall clock time as UNIX time value in microseconds.

    ***************************************************************************/

    public final ulong now ( )
    {
        return MicrosecondsClock.now_us();
    }

    /***************************************************************************

        Checks for timed out clients. For any timed out client its timeout()
        method is called, then it is unregistered, finally dg() is called with
        it as argument.

        This method should be called when the timeout set by setTimeout() has
        expired.

        If dg returns false to cancel, the clients iterated over so far are
        removed. To remove the remaining clients, call this method again.

        Params:
            dg = optional callback delegate that will be called with each timed
                 out client and must return true to continue or false to cancel.

        Returns:
            the number of expired clients.

    ***************************************************************************/

    public size_t checkTimeouts ( bool delegate ( ITimeoutClient client ) dg = null )
    {
        return this.checkTimeouts(this.now, dg);
    }

    public size_t checkTimeouts ( ulong now, bool delegate ( ITimeoutClient client ) dg = null )
    {
        debug ( TimeoutManager )
        {
            this.printTime(now, false);
            Stderr(" --------------------- checkTimeouts\n");

            this.next_expiration_us_called_from_internal = true;
        }

        ulong previously_next = this.next_expiration_us;

        this.expired_registrations.clear();

        // We first build up a list of all expired registrations, in order to
        // avoid the situation of the timeout() delegates potentially modifying
        // the tree while iterating over it.

        version (all)
        {
            scope expiries = this.expiry_tree.new PartIterator(now);

            foreach_reverse (ref expiry; expiries)
            {
                IExpiryRegistration registration = *this.expiry_to_client.get(&expiry);

                debug ( TimeoutManager ) Stderr('\t')(registration.id)(" timed out\n");

                this.expired_registrations ~= registration;
            }
        }
        else foreach (expiry, expire_time; this.expiry_tree.lessEqual(now))
        {
            IExpiryRegistration registration = this.expiry_to_client[expiry];

            debug ( TimeoutManager ) Stderr('\t')(registration.id)(" timed out\n");

            this.expired_registrations ~= registration;
        }

        debug ( TimeoutManager ) Stderr.flush();

        // All expired registrations are removed from the expiry tree. They are
        // removed before the timeout() delegates are called in order to avoid
        // the situation of an expiry registration re-registering itself in its
        // timeout() method, thus being registered in the expiry tree twice.
        foreach (registration; this.expired_registrations[])
        {
            registration.unregister();
        }

        // Finally all expired registrations in the list are set to null and
        // the timeout is updated.
        scope ( exit )
        {
            this.expired_registrations[] = cast(IExpiryRegistration)null;

            this.setTimeout_(previously_next);
        }

        // The timeout() method of all expired registrations is called, until
        // the optional delegate returns false.
        foreach (ref registration; this.expired_registrations[])
        {
            ITimeoutClient client = registration.timeout();

            if (dg !is null) if (!dg(client)) break;
        }

        return this.expired_registrations.length;
    }

    /***************************************************************************

        Registers registration and sets the timeout for its client.

        Params:
            registration = IExpiryRegistration instance to register
            timeout_us   = timeout in microseconds from now

        Returns:
            expiry token: required for unregister(); the "key" member is the
            wall clock time of expiration as UNIX time in microseconds.

    ***************************************************************************/

    protected Expiry* register ( IExpiryRegistration registration, ulong timeout_us )
    out (expiry)
    {
        assert (expiry);
    }
    body
    {
        ulong now = this.now;

        ulong t = now + timeout_us;

        debug ( TimeoutManager ) this.next_expiration_us_called_from_internal = true;

        ulong previously_next = this.next_expiration_us;

        Expiry* expiry = this.expiry_tree.add(t);

        *this.expiry_to_client.put(expiry) = registration;

        debug ( TimeoutManager )
        {
            Stderr("----------- ");
            this.printTime(now, false);
            Stderr(" registered ")(registration.id)(" for ")(timeout_us)(" µs, times out at ");
            this.printTime(t, false);
            Stderr("\n\t")(this.expiry_tree.length)(" clients registered, first times out at ");
            this.printTime(this.expiry_tree.first.key, false);
            Stderr('\n');

            version (none) foreach (expiry, expire_time; this.expiry_tree.lessEqual(now + 20_000_000))
            {
                IExpiryRegistration registration = this.expiry_to_client[expiry];

                Stderr('\t')('\t')(registration.id)(" ");
                if ( expire_time <= now ) Stderr(" ** ");
                this.printTime(expire_time);
            }
        }

        this.setTimeout_(previously_next);

        return expiry;
    }

    /***************************************************************************

        Unregisters the IExpiryRegistration instance corresponding to expiry.

        Params:
            expiry = expiry token returned by register() when registering the
                     IExpiryRegistration instance to unregister

        Throws:
            Exception if no IExpiryRegistration instance corresponding to expiry
            is currently registered.

    ***************************************************************************/

    protected void unregister ( ref Expiry expiry )
    {
        debug ( TimeoutManager ) this.next_expiration_us_called_from_internal = true;

        ulong previously_next = this.next_expiration_us;

        debug ulong t = expiry.key;

        try try
        {
            this.expiry_to_client.remove(&expiry);
        }
        finally
        {
            this.expiry_tree.remove(expiry);
        }
        finally
        {
            debug ( TimeoutManager )
            {
                size_t n = this.expiry_tree.length;

                Stderr("----------- ");
                this.printTime(now, false);
                Stderr(" unregistered ");
                this.printTime(t, false);
                Stderr("\n\t")(n)(" clients registered");
                if (n)
                {
                    Stderr(", first times out at ");
                    this.printTime(this.expiry_tree.first.key, false);
                }
                Stderr('\n');
            }

            this.setTimeout_(previously_next);
        }
    }

    /***************************************************************************

        Called when the overall timeout needs to be set or changed.

        Params:
            next_expiration_us = wall clock time when the first client times
                                    out so that checkTimeouts() must be called.

    ***************************************************************************/

    protected void setTimeout ( ulong next_expiration_us ) { }

    /***************************************************************************

        Called when the last client has been unregistered so that the timer may
        be disabled.

    ***************************************************************************/

    protected void stopTimeout ( ) { }

    /***************************************************************************

        Calls setTimeout() or stopTimeout() if required.

        Params:
            previously_next = next expiration time before a client was
                                 registered/unregistered

    ***************************************************************************/

    private void setTimeout_ ( ulong previously_next )
    {
        Expiry* expiry = this.expiry_tree.first;

        if (expiry)
        {
            ulong next_now = expiry.key;

            if (next_now != previously_next)
            {
                this.setTimeout(next_now);
            }
        }
        else if (previously_next < previously_next.max)
        {
            this.stopTimeout();
        }
    }

    /***************************************************************************

        TODO: Remove debugging output.

    ***************************************************************************/

    debug ( TimeoutManager ):

    bool next_expiration_us_called_from_internal;

    /***************************************************************************

        Prints the current wall clock time.

    ***************************************************************************/

    void printTime ( bool nl = true )
    {
        this.printTime(this.now, nl);
    }

    /***************************************************************************

        Prints t.

        Params:
            t = wall clock time as UNIX time in microseconds.

    ***************************************************************************/

    static void printTime ( ulong t, bool nl = true )
    {
        time_t s  = cast (time_t) (t / 1_000_000);
        uint   us = cast (uint)   (t % 1_000_000);

        char* str = ctime(&s);

        Stderr(str[0 .. strlen(str) - 1])('.')(us);

        if (nl) Stderr('\n').flush();
    }
}
