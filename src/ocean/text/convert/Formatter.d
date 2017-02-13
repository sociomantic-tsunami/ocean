/*******************************************************************************

    Compile-time version of `Layout_tango`, allows one to format structs,
    and supports `Typedef` both in D1 and D2.

    This module provides 4 possible semantics:
    - For pedestrian usage which doesn't care about allocations, see `format`
    - For allocation-friendly semantic where the data is output either to
      a sink or to a `ref char[]`, see the `sformat` overloads
    - To ensure absolutely no allocation happens, see `snformat`

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        Some parts (marked explicitly) copyright Kris and/or Larsivi.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

*******************************************************************************/

module ocean.text.convert.Formatter;

import ocean.transition;
import ocean.core.Traits;
import Integer = ocean.text.convert.Integer_tango;
import Float = ocean.text.convert.Float;
import UTF = ocean.text.convert.Utf;

version (UnitTest)
{
    import ocean.core.Test;
}


/*******************************************************************************

    Type of 'sink' that can be passed to `format`, matches `Layout.SizeSink`

*******************************************************************************/

public alias size_t delegate(cstring) Sink;


/*******************************************************************************

    Formats an input string into a newly-allocated string and returns it

    Params:
        fmt     = Format string to use
        args    = Variadic arguments to format according to `fmt`

    Returns:
        A newly allocated, immutable formatted string

*******************************************************************************/

public istring format (Args...) (cstring fmt, Args args)
{
    mstring buffer;

    scope Sink sink = (cstring s)
    {
        buffer ~= s;
        return s.length;
    };

    sformat(sink, fmt, args);
    return assumeUnique(buffer);
}


/*******************************************************************************

    Write the processed (formatted) input into a buffer

    Params:
        buffer  = The buffer to write the formatted string into, will be
                  extended if needed
        fmt     = Format string to use
        args    = Variadic arguments to format according to `fmt`

    Returns:
        A reference to `buffer`

*******************************************************************************/

public mstring sformat (Args...) (ref mstring buffer, cstring fmt, Args args)
{
    scope Sink sink = (cstring s)
    {
        buffer ~= s;
        return s.length;
    };
    sformat(sink, fmt, args);
    return buffer;
}


/*******************************************************************************

    Write the processed (formatted) input into a fixed-length buffer

    This function will not perform any allocation.
    If the output does not fit in `buffer`, the extra output will simply
    be discarded.

    Params:
        buffer  = The buffer to write the formatted string into.
                  Unlike the sformat overloads, the buffer won't be extended.
                  This leads to a slightly different semantic for this
                  buffer (the others are only appended to, this one is
                  written to).
        fmt     = Format string to use
        args    = Variadic arguments to format according to `fmt`

    Returns:
        A reference to `buffer`

*******************************************************************************/

public mstring snformat (Args...) (mstring buffer, cstring fmt, Args args)
{
    size_t start;

    scope Sink sink = (cstring s)
    {
        size_t left = buffer.length - start;
        size_t wsize = left <= s.length ? left : s.length;
        if (wsize > 0)
            buffer[start .. start + wsize] = s[0 .. wsize];
        start += wsize;
        return wsize;
    };

    sformat(sink, fmt, args);
    return buffer[0 .. start];
}


/*******************************************************************************

    Send the processed (formatted) input into a sink

    Params:
        sink    = A delegate that will be called, possibly multiple
                    times, with a portion of the result string
        fmt     = Format string to use
        args    = Variadic arguments to format according to fmt

    Returns:
        If formatting was successful, returns `true`, `false` otherwise.

*******************************************************************************/

public bool sformat (Args...) (Sink sink, cstring fmt, Args args)
{
    FormatInfo info;
    size_t nextIndex;

    // A delegate to write elements according to the FormatInfo
    scope elemSink = (cstring str, ref Const!(FormatInfo) f)
    {
        return widthSink(sink, str, f);
    };

    // Main loop
    while (fmt.length)
    {
        info = consume(sink, fmt);

        if (info.flags & Flags.Error)
            return false;

        if (info.flags & Flags.Format)
        {
            // Handle index, the single source of pain
            if (info.flags & Flags.Index)
                nextIndex = info.index + 1;
            else
                info.index = nextIndex++;

            /*
             * The foreach within the switch is executed at compile time
             * It allows accessing a compile-time known parameter (and most
             * importantly, its type) using a runtime index.
             * It is basically generating a jump table, which is exactly
             * what the codegen will produce.
             * Note that we need to use the break to label feature as
             * `break` would otherwise break out of the static foreach
             * (even if that doesn't make sense), and thus, execute the
             * `default` statement in every case (!)
             */
        JT: switch (info.index)
            {
                // NOTE: The access needs to be through args[idx].
                // Using the 'unused' variable generates wrong code
                // https://issues.dlang.org/show_bug.cgi?id=16521
                foreach (idx, unused; args)
                {
                case idx:
                    handle(args[idx], info, sink, elemSink);
                    break JT;
                }

            default:
                sink("{invalid index}");
            }
        }
    }
    return true;
}


