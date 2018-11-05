/*******************************************************************************

    Test module for ocean.text.convert.Formatter

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.text.convert.Formatter_test;

import ocean.core.Test;
import ocean.core.Buffer;
import ocean.text.convert.Formatter;
import ocean.transition;

unittest
{
    static struct Foo
    {
        int i = 0x2A;
        void toString (scope void delegate (cstring) sink)
        {
            sink("Hello void");
        }
    }

    Foo f;
    test!("==")(format("{}", f), "Hello void");
}

/// Test for Buffer overload
unittest
{
    Buffer!(char) buff;
    sformat(buff, "{}", 42);
    test!("==")(buff[], "42");
}

/*******************************************************************************

    Original tango Layout unittest, minus changes of behaviour

    Copyright:
        These unit tests come from `tango.text.convert.Layout`.
        Copyright Kris & Larsivi

*******************************************************************************/

unittest
{
    // basic layout tests
    test(format("abc") == "abc");
    test(format("{0}", 1) == "1");

    test(format("X{}Y", mstring.init) == "XY");

    test(format("{0}", -1) == "-1");

    test(format("{}", 1) == "1");
    test(format("{} {}", 1, 2) == "1 2");
    test(format("{} {0} {}", 1, 3) == "1 1 3");
    test(format("{} {0} {} {}", 1, 3) == "1 1 3 {invalid index}");
    test(format("{} {0} {} {:x}", 1, 3) == "1 1 3 {invalid index}");

    test(format("{0}", true) == "true");
    test(format("{0}", false) == "false");

    test(format("{0}", cast(byte)-128) == "-128");
    test(format("{0}", cast(byte)127) == "127");
    test(format("{0}", cast(ubyte)255) == "255");

    test(format("{0}", cast(short)-32768 ) == "-32768");
    test(format("{0}", cast(short)32767) == "32767");
    test(format("{0}", cast(ushort)65535) == "65535");
    test(format("{0:x4}", cast(ushort)0xafe) == "0afe");
    test(format("{0:X4}", cast(ushort)0xafe) == "0AFE");

    test(format("{0}", -2147483648) == "-2147483648");
    test(format("{0}", 2147483647) == "2147483647");
    test(format("{0}", 4294967295) == "4294967295");

    // large integers
    test(format("{0}", -9223372036854775807L) == "-9223372036854775807");
    test(format("{0}", 0x8000_0000_0000_0000L) == "9223372036854775808");
    test(format("{0}", 9223372036854775807L) == "9223372036854775807");
    test(format("{0:X}", 0xFFFF_FFFF_FFFF_FFFF) == "FFFFFFFFFFFFFFFF");
    test(format("{0:x}", 0xFFFF_FFFF_FFFF_FFFF) == "ffffffffffffffff");
    test(format("{0:x}", 0xFFFF_1234_FFFF_FFFF) == "ffff1234ffffffff");
    test(format("{0:x19}", 0x1234_FFFF_FFFF) == "00000001234ffffffff");
    test(format("{0}", 18446744073709551615UL) == "18446744073709551615");
    test(format("{0}", 18446744073709551615UL) == "18446744073709551615");

    // fragments before and after
    test(format("d{0}d", "s") == "dsd");
    test(format("d{0}d", "1234567890") == "d1234567890d");

    // brace escaping
    test(format("d{0}d", "<string>") == "d<string>d");
    test(format("d{{0}d", "<string>") == "d{0}d");
    test(format("d{{{0}d", "<string>") == "d{<string>d");
    test(format("d{0}}d", "<string>") == "d<string>}d");

    // hex conversions, where width indicates leading zeroes
    test(format("{0:x}", 0xafe0000) == "afe0000");
    test(format("{0:x7}", 0xafe0000) == "afe0000");
    test(format("{0:x8}", 0xafe0000) == "0afe0000");
    test(format("{0:X8}", 0xafe0000) == "0AFE0000");
    test(format("{0:X9}", 0xafe0000) == "00AFE0000");
    test(format("{0:X13}", 0xafe0000) == "000000AFE0000");
    test(format("{0:x13}", 0xafe0000) == "000000afe0000");

    // decimal width
    test(format("{0:d6}", 123) == "000123");
    test(format("{0,7:d6}", 123) == " 000123");
    test(format("{0,-7:d6}", 123) == "000123 ");

    // width & sign combinations
    test(format("{0:d7}", -123) == "-0000123");
    test(format("{0,7:d6}", 123) == " 000123");
    test(format("{0,7:d7}", -123) == "-0000123");
    test(format("{0,8:d7}", -123) == "-0000123");
    test(format("{0,5:d7}", -123) == "-0000123");

    // Negative numbers in various bases
    test(format("{:b}", cast(byte) -1) == "11111111");
    test(format("{:b}", cast(short) -1) == "1111111111111111");
    test(format("{:b}", cast(int) -1)
           , "11111111111111111111111111111111");
    test(format("{:b}", cast(long) -1)
           , "1111111111111111111111111111111111111111111111111111111111111111");

    test(format("{:o}", cast(byte) -1) == "377");
    test(format("{:o}", cast(short) -1) == "177777");
    test(format("{:o}", cast(int) -1) == "37777777777");
    test(format("{:o}", cast(long) -1) == "1777777777777777777777");

    test(format("{:d}", cast(byte) -1) == "-1");
    test(format("{:d}", cast(short) -1) == "-1");
    test(format("{:d}", cast(int) -1) == "-1");
    test(format("{:d}", cast(long) -1) == "-1");

    test(format("{:x}", cast(byte) -1) == "ff");
    test(format("{:x}", cast(short) -1) == "ffff");
    test(format("{:x}", cast(int) -1) == "ffffffff");
    test(format("{:x}", cast(long) -1) == "ffffffffffffffff");

    // argument index
    test(format("a{0}b{1}c{2}", "x", "y", "z") == "axbycz");
    test(format("a{2}b{1}c{0}", "x", "y", "z") == "azbycx");
    test(format("a{1}b{1}c{1}", "x", "y", "z") == "aybycy");

    // alignment does not restrict the length
    test(format("{0,5}", "hellohello") == "hellohello");

    // alignment fills with spaces
    test(format("->{0,-10}<-", "hello") == "->hello     <-");
    test(format("->{0,10}<-", "hello") == "->     hello<-");
    test(format("->{0,-10}<-", 12345) == "->12345     <-");
    test(format("->{0,10}<-", 12345) == "->     12345<-");

    // chop at maximum specified length; insert ellipses when chopped
    test(format("->{.5}<-", "hello") == "->hello<-");
    test(format("->{.4}<-", "hello") == "->hell...<-");
    test(format("->{.-3}<-", "hello") == "->...llo<-");

    // width specifier indicates number of decimal places
    test(format("{0:f}", 1.23f) == "1.23");
    test(format("{0:f4}", 1.23456789L) == "1.2346");
    test(format("{0:e4}", 0.0001) == "1.0000e-04");

    // 'f.' & 'e.' format truncates zeroes from floating decimals
    test(format("{:f4.}", 1.230) == "1.23");
    test(format("{:f6.}", 1.230) == "1.23");
    test(format("{:f1.}", 1.230) == "1.2");
    test(format("{:f.}", 1.233) == "1.23");
    test(format("{:f.}", 1.237) == "1.24");
    test(format("{:f.}", 1.000) == "1");
    test(format("{:f2.}", 200.001) == "200");

    // array output
    int[] a = [ 51, 52, 53, 54, 55 ];
    test(format("{}", a) == "[51, 52, 53, 54, 55]");
    test(format("{:x}", a) == "[33, 34, 35, 36, 37]");
    test(format("{,-4}", a) == "[51  , 52  , 53  , 54  , 55  ]");
    test(format("{,4}", a) == "[  51,   52,   53,   54,   55]");
    int[][] b = [ [ 51, 52 ], [ 53, 54, 55 ] ];
    test(format("{}", b) == "[[51, 52], [53, 54, 55]]");

    char[1024] static_buffer;
    static_buffer[0..10] = "1234567890";

    test (format("{}", static_buffer[0..10]) == "1234567890");

    // sformat()
    mstring buffer;
    test(sformat(buffer, "{}", 1) == "1");
    test(buffer == "1");

    buffer.length = 0;
    enableStomping(buffer);
    test(sformat(buffer, "{}", 1234567890123) == "1234567890123");
    test(buffer == "1234567890123");

    auto old_buffer_ptr = buffer.ptr;
    buffer.length = 0;
    enableStomping(buffer);
    test(sformat(buffer, "{}", 1.24) == "1.24");
    test(buffer == "1.24");
    test(buffer.ptr == old_buffer_ptr);

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

    test (format("{}", i) == "something");
    test (format("{}", c) == "something");

    static struct S
    {
        istring toString()
        {
            return "something";
        }
    }

    test(format("{}", S.init) == "something");

    // Time struct
    // Should result in something similar to "01/01/70 00:00:00" but it's
    // dependent on the system locale so we just make sure that it's handled
    version(none)
    {
        test(format("{}", Time.epoch1970).length);
    }


    // snformat is supposed to overwrite the provided buffer without changing
    // its length and ignore any remaining formatted data that does not fit
    mstring target;
    snformat(target, "{}", 42);
    test(target.ptr is null);
    target.length = 5; target[] = 'a';
    snformat(target, "{}", 42);
    test(target, "42aaa");
}


