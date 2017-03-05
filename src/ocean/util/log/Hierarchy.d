/*******************************************************************************

    The Logger hierarchy implementation.

    We keep a reference to each logger in a hash-table for convenient lookup
    purposes, plus keep each logger linked to the others in an ordered group.
    Ordering places shortest names at the head and longest ones at the tail,
    making the job of identifying ancestors easier in an orderly fashion.
    For example, when propagating levels across descendants it would be
    a mistake to propagate to a child before all of its ancestors were
    taken care of.

    Copyright:
        Copyright (c) 2004 Kris Bell.
        Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

*******************************************************************************/

module ocean.util.log.Hierarchy;

import ocean.transition;
import ocean.core.ExceptionDefinitions;
import ocean.util.log.model.ILogger;


/// Ditto
package class HierarchyT (LoggerT) : ILogger.Context
{
    private LoggerT             root_;
    private istring             label_,
                                address_;
    private ILogger.Context     context_;
    private LoggerT[istring]    loggers;


    /***************************************************************************

        Construct a hierarchy with the given name.

    ***************************************************************************/

    this (istring hlabel)
    {
        this.label_ = hlabel;
        this.address_ = "network";

        // insert a root node; the root has an empty name
        this.root_ = new LoggerT(this, "");
        this.context_ = this;
    }

    /***************************************************************************

        Returns:
            The label associated with this Hierarchy

    ***************************************************************************/

    final istring label ()
    {
        return this.label_;
    }

    /***************************************************************************

        Set the name of this Hierarchy

    ***************************************************************************/

    final void label (istring value)
    {
        this.label_ = value;
    }

    /***************************************************************************

        Tells whether a given `level` is higher than another `test` level

    ***************************************************************************/

    final bool enabled (ILogger.Level level, ILogger.Level test)
    {
        return test >= level;
    }

    /***************************************************************************

        Return the address of this Hierarchy.
        This is typically attached when sending events to remote monitors.

    ***************************************************************************/

    final istring address ()
    {
        return this.address_;
    }

    /***************************************************************************

        Set the address of this Hierarchy.
        The address is attached used when sending events to remote monitors.

    ***************************************************************************/

    final void address (istring address)
    {
        this.address_ = address;
    }

    /***************************************************************************

        Return the diagnostic context.
        Useful for setting an override logging level.

    ***************************************************************************/

    final ILogger.Context context ()
    {
        return this.context_;
    }

    /***************************************************************************

        Set the diagnostic context.

        Not usually necessary, as a default was created.
        Useful when you need to provide a different implementation,
        such as a ThreadLocal variant.

    ***************************************************************************/

    final void context (ILogger.Context context)
    {
        this.context_ = context;
    }

    /***************************************************************************

        Return the root node.

    ***************************************************************************/

    final LoggerT root ()
    {
        return this.root_;
    }

    /***************************************************************************

        Return the instance of a LoggerT with the provided label.
        If the instance does not exist, it is created at this time.

        Note that an empty label is considered illegal, and will be ignored.

    ***************************************************************************/

    final LoggerT lookup (cstring label)
    {
        if (!label.length)
            return null;

        return this.inject(
            label,
            (cstring name) { return new LoggerT (this, idup(name)); }
            );
    }

    /***************************************************************************

        Traverse the set of configured loggers

    ***************************************************************************/

    final int opApply (int delegate(ref LoggerT) dg)
    {
        int ret;

        for (auto log = this.root; log; log = log.next)
            if ((ret = dg(log)) != 0)
                break;
        return ret;
    }

    /***************************************************************************

        Return the instance of a LoggerT with the provided label.
        If the instance does not exist, it is created at this time.

    ***************************************************************************/

    private LoggerT inject (cstring label, LoggerT delegate(cstring name) dg)
    {
        // try not to allocate unless you really need to
        char[255] stack_buffer;
        mstring buffer = stack_buffer;

        if (buffer.length < label.length + 1)
            buffer.length = label.length + 1;

        buffer[0 .. label.length] = label[];
        buffer[label.length] = '.';

        auto name_ = buffer[0 .. label.length + 1];
        cstring name;
        auto l = name_ in loggers;

        if (l is null)
        {
            // don't use the stack allocated buffer
            if (name_.ptr is stack_buffer.ptr)
                name = idup(name_);
            else
                name = assumeUnique(name_);
            // create a new logger
            auto li = dg(name);
            l = &li;

            // insert into linked list
            insert (li);

            // look for and adjust children. Don't force
            // property inheritance on existing loggers
            update (li);

            // insert into map
            loggers [name] = li;
        }

        return *l;
    }

    /***************************************************************************

        Loggers are maintained in a sorted linked-list. The order is maintained
        such that the shortest name is at the root, and the longest at the tail.

        This is done so that updateLoggers() will always have a known
        environment to manipulate, making it much faster.

    ***************************************************************************/

    private void insert (LoggerT l)
    {
        LoggerT prev,
                curr = this.root;

        while (curr)
        {
            // insert here if the new name is shorter
            if (l.name.length < curr.name.length)
                if (prev is null)
                    throw new IllegalElementException ("invalid hierarchy");
                else
                {
                    l.next = prev.next;
                    prev.next = l;
                    return;
                }
            else
                // find best match for parent of new entry
                // and inherit relevant properties (level, etc)
                this.propagate(l, curr, true);

            // remember where insertion point should be
            prev = curr;
            curr = curr.next;
        }

        // add to tail
        prev.next = l;
    }

    /***************************************************************************

         Propagate hierarchical changes across known loggers.
         This includes changes in the hierarchy itself, and to
         the various settings of child loggers with respect to
         their parent(s).

    ***************************************************************************/

    private void update (LoggerT changed, bool force = false)
    {
        foreach (logger; this)
            this.propagate(logger, changed, force);
    }

    /***************************************************************************

         Propagates the property to all child loggers.

         Params:
            Property = property to set
            T = type of the property
            parent_name = name of the parent logger
            value = value to set

    ***************************************************************************/

    package void propagateValue (istring property, T)
        (istring parent_name, T value)
    {
        foreach (log; this)
        {
            if (log.isChildOf (parent_name))
            {
                mixin("log." ~ property ~ " = value;");
            }
        }
    }

    /***************************************************************************

        Propagate changes in the hierarchy downward to child Loggers.
        Note that while 'parent' is always changed, the adjustment of
        'level' is selectable.

    ***************************************************************************/

    private void propagate (LoggerT logger, LoggerT changed, bool force = false)
    {
        // is the changed instance a better match for our parent?
        if (logger.isCloserAncestor(changed))
        {
            // update parent (might actually be current parent)
            logger.parent = changed;

            // if we don't have an explicit level set, inherit it
            // Be careful to avoid recursion, or other overhead
            if (force)
            {
                logger.level_ = changed.level;
                logger.collect_stats = changed.collect_stats;
            }
        }
    }
}
