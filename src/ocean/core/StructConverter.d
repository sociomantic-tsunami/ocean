/******************************************************************************

    Struct Converter functions

    Functions to make converting an instance to a similar but not equal type
    easier.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.core.StructConverter;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;
import ocean.core.Traits,
       ocean.core.Traits;

/***************************************************************************

    Copies members of the same name from <From> to <To>.

    Given a variable in <To> called 'example_var', if a convert function in <To>
    exists with the name 'convert_example_var', then this function will be
    called and no automatic conversion will happen for that variable. The
    function must have one of the following signatures:
    ---
    void delegate ( ref <From>, void[] delegate ( size_t ) )
    void delegate ( ref <From> )
    void delegate ( );
    ---
    The delegate passed to the first can be used to allocate temporary buffers
    that the convert function might need to do its converting.

    If no convert function exists and the types differ, various things happen:

    * For structs it calls this function again
    * For dynamic arrays, a temporary array of the same length is created and
      this function is called for every element of the array
    * For static arrays the same happens, just without a temporary allocation

    If the types are the same a simple assignment will be done. The types have
    to match exactly, implicit conversions are not supported.

    It is an error if a variable in <To> doesn't exist in <From> and no convert
    function for it exists,

    Note: Dynamic arrays of the same type will actually reference the same
          memory where as arrays of similar types that were converted use memory
          provided by the requestBuffer delegate.

    Template Parameters:
        From = type we're copying from
        To   = type we're copying to

    Parameters:
        from          = instance we're copying from
        to            = instance we're copying to
        requestBuffer = delegate to request temporary buffers used during
                        conversion.

***************************************************************************/

public void structConvert ( From, To ) ( ref From from, out To to,
    void[] delegate ( size_t ) requestBuffer
        = ( size_t n ) { return new void[n]; } )
{
    static assert ( is ( From == struct ) && is ( To == struct ),
            "structConvert works only on structs, not on " ~
            From.stringof ~ " / " ~ To.stringof);

    static if (is(From == To))
    {
        to = from;
    }
    else
    {
        foreach ( to_index, ref to_member; to.tupleof )
        {
            // FIXME enum
            version (D_Version2)
                mixin(`enum convFuncName = "convert_" ~ FieldName!(to_index, To);`);
            else
                const convFuncName = "convert_" ~ FieldName!(to_index, To);

            static if ( structHasMember!(convFuncName, To)() )
            {
                callBestOverload!(From, To, convFuncName)(from, to, requestBuffer);
            }
            else static if ( structHasMember!(FieldName!(to_index, To), From)() )
            {
                auto from_field = getField!(FieldName!(to_index, To))(from);
                auto to_field = &to.tupleof[to_index];

                copyField(from_field, to_field, requestBuffer);
            }
            else
            {
                static assert ( false, "Unhandled field: " ~
                            FieldName!(to_index, To) ~ " of type " ~
                            typeof(to_member).stringof);
            }
        }
    }
}

/*******************************************************************************

    Helper function for structConvert().

    Copies a field to another field, doing a conversion if required and
    possible.

    Template_Params:
        From = type of field we copy/convert from
        To   = type of field we copy/convert to

    Params:
        from_field = pointer to the field we want to copy/convert from
        to_field   = pointer to the field we want to copy/convert to
        requestBuffer = delegate to request temporary memory for doing
                        conversions

*******************************************************************************/