/*******************************************************************************

    Internal sink type that wraps the user-provided one and takes care
    of cropping and width

    This sink expects to receive a full element as the first parameter,
    in other words, the full chunk of text that needs a fixed size.
    This is why one cannot format a whole aggregate (struct, arrays etc.), but
    only individual elements.

*******************************************************************************/

public alias size_t delegate(cstring, ref Const!(FormatInfo)) ElementSink;


/*******************************************************************************

    A function that writes to a `Sink` according to the width limits

    Params:
        sink = Sink to write to
        str  = String to write to the sink
        f    = FormatInfo object from which to read the width and flags

    Returns:
        Number of elements written to the sink

*******************************************************************************/

private size_t widthSink (Sink sink, cstring str, ref Const!(FormatInfo) f)
{
    if (f.flags & Flags.Width)
    {
        // "{.4}",  "Hello" gives "Hell..."
        // "{.-4}", "Hello" gives "...ello"
        if (f.flags & Flags.Crop)
        {
            if (f.flags & Flags.AlignLeft)
            {
                return (str.length > f.width ? sink("...") : 0)
                    + sink(str[$ > f.width ? $ - f.width : 0 .. $]);
            }
            else
            {
                assert(f.flags & Flags.AlignRight);
                return sink(str[0 .. $ > f.width ? f.width : $])
                    + (str.length > f.width ? sink("...") : 0);
            }
        }
        if (f.width > str.length)
        {
            if (f.flags & Flags.AlignLeft)
                return sink(str) + writeSpace(sink, f.width - str.length);

            assert(f.flags & Flags.AlignRight);
            return writeSpace(sink, f.width - str.length) + sink(str);
        }
        // Else fall back to just writing the string
    }

    return sink(str);
}


/*******************************************************************************

    Converts a value of a given type to its string representation

    Params:
        T   = Type of the argument to convert
        v   = Value of the argument to convert
        f   = Format information gathered from parsing
        sf  = Fragment sink, to emit a part of the text without alignment
        se  = Element sink, to emit a single element with alignment

*******************************************************************************/

