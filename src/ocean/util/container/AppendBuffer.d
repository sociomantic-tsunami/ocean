/******************************************************************************

    Manages an array buffer for better incremental appending performance

    Manages an array buffer for better performance when elements are
    incrementally appended to an array.

    Note that, as with each dynamic array, changing the length invalidates
    existing slices to the array, potentially turning them into dangling
    references.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.util.container.AppendBuffer;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.transition;

import core.stdc.stdlib: malloc, realloc, free;

import ocean.core.ExceptionDefinitions: onOutOfMemoryError;

import ocean.core.Traits;

/******************************************************************************

    AppendBuffer Base interface.

 ******************************************************************************/

interface IAppendBufferBase
{
    /**************************************************************************

        Returns:
            number of elements in content

     **************************************************************************/

    size_t length ( );
}

/******************************************************************************

    Read-only AppendBuffer interface.

    Note that there is no strict write protection to an IAppendBufferReader
    instance because it is still possible to modify the content an obtained
    slice refers to. However, this is not the intention of this interface and
    may not result in the desired or even result in undesired side effects.

 ******************************************************************************/

interface IAppendBufferReader ( T ) : IAppendBufferBase
{
    alias T ElementType;
    const element_size = T.sizeof;

    /**************************************************************************

        Checks if T is 'void' or a static array type.

     **************************************************************************/

    static if (!is (T == void))
    {
        /**********************************************************************

            Unless T is 'void' opIndex() is declared and the
            static_array_element flag defined which tells whether T is a static
            array type or not.
            R is defined as return type of opIndex() and other methods which
            return an array element. Normally this aliases T; however, if T is a
            static array type which cannot be the return type, it aliases the
            dynamic array of the same base type. For example, if T aliases
            int[4], R aliases int[].
            If T is 'void', static_array_element, R and opIndex are not
            declared/defined at all.

         **********************************************************************/

        static if (is (T U : U[]) && !is (T == U[]))
        {
            const static_array_element = true;

            alias U[] R;
        }
        else
        {
            const static_array_element = false;

            alias T R;
        }

        /**********************************************************************

            Returns the i-th element in content.

            Params:
                i = element index

            Returns:
                i-th element in content

         **********************************************************************/

        R opIndex ( size_t i );
    }
    else
    {
        const static_array_element = false;
    }

    /**************************************************************************

        Returns:
            the current content

     **************************************************************************/

    T[] opSlice ( );

    /**************************************************************************

        Returns content[start .. end].
        start must be at most end and end must be at most the current content
        length.

        Params:
            start = start index
            end   = end index (exclusive)

        Returns:
            content[start .. end]

     **************************************************************************/

    T[] opSlice ( size_t start, size_t end );

    /**************************************************************************

        Returns content[start .. length].

        Params:
            start = start index

        Returns:
            content[start .. length]

     **************************************************************************/

    T[] tail ( size_t start );
}

/******************************************************************************

    AppendBuffer class template

    Template_Params:
        T          = array element type
        use_malloc = true:  use malloc()/realloc()/free() to (re/de)allocate
                            the content buffer
                     false: use new/dynamic array resizing/delete

 ******************************************************************************/

public template AppendBuffer ( T, bool use_malloc = false )
{
    static if (use_malloc)
    {
        alias AppendBuffer!(T, MallocAppendBufferImpl) AppendBuffer;
    }
    else
    {
        alias AppendBuffer!(T, AppendBufferImpl) AppendBuffer;
    }
}

/******************************************************************************

    AppendBuffer class template

    Template_Params:
        T    = array element type
        Base = base class

******************************************************************************/

public class AppendBuffer ( T, Base: AppendBufferImpl ): Base, IAppendBufferReader!(T)
{
    static if ( is(T == class) || is(T == interface) )
    {
        // implicit reference semantics make impossible to use const params
        alias T ParamT;
    }
    else
    {
        alias Const!(T) ParamT;
    }

    /**********************************************************************

        Constructor without buffer preallocation

     **********************************************************************/

    this ( )
    {
        this(0);
    }