private void copyField ( From, To ) ( From* from_field, To* to_field,
                                      void[] delegate ( size_t ) requestBuffer )
{
    static if ( is ( typeof(*to_field) : typeof(*from_field) ) )
    {
        static if ( isStaticArrayType!(typeof((*to_field))) )
        {
            (*to_field)[] = (*from_field)[];
        }
        else
        {
            *to_field = *from_field;
        }
    }
    else static if ( is ( typeof((*to_field)) == struct ) &&
                     is ( typeof(*from_field) == struct ) )
    {
        alias structConvert!(typeof(*from_field), typeof((*to_field))) copyMember;

        copyMember(*from_field, *to_field,
                   requestBuffer);
    }
    else static if (isStaticArrayType!(typeof((*to_field))) &&
                    isStaticArrayType!(typeof(*from_field)))
    {
        alias BaseTypeOfArrays!(typeof(*to_field))   ToBaseType;
        alias BaseTypeOfArrays!(typeof(*from_field)) FromBaseType;

        static if ( is(ToBaseType == struct) &&
                    is(FromBaseType == struct) )
        {
            foreach ( i, ref el; *to_field )
            {
                structConvert!(FromBaseType, ToBaseType)((*from_field)[i],
                                                       el, requestBuffer);
            }
        }
        else
        {
            static assert (1==0, "Unsupported auto-struct-conversion " ~
                FromBaseType.stringof ~ " -> " ~ ToBaseType.stringof ~
                ". Please provide the convert function " ~ To.stringof ~
                 "." ~ convertToFunctionName(FieldName!(to_index, To)));
        }
    }
    else static if (isDynamicArrayType!(typeof((*to_field))) &&
                    isDynamicArrayType!(typeof(*from_field)))
    {
        alias BaseTypeOfArrays!(typeof(*to_field))   ToBaseType;
        alias BaseTypeOfArrays!(typeof(*from_field)) FromBaseType;

        static if ( is(ToBaseType == struct) &&
                    is(FromBaseType == struct) )
        {
            if ( from_field.length > 0 )
            {
                auto buf = requestBuffer(from_field.length * ToBaseType.sizeof);

                *to_field = (cast(ToBaseType*)buf)[0 .. from_field.length];

                foreach ( i, ref el; *to_field )
                {
                    structConvert!(FromBaseType, ToBaseType)((*from_field)[i],
                                                          el, requestBuffer);
                }
            }
            else
            {
                *to_field = null;
            }
        }
        else
        {
            static assert (false, "Unsupported auto-struct-conversion " ~
                FromBaseType.stringof ~ " -> " ~ ToBaseType.stringof ~
                ". Please provide the convert function " ~ To.stringof ~
                 "." ~ convertToFunctionName(FieldName!(to_index, To)));
        }
    }
    else
    {
        // Workaround for error-swallowing DMD1 bug
        /+
            module main;

            size_t foo ( bool bar ) ( int )
            {
            }

            unittest
            {
                    foo!(true) ();
            }

            Outputs:
                main.d(10): Error: template main.foo(bool bar) does not match any function template declaration
                main.d(10): Error: template main.foo(bool bar) cannot deduce template function from argument types !(true)()

            Fixing the error in foo (by adding `return 0;`) changes the output to

            main.d(10): Error: function main.foo!(true).foo (int _param_0) does not match parameter types ()
            main.d(10): Error: expected 1 function arguments, not 0
        +/

        pragma(msg, "Unhandled field: " ~
                    FieldName!(to_index, To) ~ " of types " ~ To.stringof ~ "." ~
                        typeof((*to_field)).stringof ~ " " ~ From.stringof ~ "." ~
                        typeof(*from_field).stringof);

        static assert ( false, "Unhandled field: " ~
                        FieldName!(to_index, To) ~ " of types " ~
                        typeof((*to_field)).stringof ~ " " ~
                        typeof(*from_field).stringof);
    }
}

/*******************************************************************************

    Checks whether struct S has a member (variable or method) of the given name

    Template_Params:
        name = name to check for
        S    = struct to check

    Returns:
        true if S has queried member, else false

*******************************************************************************/

private bool structHasMember ( istring name, S ) ( )
{
    mixin(`
        static if (is(typeof(S.` ~ name ~`)))
        {
            return true;
        }
        else
        {
            return false;
        }`);
}

/*******************************************************************************

    Calls the function given in function_name in struct To.
    The function must have one of the following signatures:
    ---
    void delegate ( ref <From>, void[] delegate ( size_t ) )
    void delegate ( ref <From> )
    void delegate ( );
    ---

    Template_Params:
        From = type of the struct that will be passed to the function
        To   = type of the struct that has to have that function
        function_name = name of the function that To must have

    Params:
        from = struct instance that will be passed to the function
        to   = struct instance that should have said function declared
        requestBuffer = memory request method that the function can use (it
                        should not allocate memory itself)

*******************************************************************************/

private void callBestOverload ( From, To, istring function_name )
           ( ref From from, ref To to, void[] delegate ( size_t ) requestBuffer )
{
     mixin (`
        void delegate ( ref From, void[] delegate ( size_t ) ) longest_convert;
        void delegate ( ref From ) long_convert;
        void delegate ( ) convert;

        static if ( is ( typeof(longest_convert = &to.`~function_name~`)) )
        {
            longest_convert = &to.`~function_name~`;

            longest_convert(from, requestBuffer);
        }
        else static if ( is ( typeof(long_convert = &to.`~function_name~`)) )
        {
            long_convert = &to.`~function_name~`;

            long_convert(from);
        }
        else static if ( is ( typeof(convert = &to.`~function_name~`)) )
        {
            convert = &to.`~function_name~`;

            convert();
        }
        else
        {
            const convFuncTypeString = typeof(&to.`~function_name~`).stringof;
            static assert ( false,
              "Function ` ~
             To.stringof ~ `.` ~ function_name ~
             ` (" ~ convFuncTypeString ~ ") doesn't `
             `have any of the accepted types `
             `'void delegate ( ref "~From.stringof~", void[] delegate ( size_t ) )' or `
             `'void delegate ( ref "~From.stringof~" )' or `
             `'void delegate ( )'" );
        }`);

}

