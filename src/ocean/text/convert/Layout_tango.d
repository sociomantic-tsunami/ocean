/*******************************************************************************

        This module provides a general-purpose formatting system to
        convert values to text suitable for display. There is support
        for alignment, justification, and common format specifiers for
        numbers.

        Layout can be customized via configuring various handlers and
        associated meta-data. This is utilized to plug in text.locale
        for handling custom formats, date/time and culture-specific
        conversions.

        The format notation is influenced by that used by the .NET
        and ICU frameworks, rather than C-style printf or D-style
        writef notation.

        Copyright:
            Copyright (c) 2005 Kris.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: 2005

        Authors: Kris, Keinfarbton

******************************************************************************/

module ocean.text.convert.Layout_tango;

import ocean.transition;

import ocean.core.Exception_tango;
import ocean.core.RuntimeTraits;

import ocean.time.Time;
import ocean.text.convert.DateTime_tango;

import Utf = ocean.text.convert.Utf;

import Float = ocean.text.convert.Float,
       Integer = ocean.text.convert.Integer_tango;

import ocean.io.model.IConduit : OutputStream;

version(WithVariant)
    import ocean.core.Variant;

version(WithExtensions)
{
    import ocean.text.convert.Extensions;
}


/*******************************************************************************

        Platform issues ...

*******************************************************************************/

version(DigitalMars)
{
    import ocean.core.Vararg;
    alias void* Arg;
    alias va_list ArgList;

    version(X86_64)
    {
        version = DigitalMarsX64;
        version = LinuxVarArgs;
    }
}
else
{
    alias void* Arg;
    alias void* ArgList;
}

/*******************************************************************************

    Contains methods for replacing format items in a string with string
    equivalents of each argument.

*******************************************************************************/

class Layout(T)
{
    public alias convert opCall;
    // This alias is kept for compatibility reason, but it's better to use
    // SizeSink instead.
    public alias uint delegate (Const!(T)[]) Sink;
    public alias size_t delegate (Const!(T)[]) SizeSink;

    static if (is (DateTimeLocale))
        private DateTimeLocale* dateTime;

    /**********************************************************************

        Return shared instance

        Note that this is not threadsafe, and that a static-ctor
        can't be used because other static constructors depend on it
        (e.g. Stdout).

     **********************************************************************/

    static Layout instance ()
    {
        static Layout common;

        if (common is null)
            common = new Layout!(T);
        return common;
    }

    /**********************************************************************

        Append formatted text to the buffer, the buffer will be resized as
        appropriate, so allocations might happen.

        FIXME: If I make the method final instead of static, I get
        a segmentation fault. If I keep it final instead of static
        but I remove the `ref` to the argument, then it works again.

     **********************************************************************/

    public static T[] format (ref T[] buffer, Const!(T)[] formatStr, ...)
    {
        return instance.vformat (buffer, formatStr, _arguments, _argptr);
    }

    /**********************************************************************

     **********************************************************************/

    public final T[] vformat (ref T[] buffer, Const!(T)[] formatStr,
            TypeInfo[] arguments, va_list argptr)
    {
        convert(
            (Const!(T)[] s)
            {
                auto start = buffer.length;
                buffer.length = buffer.length + s.length;
                enableStomping(buffer);
                buffer[start .. $] = s[];
                return s.length;
            },
            arguments, argptr, formatStr
        );

        return buffer;
    }

    /**********************************************************************

     **********************************************************************/

    public final T[] sprint (T[] result, Const!(T)[] formatStr, ...)
    {
        return vprint (result, formatStr, _arguments, _argptr);
    }

    /**********************************************************************

     **********************************************************************/

    public final T[] vprint (T[] result, Const!(T)[] formatStr, TypeInfo[] arguments, ArgList args)
    {
        T*  p = result.ptr;
        auto available = result.length;

        size_t sink (Const!(T)[] s)
        {
            auto len = s.length;
            if (len > available)
                len = available;

            available -= len;
            p [0..len] = s[0..len];
            p += len;
            return len;
        }

        convert (&sink, arguments, args, formatStr);
        return result [0 .. cast(size_t) (p-result.ptr)];
    }

    /**********************************************************************

        Replaces the _format item in a string with the string
        equivalent of each argument.

        Params:
        formatStr  = A string containing _format items.
        args       = A list of arguments.

        Returns: A copy of formatStr in which the items have been
        replaced by the string equivalent of the arguments.

        Remarks: The formatStr parameter is embedded with _format
        items of the form: $(BR)$(BR)
        {index[,alignment][:_format-string]}$(BR)$(BR)
        $(UL $(LI index $(BR)
        An integer indicating the element in a list to _format.)
        $(LI alignment $(BR)
        An optional integer indicating the minimum width. The
        result is padded with spaces if the length of the value
        is less than alignment.)
        $(LI _format-string $(BR)
        An optional string of formatting codes.)
        )$(BR)

        The leading and trailing braces are required. To include a
        literal brace character, use two leading or trailing brace
        characters.$(BR)$(BR)
        If formatStr is "{0} bottles of beer on the wall" and the
        argument is an int with the value of 99, the return value
        will be:$(BR) "99 bottles of beer on the wall".

     **********************************************************************/

