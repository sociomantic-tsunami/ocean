/*******************************************************************************

    Posix functions for masking & unmasking signals.

    Masked signals will not be noted but will not fire. If a signal occurs one
    or more times while masked, when it is unmasked it will fire immediately.
    Signals are not queued, so if a signal fires multiple times while masked, it
    will only fire once upon unmasking.

    The list of posix signals is defined in ocean.stdc.posix.signal

    Build flags:
        -debug=SignalMask: prints debugging information to Stderr

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.sys.SignalMask;


/*******************************************************************************

    Imports

*******************************************************************************/

version ( Posix )
{
    import core.sys.posix.signal;
}
else
{
    static assert(false, "module ocean.sys.SignalMask only supported in posix environments");
}

debug ( SignalMask ) import ocean.io.Stdout : Stderr;



/*******************************************************************************

    Signal set struct wrapping the C sigset_t and its setter / getter functions.

    Note that, as this is a struct rather than a class, and thus has no
    constructor, it is necessary to explicitly call the clear() method before
    using an instance.

*******************************************************************************/

public struct SignalSet
{
    /***************************************************************************

        Signal set.

    ***************************************************************************/

    private sigset_t sigset;


    /***************************************************************************

        Clears all signals in the set (i.e. sets to the set of no signals).

    ***************************************************************************/

    public void clear ( )
    {
        sigemptyset(&this.sigset);
    }


    /***************************************************************************

        Sets to the set of all signals.

    ***************************************************************************/

    public void setAll ( )
    {
        sigfillset(&this.sigset);
    }


    /***************************************************************************

        Removes the specified signal from the set.

        Params:
            signal = signal to remove from set

        This method is aliased as opSub.

    ***************************************************************************/

    public void remove ( int signal )
    {
        sigdelset(&this.sigset, signal);
    }

    public alias remove opSub;


    /***************************************************************************

        Adds the specified signal to the set.

        Params:
            signal = signal to add to set

        This method is aliased as opAdd.

    ***************************************************************************/

    public void add ( int signal )
    {
        sigaddset(&this.sigset, signal);
    }

    public alias add opAdd;


    /***************************************************************************

        Removes the specified signals from the set.

        Params:
            signals = signals to remove from set

        This method is aliased as opSub.

    ***************************************************************************/

    public void remove ( in int[] signals )
    {
        foreach ( signal; signals )
        {
            this.remove(signal);
        }
    }

    public alias remove opSub;


    /***************************************************************************

        Adds the specified signals to the set.

        Params:
            signals = signals to add to set

        This method is aliased as opAdd.

    ***************************************************************************/

    public void add ( in int[] signals )
    {
        foreach ( signal; signals )
        {
            this.add(signal);
        }
    }

    public alias add opAdd;


    /***************************************************************************

        Tells whether a signal is in the set.

        Params:
            signal = signal to test

        Returns:
            true if signal is in set

    ***************************************************************************/

    public bool isSet ( int signal )
    {
        return !!sigismember(&this.sigset, signal);
    }

    /***************************************************************************

        Calls pthread_sigmask() with the set of signals of this instance.

        Params:
            how = specifies the operation of pthread_sigmask():
                  SIG_SETMASK: All signals in the set of this instance this set
                      will be blocked, and all other signals will be unblocked.
                  SIG_BLOCK: All signals in the set of this instance this set
                      will be blocked, and the blocking status of all other
                      signals will remain unchanged.
                  SIG_UNBLOCK: All signals in the set of this instance this set
                      will be unblocked, and the blocking status of all other
                      signals will remain unchanged.

        Returns:
            previous masked signals set (call its sigmask() method to restore
            the previous state)

        In:
            how must be SIG_SETMASK, SIG_BLOCK or SIG_UNBLOCK. Note that
            ensuring this guarantees that pthread_sigmask() will always
            succeed.

    ***************************************************************************/

    public typeof(*this) mask ( int how = SIG_SETMASK )
    in
    {
        switch (how)
        {
            case SIG_SETMASK, SIG_BLOCK, SIG_UNBLOCK:
                break;

            default:
                assert(false, "invalid pthread_sigmask opcode");
        }
    }
    body
    {
        typeof(*this) old_set;

        pthread_sigmask(how, &this.sigset, &old_set.sigset);

        return old_set;
    }

    /***************************************************************************

        Blocks the signals in in the set of this instance in the calling thread.
        Signals that are not in this set but are already blocked will stay
        blocked.

        Returns:
            previous masked signals set (call its mask() method to restore the
            previous state)

    ***************************************************************************/

    public typeof(*this) block ( )
    {
        return this.mask(SIG_BLOCK);
    }

    /***************************************************************************

        Unblocks the signals in in the set of this instance in the calling
        thread. Signals that are not in this set but are not blocked will stay
        unblocked.

        Returns:
            previous masked signals set (call its mask() method to restore the
            previous state)

    ***************************************************************************/

    public typeof(*this) unblock ( )
    {
        return this.mask(SIG_UNBLOCK);
    }

    /***************************************************************************

        Executes op with the signals in this set blocked. The signals are
        automatically unblocked again after op has finished (returned or threw).

        Params:
            op = the operation to execute

    ***************************************************************************/

    public void callBlocked ( lazy void op )
    {
        auto old_sigset = this.block();

        scope ( exit )
        {
            debug ( SignalMask )
            {
                sigset_t pending;
                sigpending(&pending);

                foreach ( signal; this.signals )
                {
                    if ( sigismember(&pending, signal) )
                    {
                        Stderr.formatln("Signal {} fired while masked", signal);
                    }
                }
            }

            old_sigset.mask();
        }

        op;
    }

    /***************************************************************************

        Gets the signal mask for the calling thread.

        Returns:
            set of currently masked signals for the calling thread

    ***************************************************************************/

    public static typeof(*this) getCurrent ( )
    {
        typeof(*this) current_set;

        pthread_sigmask(SIG_SETMASK, null, &current_set.sigset);

        return current_set;
    }

    /***************************************************************************

        Cast operator for convenient use of this struct in C functions which
        accept a sigset_t.

    ***************************************************************************/

    public sigset_t opCast ( )
    {
        return this.sigset;
    }
}