private void handle (T) (T v, FormatInfo f, Sink sf, ElementSink se)
{
    // Handle ref types explicitly
    static if (is (typeof(v is null)))
    {
        if (v is null)
        {
            se("null", f);
            return;
        }
    }

    /** The order in which the following conditions are applied matters.
     * Explicit type checks (e.g. associative array, or `is(T == V)`)
     * should go first as they are unambiguous.
     * Multiple conditions could be matched by the same type.
     */

    // `typeof(null)` matches way too many things
    static if (IsTypeofNull!(T))
        se("null", f);

    /** D1 + D2 support of typedef
     * Note that another approach would be to handle `struct` at the very
     * last stage and relying on `alias this` for implicit conversions.
     * However this is not a reliable approach, as having an `alias this`
     * doesn't mean that it will be a typedef, and a user might want the struct
     * to be printed instead of the first matching `alias this`.
     * In fact, there is no way to semantically express subtyping,
     * but only the means to perform it.
     * This could be solved later with a UDA, but it's at best a workaround.
     */
    else static if (IsTypedef!(T))
        handle!(DropTypedef!(T))(v, f, sf, se);

    // Cannot print enum member name in D1, so just print the value
    else static if (is (T V == enum))
             handle!(V)(v, f, sf, se);

    // Delegate / Function pointers
    else static if (is(T == delegate))
    {
        sf(T.stringof ~ ": { funcptr: ");
        writePointer(v.funcptr, f, se);
        sf(", ptr: ");
        writePointer(v.ptr, f, se);
        sf(" }");
    }
    else static if (is(T U == return))
    {
        sf(T.stringof ~ ": ");
        writePointer(v, f, se);
    }

    // Pointers need to be at the top because `(int*).min` compiles
    // and hence would match the integer rules
    // In addition, thanks to automatic dereferencing,
    // the check `v.toString()` would pass for an `Object` and an `Object*`.
    else static if (is (T P == P*))
        writePointer(v, f, se);

    // toString hook: Give priority to the non-allocating one
    // Note: sink `toString` overload should take a `scope` delegate
    else static if (is(typeof(v.toString(sf))))
        v.toString((cstring e) { return se(e, f); });
    else static if (is(typeof(v.toString()) : cstring))
        se(v.toString(), f);
    else static if (is(T == interface))
        handle!(Object)(cast(Object) v, f, sf, se);

    // Aggregate should be matched before basic type to avoid
    // `alias this` kicking in. See typedef support for more info.
    else static if (is (T == struct))
    {
        Flags old = f.flags;
        f.flags |= Flags.Nested;
        foreach (idx, ref m; v.tupleof)
        {
            static if (idx == 0)
                sf("{ " ~ FieldName!(idx, T) ~ ": ");
            else
                sf(", " ~ FieldName!(idx, T) ~ ": ");

            // A bit ugly but it makes string much more readable
            handle(m, f, sf, se);
        }
        sf(v.tupleof.length ? " }" : "{ empty struct }");
        f.flags = old;
    }

    // Bool
    else static if (is (T == bool))
        se(v ? "true" : "false", f);

    // Floating point values - Explicitly typed because we don't want
    // to support imaginary and complex FP types
    else static if (is(Unqual!(T) == float) || is(Unqual!(T) == double)
                    || is(Unqual!(T) == real))
    {
        char[T.sizeof * 8] buff = void;
        se(Float.format(buff, v, f.format), f);
    }

    // Associative array cannot be matched by IsExp in D1
    else static if (is(AAType!(T).Key))
    {
        bool started;
        Flags old = f.flags;
        f.flags |= Flags.Nested;
        foreach (key, ref val; v)
        {
            if (!started)
            {
                started = true;
                sf("[ ");
            }
            else
                sf(", ");

            handle(key, f, sf, se);
            sf(": ");
            handle(val, f, sf, se);
        }
        if (started)
            sf(" ]");
        else // Empty but not null
            sf("[:]");
        f.flags = old;
    }

    // UTF-8 strings and chars (UTF-16 and UTF-32 unsupported)
    else static if (is(T : cstring)
                    || is(T : Const!(wchar)[])
                    || is(T : Const!(dchar)[]))
    {
        if (f.flags & Flags.Nested) sf(`"`);
        UTF.toString(v, (cstring val) { return se(val, f); });
        if (f.flags & Flags.Nested) sf(`"`);
    }
    else static if (is(typeof((&v)[0 .. 1]) : cstring)
                    || is(typeof((&v)[0 .. 1]) : Const!(wchar)[])
                    || is(typeof((&v)[0 .. 1]) : Const!(dchar)[]))
    {
        Unqual!(T)[3] b = "'_'";
        b[1] = v;
        if (f.flags & Flags.Nested)
            UTF.toString(b, (cstring val) { return se(val, f); });
        else
            UTF.toString(b[1 .. 2], (cstring val) { return se(val, f); });
    }

    // Signed integer
    else static if (is(typeof(T.min)) && T.min < 0)
    {
        // Needs to support base 2 at most, plus an optional prefix
        // of 2 chars max
        char[T.sizeof * 8 + 2] buff = void;
        se(Integer.format(buff, v, f.format), f);
    }
    // Unsigned integer
    else static if (is(typeof(T.min)) && T.min == 0)
    {
        // Needs to support base 2 at most, plus an optional prefix of 2 chars
        // max
        char[T.sizeof * 8 + 2] buff = void;
        se(Integer.format(buff, v, (f.format.length ? f.format : "u")), f);
    }

    // Arrays (dynamic and static)
    else static if (is (T A : A[]))
    {
        static if (is(A == void))
            handle!(ubyte[])(cast(ubyte[]) v, f, sf, se);
        else
        {
            sf("[");
            if (v.length)
            {
                Flags old = f.flags;
                f.flags |= Flags.Nested;

                handle!(A)(v[0], f, sf, se);
                foreach (idx, ref e; v[1 .. $])
                {
                    sf(", ");
                    handle!(A)(e, f, sf, se);
                }

                f.flags = old;
            }
            sf("]");
        }
    }

    else
        static assert (0, "Type unsupported by ocean.text.convert.Formatter: "
                       ~ T.stringof);
}


/*******************************************************************************

        Helper template to detect `typeof(null)`.

        In D2, `typeof(null)` is a special type, as it has conversion rules like
        not other type. In D1, it is just `void*`.
        Since D2 version will match many cases in `handle` because it converts
        to many different type, we need to single it out, however we cannot
        just check for `is(T == typeof(null))` as it would mean `== void*` in D1

        Params:
            T   = Type to check

*******************************************************************************/

private template IsTypeofNull (T)
{
    version (D_Version2)
    {
        static if (is(T == typeof(null)))
            public const bool IsTypeofNull = true;
        else
            public const bool IsTypeofNull = false;
    }
    else
    {
        public const bool IsTypeofNull = false;
    }
}


/*******************************************************************************

        Helper template to detect if a given type is a typedef (D1 and D2).

        This bears the same name as the template in `ocean.core.Traits`.
        However, the definition in `Traits` unconditionally returns `false`
        in D2.
        While it might be suitable for most use cases, here we have to
        explicitly handle `typedef`.

        Params:
            T   = Type to check

*******************************************************************************/

private template IsTypedef (T)
{
    version (D_Version2)
        const IsTypedef = is(T.IsTypedef);
    else
        const IsTypedef = mixin("is(T == typedef)");
}

/*******************************************************************************

        Helper template to get the underlying type of a typedef (D1 and D2).

        This bears the same name as the template in `ocean.core.Traits`.
        However, the definition in `Traits` unconditionally returns `T` in D2.
        While it might be suitable for most use cases, here we have to
        explicitly handle `typedef`.

        Params:
            T   = Typedef for which to get the underlying type

*******************************************************************************/