    public final Immut!(T)[] convert (Const!(T)[] formatStr, ...)
    {
        return convert (_arguments, _argptr, formatStr);
    }

    /**********************************************************************

     **********************************************************************/

    public final size_t convert (Sink sink, Const!(T)[] formatStr, ...)
    {
        return convert (cast(SizeSink)sink, _arguments, _argptr, formatStr);
    }

    public final size_t convert (SizeSink sink, Const!(T)[] formatStr, ...)
    {
        return convert (sink, _arguments, _argptr, formatStr);
    }


    /**********************************************************************

      Tentative convert using an OutputStream as sink - may still be
      removed.

     **********************************************************************/

    public final size_t convert (OutputStream output, Const!(T)[] formatStr, ...)
    {
        size_t sink (Const!(T)[] s)
        {
            return output.write(s);
        }

        return convert (&sink, _arguments, _argptr, formatStr);
    }

    /**********************************************************************

     **********************************************************************/

    public final Immut!(T)[] convert (TypeInfo[] arguments, ArgList args, Const!(T)[] formatStr)
    {
        T[] output;

        size_t sink (Const!(T)[] s)
        {
            output ~= s;
            return s.length;
        }

        convert (&sink, arguments, args, formatStr);
        return assumeUnique(output);
    }

    /**********************************************************************

     **********************************************************************/

    version (old) public final T[] convertOne (T[] result, TypeInfo ti, Arg arg)
    {
        return dispatch (result, null, ti, arg);
    }

    /******************************************************************

      Reused buffers for variadic argument conversion

     ******************************************************************/

    private Arg[]  arglist;

    /******************************************************************

      Preallocates the buffers.

     ******************************************************************/

    public this ( )
    {
        this.arglist = new Arg[0x40];

        static if (is (DateTimeLocale))
            this.dateTime = &DateTimeDefault;
    }

    /******************************************************************

     *******************************************************************/

    version (D_Version2)
    {}
    else
    {
        protected override void dispose ( )
        {
            delete this.arglist;
        }
    }

    /**********************************************************************

     **********************************************************************/

    public final size_t convert (Sink sink, TypeInfo[] arguments, ArgList args, Const!(T)[] formatStr)
    {
        return convert(cast(SizeSink)sink, arguments, args, formatStr);
    }

    public final size_t convert (SizeSink sink, TypeInfo[] arguments, ArgList args, Const!(T)[] formatStr)
    {
        version (LinuxVarArgs)
        {
            assert (formatStr, "null format specifier");
            assert (arguments.length < 64, "too many args in Layout.convert");

            union ArgU {int i; byte b; long l; short s; void[] a;
                real r; float f; double d;
                cfloat cf; cdouble cd; creal cr;}

            Arg[64] arglist = void;
            ArgU[64] storedArgs = void;

            foreach (i, arg; arguments)
            {
                static if (is(typeof(args.ptr)))
                    arglist[i] = args.ptr;
                else
                    arglist[i] = args;

                /* Since floating point types don't live on
                 * the stack, they must be accessed by the
                 * correct type. */
                bool converted = false;

                auto tinfo = arg;

                if (tinfo is typeid(float) || tinfo is typeid(ifloat))
                {
                    storedArgs[i].f = va_arg!(float)(args);
                    arglist[i] = &(storedArgs[i].f);
                    converted = true;
                }
                else if (tinfo is typeid(cfloat))
                {
                    storedArgs[i].cf = va_arg!(cfloat)(args);
                    arglist[i] = &(storedArgs[i].cf);
                    converted = true;
                }
                else if (tinfo is typeid(double) || tinfo is typeid(idouble))
                {
                    storedArgs[i].d = va_arg!(double)(args);
                    arglist[i] = &(storedArgs[i].d);
                    converted = true;
                }
                else if (tinfo is typeid(cdouble))
                {
                    storedArgs[i].cd = va_arg!(cdouble)(args);
                    arglist[i] = &(storedArgs[i].cd);
                    converted = true;
                }
                else if (tinfo is typeid(real) || tinfo is typeid(ireal))
                {
                    storedArgs[i].r = va_arg!(real)(args);
                    arglist[i] = &(storedArgs[i].r);
                    converted = true;
                }
                else if (tinfo is typeid(creal))
                {
                    storedArgs[i].cr = va_arg!(creal)(args);
                    arglist[i] = &(storedArgs[i].cr);
                    converted = true;
                }

                if (! converted)
                {
                    switch (arg.tsize)
                    {
                        version (D_Version2)
                        {
                            case 0: // null literal, consider it pointer size 
                                static if (is(size_t == ulong))
                                {
                                    storedArgs[i].l = va_arg!(long)(args);
                                    arglist[i] = &(storedArgs[i].l);
                                }
                                else
                                {
                                    storedArgs[i].i = va_arg!(int)(args);
                                    arglist[i] = &(storedArgs[i].i);
                                }
                                break;
                        }
                        case 1:
                            storedArgs[i].b = va_arg!(byte)(args);
                            arglist[i] = &(storedArgs[i].b);
                            break;
                        case 2:
                            storedArgs[i].s = va_arg!(short)(args);
                            arglist[i] = &(storedArgs[i].s);
                            break;
                        case 4:
                            storedArgs[i].i = va_arg!(int)(args);
                            arglist[i] = &(storedArgs[i].i);
                            break;
                        case 8:
                            storedArgs[i].l = va_arg!(long)(args);
                            arglist[i] = &(storedArgs[i].l);
                            break;
                        case 16:
                            assert((void[]).sizeof==16,"Structure size not supported");
                            storedArgs[i].a = va_arg!(void[])(args);
                            arglist[i] = &(storedArgs[i].a);
                            break;
                        default:
                            assert (false, "Unknown size: " ~ Integer.toString (arg.tsize));
                    }
                }
            }
        }
        else
        {
            /+
                Arg[64] arglist = void;
            foreach (i, arg; arguments)
            {
                arglist[i] = args;
                args += (arg.tsize + size_t.sizeof - 1) & ~ (size_t.sizeof - 1);
            }
            +/

            this.arglist.length = arguments.length;

            foreach (i, arg; arguments)
            {
                this.arglist[i] = args;
                args += (arg.tsize + size_t.sizeof - 1) & ~ (size_t.sizeof - 1);
            }

        }
        return parse (formatStr, arguments, arglist, sink);
    }