    /**************************************************************************

        Constructor

        Params:
            n = content length for buffer preallocation
            limited = true: enable size limitation, false: disable

     **************************************************************************/

    this ( size_t n, bool limited = false )
    {
        super(T.sizeof, n);

        this.limited = limited;
    }

    /**************************************************************************

        Methods overloading array operations which deal with array elements.
        As these array operations are not available for 'void[]', they are not
        implemented if T is 'void' .

     **************************************************************************/

    static if (!is (T == void))
    {
        /**********************************************************************

            Returns the i-th element in content.

            If T is a static array type, a slice to the element is returned.

            Params:
                i = element index

            Returns:
                i-th element in content

            Out:
                If T is a static array type, the length of the returned slice is
                T.length.

         **********************************************************************/

        R opIndex ( size_t i )
        out (element)
        {
            static if (static_array_element)
            {
                assert (element.length == T.length);
            }
        }
        body
        {
            return *cast (T*) this.index_(i);
        }

        /**********************************************************************

            Sets the i-th element in content.

            Params:
                val = value to set
                i = element index

            Returns:
                element (or a slice to the element if T is a static array type).

            Out:
                If T is a static array type, the length of the returned slice is
                T.length.

         **********************************************************************/

        R opIndexAssign ( T val, size_t i )
        out (element)
        {
            static if (static_array_element)
            {
                assert (element.length == T.length);
            }
        }
        body
        {
            static if (static_array_element)
            {
                return (*cast (T*) this.index_(i))[] = val;
            }
            else
            {
                return *cast (T*) this.index_(i) = val;
            }
        }

        /**************************************************************************

            Sets all elements in the current content to element.

            Params:
                element = element to set all elements to

            Returns:
                current content

         **************************************************************************/

        T[] opSliceAssign ( ParamT element )
        {
            return this.opSlice()[] = element;
        }

        /**************************************************************************

            Copies chunk to the content, setting the content length to chunk.length.

            Params:
                element = chunk to copy to the content
                start = start of the slice
                end = end of the slice

            Returns:
                slice to chunk in the content

         **************************************************************************/

        T[] opSliceAssign ( ParamT element, size_t start, size_t end )
        {
            return this.opSlice(start, end)[] = element;
        }

        /**************************************************************************

            Appends element to the content, extending content where required.

            Params:
                element = element to append to the content

            Returns:
                slice to element in the content

         **************************************************************************/

        T[] opCatAssign ( T element )
        {
            T[] dst = this.extend(1);

            if (dst.length)
            {
                static if (static_array_element)
                {
                    dst[0][] = element;
                }
                else
                {
                    dst[0] = element;
                }
            }

            return this[];
        }
    }

    /**************************************************************************

        Returns:
            the current content

     **************************************************************************/

    T[] opSlice ( )
    {
        return cast (T[]) this.slice_();
    }

    /**************************************************************************

        Returns content[start .. end].
        start must be at most end and end must be at most the current content
        length.

        Params:
            start = start index
            end   = end index (exclusive)

        Returns:
            content[start .. end]

     **************************************************************************/

    T[] opSlice ( size_t start, size_t end )
    {
        return cast (T[]) this.slice_(start, end);
    }

    /**************************************************************************

        Returns content[start .. length].

        Params:
            start = start index

        Returns:
            content[start .. length]

     **************************************************************************/

    T[] tail ( size_t start )
    {
        return this[start .. this.length];
    }

    /**************************************************************************

        Copies chunk to the content, setting the content length to chunk.length.

        Params:
            chunk = chunk to copy to the content

        Returns:
            slice to chunk in the content

     **************************************************************************/

    T[] opSliceAssign ( ParamT[] chunk )
    {
        return cast (T[]) this.copy_(chunk);
    }

    /**************************************************************************

        Copies chunk to content[start .. end].
        chunk.length must be end - start and end must be at most the current
        content length.

        Params:
            chunk = chunk to copy to the content
            start = start of the slice
            end = end of the slice

        Returns:
            slice to chunk in the content

     **************************************************************************/

    T[] opSliceAssign ( ParamT[] chunk, size_t start, size_t end )
    {
        return cast (T[]) this.copy_(chunk, start, end);
    }

