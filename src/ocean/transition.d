/*******************************************************************************

    This modules contains utilities and aliases that are used during D1->D2
    transition process. Idea is to define single module that contains wrapper
    aliases / structures and switch all code to use it. Once actual porting
    time comes it will be enough to simply change version in this module.

    version(D2) can't be used because D2 code can't be even parsed by D1
    compiler, resorting to commenting out because of that.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.transition;

/*******************************************************************************

    String type aliases. Goal is to avoid mentioning plain `char[]` types in
    code and replace with aliases needed for this code to compile in D2. To
    find this out one needs to try compiling module in D2 mode once other
    stuff is taken care of and fix all immutability errors by using these
    aliases, then switch back to D1 and verify it still compiles.

    In most cases you will need to use cstring for any function parameter types
    as those can accept both immutable and normal char arrays. However istring
    is necessary for Object overloads like toString() to match exact signature
    in object.di

*******************************************************************************/

alias Immut!(char)[] istring;
alias Const!(char)[] cstring;
alias char[]         mstring;

/*******************************************************************************

    Helper template to be used instead of plain types in function parameter
    list when one will need to be const-qualified in D2 world - usually this is
    necessary if function needs to handle string literals.

    This should be used instead of istring/cstring aliases in generic array
    processing functions as opposed to string-specific code.

    Example:

    ---
    void foo(Element)(Const!(Element)[] buf)
    {
    }

    foo!(char)("aaa"); // will work in both D1 and D2
    ---

*******************************************************************************/

template Const(T)
{
    version(D_Version2)
    {
        mixin("alias const(T) Const;");
    }
    else
    {
        alias T Const;
    }
}

unittest
{
    alias Const!(int[]) Int;

    static assert (is(Int));

    version(D_Version2)
    {
        mixin("static assert (is(Int == const));");
    }
}

/*******************************************************************************

    Same as Const!(T) but for immutable

    Example:

    ---
    Immut!(char)[] foo()
    {
        return "aaa"; // ok, immutable
        return new char[]; // error, mutable
    }
    ---

*******************************************************************************/

template Immut(T)
{
    version(D_Version2)
    {
        mixin("alias immutable(T) Immut;");
    }
    else
    {
        alias T Immut;
    }
}

unittest
{
    alias Immut!(int[]) Int;

    static assert (is(Int));

    version(D_Version2)
    {
        mixin("static assert (is(Int == immutable));");
    }
}

/*******************************************************************************

    Same as Const!(T) but for inout

    Example:

    ---
    Inout!(char[]) foo(Inout!(char[]) arg)
    {
        return arg;
    }

    mstring = foo("aaa"); // error
    istring = foo("aaa"); // ok
    mstring = foo("aaa".dup); // ok
    ---

*******************************************************************************/

template Inout(T)
{
    version(D_Version2)
    {
        mixin("alias inout(T) Inout;");
    }
    else
    {
        alias T Inout;
    }
}

unittest
{
    alias Inout!(char[]) Str;

    Str foo ( Str arg ) { return arg; }

    mstring s1 = foo("aaa".dup);
    istring s2 = foo("aaa");
}

/*******************************************************************************

    In D1 does nothing. In D2 strips top-most type qualifier.

    This is a small helper useful for adapting templated code where template
    parameter can possibly be deduced as const or immutable. Using this type
    directly in implementation will result in unmodifiable variables which isn't
    always wanted.

    Example:

    ---
    void foo(Element)(Element[] buf)
    {
        // this causes an error with D2 if element
        // gets deduced as const
        Element tmp;
        tmp = Element.init;

        // this is ok in both d1 and D2
        Unqual!(Element) tmp;
        tmp = Element.init;
    }
    ---

*******************************************************************************/