private template DropTypedef (T)
{
    static assert(IsTypedef!(T),
                  "DropTypedef called on non-typedef type " ~ T.stringof);

    version (D_Version2)
        alias typeof(T.value) DropTypedef;
    else
        mixin("static if (is (T V == typedef))
                alias V DropTypedef;");
}


/*******************************************************************************

        Consumes the format string until a format specifier is found,
        then returns information about that format specifier

        Note:
          This function iterates over 'char', and is *NOT* Unicode-correct.
          However, neither is the original Tango one.

        Params:
            sink    = An output delegate to write to
            fmt     = The format string to consume

        Copyright:
            This function was adapted from
            `tango.text.convert.Layout.Layout.consume`.
            The original was (c) Kris

        Returns:
            A description of the format specification, see `FormatInfo`'s
            definition for more details

*******************************************************************************/

private FormatInfo consume (Sink sink, ref cstring fmt)
{
    FormatInfo ret;
    auto s = fmt.ptr;
    auto end = s + fmt.length;

    while (s < end && *s != '{')
        ++s;

    // Write all non-formatted content
    sink(forwardSlice(fmt, s));

    if (s == end)
        return ret;

    // Tango format allowed escaping braces: "{{0}" would be turned
    // into "{0}"
    if (*++s == '{')
    {
        // Will always return "{{", but we only need the first char
        sink(forwardSlice(fmt, s + 1)[0 .. 1]);
        return ret;
    }

    ret.flags |= Flags.Format;

    // extract index
    if (readNumber(ret.index, s))
        ret.flags |= Flags.Index;

    s = skipSpace(s, end);

    // has minimum or maximum width?
    if (*s == ',' || *s == '.')
    {
        if (*s == '.')
            ret.flags |= Flags.Crop;

        s = skipSpace(++s, end);
        if (*s == '-')
        {
            ret.flags |= Flags.AlignLeft;
            ++s;
        }
        else
            ret.flags |= Flags.AlignRight;

        // Extract expected width
        if (readNumber(ret.width, s))
            ret.flags |= Flags.Width;

        // skip spaces
        s = skipSpace(s, end);
    }

    // Finally get the format string, if any
    // e.g. for `{5:X} that would be 'X'
    if (*s == ':' && s < end)
    {
        auto fs = ++s;

        // eat everything up to closing brace
        while (s < end && *s != '}')
            ++s;
        ret.format = fs[0 .. cast(size_t) (s - fs)];
    }

    forwardSlice(fmt, s);

    // When the user-provided string is e.g. "Foobar {0:X"
    if (*s != '}')
    {
        sink("{missing closing '}'}");
        ret.flags |= Flags.Error;
        return ret;
    }

    // Eat the closing bracket ('}')
    fmt = fmt[1 .. $];

    return ret;
}


/*******************************************************************************

        Helper function to advance a slice to a pointer

        Params:
            s   = Slice to advance
            p   = Internal pointer to 's'

        Returns:
            A slice to the data that was consumed (e.g. s[0 .. s.ptr - p])

*******************************************************************************/

private cstring forwardSlice (ref cstring s, Const!(char)* p)
in
{
    assert(s.ptr <= p);
    assert(s.ptr + s.length >= p);
}
out (ret)
{
    assert(s.ptr == p);
    assert(ret.ptr + ret.length == p);
}
body
{
    cstring old = s.ptr[0 .. cast(size_t) (p - s.ptr)];
    s = s[old.length .. $];
    return old;
}

/*******************************************************************************

        Helper function to advance a pointer to the next non-space character

        Params:
            s   = Pointer to iterate
            end = Pointer to the end of 's'

        Returns:
            's' pointing to a non-space character or 'end'

*******************************************************************************/

private Const!(char)* skipSpace (Const!(char)* s, Const!(char)* end)
{
    while (s < end && *s == ' ')
        ++s;
    return s;
}

/*******************************************************************************

        Helper function to write a space to a sink

        Allows one to pad a string. Writes in chunk of 32 chars at most.

        Params:
            s   = Sink to write to
            n   = Amount of spaces to write

        Returns:
            Amount written (should be == n)

*******************************************************************************/

private size_t writeSpace (Sink s, size_t n)
{
    const istring Spaces32 = "                                ";
    size_t ret;

    // Make 'n' a multiple of Spaces32.length (32)
    ret += s(Spaces32[0 .. n % Spaces32.length]);
    n -= n % Spaces32.length;

    assert((n % Spaces32.length) == 0);

    while (n != 0)
    {
        ret += s(Spaces32);
        n -= Spaces32.length;
    }

    return ret;
}

/*******************************************************************************

        Helper function to read a number while consuming the input

        Params:
            f = Value in which to store the number
            s = Pointer to consume / read from

        Copyright:
            Originally from `tango.text.convert.Layout`.
            Copyright Kris

        Returns:
            `true` if a number was read, `false` otherwise

*******************************************************************************/

private bool readNumber (out size_t f, ref Const!(char)* s)
{
    if (*s >= '0' && *s <= '9')
    {
        do
            f = f * 10 + *s++ -'0';
        while (*s >= '0' && *s <= '9');
        return true;
    }
    return false;
}


/*******************************************************************************

        Write a pointer to the sink

        Params:
            v   = Pointer to write
            f   = Format information gathered from parsing
            se  = Element sink, to emit a single element with alignment

        Returns:
            `true` if a number was read, `false` otherwise

*******************************************************************************/

private void writePointer (in void* v, ref FormatInfo f, ElementSink se)
{
    alias void* T;

    version (D_Version2)
        mixin("enum int l = (T.sizeof * 2);");
    else
        const int l = (T.sizeof * 2); // Needs to be int to avoid suffix
    const defaultFormat = "X" ~ l.stringof ~ "#";

    // Needs to support base 2 at most, plus an optional prefix
    // of 2 chars max
    char[T.sizeof * 8 + 2] buff = void;
    se(Integer.format(buff, cast(ptrdiff_t) v,
                      (f.format.length ? f.format : defaultFormat)), f);
}


/*******************************************************************************

    Represent all possible boolean values that can be set in FormatInfo.flags

*******************************************************************************/

private enum Flags : ubyte
{
    None        = 0x00,     /// Default
    Format      = 0x01,     /// There was a formatting string (even if empty)
    Error       = 0x02,     /// An error happened during formatting, bail out
    AlignLeft   = 0x04,     /// Left alignment requested (via ',-' or '.-')
    AlignRight  = 0x08,     /// Right alignment requested (via ',' or '.')
    Crop        = 0x10,     /// Crop to width (via '.')
    Index       = 0x20,     /// An index was explicitly provided
    Width       = 0x40,     /// A width was explicitly provided
    Nested      = 0x80,     /// We are formatting something nested
                            ///   (i.e. in an aggregate type or an array)
}

/*******************************************************************************

    Internal struct to hold information about the format specification

*******************************************************************************/

private struct FormatInfo
{
    /***************************************************************************

        Format string, might be empty

        E.g. "{}" gives an empty `format`, and so does "{0}"
        The string "{d}" and "{0,10:f}" give 'd' and 'f', respectively.

    ***************************************************************************/

    public cstring format;

    /***************************************************************************

        Explicitly requested index to use, only meaningful if flags.Index is set

    ***************************************************************************/

    public size_t index;

    /***************************************************************************

        Output width explicitly requested, only meaningful if flags.Width is set

    ***************************************************************************/

    public size_t width;

    /***************************************************************************

        Grab bag of boolean values, check `Flags` enum for complete doc

    ***************************************************************************/

    public Flags flags;
}


/*******************************************************************************

    Original tango Layout unittest, minus changes of behaviour

    Copyright:
        These unit tests come from `tango.text.convert.Layout`.
        Copyright Kris & Larsivi

    Note:
        These tests use `assert` instead of `ocean.core.Test.test`
        since the latter will in the future use `format` to format its output,
        thus creating a circular dependency.

*******************************************************************************/

unittest
{
    // basic layout tests
    assert(format("abc") == "abc");
    assert(format("{0}", 1) == "1");


    assert(format("{0}", -1) == "-1");

    assert(format("{}", 1) == "1");
    assert(format("{} {}", 1, 2) == "1 2");
    assert(format("{} {0} {}", 1, 3) == "1 1 3");
    assert(format("{} {0} {} {}", 1, 3) == "1 1 3 {invalid index}");
    assert(format("{} {0} {} {:x}", 1, 3) == "1 1 3 {invalid index}");

    assert(format("{0}", true) == "true");
    assert(format("{0}", false) == "false");

    assert(format("{0}", cast(byte)-128) == "-128");
    assert(format("{0}", cast(byte)127) == "127");
    assert(format("{0}", cast(ubyte)255) == "255");

    assert(format("{0}", cast(short)-32768 ) == "-32768");
    assert(format("{0}", cast(short)32767) == "32767");
    assert(format("{0}", cast(ushort)65535) == "65535");
    assert(format("{0:x4}", cast(ushort)0xafe) == "0afe");
    assert(format("{0:X4}", cast(ushort)0xafe) == "0AFE");

    assert(format("{0}", -2147483648) == "-2147483648");
    assert(format("{0}", 2147483647) == "2147483647");
    assert(format("{0}", 4294967295) == "4294967295");

    // large integers
    assert(format("{0}", -9223372036854775807L) == "-9223372036854775807");
    assert(format("{0}", 0x8000_0000_0000_0000L) == "9223372036854775808");
    assert(format("{0}", 9223372036854775807L) == "9223372036854775807");
    assert(format("{0:X}", 0xFFFF_FFFF_FFFF_FFFF) == "FFFFFFFFFFFFFFFF");
    assert(format("{0:x}", 0xFFFF_FFFF_FFFF_FFFF) == "ffffffffffffffff");
    assert(format("{0:x}", 0xFFFF_1234_FFFF_FFFF) == "ffff1234ffffffff");
    assert(format("{0:x19}", 0x1234_FFFF_FFFF) == "00000001234ffffffff");
    assert(format("{0}", 18446744073709551615UL) == "18446744073709551615");
    assert(format("{0}", 18446744073709551615UL) == "18446744073709551615");

    // fragments before and after
    assert(format("d{0}d", "s") == "dsd");
    assert(format("d{0}d", "1234567890") == "d1234567890d");

    // brace escaping
    assert(format("d{0}d", "<string>") == "d<string>d");
    assert(format("d{{0}d", "<string>") == "d{0}d");
    assert(format("d{{{0}d", "<string>") == "d{<string>d");
    assert(format("d{0}}d", "<string>") == "d<string>}d");

    // hex conversions, where width indicates leading zeroes
    assert(format("{0:x}", 0xafe0000) == "afe0000");
    assert(format("{0:x7}", 0xafe0000) == "afe0000");
    assert(format("{0:x8}", 0xafe0000) == "0afe0000");
    assert(format("{0:X8}", 0xafe0000) == "0AFE0000");
    assert(format("{0:X9}", 0xafe0000) == "00AFE0000");
    assert(format("{0:X13}", 0xafe0000) == "000000AFE0000");
    assert(format("{0:x13}", 0xafe0000) == "000000afe0000");

    // decimal width
    assert(format("{0:d6}", 123) == "000123");
    assert(format("{0,7:d6}", 123) == " 000123");
    assert(format("{0,-7:d6}", 123) == "000123 ");

    // width & sign combinations
    assert(format("{0:d7}", -123) == "-0000123");
    assert(format("{0,7:d6}", 123) == " 000123");
    assert(format("{0,7:d7}", -123) == "-0000123");
    assert(format("{0,8:d7}", -123) == "-0000123");
    assert(format("{0,5:d7}", -123) == "-0000123");

    // Negative numbers in various bases
    assert(format("{:b}", cast(byte) -1) == "11111111");
    assert(format("{:b}", cast(short) -1) == "1111111111111111");
    assert(format("{:b}", cast(int) -1)
           , "11111111111111111111111111111111");
    assert(format("{:b}", cast(long) -1)
           , "1111111111111111111111111111111111111111111111111111111111111111");

    assert(format("{:o}", cast(byte) -1) == "377");
    assert(format("{:o}", cast(short) -1) == "177777");
    assert(format("{:o}", cast(int) -1) == "37777777777");
    assert(format("{:o}", cast(long) -1) == "1777777777777777777777");

    assert(format("{:d}", cast(byte) -1) == "-1");
    assert(format("{:d}", cast(short) -1) == "-1");
    assert(format("{:d}", cast(int) -1) == "-1");
    assert(format("{:d}", cast(long) -1) == "-1");

    assert(format("{:x}", cast(byte) -1) == "ff");
    assert(format("{:x}", cast(short) -1) == "ffff");
    assert(format("{:x}", cast(int) -1) == "ffffffff");
    assert(format("{:x}", cast(long) -1) == "ffffffffffffffff");

    // argument index
    assert(format("a{0}b{1}c{2}", "x", "y", "z") == "axbycz");
    assert(format("a{2}b{1}c{0}", "x", "y", "z") == "azbycx");
    assert(format("a{1}b{1}c{1}", "x", "y", "z") == "aybycy");

    // alignment does not restrict the length
    assert(format("{0,5}", "hellohello") == "hellohello");

    // alignment fills with spaces
    assert(format("->{0,-10}<-", "hello") == "->hello     <-");
    assert(format("->{0,10}<-", "hello") == "->     hello<-");
    assert(format("->{0,-10}<-", 12345) == "->12345     <-");
    assert(format("->{0,10}<-", 12345) == "->     12345<-");

    // chop at maximum specified length; insert ellipses when chopped
    assert(format("->{.5}<-", "hello") == "->hello<-");
    assert(format("->{.4}<-", "hello") == "->hell...<-");
    assert(format("->{.-3}<-", "hello") == "->...llo<-");

    // width specifier indicates number of decimal places
    assert(format("{0:f}", 1.23f) == "1.23");
    assert(format("{0:f4}", 1.23456789L) == "1.2346");
    assert(format("{0:e4}", 0.0001) == "1.0000e-04");

    // 'f.' & 'e.' format truncates zeroes from floating decimals
    assert(format("{:f4.}", 1.230) == "1.23");
    assert(format("{:f6.}", 1.230) == "1.23");
    assert(format("{:f1.}", 1.230) == "1.2");
    assert(format("{:f.}", 1.233) == "1.23");
    assert(format("{:f.}", 1.237) == "1.24");
    assert(format("{:f.}", 1.000) == "1");
    assert(format("{:f2.}", 200.001) == "200");

    // array output
    int[] a = [ 51, 52, 53, 54, 55 ];
    assert(format("{}", a) == "[51, 52, 53, 54, 55]");
    assert(format("{:x}", a) == "[33, 34, 35, 36, 37]");
    assert(format("{,-4}", a) == "[51  , 52  , 53  , 54  , 55  ]");
    assert(format("{,4}", a) == "[  51,   52,   53,   54,   55]");
    int[][] b = [ [ 51, 52 ], [ 53, 54, 55 ] ];
    assert(format("{}", b) == "[[51, 52], [53, 54, 55]]");

    char[1024] static_buffer;
    static_buffer[0..10] = "1234567890";

    assert (format("{}", static_buffer[0..10]) == "1234567890");

    // sformat()
    mstring buffer;
    assert(sformat(buffer, "{}", 1) == "1");
    assert(buffer == "1");

    buffer.length = 0;
    enableStomping(buffer);
    assert(sformat(buffer, "{}", 1234567890123) == "1234567890123");
    assert(buffer == "1234567890123");

    auto old_buffer_ptr = buffer.ptr;
    buffer.length = 0;
    enableStomping(buffer);
    assert(sformat(buffer, "{}", 1.24) == "1.24");
    assert(buffer == "1.24");
    assert(buffer.ptr == old_buffer_ptr);

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

    assert (format("{}", i) == "something");
    assert (format("{}", c) == "something");

    static struct S
    {
        istring toString()
        {
            return "something";
        }
    }

    assert(format("{}", S.init) == "something");

    // Time struct
    // Should result in something similar to "01/01/70 00:00:00" but it's
    // dependent on the system locale so we just make sure that it's handled
    version(none)
    {
        assert(format("{}", Time.epoch1970).length);
    }


    // snformat is supposed to overwrite the provided buffer without changing
    // its length and ignore any remaining formatted data that does not fit
    mstring target;
    snformat(target, "{}", 42);
    assert(target.ptr is null);
    target.length = 5; target[] = 'a';
    snformat(target, "{}", 42);
    assert(target, "42aaa");
}


/*******************************************************************************

    Tests for the new behaviour that diverge from the original Layout unit tests

*******************************************************************************/

unittest
{
    // This is handled as a pointer, not as an integer literal
    assert(format("{}", null) == "null");

    // Imaginary and complex numbers aren't supported anymore (deprecated in D2)
    // assert(format("{0:f}", 1.23f*1i) == "1.23*1i");
    // See the original Tango's code for more examples

    static struct S2 { }
    assert(format("{}", S2.init) == "{ empty struct }");
    // This used to produce '{unhandled argument type}'

    // Basic wchar / dchar support
    assert(format("{}", "42"w) == "42");
    assert(format("{}", "42"d) == "42");
    wchar wc = '4';
    dchar dc = '2';
    assert(format("{}", wc) == "4");
    assert(format("{}", dc) == "2");

    assert(format("{,3}", '8') == "  8");

    /*
     * Associative array formatting used to be in the form `{key => value, ...}`
     * However this looks too much like struct, and does not match AA literals
     * syntax (hence it's useless for any code formatting).
     * So it was changed to `[ key: value, ... ]`
     */

    // integer AA
    ushort[long] d;
    d[42] = 21;
    d[512] = 256;
    cstring formatted = format("{}", d);
    assert(formatted == "[ 42: 21, 512: 256 ]"
           || formatted == "[ 512: 256, 42: 21 ]");

    // bool/string AA
    bool[istring] e;
    e["key"] = false;
    e["value"] = true;
    formatted = format("{}", e);
    assert(formatted == `[ "key": false, "value": true ]`
           || formatted == `[ "value": true, "key": false ]`);

    // string/double AA
    mstring[double] f;
    f[ 2.0 ] = "two".dup;
    f[ 3.14 ] = "PI".dup;
    formatted = format("{}", f);
    assert(formatted == `[ 2.00: "two", 3.14: "PI" ]`
           || formatted == `[ 3.14: "PI", 2.00: "two" ]`);

    // This used to yield `[aa, bb]` but is now quoted
    assert(format("{}", [ "aa", "bb" ]) == `["aa", "bb"]`);
}


/*******************************************************************************

    Additional unit tests

*******************************************************************************/

unittest
{
    // This was not tested by tango, but the behaviour was the same
    assert(format("{0", 42) == "{missing closing '}'}");

    // Wasn't tested either, but also the same behaviour
    assert(format("foo {1} bar", 42) == "foo {invalid index} bar");

    // Typedefs are correctly formatted
    mixin(Typedef!(ulong, "RandomTypedef"));
    RandomTypedef r;
    assert(format("{}", r) == "0");

    // Support for new sink-based toString
    static struct S1
    {
        void toString (size_t delegate(cstring d) sink)
        {
            sink("42424242424242");
        }
    }
    S1 s1;
    assert(format("The answer is {0.2}", s1) == "The answer is 42...");

    // For classes too
    static class C1
    {
        void toString (size_t delegate(cstring d) sink)
        {
            sink("42424242424242");
        }
    }
    C1 c1 = new C1;
    assert(format("The answer is {.2}", c1) == "The answer is 42...");

    // Compile time support is awesome, isn't it ?
    static struct S2
    {
        void toString (size_t delegate(cstring d) sink, cstring default_ = "42")
        {
            sink(default_);
        }
    }
    S2 s2;
    assert(format("The answer is {0.2}", s2) == "The answer is 42");

    // Support for formatting struct (!)
    static struct S3
    {
        C1 c;
        int a = 42;
        int* ptr;
        char[] foo;
        cstring bar = "Hello World";
    }
    S3 s3;
    assert(format("Woot {} it works", s3)
           == `Woot { c: null, a: 42, ptr: null, foo: null, bar: "Hello World" } it works`);

    // Pointers are nice too
    int* x = cast(int*)0x2A2A_0000_2A2A;
    assert(format("Here you go: {1}", 42, x) == "Here you go: 0X00002A2A00002A2A");

    // Null AA / array
    int[] empty_arr;
    int[int] empty_aa;
    assert(format("{}", empty_arr) == "null");
    assert(format("{}", empty_aa) == "null");

    // Sadly empty != null
    int[1] static_arr;
    assert(format("{}", static_arr[$ .. $]) == "[]");

    empty_aa[42] = 42;
    empty_aa.remove(42);
    assert(format("{}", empty_aa) == "[:]");

    // Enums
    enum Foo : ulong
    {
        A = 0,
        B = 1,
        FooBar = 42
    }

    Foo f = Foo.FooBar;
    assert("42" == format("{}", f));
    f = cast(Foo)36;
    assert("36" == format("{}", f));

    // Chars
    static struct CharC { char c = 'H'; }
    char c = '4';
    CharC cc;
    assert("4" == format("{}", c));
    assert("{ c: 'H' }" == format("{}", cc));

    // void[] array are 'special'
    ubyte[5] arr = [42, 43, 44, 45, 92];
    void[] varr = arr;
    assert(format("{}", varr) == "[42, 43, 44, 45, 92]");

    // Function ptr / delegates
    auto func = cast(int function(char[], char, int)) 0x4444_1111_2222_3333;
    int delegate(void[], char, int) dg;
    dg.funcptr = cast(typeof(dg.funcptr)) 0x1111_2222_3333_4444;
    dg.ptr     = cast(typeof(dg.ptr))     0x5555_6666_7777_8888;
    assert(format("{}", func)
           == "int function(char[], char, int): 0X4444111122223333");
    assert(format("{}", dg)
           == "int delegate(void[], char, int): { funcptr: 0X1111222233334444, ptr: 0X5555666677778888 }");
}

// Const tests
unittest
{
    const int ai = 42;
    const double ad = 42.00;
    static struct Answer_struct { int value; }
    static class Answer_class
    {
        public override istring toString () /* d1to2fix_inject: const */
        {
            return "42";
        }
    }

    Const!(Answer_struct) as = Answer_struct(42);
    auto ac = new Const!(Answer_class);

    assert(format("{}", ai) == "42");
    assert(format("{:f2}", ad) == "42.00", format("{:f2}", ad));
    assert(format("{}", as) == "{ value: 42 }");
    assert(format("{}", ac) == "42");
}

// Check that `IsTypeofNull` does its job
unittest
{
    static bool test (bool fatal, istring expected, istring actual)
    {
        if (expected == actual)
            return false;
        assert(!fatal, "Expected '" ~ expected ~ "' but got: " ~ actual);
        return true;
    }

    // The logic here is a bit complicated, because we don't know
    // where in the stack we are. We could start at address
    // 0x0000_7000_0000 so growing down we'd go at address
    // 0x0000_6XXX_XXXX, which obviously would be problematic.
    // However we know that our stack frame is 68 / 72 (depends
    // on alignment), and our pointers are 16 bytes appart,
    // so retrying once should cover all cases.
    static void doTest (bool fatal)
    {
        scope Object o = new Object;
        scope void* ptr = cast(void*)o;

        istring expected = format("{}", ptr);
        istring stack_ptr = format("{}", &expected);
        istring null_str = format("{}", null);

        bool has_error;
        // Sanity check
        assert(expected != null_str);

        // Address of a pointer to the stack - can't test the value,
        // so just make sure it's a stack-ish pointer
        // We do so by testing the address  / 100

        assert(expected.length == stack_ptr.length, "Length mismatch");
        has_error = test(fatal, expected[0 .. $ - 2], stack_ptr[0 .. $ - 2]);

        stack_ptr = format("{}", &o);
        assert(expected.length == stack_ptr.length, "Length mismatch");
        if (!has_error)
            has_error = test(fatal, expected[0 .. $ - 2], stack_ptr[0 .. $ - 2]);

        if (has_error)
            doTest(true);
    }

    doTest(false);
}