    /**************************************************************************

        Appends chunk to the content, extending content where required.

        Params:
            chunk = chunk to append to the content

        Returns:
            slice to chunk in the content

     **************************************************************************/

    T[] opCatAssign ( ParamT[] chunk )
    {
        T[] dst = this.extend(chunk.length);

        dst[] = chunk[0 .. dst.length];

        return this[];
    }

    /**************************************************************************

        Cuts the last n elements from the current content. If n is greater than
        the current content length, all elements in the content are cut.

        Params:
            n = number of elements to cut from content, if available

        Returns:
            last n elements cut from the current content, if n is at most the
            content length or all elements from the current content otherwise.

     **************************************************************************/

    T[] cut ( size_t n )
    out (elements)
    {
        assert (elements.length <= n);
    }
    body
    {
        size_t end   = this.length,
        start = (end >= n)? end - n : 0;

        scope (success) this.length = start;

        return this[start .. end];
    }

    static if (!static_array_element)
    {
        /**********************************************************************

            Cuts the last element from the current content.

            TODO: Not available if T is a static array type because a reference
            to the removed element would be needed to be returned, but the
            referenced element is erased and may theoretically relocated or
            deallocated (in fact it currently stays at the same location but
            there shouldn't be a guarantee.)
            Should this method be available if T is a static array type? It then
            would need to return 'void' or a struct with one member of type T.
            (Or we wait for migration to D2.)

            Returns:
                the element cut from the current content (unless T is void).

            In:
                The content must not be empty.

         **********************************************************************/

        T cut ( )
        in
        {
            assert (this.length, "cannot cut last element: content is empty");
        }
        body
        {
            size_t n = this.length - 1;

            scope (success) this.length = n;

            static if (!is (T == void))
            {
                return this[n];
            }
        }
    }

    /**************************************************************************

        Cuts the last n elements from the current content. If n is greater than
        the current content length, all elements in the content are cut.

        Returns:
            last n elements cut from the current content, if n is at most the
            content length or all elements from the current content otherwise.

     **************************************************************************/

    T[] dump ( )
    {
        scope (exit) this.length = 0;

        return this[];
    }

    /**************************************************************************

        Concatenates chunks and appends them to the content, extending the
        content where required.

        Params:
            chunks = chunks to concatenate and append to the content

        Returns:
            slice to concatenated chunks in the content which may be shorter
            than the chunks to concatenate if the content would have needed to
            be extended but content length limitation is enabled.

     **************************************************************************/

    T[] append ( U ... ) ( U chunks )
    {
        size_t start = this.length;

        Top: foreach (i, chunk; chunks)
        {
            static if (is (U[i] V : V[]) && is (V W : W[]))
            {
                foreach (chun; chunk)
                {
                    if (!this.append(chun)) break Top;                          // recursive call
                }
            }
            else static if (is (U[i] : T))
            {
                if (!this.opCatAssign(chunk).length) break;
            }
            else
            {
                static assert (is (typeof (this.append_(chunk))), "cannot append " ~ U[i].stringof ~ " to " ~ (T[]).stringof);

                if (!this.append_(chunk)) break;
            }
        }

        return this.tail(start);
    }

    /**************************************************************************

        Appends chunk to the content, extending the content where required.

        Params:
            chunks = chunk to append to the content

        Returns:
            true on success or false if the content would have needed to be
            extended but content length limitation is enabled.

     **************************************************************************/

    private bool append_ ( ParamT[] chunk )
    {
        return chunk.length? this.opCatAssign(chunk).length >= chunk.length : true;
    }

    /**************************************************************************

        Increases the content length by n elements.

        Note that previously returned slices must not be used after this method
        has been invoked because the content buffer may be relocated, turning
        existing slices to it into dangling references.

        Params:
            n = number of characters to extend content by

        Returns:
            slice to the portion in content by which content has been extended
            (last n elements in content after extension)

     **************************************************************************/

    T[] extend ( size_t n )
    {
        return cast (T[]) this.extend_(n);
    }

    /**************************************************************************

        Returns:
            pointer to the content

     **************************************************************************/