/*******************************************************************************

    Tests for the new behaviour that diverge from the original Layout unit tests

*******************************************************************************/

unittest
{
    // This is handled as a pointer, not as an integer literal
    test(format("{}", null) == "null");

    // Imaginary and complex numbers aren't supported in D2
    // test(format("{0:f}", 1.23f*1i) == "1.23*1i");
    // See the original Tango's code for more examples

    static struct S2 { }
    test(format("{}", S2.init) == "{ empty struct }");
    // This used to produce '{unhandled argument type}'

    // Basic wchar / dchar support
    test(format("{}", "42"w) == "42");
    test(format("{}", "42"d) == "42");
    wchar wc = '4';
    dchar dc = '2';
    test(format("{}", wc) == "4");
    test(format("{}", dc) == "2");

    test(format("{,3}", '8') == "  8");

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
    test(formatted == "[ 42: 21, 512: 256 ]"
           || formatted == "[ 512: 256, 42: 21 ]");

    // bool/string AA
    bool[istring] e;
    e["key"] = false;
    e["value"] = true;
    formatted = format("{}", e);
    test(formatted == `[ "key": false, "value": true ]`
           || formatted == `[ "value": true, "key": false ]`);

    // string/double AA
    mstring[double] f;
    f[ 2.0 ] = "two".dup;
    f[ 3.14 ] = "PI".dup;
    formatted = format("{}", f);
    test(formatted == `[ 2.00: "two", 3.14: "PI" ]`
           || formatted == `[ 3.14: "PI", 2.00: "two" ]`);

    // This used to yield `[aa, bb]` but is now quoted
    test(format("{}", [ "aa", "bb" ]) == `["aa", "bb"]`);
}