    /**********************************************************************

      Parse the format-string, emitting formatted args and text
      fragments as we go

     **********************************************************************/

    private size_t parse (Const!(T)[] layout, TypeInfo[] ti, Arg[] args, SizeSink sink)
    {
        T[512] result = void;
        ptrdiff_t length, nextIndex;


        auto s = layout.ptr;
        auto fragment = s;
        auto end = s + layout.length;

        while (true)
        {
            while (s < end && *s != '{')
                ++s;

            // emit fragment
            length += sink (fragment [0 .. cast(size_t) (s - fragment)]);

            // all done?
            if (s is end)
                break;

            // check for "{{" and skip if so
            if (*++s is '{')
            {
                fragment = s++;
                continue;
            }

            ptrdiff_t index = 0;
            bool indexed = false;

            // extract index
            while (*s >= '0' && *s <= '9')
            {
                index = index * 10 + *s++ -'0';
                indexed = true;
            }

            // skip spaces
            while (s < end && *s is ' ')
                ++s;

            bool crop;
            bool left;
            bool right;
            int  width;

            // has minimum or maximum width?
            if (*s is ',' || *s is '.')
            {
                if (*s is '.')
                    crop = true;

                while (++s < end && *s is ' ') {}
                if (*s is '-')
                {
                    left = true;
                    ++s;
                }
                else
                    right = true;

                // get width
                while (*s >= '0' && *s <= '9')
                    width = width * 10 + *s++ -'0';

                // skip spaces
                while (s < end && *s is ' ')
                    ++s;
            }

            Const!(T)[] format;

            // has a format string?
            if (*s is ':' && s < end)
            {
                auto fs = ++s;

                // eat everything up to closing brace
                while (s < end && *s != '}')
                    ++s;
                format = fs [0 .. cast(size_t) (s - fs)];
            }

            // insist on a closing brace
            if (*s != '}')
            {
                length += sink ("{malformed format}");
                continue;
            }

            // check for default index & set next default counter
            if (! indexed)
                index = nextIndex;
            nextIndex = index + 1;

            // next char is start of following fragment
            fragment = ++s;

            // handle alignment
            void emit (Const!(T)[] str)
            {
                ptrdiff_t padding = width - str.length;

                if (crop)
                {
                    if (padding < 0)
                    {
                        if (left)
                        {
                            length += sink ("...");
                            length += sink (Utf.cropLeft (str[-padding..$]));
                        }
                        else
                        {
                            length += sink (Utf.cropRight (str[0..width]));
                            length += sink ("...");
                        }
                    }
                    else
                        length += sink (str);
                }
                else
                {
                    // if right aligned, pad out with spaces
                    if (right && padding > 0)
                        length += spaces (sink, padding);

                    // emit formatted argument
                    length += sink (str);

                    // finally, pad out on right
                    if (left && padding > 0)
                        length += spaces (sink, padding);
                }
            }

            // an astonishing number of typehacks needed to handle arrays :(
            void process (TypeInfo _ti, Arg _arg)
            {
                // Because Variants can contain AAs (and maybe
                // even static arrays someday), we need to
                // process them here.
                version (WithVariant)
                {
                    if (_ti is typeid(Variant))
                    {
                        // Unpack the variant and forward
                        auto vptr = cast(Variant*)_arg;
                        auto innerTi = vptr.type;
                        auto innerArg = vptr.ptr;
                        process (innerTi, innerArg);
                    }
                }
                if (_ti.classinfo.name.length is 20 && _ti.classinfo.name[9..$] == "StaticArray" )
                {
                    auto tiStat = cast(TypeInfo_StaticArray)_ti;
                    auto p = _arg;
                    length += sink ("[");
                    for (int i = 0; i < tiStat.len; i++)
                    {
                        if (p !is _arg )
                            length += sink (", ");
                        process (tiStat.value, p);
                        p += tiStat.tsize/tiStat.len;
                    }
                    length += sink ("]");
                }
                else
                    if (_ti.classinfo.name.length is 25 && _ti.classinfo.name[9..$] == "AssociativeArray")
                    {
                        auto tiAsso = cast(TypeInfo_AssociativeArray)_ti;
                        auto tiKey = tiAsso.key;
                        auto tiVal = tiAsso.next();

                        // the knowledge of the internal k/v storage is used
                        // so this might break if, that internal storage changes
                        alias ubyte AV; // any type for key, value might be ok, the sizes are corrected later
                        alias ubyte AK;
                        auto aa = *cast(AV[AK]*) _arg;

                        length += sink ("{");
                        bool first = true;

                        size_t roundUp (size_t tsize)
                        {
                            //return (sz + (void*).sizeof -1) & ~((void*).sizeof - 1);

                            version (X86_64)
                                // Size of key needed to align value on 16 bytes
                                return (tsize + 15) & ~(15);
                            else
                                return (tsize + size_t.sizeof - 1) & ~(size_t.sizeof - 1);
                        }

                        void handleKV ( void* pk, void* pv )
                        {
                            if (!first)
                                length += sink (", ");
                            process (tiKey, pk);
                            length += sink (" => ");
                            process (tiVal, pv);
                            first = false;
                        }

                        static if (__VERSION__ > 2067)
                        {
                            foreach (ref k, ref v; aa)
                            {
                                auto pk = cast(Arg) &k;
                                auto pv = cast(Arg) &v;
                                handleKV(pk, pv);
                            }
                        }
                        else
                        {
                            foreach (ref v; aa)
                            {
                                // the key is befor the value, so substrace with
                                //fixed key size from above
                                auto pk = cast(Arg)( &v - roundUp(AK.sizeof));
                                // now the real value pos is plus the real key size
                                auto pv = cast(Arg)(pk + roundUp(tiKey.tsize()));
                                handleKV(pk, pv);
                            }
                        }

                        length += sink ("}");
                    }
                    else
                        if (isArray(_ti))
                        {
                            auto elTi = valueType(_ti);
                            auto size = elTi.tsize();

                            if (isString(_ti))
                            {
                                if (size == 1)
                                    emit (Utf.fromString8 (*cast(char[]*) _arg, result));
                                else if (size == 2)
                                    emit (Utf.fromString16 (*cast(wchar[]*) _arg, result));
                                else if (size == 4)
                                    emit (Utf.fromString32 (*cast(dchar[]*) _arg, result));
                                else
                                    assert(false, _ti.toString());
                            }
                            else
                            {
                                // for all non string array types (including char[][])
                                auto arr = *cast(void[]*)_arg;
                                auto len = arr.length;
                                auto ptr = cast(Arg) arr.ptr;
                                length += sink ("[");
                                while (len > 0)
                                {
                                    if (ptr !is arr.ptr)
                                        length += sink (", ");
                                    process (elTi, ptr);
                                    len -= 1;
                                    ptr += size;
                                }
                                length += sink ("]");
                            }
                        }
                        else
                            // the standard processing
                            emit (dispatch (result, format, _ti, _arg));
            }


            // process this argument
            if (index >= ti.length)
                emit ("{invalid index}");
            else
                process (ti[index], args[index]);
        }
        return length;
    }