    T* ptr ( )
    {
        return cast (T*) this.index_(0);
    }

    /**************************************************************************

        Sets all elements in data to the initial value of the element type.
        data.length is guaranteed to be dividable by the element size.

        Params:
            data = data to erase

     **************************************************************************/

    protected override void erase ( void[] data )
    {
        static if (static_array_element && is (T U : U[]) && is (typeof (T.init) == U))
        {
            // work around DMD bug 7752

            const t_init = [U.init];

            data[] = t_init;
        }
        else
        {
            static if (is (T == void))
            {
                alias ubyte U;
            }
            else
            {
                alias T U;
            }

            (cast (U[]) data)[] = U.init;
        }
    }
}

/******************************************************************************

    Generic append buffer

 ******************************************************************************/

private abstract class AppendBufferImpl: IAppendBufferBase
{
    /**************************************************************************

        Content buffer. Declared as void[], but newed as ubyte[]
        (see newContent()).

        We new as ubyte[], not void[], because the GC scans void[] buffers for
        references. (The GC determines whether a block of memory possibly
        contains pointers or not at the point where it is newed, not based on
        the type it is assigned to. See _d_newarrayT() and _d_newarrayiT() in
        ocean.core.rt.compiler.dmd.rt.lifetime, lines 232 and 285,
        "BlkAttr.NO_SCAN".)

        @see http://thecybershadow.net/d/Memory_Management_in_the_D_Programming_Language.pdf

        , page 30.

     **************************************************************************/

    private void[] content;

    /**************************************************************************

        Number of elements in content

     **************************************************************************/

    private size_t n = 0;

    /**************************************************************************

        Element size

     **************************************************************************/

    private size_t e;

    /**************************************************************************

        Limitation flag

     **************************************************************************/

    private bool limited_ = false;

    /**************************************************************************

        Content base pointer and length which are ensured to be invariant when
        limitation is enabled unless the capacity is changed.

     **************************************************************************/

    private struct LimitInvariants
    {
        private void* ptr = null;
        size_t        len;
    }

    private LimitInvariants limit_invariants;

    /**************************************************************************

        Consistency checks for content length and number, limitation and content
        buffer location if limitation enabled.

     **************************************************************************/

    invariant ( )
    {
        assert (!(this.content.length % this.e));
        assert (this.n * this.e <= this.content.length);

        with (this.limit_invariants) if (this.limited_)
        {
            assert (ptr is this.content.ptr);
            assert (len == this.content.length);
        }
        else
        {
            assert (ptr is null);
        }
    }

    /**************************************************************************

        Constructor

        Params:
            e = element size (non-zero)
            n = number of elements in content for preallocation (optional)

     **************************************************************************/

    protected this ( size_t e, size_t n = 0 )
    in
    {
        assert (e, typeof (this).stringof ~ ": element size must be at least 1");
    }
    body
    {
        this.e = e;

        if (n)
        {
            this.content = this.newContent(e * n);
        }
    }

    /**************************************************************************

        Sets the number of elements in content to 0.

        Returns:
            previous number of elements.

     **************************************************************************/

    public size_t clear ( )
    {
        scope (success) this.n = 0;

        this.erase(this.content[0 .. this.n * this.e]);

        return this.n;
    }

    /**************************************************************************

        Enables or disables size limitation.

        Params:
            limited_ = true: enable size limitation, false: disable

        Returns:
            limited_

     **************************************************************************/

    public bool limited ( bool limited_ )
    {
        scope (exit) this.setLimitInvariants();

        return this.limited_ = limited_;
    }

    /**************************************************************************

        Returns:
            true if size limitation is enabled or false if disabled

     **************************************************************************/

    public bool limited ( )
    {
        return this.limited_;
    }

    /**************************************************************************

        Returns:
            number of elements in content

     **************************************************************************/

    public size_t length ( )
    {
        return this.n;
    }

    /**************************************************************************

        Returns:
            size of currently allocated buffer in bytes.

     **************************************************************************/

    public size_t dimension ( )
    {
        return this.content.length;
    }

