/*******************************************************************************

    Types concerning the values stored in cache.

    Value is the type stored in the cache.

    ValueRef is the type of a reference to a value as it is returned by
    createRaw(), getRaw() and getOrCreateRaw().

    For values of fixed size (not dynamic, ValueSize != 0) createRaw() and
    getOrCreateRaw() return a dynamic array which slices to the value in the
    cache and therefore has always a length of ValueSize. getRaw() returns
    either such a slice or null.

    For values of dynamic size createRaw() and getOrCreateRaw() return a pointer
    to a Value struct instance while getRaw() returns either a pointer or null.
    The Value struct wraps a dynamic array and provides access via struct
    methods.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.cache.model.Value;

/******************************************************************************/

template Value ( size_t ValueSize )
{
    /***************************************************************************

        Tells if the values are of dynamic size; if not, they are of fixed size.

    ***************************************************************************/

    const is_dynamic = !ValueSize;

    static if (is_dynamic)
    {
        struct Value
        {
            /*******************************************************************

                Value array. This may be an allocated buffer or a slice to an
                external array, depending on whether it is assigned by
                opSliceAssign() (allocates or reuses a buffer) or opSlice()
                (slices an external array).

            *******************************************************************/

            private void[] array;

            /*******************************************************************

                Sets the value array instance to val.

                Params:
                    val = new value array instance

                Returns:
                    val.

            *******************************************************************/

            public void[] opAssign ( void[] val )
            {
                return this.array = val;
            }

            /*******************************************************************

                Allocates a buffer for the value array and copies the content of
                val into the value array. If the value array already exists (is
                not null), it is resized and reused.

                Params:
                    val = value content to copy to the value array of this
                          instance

                Returns:
                    the value array of this instance.

            *******************************************************************/

            public void[] opSliceAssign ( void[] val )
            {
                if (this.array is null)
                {
                    this.array = new ubyte[val.length];
                }
                else
                {
                    this.array.length = val.length;
                }

                return this.array[] = val[];
            }

            /*******************************************************************

                Returns:
                    the value array.

            *******************************************************************/

            public void[] opSlice ( )
            {
                return this.array;
            }

            /*******************************************************************

                Obtains a pointer to the value array instance.
                Should only be used in special situations where it would be
                unreasonably difficult to use the other access methods.

                Returns:
                    a pointer to the value array instance.

            *******************************************************************/

            public void[]* opCast ( )
            {
                return &this.array;
            }
        }

        public alias Value* ValueRef;
    }
    else
    {
        public alias ubyte[ValueSize] Value;
        public alias void[]           ValueRef;
    }
}