    /***********************************************************************

     ***********************************************************************/

    private Const!(T)[] dispatch (T[] result, Const!(T)[] format, TypeInfo tinfo, Arg p)
    {
        if (tinfo is typeid(bool))
        {
            static t = "true";
            static f = "false";
            return (*cast(bool*) p) ? t : f;
        }

        if (tinfo is typeid(byte))
            return integer (result, *cast(byte*) p, format, ubyte.max);

        if (tinfo is typeid(void) || tinfo is typeid(ubyte))
            return integer (result, *cast(ubyte*) p, format, ubyte.max, "u");

        if (tinfo is typeid(short))
            return integer (result, *cast(short*) p, format, ushort.max);

        if (tinfo is typeid(ushort))
            return integer (result, *cast(ushort*) p, format, ushort.max, "u");

        if (tinfo is typeid(int))
            return integer (result, *cast(int*) p, format, uint.max);

        if (tinfo is typeid(uint))
            return integer (result, *cast(uint*) p, format, uint.max, "u");

        if (tinfo is typeid(ulong))
            return integer (result, *cast(long*) p, format, ulong.max, "u");

        if (tinfo is typeid(long))
            return integer (result, *cast(long*) p, format, ulong.max);

        if (tinfo is typeid(float))
            return floater (result, *cast(float*) p, format);

        if (tinfo is typeid(ifloat))
            return imaginary (result, *cast(ifloat*) p, format);

        if (tinfo is typeid(idouble))
            return imaginary (result, *cast(idouble*) p, format);

        if (tinfo is typeid(ireal))
            return imaginary (result, *cast(ireal*) p, format);

        if (tinfo is typeid(cfloat))
            return complex (result, *cast(cfloat*) p, format);

        if (tinfo is typeid(cdouble))
            return complex (result, *cast(cdouble*) p, format);

        if (tinfo is typeid(creal))
            return complex (result, *cast(creal*) p, format);

        if (tinfo is typeid(double))
            return floater (result, *cast(double*) p, format);

        if (tinfo is typeid(real))
            return floater (result, *cast(real*) p, format);

        if (tinfo is typeid(char))
            return Utf.fromString8 ((cast(char*) p)[0..1], result);

        if (tinfo is typeid(wchar))
            return Utf.fromString16 ((cast(wchar*) p)[0..1], result);

        if (tinfo is typeid(dchar))
            return Utf.fromString32 ((cast(dchar*) p)[0..1], result);

        if (cast(TypeInfo_Pointer) tinfo)
            return integer (result, *cast(size_t*) p, format, size_t.max, "x");

        if (tinfo.classinfo is TypeInfo.classinfo) // null literal, same as pointer
            return integer (result, *cast(size_t*) p, format, size_t.max, "x");

        if (cast(TypeInfo_Class) tinfo)
        {
            auto c = *cast(Object*) p;
            assert (c !is null);
            return Utf.fromString8 (c.toString, result);
        }

        if (cast(TypeInfo_Interface) tinfo)
        {
            auto x = *cast(void**) p;
            assert (x !is null);
            auto pi = **cast(Interface ***) x;
            auto o = cast(Object)(*cast(void**)p - pi.offset);
            return Utf.fromString8 (o.toString, result);
        }

        if (cast(TypeInfo_Enum) tinfo)
            return dispatch (result, format, (cast(TypeInfo_Enum) tinfo).base, p);

        if (cast(TypeInfo_Typedef) tinfo)
            return dispatch (result, format, (cast(TypeInfo_Typedef) tinfo).base, p);

        if (auto s = cast(TypeInfo_Struct) tinfo)
        {
            if (s.xtoString)
            {
                istring delegate() toString;
                toString.ptr = p;
                toString.funcptr = cast(istring function())s.xtoString;
                return Utf.fromString8 (toString(), result);
            }

            // else default
        }

        return unknown (result, format, tinfo, p);
    }

