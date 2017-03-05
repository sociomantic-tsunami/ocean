/*******************************************************************************

    Interface and GC / malloc implementations of a memory manager which can
    create and destroy chunks of memory.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.mem.MemManager;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.core.Enforce;

import ocean.core.ExceptionDefinitions : onOutOfMemoryError;

import core.stdc.stdlib : malloc, free;

import core.memory;

import ocean.transition;

/*******************************************************************************

    C Malloc memory manager instance,
    not scanned by the gc for pointers/references

*******************************************************************************/

mixin(global("IMemManager noScanMallocMemManager"));


/*******************************************************************************

    C Malloc memory manager instance, scanned by the gc for pointers/references

*******************************************************************************/

mixin(global("IMemManager mallocMemManager"));


/*******************************************************************************

    GC memory manager instance,
    not scanned by the gc for pointers/references

*******************************************************************************/

mixin(global("IMemManager noScanGcMemManager"));


/*******************************************************************************

    GC memory manager instance, scanned by the gc for pointers/references

*******************************************************************************/

mixin(global("IMemManager gcMemManager"));

version (D_Version2)
{
    mixin(`
        shared static this ( )
        {
            noScanMallocMemManager = new MallocMemManager!(false);
            noScanGcMemManager     = new GCMemManager!(false);
            mallocMemManager       = new MallocMemManager!(true);
            gcMemManager           = new GCMemManager!(true);
        }
    `);
}
else
{
    static this ( )
    {
        noScanMallocMemManager = new MallocMemManager!(false);
        noScanGcMemManager     = new GCMemManager!(false);
        mallocMemManager       = new MallocMemManager!(true);
        gcMemManager           = new GCMemManager!(true);
    }
}


/*******************************************************************************

    Memory manager interface.

*******************************************************************************/

public interface IMemManager
{
    /***************************************************************************

        Allocates a buffer of the specified dimension.

        Params:
            dimension = bytes to allocate

        Returns:
            new buffer

    ***************************************************************************/

    public ubyte[] create ( size_t dimension );


    /***************************************************************************

        Explicit deallocation

        Note that it is up to the user of classes which implement this interface
        to ensure that the buffer passed was in fact allocated by the same
        instance.

        Params:
            buffer = buffer to deallocate

    ***************************************************************************/

    public void destroy ( ubyte[] buffer );


    version (D_Version2) {}
    else
    {
        /***********************************************************************

            Dispose compatible deallocation

            Note that it is up to the user of classes which implement this
            interface to ensure that the buffer passed was in fact allocated
            by the same instance.

            `void Object.dispose()` is called on explicit delete. This method is
            intended to be called from that method.

            Params:
                buffer = buffer to deallocate

        ***********************************************************************/

        public void dispose ( ubyte[] buffer );
    }


    /***************************************************************************

        Destructor compatible deallocation

        Note that it is up to the user of classes which implement this interface
        to ensure that the buffer passed was in fact allocated by the same
        instance.

        The destructor is always called when an object is collected or when it
        is explicitly deleted. This method is intended to be called from the
        destructor.

        Params:
            buffer = buffer to cleanup

    ***************************************************************************/

    public void dtor ( ubyte[] buffer );
}



/*******************************************************************************

    Memory manager implementation using the D garbage collector.

    Template Parameters:
        gc_aware  = whether the gc should scan the allocated memory for
                    pointers or references

*******************************************************************************/

private class GCMemManager ( bool gc_aware ) : IMemManager
{
    /***************************************************************************

        Allocates a buffer of the specified dimension via the GC.

        Params:
            dimension = bytes to allocate

        Returns:
            new buffer

    ***************************************************************************/

    public override ubyte[] create ( size_t dimension )
    {
        static if ( gc_aware )
        {
            return cast(ubyte[]) new void[dimension];
        }
        else
        {
            return new ubyte[dimension];
        }
    }


    /***************************************************************************

        Explicit deallocation

        Note that it is up to the user of classes which implement this interface
        to ensure that the buffer passed was in fact allocated by the same
        instance.

        Params:
            buffer = buffer to deallocate

    ***************************************************************************/

    public override void destroy ( ubyte[] buffer )
    {
        delete buffer;
    }


    /***************************************************************************

        Deallocates the passed buffer.

        Params:
            buffer = buffer to deallocate

    ***************************************************************************/

    version (D_Version2) {}
    else public override void dispose ( ubyte[] buffer )
    {
        delete buffer;
    }


    /***************************************************************************

        Destructor compatible deallocation

        Note that it is up to the user of classes which implement this interface
        to ensure that the buffer passed was in fact allocated by the same
        instance.

        The destructor is always called when an object is collected or when it
        is explicitly deleted. This method is intended to be called from the
        destructor.

        Params:
            buffer = buffer to cleanup

    ***************************************************************************/

    public override void dtor ( ubyte[] buffer )
    {
    }
}



/*******************************************************************************

    Memory manager implementation using malloc and free.

    Template Parameters:
        gc_aware  = whether the gc should scan the allocated memory for
                    pointers or references

*******************************************************************************/

private class MallocMemManager ( bool gc_aware ) : IMemManager
{
    /***************************************************************************

        Allocates a buffer of the specified dimension using malloc.

        Params:
            dimension = bytes to allocate

        Returns:
            new buffer

    ***************************************************************************/

    public override ubyte[] create ( size_t dimension )
    {
        auto ptr = cast(ubyte*)malloc(dimension);
        if (ptr is null)
        {
            onOutOfMemoryError();
        }

        static if ( gc_aware )
        {
            GC.addRange(ptr, dimension);
        }

        return ptr[0..dimension];
    }


    /***************************************************************************

        Explicit deallocation

        Note that it is up to the user of classes which implement this interface
        to ensure that the buffer passed was in fact allocated by the same
        instance.

        Params:
            buffer = buffer to deallocate

    ***************************************************************************/

    public override void destroy ( ubyte[] buffer )
    {
        if ( buffer.ptr !is null )
        {
            static if ( gc_aware )
            {
                GC.removeRange(buffer.ptr);
            }

            free(buffer.ptr);
        }
    }


    /***************************************************************************

        Does nothing.

        Params:
            buffer = buffer to deallocate

    ***************************************************************************/

    version (D_Version2) {}
    else public override void dispose ( ubyte[] buffer ) {}


    /***************************************************************************

        Destructor compatible deallocation

        Note that it is up to the user of classes which implement this interface
        to ensure that the buffer passed was in fact allocated by the same
        instance.

        The destructor is always called when an object is collected or when it
        is explicitly deleted. This method is intended to be called from the
        destructor.

        Params:
            buffer = buffer to cleanup

    ***************************************************************************/

    public override void dtor ( ubyte[] buffer )
    {
        if ( buffer.ptr !is null )
        {
            static if ( gc_aware )
            {
                GC.removeRange(buffer.ptr);
            }

            free(buffer.ptr);
        }
    }
}