    /**************************************************************************

        Returns:
            available space (number of elements) in the content buffer, if
            limitation is enabled, or size_t.max otherwise.

    **************************************************************************/

    public size_t available ( )
    {
        return this.limited_? this.content.length / this.e - this.n : size_t.max;
    }

    /**************************************************************************

        Sets the number of elements in content (content length). If length is
        increased, spare elements will be appended. If length is decreased,
        elements will be removed at the end. If limitation is enabled, the
        new number of elements is truncated to capacity().

        Note that, unless limitation is enabled, previously returned slices must
        not be used after this method has been invoked because the content
        buffer may be relocated, turning existing slices to it into dangling
        references.

        Params:
            n = new number of elements in content

        Returns:
            new number of elements, will be truncated to capacity() if
            limitation is enabled.

     **************************************************************************/

    public size_t length ( size_t n )
    out (n_new)
    {
        if (this.limited_)
        {
            assert (n_new <= n);
        }
        else
        {
            assert (n_new == n);
        }
    }
    body
    {
        size_t len = n * this.e;

        size_t old_len = this.content.length;

        if (this.content.length < len)
        {
            if (this.limited_)
            {
                len = this.content.length;
            }
            else
            {
                this.setContentLength(this.content, len);
            }
        }

        if (old_len < len)
        {
            this.erase(this.content[old_len .. len]);
        }

        return this.n = len / this.e;
    }

    /**************************************************************************

        Returns:
            Actual content buffer length (number of elements). This value is
            always at least length().

     **************************************************************************/

    public size_t capacity ( )
    {
        return this.content.length / this.e;
    }

    /**************************************************************************

        Returns:
            the element size in bytes. The constructor guarantees it is > 0.

     **************************************************************************/

    public size_t element_size ( )
    {
        return this.e;
    }

    /**************************************************************************

        Sets the content buffer length, preserving the actual content and
        overriding/adjusting the limit if limitation is enabled.
        If the new buffer length is less than length(), the buffer length will
        be set to length() so that no element is removed.

        Note that previously returned slices must not be used after this method
        has been invoked because the content buffer may be relocated, turning
        existing slices to it into dangling references.

        Params:
            capacity = new content buffer length (number of elements).

        Returns:
            New content buffer length (number of elements). This value is always
            at least length().

     **************************************************************************/

    public size_t capacity ( size_t capacity )
    {
        if (capacity > this.n)
        {
            this.setContentLength(this.content, capacity * this.e);

            this.setLimitInvariants();

            return capacity;
        }
        else
        {
            return this.n;
        }
    }

    /**************************************************************************

        Sets capacity() to length().

        Note that previously returned slices must not be used after this method
        has been invoked because the content buffer may be relocated, turning
        existing slices to it into dangling references.

        Returns:
            previous capacity().

     **************************************************************************/

    public size_t minimize ( )
    {
        scope (success)
        {
            this.setContentLength(this.content, this.n * this.e);
        }

        return this.content.length / this.e;
    }

    /**************************************************************************

        Sets all elements in data to the initial value of the element type.
        data.length is guaranteed to be dividable by the element size.

        Params:
            data = data to erase

     **************************************************************************/

    abstract protected void erase ( void[] data );

    /**************************************************************************

        Returns:
            current content

     **************************************************************************/

    protected void[] slice_ ( )
    {
        return this.content[0 .. this.n * this.e];
    }

    /**************************************************************************

        Slices content. start and end index content elements with element size e
        (as passed to the constructor).
        start must be at most end and end must be at most the current number
        of elements in content.

        Params:
            start = index of start element
            end   = index of end element (exclusive)

        Returns:
            content[start * e .. end * e]

     **************************************************************************/

    protected void[] slice_ ( size_t start, size_t end )
    in
    {
        assert (start <= end, typeof (this).stringof ~ ": slice start behind end index");
        assert (end <= this.n, typeof (this).stringof ~ ": slice end out of range");
    }
    body
    {
        return this.content[start * this.e .. end * this.e];
    }

    /**************************************************************************

        Returns a pointer to the i-th element in content.

        Params:
            i = element index

        Returns:
            pointer to the i-th element in content

     **************************************************************************/