    /**********************************************************************

      handle "unknown-type" errors

     **********************************************************************/

    protected Const!(T)[] unknown (T[] result, Const!(T)[] format, TypeInfo tinfo, Arg p)
    {
        version (WithExtensions)
        {
            result = Extensions!(T).run (type, result, p, format);
            if (result.length)
                return result;
        }
        else
        {
            if (tinfo is typeid(Time))
            {
                static if (is (T == char))
                    return dateTime.format(result, *cast(Time*) p, format);
                else
                {
                    // TODO: this needs to be cleaned up
                    char[128] tmp0 = void;
                    char[128] tmp1 = void;
                    return Utf.fromString8(dateTime.format(tmp0, *cast(Time*) p, Utf.toString(format, tmp1)), result);
                }
            }
        }

        return "{unhandled argument type}";
    }

    /**********************************************************************

      Format an integer value

     **********************************************************************/

    protected Const!(T)[] integer (T[] output, long v, Const!(T)[] format, ulong mask = ulong.max, Const!(T)[] def="d")
    {
        if (format.length is 0)
            format = def;
        if (format[0] != 'd')
            v &= mask;

        return Integer.format (output, v, format);
    }

    /**********************************************************************

      format a floating-point value. Defaults to 2 decimal places

     **********************************************************************/

    protected Const!(T)[] floater (T[] output, real v, Const!(T)[] format)
    {
        uint dec = 2,
             exp = 10;
        bool pad = true;

        for (auto p=format.ptr, e=p+format.length; p < e; ++p)
            switch (*p)
            {
                case '.':
                    pad = false;
                    break;
                case 'e':
                case 'E':
                    exp = 0;
                    break;
                case 'x':
                case 'X':
                    double d = v;
                    return integer (output, *cast(long*) &d, "x#");
                default:
                    Unqual!(T) c = *p;
                    if (c >= '0' && c <= '9')
                    {
                        dec = c - '0', c = p[1];
                        if (c >= '0' && c <= '9' && ++p < e)
                            dec = dec * 10 + c - '0';
                    }
                    break;
            }

        return Float.format (output, v, dec, exp, pad);
    }

    /**********************************************************************

     **********************************************************************/

    private void error (istring msg)
    {
        throw new IllegalArgumentException (msg);
    }

    /**********************************************************************

     **********************************************************************/