/*******************************************************************************

    aliases to the type of the member <name> in the struct <Struct>

    Template_Params:
        name = name of the member you want the type of
        Struct = struct that <name> is member of

*******************************************************************************/

private template TypeOf ( istring name, Struct )
{
    mixin(`alias typeof(Struct.`~name~`) TypeOf;`);
}

/*******************************************************************************

    Returns a pointer to the field <field_name> defined in the struct <Struct>

    Template_Params:
        field_name = name of the field in the struct <Struct>
        Struct     = struct that is expected to have a member called
                     <field_name>

    Returns:
        pointer to the field <field_name> defined in the struct <Struct>

*******************************************************************************/

private TypeOf!(field_name, Struct)* getField ( istring field_name, Struct )
                                              ( ref Struct s )
{
    mixin(`
        static if ( is ( typeof(Struct.`~field_name~`) ) )
        {
            return &(s.`~field_name~`);
        }
        else
        {
            return null;
        }`);
}

version(UnitTest)
{
    void[] testAlloc( size_t s )
    {
        return new void[s];
    }
}

// same struct
unittest
{
    struct A
    {
        int x;
    }

    A a1, a2;
    a1.x = 42;

    structConvert(a1, a2, toDg(&testAlloc));
    assert ( a1.x == a2.x, "failure to copy same type instances" );
}

// same fields, different order
unittest
{
    struct A
    {
        int a;
        int b;
        short c;
    }

    struct B
    {
        short c;
        int a;
        int b;
    }

    auto a = A(1,2,3);
    B b;

    structConvert(a, b, toDg(&testAlloc));

    assert ( a.a == b.a, "a != a" );
    assert ( a.b == b.b, "b != b" );
    assert ( a.c == b.c, "c != c" );
}

// no conversion method -> failure
unittest
{
    struct A
    {
        int x;
    }

    struct B
    {
        int x;
        int y;
    }

    A a; B b;

    static assert (!is(typeof(structConvert(a, b, toDg(&testAlloc)))));
}

// multiple conversions at once
unittest
{
    static struct A
    {
        int a;
        int b;
        int[][] i;
        int c;
        char[] the;

        struct C
        {
            int b;
        }

        C srt;
    }

    static struct B
    {
        int c;
        short b;
        int a;
        short d;
        char[] the;
        int[][] i;

        struct C
        {
            int b;
            int c;
            int ff;

            // verify different conversion signatures...
            void convert_c () {}
            void convert_ff ( ref A.C, void[] delegate ( size_t ) ) {}
        }

        C srt;

        void convert_b ( ref A structa )
        {
            this.b = cast(short) structa.b;
        }

        void convert_d ( ref A structa)
        {
            this.d = cast(short) structa.a;
        }
    }

    auto a = A(1,2, [[1,2], [45,234], [53],[3]],3, "THE TEH THE RTANEIARTEN".dup);
    B b_loaded;

    structConvert!(A, B)(a, b_loaded, toDg(&testAlloc));

    assert ( b_loaded.a == a.a, "Conversion failure" );
    assert ( b_loaded.b == a.b, "Conversion failure" );
    assert ( b_loaded.c == a.c, "Conversion failure" );
    assert ( b_loaded.d == a.a, "Conversion failure" );
    assert ( b_loaded.the[] == a.the[], "Conversion failure" );
    assert ( b_loaded.the.ptr == a.the.ptr, "Conversion failure" );
    assert ( b_loaded.i.ptr == a.i.ptr, "Conversion failure" );
    assert ( b_loaded.i[0][] == a.i[0][], "Nested array mismatch" );
    assert ( b_loaded.i[1][] == a.i[1][], "Nested array mismatch" );
    assert ( b_loaded.i[2][] == a.i[2][], "Nested array mismatch" );
    assert ( b_loaded.i[3][] == a.i[3][], "Nested array mismatch" );
}

// multiple conversion overloads

version(UnitTest)
{
    // can't place those structs inside unit test block because of
    // forward reference issue

    struct A
    {
        int x;

        void convert_x ( ref B src )
        {
            this.x = cast(int) src.x;
        }
    }

    struct B
    {
        uint x;

        void convert_x ( ref A src )
        {
            this.x = cast(uint) src.x;
        }

        void convert_x ( ref C src )
        {
            this.x = cast(uint) src.x;
        }
    }

    struct C
    {
        double x;

        void convert_x ( ref B src )
        {
            this.x = src.x;
        }
    }
}

unittest
{
    A a; B b; C c;

    a.x = 42;
    structConvert(a, b, toDg(&testAlloc));
    assert(b.x == 42);

    b.x = 43;
    structConvert(b, a, toDg(&testAlloc));
    assert(a.x == 43);

    structConvert(b, c, toDg(&testAlloc));
    assert(c.x == 43);

    c.x = 44;
    structConvert(c, b, toDg(&testAlloc));
    assert(b.x == 44);
}