template Unqual(T)
{
    version (D_Version2)
    {
        mixin("
            static if (is(T U == const U))
            {
                alias U Unqual;
            }
            else static if (is(T U == immutable U))
            {
                alias U Unqual;
            }
            else
            {
                alias T Unqual;
            }
        ");
    }
    else
    {
        alias T Unqual;
    }
}

unittest
{
    static assert (is(Unqual!(typeof("a"[0])) == char));
}

/*******************************************************************************

    Checks (non-transitively) if type is mutable

    Template_Params:
        T = any plain type

*******************************************************************************/

template isMutable( T )
{
    version (D_Version2)
    {
        mixin ("enum isMutable = !is(T == const) && !is(T == immutable);");
    }
    else
    {
        const isMutable = true;
    }
}

unittest
{
    version (D_Version2)
        static assert (!isMutable!(typeof("aaa"[0])));
    else
        static assert ( isMutable!(typeof("aaa"[0])));
}

/*******************************************************************************

    Replacement for `typedef` which is completely deprecated. It generates
    usual `typedef` when built with D1 compiler and wrapper struct with
    `alias this` when built with D2 compiler.

    Used as mixin(Typedef!(hash_t, "MyHash"))

    D2 version has `IsTypedef` member alias defined so that any struct type
    can be quickly checked if it originates from typedef via
    `is(typeof(S.IsTypedef))`. This is a hack reserved for backwards
    compatibility in libaries and should be never relied upon in user code.

    Template Parameters:
        T       = type to typedef
        name    = identifier string for new type
        initval = optional default value for that type

*******************************************************************************/

template Typedef(T, istring name, T initval)
{
    static assert (name.length, "Can't create Typedef with an empty identifier");
    version(D_Version2)
    {
        mixin(`
            enum Typedef =
                ("static struct " ~ name ~
                "{ " ~
                "alias IsTypedef = void;" ~
                T.stringof ~ " value = " ~ initval.stringof ~ ";" ~
                "alias value this;" ~
                "this(" ~ T.stringof ~ " rhs) { this.value = rhs; }" ~
                " }");
        `);
    }
    else
    {
        mixin(`
            const Typedef = ("typedef " ~ T.stringof ~ " " ~ name ~
                " = " ~ initval.stringof ~ ";");
        `);
    }
}

/// ditto
template Typedef(T, istring name)
{
    static assert (name.length, "Can't create Typedef with an empty identifier");
    version(D_Version2)
    {
        mixin(`
            enum Typedef =
                ("static struct " ~ name ~
                "{ " ~
                "alias IsTypedef = void;" ~
                T.stringof ~ " value; " ~
                "alias value this;" ~
                "this(" ~ T.stringof ~ " rhs) { this.value = rhs; }" ~
                " }");
        `);
    }
    else
    {
        mixin(`
            const Typedef = ("typedef " ~ T.stringof ~ " " ~ name ~ ";");
        `);
    }
}

unittest
{
    mixin(Typedef!(int, "MyInt1", 42));
    mixin(Typedef!(int, "MyInt2", 42));

    static assert (!is(MyInt1 : MyInt2));

    MyInt1 myint;
    assert(myint == 42);

    void foo1(MyInt2) { }
    void foo2(MyInt1) { }
    void foo3(int) { }

    static assert (!is(typeof(foo1(myint))));
    static assert ( is(typeof(foo2(myint))));
    static assert ( is(typeof(foo3(myint))));

    int base = myint;
    assert(base == myint);
    myint = cast(MyInt1) (base + 1);
    assert(myint == 43);
}

unittest
{
    struct MyType { }

    mixin(Typedef!(MyType, "MyType2"));
    MyType2 var;

    static assert (is(typeof(var) : MyType));
}

unittest
{
    mixin(Typedef!(int, "MyInt"));
    MyInt var = 42;
    assert (var == 42);
}

/*******************************************************************************

    Helper to smooth transition between D1 and D2 runtime behaviours regarding
    array stomping. In D2 appending to array slice after length has been changed
    results in allocating new array to prevent overwriting old data.

    We use and actually rely on that behaviour for buffer re-usage.
    `assumeSafeAppend` from object.d enables stomping back but adding using this
    no-op wrapper in D1 code will save time on trying to find those extremely
    subtle issues upon actual transition.

    All places that reset length to 0 will need to call this helper.

    Params:
        array = array slice that is going to be overwritten

*******************************************************************************/

void enableStomping(T)(ref T array)
{
    version(D_Version2)
    {
        assumeSafeAppend(array);
    }
    else
    {
        /* no-op */
    }
}

/*******************************************************************************

    Helper template that can be used instead of deprecated octal literals. In
    some cases preserving octal notation is really important for readability and
    those can't be simply replace with decimal/hex ones.

    Template_Params:
        literal = octal number literal as string

*******************************************************************************/

static import ocean.text.convert.Integer_tango;

template Octal(istring literal)
{
    const Octal = ocean.text.convert.Integer_tango.parse(literal, 8);
}

unittest
{
    static assert (Octal!("00") == 0);
    static assert (Octal!("12") == 10);
    static assert (Octal!("1") == 1);
    static assert (Octal!("0001") == 1);
    static assert (Octal!("0010") == 8);
    static assert (Octal!("666") == (6 + 8*6 + 8*8*6));
}

/*******************************************************************************

    In D1 ModuleInfo is a class. In D2 it is a struct. ModuleInfoPtr aliases
    to matching reference type for each of those.

*******************************************************************************/

version (D_Version2)
{
    alias ModuleInfo* ModuleInfoPtr;
}
else
{
    alias ModuleInfo  ModuleInfoPtr;
}


/*******************************************************************************

    In D2 variables are thread-local by default. In many cases this is exactly
    what you need but sometimes true globals are necessary - primarily related
    to thread and related tool implementation.

    This small mixin helper prepends __gshared to input declatation when
    compiled in D2 mode.

*******************************************************************************/

istring global(istring decl)
{
    version (D_Version2)
    {
        return "__gshared " ~ decl ~ ";";
    }
    else
    {
        return decl ~ ";";
    }
}

unittest
{
    mixin(global("int x = 42"));
    assert(x == 42);
}

/*******************************************************************************

    D1 does not have notion of immutable and thus .idup built-in. However it is
    necessary to make certain algorithms const-correct. Hiding D2 built-in
    behind trivial wrapper function helps with that.

    Params:
        s = string to idup

    Returns:
        copy of s, immutable if compiled in D2 mode

*******************************************************************************/

version (D_Version2)
{}
else
{
    Immut!(T)[] idup(T)(T[] s)
    {
        return cast(Immut!(T)[]) s.dup;
    }
}

unittest
{
    mstring s1;
    istring s2 = idup(s1);
    s2 = idup("aaa");
    s2 = idup(cstring.init);

    wchar[] w1;
    Immut!(wchar)[] w2 = idup(w1);

    dchar[] d1;
    Immut!(dchar)[] d2 = idup(d1);
}

/*******************************************************************************

    In D2 .min was renamed to .min_normal for floating point types to
    make its meaning more obvious. This is a trivial template wrapper that
    unifies the naming.

    Template_Params:
        T = any floating point type

    Return:
        minimal normalized value for that type

*******************************************************************************/

version (D_Version2)
{
    template min_normal(T : real)
    {
        const min_normal = T.min_normal;
    }
}
else
{
    template min_normal(T : real)
    {
        const min_normal = T.min;
    }
}

unittest
{
    version (D_Version2)
    {
        static assert (min_normal!(double) == double.min_normal);
    }
    else
    {
        static assert (min_normal!(double) == double.min);
    }
}

/*******************************************************************************

    Trivial wrapper for a cast from any string to immutable string to make code
    more readable. Is only legal if no one else has reference to `input`
    contents.

    NB! D1 does not allow overloading on rvalue vs lvalue, nor it has anything
    similar to D2 `auto ref` feature. At the same time matching Phobos semantics
    requires to nullify slice that gets casted to immutable. Because of that
    our assumeUnique accepts only rvalues - use temporary local variables to
    assign lvalues if those need to be used with assumeUnique

*******************************************************************************/

Immut!(T)[] assumeUnique(T)(ref T[] input)
{
    auto tmp = input;
    input = null;
    return cast(Immut!(T)[]) tmp;
}

unittest
{
    auto s1  = "aaa".dup;
    auto s2 = assumeUnique(s1);

    assert (s2 == "aaa");
    assert (s1 is null);
}

/*******************************************************************************

    Mixin helper to generate proper opCmp declaration. It differs between D1
    and D2 runtime and not matching exact signature will result in weird
    segmentation faults from inside the runtime.

    Params:
        func_body = code of opCmp as string. Must refer to argument as `rhs`

    Returns:
        full declaration/definition of opCmp that matches current compiler

*******************************************************************************/

istring genOpCmp(istring func_body)
{
    istring result;

    // We need to know if it's a class or not. If it is, one might want to
    // compare against literals, so we cannot take it by `const ref`.

    result ~= "static if (is(typeof(this) == class))\n{\n";
    result ~= "override int opCmp(Object rhs)\n";
    result ~= func_body;
    result ~= "\n}\nelse\n{\n";
    version (D_Version2)
    {
        result ~= "int opCmp(const typeof(this) rhs) const\n";
    }
    else
    {
        result ~= "int opCmp(typeof(*this) rhs)\n";
    }
    result ~= func_body;
    result ~= "\n}\n";

    return result;
}

unittest
{
    struct S
    {
        int x;

        mixin (genOpCmp("
        {
            if (this.x >= rhs.x)
                return this.x > rhs.x;
            return -1;
        }
        "));

        equals_t opEquals (S rhs)
        {
            return this.opCmp(rhs) == 0;
        }
    }

    class C
    {
        private int x;

        this (int a)
        {
            this.x = a;
        }

        mixin (genOpCmp(
        `{
            auto o = cast(typeof(this)) rhs;
            if (o is null)
                return -1;
            if (this.x >= o.x)
                return this.x > o.x;
            return -1;
        }`));
    }

    assert (S(1) < S(2));
    assert (S(2) > S(1));
    assert (S(2) >= S(2));
    assert (S(2) <= S(2));
    assert (new C(1) < new C(2));
    assert (new C(2) > new C(1));
    assert (new C(2) >= new C(2));
    assert (new C(2) <= new C(2));

    version (D_Version2) { }
    else
    {
        // built-in sort is deprecated and importing ocean.core.Array
        // introduces module cycle
        auto s_arr = [ S(2), S(3), S(1) ];
        auto c_arr = [ new C(2), new C(3), new C(1) ];
        s_arr.sort;
        c_arr.sort;

        assert (s_arr == [ S(1), S(2), S(3) ]);
        assert (c_arr <= [ new C(1), new C(2), new C(3) ]);
        assert (c_arr >= [ new C(1), new C(2), new C(3) ]);
        // Fails because we haven't overriden opEquals...
        // assert (c_arr == [ new C(1), new C(2), new C(3) ]);
    }
}

/*******************************************************************************

    Mixin helper to generate proper opEquals declaration. It differs between D1
    and D2 runtime and not matching exact signature will result in the default
    version, defined by the compiler, to be silently called instead.

    Params:
        func_body = code of opEquals as string. Must refer to argument as `rhs`

    Returns:
        full declaration/definition of opEquals that matches current compiler

*******************************************************************************/

public istring genOpEquals(istring func_body)
{
    istring result;

    // We need to know if it's a class or not. If it is, one might want to
    // compare against literals, so we cannot take it by `const ref`.

    result ~= "static if (is(typeof(this) == class))\n{\n";
    result ~= "override equals_t opEquals(Object rhs)\n";
    result ~= func_body;
    result ~= "\n}\nelse\n{\n";
    version (D_Version2)
    {
        result ~= "bool opEquals(const typeof(this) rhs) const\n";
    }
    else
    {
        result ~= "int opEquals(typeof(*this) rhs)\n";
    }
    result ~= func_body;
    result ~= "\n}\n";

    return result;
}

unittest
{
    struct S
    {
        int x;
        int y;

        // Use a crazy definition, as the default one would pass those tests :)
        mixin (genOpEquals("
        {
            return this.x == rhs.y && this.y == rhs.x;
        }
        "));
    }

    class C
    {
        private int x;

        this (int a)
        {
            this.x = a;
        }

        mixin (genOpEquals(
        `{
            auto o = cast(typeof(this)) rhs;
            if (o is null) return false;
            return (this.x == o.x);
        }`));
    }

    assert (S(2, 1) == S(1, 2));
    assert (new C(2) == new C(2));

    assert (S(1, 2) != S(1, 2));
    assert (S(2, 1) != S(2, 1));
    assert (!(S(1, 2) == S(1, 2)));
    assert (!(S(2, 1) == S(2, 1)));

    C nil;

    assert (new C(1) != new C(2));
    assert (new C(2) != new C(1));
    assert (!(new C(1) == new C(2)));
    assert (!(new C(2) == new C(1)));
    assert (new C(1) != nil);
    assert (!(new C(1) == nil));

    // D1 runtime dereference null if it's LHS...
    //assert (nil != new C(2));
    //assert (!(nil == new C(2)));
}


/*******************************************************************************

    D2 differentiates between Exceptions ("normal" recoverable cases) and
    Errors (fatal failures). Throwable is an exception hierarchy root that is
    used a base for both.

*******************************************************************************/

version (D_Version2)
{
    // already provided by object.d
}
else
{
    alias Exception Throwable;
}


/*******************************************************************************

    In D1, typeof(this) is always a reference type to the aggregate, while in
    D2 it's the actual type of the aggregate. It doesn't change anything for
    classes which are reference types, but for struct and unions, it yields
    a pointer instead of the actual type.
    d1tod2fix does the convertion automatically for `structs`, but there are
    places where manual intervention is needed (e.g. `mixin template`s).

*******************************************************************************/

public template TypeofThis()
{
    version (D_Version2)
    {
        alias typeof(this) This;
    }
    else
    {
        static if (is(typeof(this) == class))
        {
            alias typeof(this) This;
        }
        else
        {
            alias typeof(*this) This;
        }
    }
}

version (UnitTest)
{
    private struct FooClass
    {
        mixin TypeofThis;
    }
    private struct FooStruct
    {
        mixin TypeofThis;
    }

    private union FooUnion
    {
        mixin TypeofThis;
    }
}

unittest
{
    static assert (is(FooClass.This == FooClass));
    static assert (is(FooStruct.This == FooStruct));
    static assert (is(FooUnion.This == FooUnion));
}

/*******************************************************************************

    Exact upstream API for `Throwable.message` is not yet known. Using this
    function to get it allows to implement any needed API bridge without
    breaking/changing user code.

*******************************************************************************/

cstring getMsg ( Throwable e )
{
    // if compiled with a runtime which already provides `message()`, use it
    static if (is(typeof(e.message())))
        return e.message();
    else
    {
        // try workaround alternatives

        version (D_Version2)
        {
            // reusable exceptions don't have common base class which makes
            // impossible to accesss `reused_msg` directly but it is best to
            // ensure at least "traditional" exceptions are formatted correctly
            // before failing 
            if (e.msg.length)
                return e.msg;
            else
                // ReusableExceptionImpl currently implements D2 toString in
                // the same way as D1 toString which is illegal but can be used
                // as temporary workaround
                return e.toString();
        }
        else
        {
            // in D1 `toString` only contains message thus can use it as a replacement
            return e.toString();
        }
    }

    // example of adapting sink based API
    version (none)
    {
        static mstring buffer;
        buffer.length = 0;
        enableStomping(buffer);
        e.message((cstring chunk) {
            buffer ~= chunk;
        });  
        return buffer;
    }
}

unittest
{
    auto e = new Exception("abcde");
    assert (getMsg(e) == "abcde");
}

/*******************************************************************************

    Helper which provides stub implementation of GC.usage if it is not present
    upstream in order to keep ocean compiling and passing tests.

*******************************************************************************/

static import core.memory;

static if (is(typeof(core.memory.GC.usage)))
{
    alias core.memory.GC.usage gc_usage;
}
else
{
    void gc_usage ( out size_t used, out size_t free )
    {
        // no-op
    }
}