    private size_t spaces (SizeSink sink, ptrdiff_t count)
    {
        size_t ret;

        static Const!(T[32]) Spaces = ' ';
        while (count > Spaces.length)
        {
            ret += sink (Spaces);
            count -= Spaces.length;
        }
        return (ret + sink (Spaces[0..count]));
    }

    /**********************************************************************

      format an imaginary value

     **********************************************************************/

    private Const!(T)[] imaginary (T[] result, ireal val, Const!(T)[] format)
    {
        return floatingTail (result, val.im, format, "*1i");
    }

    /**********************************************************************

      format a complex value

     **********************************************************************/

    private Const!(T)[] complex (T[] result, creal val, Const!(T)[] format)
    {
        static bool signed (real x)
        {
            static if (real.sizeof is 4)
                return ((*cast(uint *)&x) & 0x8000_0000) != 0;
            else
                static if (real.sizeof is 8)
                    return ((*cast(ulong *)&x) & 0x8000_0000_0000_0000) != 0;
            else
            {
                auto pe = cast(ubyte *)&x;
                return (pe[9] & 0x80) != 0;
            }
        }
        static plus = "+";

        auto len = floatingTail (result, val.re, format, signed(val.im) ? null : plus).length;
        return result [0 .. len + floatingTail (result[len..$], val.im, format, "*1i").length];
    }

    /**********************************************************************

      formats a floating-point value, and appends a tail to it

     **********************************************************************/

    private Const!(T)[] floatingTail (T[] result, real val, Const!(T)[] format, Const!(T)[] tail)
    {
        assert (result.length > tail.length);

        auto res = floater (result[0..$-tail.length], val, format);
        auto len=res.length;
        if (res.ptr!is result.ptr)
            result[0..len]=res;
        result [len .. len + tail.length] = tail;
        return result [0 .. len + tail.length];
    }
}

/*******************************************************************************

 *******************************************************************************/

version (UnitTest)
{
    Layout!(char) Formatter;

    static this ( )
    {
        Formatter = Layout!(char).instance;
    }
}

