/*******************************************************************************

    Interface and GC / malloc implementations of a memory manager which can
    create and destroy chunks of memory.

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.mem.MemManager;

import core.memory;
import core.stdc.stdlib : malloc, free;

import ocean.core.Enforce;
import ocean.core.ExceptionDefinitions : onOutOfMemoryError;
import ocean.meta.types.Qualifiers;

/*******************************************************************************

    C Malloc memory manager instance,
    not scanned by the gc for pointers/references

*******************************************************************************/

__gshared IMemManager noScanMallocMemManager;


/*******************************************************************************

    C Malloc memory manager instance, scanned by the gc for pointers/references

*******************************************************************************/

__gshared IMemManager mallocMemManager;


/*******************************************************************************

    GC memory manager instance,
    not scanned by the gc for pointers/references

*******************************************************************************/

__gshared IMemManager noScanGcMemManager;


/*******************************************************************************

    GC memory manager instance, scanned by the gc for pointers/references

*******************************************************************************/

__gshared IMemManager gcMemManager;

shared static this ( )
{
    noScanMallocMemManager = new MallocMemManager!(false);
    noScanGcMemManager     = new GCMemManager!(false);
    mallocMemManager       = new MallocMemManager!(true);
    gcMemManager           = new GCMemManager!(true);
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

    Params:
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
        import core.memory;
        GC.free(buffer.ptr);
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