/*******************************************************************************

    Additional unit tests

*******************************************************************************/

unittest
{
    // This was not tested by tango, but the behaviour was the same
    test(format("{0", 42) == "{missing closing '}'}");

    // Wasn't tested either, but also the same behaviour
    test(format("foo {1} bar", 42) == "foo {invalid index} bar");

    // Typedefs are correctly formatted
    mixin(Typedef!(ulong, "RandomTypedef"));
    RandomTypedef r;
    test(format("{}", r) == "0");

    // Support for new sink-based toString
    static struct S1
    {
        void toString (scope FormatterSink sink)
        {
            sink("42424242424242");
        }
    }
    S1 s1;
    test(format("The answer is {0.2}", s1) == "The answer is 42...");

    // For classes too
    static class C1
    {
        void toString (scope FormatterSink sink)
        {
            sink("42424242424242");
        }
    }
    C1 c1 = new C1;
    test(format("The answer is {.2}", c1) == "The answer is 42...");

    // Compile time support is awesome, isn't it ?
    static struct S2
    {
        void toString (scope FormatterSink sink, cstring default_ = "42")
        {
            sink(default_);
        }
    }
    S2 s2;
    test(format("The answer is {0.2}", s2) == "The answer is 42");

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
    test(format("Woot {} it works", s3)
           == `Woot { c: null, a: 42, ptr: null, foo: "", bar: "Hello World" } it works`);

    // Pointers are nice too
    int* x = cast(int*)0x2A2A_0000_2A2A;
    test(format("Here you go: {1}", 42, x) == "Here you go: 0X00002A2A00002A2A");

    // Null AA / array
    int[] empty_arr;
    int[int] empty_aa;
    test(format("{}", empty_arr) == "[]");
    test(format("{}", empty_aa) == "[:]");
    int[1] static_arr;
    test(format("{}", static_arr[$ .. $]) == "[]");

    empty_aa[42] = 42;
    empty_aa.remove(42);
    test(format("{}", empty_aa) == "[:]");

    // Enums
    enum Foo : ulong
    {
        A = 0,
        B = 1,
        FooBar = 42
    }

    Foo f = Foo.FooBar;
    test("42" == format("{}", f));
    f = cast(Foo)36;
    test("36" == format("{}", f));

    // Chars
    static struct CharC { char c = 'H'; }
    char c = '4';
    CharC cc;
    test("4" == format("{}", c));
    test("{ c: 'H' }" == format("{}", cc));

    // void[] array are 'special'
    ubyte[5] arr = [42, 43, 44, 45, 92];
    void[] varr = arr;
    test(format("{}", varr) == "[42, 43, 44, 45, 92]");

    static immutable ubyte[5] carr = [42, 43, 44, 45, 92];
    auto cvarr = carr; // Immutable, cannot be marked `const` in D1
    test(format("{}", cvarr) == "[42, 43, 44, 45, 92]");

    // Function ptr / delegates
    auto func = cast(int function(char[], char, int)) 0x4444_1111_2222_3333;
    int delegate(void[], char, int) dg;
    dg.funcptr = cast(typeof(dg.funcptr)) 0x1111_2222_3333_4444;
    dg.ptr     = cast(typeof(dg.ptr))     0x5555_6666_7777_8888;
    test(format("{}", func)
           == "int function(char[], char, int): 0X4444111122223333");
    test(format("{}", dg)
           == "int delegate(void[], char, int): { funcptr: 0X1111222233334444, ptr: 0X5555666677778888 }");
}