unittest
{
    // basic layout tests
    assert( Formatter( "abc" ) == "abc" );
    assert( Formatter( "{0}", 1 ) == "1" );
    assert( Formatter( "{0}", -1 ) == "-1" );
    assert( Formatter( "{}", null ) == "0" );
    assert( Formatter( "{}", 1 ) == "1" );
    assert( Formatter( "{} {}", 1, 2) == "1 2" );
    assert( Formatter( "{} {0} {}", 1, 3) == "1 1 3" );
    assert( Formatter( "{} {0} {} {}", 1, 3) == "1 1 3 {invalid index}" );
    assert( Formatter( "{} {0} {} {:x}", 1, 3) == "1 1 3 {invalid index}" );

    assert( Formatter( "{0}", true ) == "true" , Formatter( "{0}", true ));
    assert( Formatter( "{0}", false ) == "false" );

    assert( Formatter( "{0}", cast(byte)-128 ) == "-128" );
    assert( Formatter( "{0}", cast(byte)127 ) == "127" );
    assert( Formatter( "{0}", cast(ubyte)255 ) == "255" );

    assert( Formatter( "{0}", cast(short)-32768  ) == "-32768" );
    assert( Formatter( "{0}", cast(short)32767 ) == "32767" );
    assert( Formatter( "{0}", cast(ushort)65535 ) == "65535" );
    assert( Formatter( "{0:x4}", cast(ushort)0xafe ) == "0afe" );
    assert( Formatter( "{0:X4}", cast(ushort)0xafe ) == "0AFE" );

    assert( Formatter( "{0}", -2147483648 ) == "-2147483648" );
    assert( Formatter( "{0}", 2147483647 ) == "2147483647" );
    assert( Formatter( "{0}", 4294967295 ) == "4294967295" );

    // large integers
    assert( Formatter( "{0}", -9223372036854775807L) == "-9223372036854775807" );
    assert( Formatter( "{0}", 0x8000_0000_0000_0000L) == "9223372036854775808" );
    assert( Formatter( "{0}", 9223372036854775807L ) == "9223372036854775807" );
    assert( Formatter( "{0:X}", 0xFFFF_FFFF_FFFF_FFFF) == "FFFFFFFFFFFFFFFF" );
    assert( Formatter( "{0:x}", 0xFFFF_FFFF_FFFF_FFFF) == "ffffffffffffffff" );
    assert( Formatter( "{0:x}", 0xFFFF_1234_FFFF_FFFF) == "ffff1234ffffffff" );
    assert( Formatter( "{0:x19}", 0x1234_FFFF_FFFF) == "00000001234ffffffff" );
    assert( Formatter( "{0}", 18446744073709551615UL ) == "18446744073709551615" );
    assert( Formatter( "{0}", 18446744073709551615UL ) == "18446744073709551615" );

    // fragments before and after
    assert( Formatter( "d{0}d", "s" ) == "dsd" );
    assert( Formatter( "d{0}d", "1234567890" ) == "d1234567890d" );

    // brace escaping
    assert( Formatter( "d{0}d", "<string>" ) == "d<string>d");
    assert( Formatter( "d{{0}d", "<string>" ) == "d{0}d");
    assert( Formatter( "d{{{0}d", "<string>" ) == "d{<string>d");
    assert( Formatter( "d{0}}d", "<string>" ) == "d<string>}d");

    // hex conversions, where width indicates leading zeroes
    assert( Formatter( "{0:x}", 0xafe0000 ) == "afe0000" );
    assert( Formatter( "{0:x7}", 0xafe0000 ) == "afe0000" );
    assert( Formatter( "{0:x8}", 0xafe0000 ) == "0afe0000" );
    assert( Formatter( "{0:X8}", 0xafe0000 ) == "0AFE0000" );
    assert( Formatter( "{0:X9}", 0xafe0000 ) == "00AFE0000" );
    assert( Formatter( "{0:X13}", 0xafe0000 ) == "000000AFE0000" );
    assert( Formatter( "{0:x13}", 0xafe0000 ) == "000000afe0000" );

    // decimal width
    assert( Formatter( "{0:d6}", 123 ) == "000123" );
    assert( Formatter( "{0,7:d6}", 123 ) == " 000123" );
    assert( Formatter( "{0,-7:d6}", 123 ) == "000123 " );

    // width & sign combinations
    assert( Formatter( "{0:d7}", -123 ) == "-0000123" );
    assert( Formatter( "{0,7:d6}", 123 ) == " 000123" );
    assert( Formatter( "{0,7:d7}", -123 ) == "-0000123" );
    assert( Formatter( "{0,8:d7}", -123 ) == "-0000123" );
    assert( Formatter( "{0,5:d7}", -123 ) == "-0000123" );

    // Negative numbers in various bases
    assert( Formatter( "{:b}", cast(byte) -1 ) == "11111111" );
    assert( Formatter( "{:b}", cast(short) -1 ) == "1111111111111111" );
    assert( Formatter( "{:b}", cast(int) -1 )
            == "11111111111111111111111111111111" );
    assert( Formatter( "{:b}", cast(long) -1 )
            == "1111111111111111111111111111111111111111111111111111111111111111" );

    assert( Formatter( "{:o}", cast(byte) -1 ) == "377" );
    assert( Formatter( "{:o}", cast(short) -1 ) == "177777" );
    assert( Formatter( "{:o}", cast(int) -1 ) == "37777777777" );
    assert( Formatter( "{:o}", cast(long) -1 ) == "1777777777777777777777" );

    assert( Formatter( "{:d}", cast(byte) -1 ) == "-1" );
    assert( Formatter( "{:d}", cast(short) -1 ) == "-1" );
    assert( Formatter( "{:d}", cast(int) -1 ) == "-1" );
    assert( Formatter( "{:d}", cast(long) -1 ) == "-1" );

    assert( Formatter( "{:x}", cast(byte) -1 ) == "ff" );
    assert( Formatter( "{:x}", cast(short) -1 ) == "ffff" );
    assert( Formatter( "{:x}", cast(int) -1 ) == "ffffffff" );
    assert( Formatter( "{:x}", cast(long) -1 ) == "ffffffffffffffff" );

    // argument index
    assert( Formatter( "a{0}b{1}c{2}", "x", "y", "z" ) == "axbycz" );
    assert( Formatter( "a{2}b{1}c{0}", "x", "y", "z" ) == "azbycx" );
    assert( Formatter( "a{1}b{1}c{1}", "x", "y", "z" ) == "aybycy" );

    // alignment does not restrict the length
    assert( Formatter( "{0,5}", "hellohello" ) == "hellohello" );

    // alignment fills with spaces
    assert( Formatter( "->{0,-10}<-", "hello" ) == "->hello     <-" );
    assert( Formatter( "->{0,10}<-", "hello" ) == "->     hello<-" );
    assert( Formatter( "->{0,-10}<-", 12345 ) == "->12345     <-" );
    assert( Formatter( "->{0,10}<-", 12345 ) == "->     12345<-" );

    // chop at maximum specified length; insert ellipses when chopped
    assert( Formatter( "->{.5}<-", "hello" ) == "->hello<-" );
    assert( Formatter( "->{.4}<-", "hello" ) == "->hell...<-" );
    assert( Formatter( "->{.-3}<-", "hello" ) == "->...llo<-" );

    // width specifier indicates number of decimal places
    assert( Formatter( "{0:f}", 1.23f ) == "1.23" );
    assert( Formatter( "{0:f4}", 1.23456789L ) == "1.2346" );
    assert( Formatter( "{0:e4}", 0.0001) == "1.0000e-04");

    assert( Formatter( "{0:f}", 1.23f*1i ) == "1.23*1i");
    assert( Formatter( "{0:f4}", 1.23456789L*1i ) == "1.2346*1i" );
    assert( Formatter( "{0:e4}", 0.0001*1i) == "1.0000e-04*1i");

    assert( Formatter( "{0:f}", 1.23f+1i ) == "1.23+1.00*1i" );
    assert( Formatter( "{0:f4}", 1.23456789L+1i ) == "1.2346+1.0000*1i" );
    assert( Formatter( "{0:e4}", 0.0001+1i) == "1.0000e-04+1.0000e+00*1i");
    assert( Formatter( "{0:f}", 1.23f-1i ) == "1.23-1.00*1i" );
    assert( Formatter( "{0:f4}", 1.23456789L-1i ) == "1.2346-1.0000*1i" );
    assert( Formatter( "{0:e4}", 0.0001-1i) == "1.0000e-04-1.0000e+00*1i");

    // 'f.' & 'e.' format truncates zeroes from floating decimals
    assert( Formatter( "{:f4.}", 1.230 ) == "1.23" );
    assert( Formatter( "{:f6.}", 1.230 ) == "1.23" );
    assert( Formatter( "{:f1.}", 1.230 ) == "1.2" );
    assert( Formatter( "{:f.}", 1.233 ) == "1.23" );
    assert( Formatter( "{:f.}", 1.237 ) == "1.24" );
    assert( Formatter( "{:f.}", 1.000 ) == "1" );
    assert( Formatter( "{:f2.}", 200.001 ) == "200");

    // array output
    int[] a = [ 51, 52, 53, 54, 55 ];
    assert( Formatter( "{}", a ) == "[51, 52, 53, 54, 55]" );
    assert( Formatter( "{:x}", a ) == "[33, 34, 35, 36, 37]" );
    assert( Formatter( "{,-4}", a ) == "[51  , 52  , 53  , 54  , 55  ]" );
    assert( Formatter( "{,4}", a ) == "[  51,   52,   53,   54,   55]" );
    int[][] b = [ [ 51, 52 ], [ 53, 54, 55 ] ];
    assert( Formatter( "{}", b ) == "[[51, 52], [53, 54, 55]]" );

    char[1024] static_buffer;
    static_buffer[0..10] = "1234567890";

    assert (Formatter( "{}", static_buffer[0..10]) == "1234567890");

    version(X86)
    {
        ushort[3] c = [ cast(ushort)51, 52, 53 ];
        assert( Formatter( "{}", c ) == "[51, 52, 53]" );
    }

    // integer AA
    ushort[long] d;
    d[234] = 2;
    d[345] = 3;

    assert( Formatter( "{}", d ) == "{234 => 2, 345 => 3}" ||
            Formatter( "{}", d ) == "{345 => 3, 234 => 2}");

    // bool/string AA
    bool[char[]] e;
    e[ idup("key") ] = true;
    e[ idup("value") ] = false;
    assert( Formatter( "{}", e ) == "{key => true, value => false}" ||
            Formatter( "{}", e ) == "{value => false, key => true}");

    // string/double AA
    char[][ double ] f;
    f[ 1.0 ] = "one".dup;
    f[ 3.14 ] = "PI".dup;
    assert( Formatter( "{}", f ) == "{1.00 => one, 3.14 => PI}" ||
            Formatter( "{}", f ) == "{3.14 => PI, 1.00 => one}");

    // format()
    char[] buffer;
    assert( Formatter.format(buffer, "{}", 1) == "1" );
    assert( buffer == "1" );

    buffer.length = 0;
    enableStomping(buffer);
    assert( Formatter.format(buffer, "{}", 1234567890123) == "1234567890123" );
    assert( buffer == "1234567890123" );

    auto old_buffer_ptr = buffer.ptr;
    buffer.length = 0;
    enableStomping(buffer);
    assert( Formatter.format(buffer, "{}", 1.24) == "1.24" );
    assert( buffer == "1.24" );
    assert( buffer.ptr == old_buffer_ptr);

    interface I
    {
    }

    class C : I
    {
        override istring toString()
        {
            return "something";
        }
    }

    C c = new C;
    I i = c;

    assert ( Formatter("{}", i) == "something" );
    assert ( Formatter("{}", c) == "something" );

    struct S
    {
        istring toString()
        {
            return "something";
        }
    }

    assert ( Formatter("{}", S.init) == "something" );

    struct S2 { }
    assert ( Formatter("{}", S2.init) == "{unhandled argument type}" );

    // Time struct
    // Should result in something similar to "01/01/70 00:00:00" but it's
    // dependent on the system locale so we just make sure that it's handled
    assert( Formatter( "{}", Time.epoch1970 ) != "{unhandled argument type}");

    assert ( Formatter("{}", [ "aa", "bb" ] ) == `[aa, bb]` );
    assert ( Formatter("{}", "aa"w) == "aa" );

    // sprint is supposed to overwrite provided buffer without changing its length
    // and ignore any remaining formatted data that does not fit
    mstring target;
    Formatter.sprint(target, "{}", 42);
    assert (target.ptr is null);
    target.length = 5; target[] = 'a';
    Formatter.sprint(target, "{}", 42);
    assert (target == "42aaa");
}