    protected void* index_ ( size_t i )
    in
    {
        assert (i <= this.n, typeof (this).stringof ~ ": index out of range");
    }
    body
    {
        return this.content.ptr + i * this.e;
    }

    /**************************************************************************

        Copies chunk to the content, setting the current number of elements in
        content to the number of elements in chunk.
        chunk.length must be dividable by the element size.

        Params:
            chunk = chunk to copy to the content

        Returns:
            slice to chunk in content

     **************************************************************************/

    protected void[] copy_ ( Const!(void)[] src )
    in
    {
        assert (!(src.length % this.e), typeof (this).stringof ~ ": data alignment mismatch");
    }
    out (dst)
    {
        if (this.limited_)
        {
            assert (dst.length <= src.length);
        }
        else
        {
            assert (dst.length == src.length);
        }
    }
    body
    {
        this.n = 0;

        void[] dst = this.extendBytes(src.length);

        assert (dst.ptr is this.content.ptr);

        return dst[] = src[0 .. dst.length];
    }

    /**************************************************************************

        Copies chunk to content[start * e .. end * e].
        chunk.length must be (end - start) * e and end must be at most the
        current number of elements in content.

        Params:
            chunk = chunk to copy to the content

        Returns:
            slice to chunk in the content

     **************************************************************************/

    protected void[] copy_ ( Const!(void)[] chunk, size_t start, size_t end )
    in
    {
        assert (!(chunk.length % this.e), typeof (this).stringof ~ ": data alignment mismatch");
        assert (start <= end,             typeof (this).stringof ~ ": slice start behind end index");
        assert (end <= this.n,            typeof (this).stringof ~ ": slice end out of range");
        assert (chunk.length == (end - start) * this.e, typeof (this).stringof ~ ": length mismatch of data to copy");
    }
    body
    {
        return this.content[start * this.e .. end * this.e] = cast (ubyte[]) chunk[];
    }

    /**************************************************************************

        Extends content by n elements. If limitation is enabled, n will be
        truncated to the number of available elements.

        Params:
            n = number of elements to extend content by

        Returns:
            Slice to the portion in content by which content has been extended
            (last n elements in content after extension).

     **************************************************************************/

    protected void[] extend_ ( size_t n )
    out (slice)
    {
        if (this.limited_)
        {
            assert (slice.length <= n * this.e);
        }
        else
        {
            assert (slice.length == n * this.e);
        }
    }
    body
    {
        return this.extendBytes(n * this.e);
    }

    /**************************************************************************

        Extends content by extent bytes.
        extent must be dividable by the element size e.

        Params:
            extent = number of bytes to extend content by

        Returns:
            slice to the portion in content by which content has been extended
            (last extent bytes in content after extension)

     **************************************************************************/

    protected void[] extendBytes ( size_t extent )
    in
    {
        assert (!(extent % this.e));
    }
    out (slice)
    {
        assert (!(slice.length % this.e));

        if (this.limited_)
        {
            assert (slice.length <= extent);
        }
        else
        {
            assert (slice.length == extent);
        }
    }
    body
    {
        size_t oldlen = this.n * this.e,
               newlen = oldlen + extent;

        if (this.content.length < newlen)
        {
            if (this.limited_)
            {
                newlen = this.content.length;
            }
            else
            {
                this.setContentLength(this.content, newlen);
            }
        }

        this.n = newlen / this.e;

        return this.content[oldlen .. newlen];
    }


    version (D_Version2) {}
    else
    {
        /***********************************************************************

            Called immediately when this instance is deleted.
            (Must be protected to prevent an invariant from failing.)

        ***********************************************************************/

        protected override void dispose ( )
        {
            if (this.content)
            {
                this.deleteContent(this.content);
            }
        }
    }

    /**************************************************************************

        Allocates a dynamic array of n bytes for the content.

        Params:
            n = content array length

        Returns:
            a newly allocated dynamic array.

        In:
            n must not be zero.

        Out:
            The array length must be n.

     **************************************************************************/