// Const tests
unittest
{
    static immutable int ai = 42;
    static immutable double ad = 42.00;
    static struct Answer_struct { int value; }
    static class Answer_class
    {
        public override istring toString () const
        {
            return "42";
        }
    }

    Const!(Answer_struct) as = Answer_struct(42);
    auto ac = new Const!(Answer_class);

    test(format("{}", ai) == "42");
    test(format("{:f2}", ad) == "42.00", format("{:f2}", ad));
    test(format("{}", as) == "{ value: 42 }");
    test(format("{}", ac) == "42");
}

// Check that `IsTypeofNull` does its job,
// and that pointers to objects are not dereferenced
unittest
{
    // Since `Object* o; istring s = o.toString();`
    // compiles, the test for `toString` used to pass
    // on pointers to object, which is wrong.
    // Fixed in sociomantic/ocean#1605
    Object* o = cast(Object*) 0xDEADBEEF_DEADBEEF;
    void* ptr = cast(void*) 0xDEADBEEF_DEADBEEF;

    static immutable istring expected = "0XDEADBEEFDEADBEEF";
    istring object_str = format("{}", o);
    istring ptr_str = format("{}", ptr);
    istring null_str = format("{}", null);

    test(ptr_str != null_str);
    test(object_str != null_str);
    test(ptr_str == expected);
    test(object_str == expected);
}

// Check for pointers to Typedef
unittest
{
    mixin(Typedef!(ulong, "Typedefed"));
    mixin(Typedef!(Typedefed*, "TypedefedPtr"));

    Typedefed* t1 =   cast(Typedefed*)   0xDEADBEEF_00000000;
    version (D_Version2)
        TypedefedPtr t2 = cast(Typedefed*)   0xDEADBEEF_DEADBEEF;
    else
        TypedefedPtr t2 = cast(TypedefedPtr) 0xDEADBEEF_DEADBEEF;

    test(format("{}", t1) == "0XDEADBEEF00000000");
    test(format("{}", t2) == "0XDEADBEEFDEADBEEF");
}

unittest
{
    static immutable bool YES = true;
    static immutable bool NO  = false;
    test(format("{} -- {}", YES, NO) == "true -- false");
}

unittest
{
    // Used to work only with "{:X}", however this limitation was lifted
    assert(format("{X}", 42) == "2A");
}