    protected void[] newContent ( size_t n )
    in
    {
        assert (n, typeof (this).stringof ~ ".newContent: attempted to allocate zero bytes");
    }
    out (content_)
    {
        assert (content_.length == n);
    }
    body
    {
        return new ubyte[n];
    }

    /**************************************************************************

        Sets the content array length to n.

        Params:
            content_ = content array, previously allocated by newContent() or
                       modified by setContentLength()
            n        = new content array length, may be zero

        Out:
            content_.length must be n. That means, if n is 0, content_ may be
            null.

     **************************************************************************/

    protected void setContentLength ( ref void[] content_, size_t n )
    out
    {
        // FIXME assert commented out as it was failing when trying to connect
        // to a MySql server using drizzle probably due to a compiler bug
        //assert (content_.length == n,
        //        typeof (this).stringof ~ ".setContentLength: content length mismatch");
    }
    body
    {
        content_.length = n;
        enableStomping(content_);
    }

    /**************************************************************************

        Deallocates the content array.

        Params:
            content_ = content array, previously allocated by newContent() or
                       modified by setContentLength()

     **************************************************************************/

    protected void deleteContent ( ref void[] content_ )
    in
    {
        assert (content_,
                typeof (this).stringof ~ ".deleteContent: content_ is null");
    }
    body
    {
        delete content_;
    }

    /**************************************************************************

        Readjusts limit_invariants.

     **************************************************************************/

    private void setLimitInvariants ( )
    {
        with (this.limit_invariants) if (this.limited_)
        {
            ptr = this.content.ptr;
            len = this.content.length;
        }
        else
        {
            ptr = null;
        }
    }
}

/******************************************************************************

    Generic append buffer, uses malloc()/realloc()/free().

 ******************************************************************************/

private abstract class MallocAppendBufferImpl: AppendBufferImpl
{
    /**************************************************************************

        Constructor

        Params:
            e = element size (non-zero)
            n = number of elements in content for preallocation (optional)

     **************************************************************************/

    protected this ( size_t e, size_t n = 0 )
    {
        super(e, n);
    }

    /**************************************************************************

        Allocates a dynamic array of n bytes for the content.

        Params:
            n = content array length

        Returns:
            a newly allocated dynamic array.

        In:
            n must not be zero.

     **************************************************************************/

    protected override void[] newContent ( size_t n )
    in
    {
        assert (n, typeof (this).stringof ~ ".newContent: attempted to allocate zero bytes");
    }
    body
    {
        return this.newArray(n);
    }

    /**************************************************************************

        Sets the content array length to n.

        Params:
            content_ = content array, previously allocated by newContent() or
                       modified by setContentLength()
            n        = new content array length, may be zero

     **************************************************************************/

    protected override void setContentLength ( ref void[] content_, size_t n )
    {
        content_ = this.arrayLength(content_, n);
    }

    /**************************************************************************

        Deallocates the content array.

        Params:
            content_ = content array, previously allocated by newContent() or
                       modified by setContentLength()

     **************************************************************************/

    protected override void deleteContent ( ref void[] content_ )
    {
        this.deleteArray(content_.ptr);
        content = null;
    }

    /**************************************************************************

        Allocates a new dynamic array of n elements using malloc().

        Template_Params:
            T = element type

        Params:
            n = length of the new array

        Returns:
            a new array or null if n is null

     **************************************************************************/

    static T[] newArray ( T = void ) ( size_t n )
    {
        return n? cast (T[]) newArray_(n * T.sizeof) : null;
    }

    /**************************************************************************

        Resizes array to length n using realloc() (or free() if n is 0).
        Has the same effect as newArray() if array is null.

        Params:
            array = array to resize, previously allocated using newArray, or
                    null
            n     = new array length

        Returns:
            the resized array or null if n is 0.

     **************************************************************************/

    static T[] arrayLength ( T = void ) ( T[] array, size_t n )
    {
        return cast (T[]) arrayLength_(array, n * T.sizeof);
    }

    /**************************************************************************

        Deallocates the dynamic array referred to by ptr using free(). Does
        nothing if ptr is null.

        Params:
            ptr = .ptr property of the array to deallocate, previously allocated
                  by newArray and/or modified by arrayLength().

        Returns:
            the resized array or null if n is 0.

     **************************************************************************/

    static void deleteArray ( void* ptr )
    {
        if (ptr)
        {
            free(ptr);
        }
    }

    /**************************************************************************

        Allocates a new dynamic array of n bytes using malloc().

        Params:
            n = length of the new array

        Returns:
            a new array or null if n is null

     **************************************************************************/

    private static void[] newArray_ ( size_t n )
    in
    {
        assert (n);
    }
    body
    {
        void* ptr = malloc(n);

        if (ptr)
        {
            return ptr[0 .. n];
        }
        else
        {
            onOutOfMemoryError();
        }

        assert(0);
    }

    /**************************************************************************

        Resizes array to length n using realloc() (or free() if n is 0).
        Has the same effect as newArray() if array is null.

        Params:
            array = array to resize, previously allocated using newArray, or
                    null
            n     = new array length

        Returns:
            the resized array or null if n is 0.

     **************************************************************************/

    private static void[] arrayLength_ ( void[] array, size_t n )
    {
        if (n != array.length)
        {
            if (n)
            {
                void* ptr = realloc(array.ptr, n);

                if (ptr)
                {
                    array = ptr[0 .. n];
                }
                else
                {
                    onOutOfMemoryError();
                }
            }
            else
            {
                deleteArray(array.ptr);
                array = null;
            }
        }

        return array;
    }
}

/******************************************************************************/

unittest
{
    scope ab = new AppendBuffer!(dchar)(10);

    assert (ab.length    == 0);
    assert (ab.capacity  == 10);
    assert (ab.dimension == 10 * dchar.sizeof);

    ab[] = "Die Kotze"d;

    assert (ab.length  == "Die Kotze"d.length);
    assert (ab[]       == "Die Kotze"d);
    assert (ab.capacity  == 10);
    assert (ab.dimension == 10 * dchar.sizeof);

    ab[5] =  'a';
    assert (ab.length  == "Die Katze"d.length);
    assert (ab[]       == "Die Katze"d);
    assert (ab[4 .. 9] == "Katze"d);
    assert (ab.capacity  == 10);
    assert (ab.dimension == 10 * dchar.sizeof);

    ab ~= ' ';

    assert (ab[]      == "Die Katze "d);
    assert (ab.length == "Die Katze "d.length);
    assert (ab.capacity  == 10);
    assert (ab.dimension == 10 * dchar.sizeof);

    ab ~= "tritt"d;

    assert (ab[]      == "Die Katze tritt"d);
    assert (ab.length == "Die Katze tritt"d.length);
    assert (ab.capacity  == "Die Katze tritt"d.length);
    assert (ab.dimension == "Die Katze tritt"d.length * dchar.sizeof);

    ab.append(" die"d[], " Treppe"d[], " krumm."d[]);

    assert (ab[]      == "Die Katze tritt die Treppe krumm."d);
    assert (ab.length == "Die Katze tritt die Treppe krumm."d.length);
    assert (ab.capacity  == "Die Katze tritt die Treppe krumm."d.length);
    assert (ab.dimension == "Die Katze tritt die Treppe krumm."d.length * dchar.sizeof);

    assert (ab.cut(4) == "umm."d);

    assert (ab.length == "Die Katze tritt die Treppe kr"d.length);
    assert (ab.capacity  == "Die Katze tritt die Treppe krumm."d.length);
    assert (ab.dimension == "Die Katze tritt die Treppe krumm."d.length * dchar.sizeof);

    assert (ab.cut() == 'r');

    assert (ab.length == "Die Katze tritt die Treppe k"d.length);
    assert (ab.capacity  == "Die Katze tritt die Treppe krumm."d.length);
    assert (ab.dimension == "Die Katze tritt die Treppe krumm."d.length * dchar.sizeof);

    ab.clear();

    assert (!ab.length);
    assert (ab[] == ""d);

    ab.extend(5);
    assert (ab.length == 5);

    ab[] = '~';
    assert (ab[] == "~~~~~"d);
}

