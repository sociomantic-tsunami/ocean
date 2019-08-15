/*******************************************************************************

    Module containing Json deserialization functions

    Copyright (c) 2019 dunnhumby Germany GmbH. All rights reserved

*******************************************************************************/

module ocean.text.json.JsonDeserializer;

import ocean.core.Array: copy;
import ocean.meta.traits.Arrays;
import ocean.meta.traits.Basic;
import ocean.meta.types.Arrays;
import ocean.meta.types.Typedef;
import ocean.text.json.Json;
import ocean.transition;
import ocean.util.ReusableException;

version(UnitTest)
{
    import ocean.core.Test;
}

/// The type of the Json parser used in this module
alias Json!(char) JsonReader;

/// Class used to deserialize Json strings to D structs
class JsonDeserializer
{
    /// Instance used to parse the json string
    private JsonReader json;

    /// The reusable exception used by the instance
    private ReusableException exception;

    ///
    private JsonReader.JsonObject* main_object;

    /// Constructor
    public this ( )
    {
        this.json = new JsonReader();
        this.exception = new ReusableException();
    }

    /**************************************************************************

        Loads a json string

        Params:
            json_string = The json string that is needed to be parsed

    ***************************************************************************/

    public void load ( string json_string )
    {
        this.main_object = json.parse(json_string).toObject();
    }

    /**************************************************************************

        Parse the loaded json to a D structure

        Params:
            T = The data type that will result after deserialization

        Returns:
            The new T instance with the parsed JSON

    **************************************************************************/

    public T getStruct ( T ) ( )
    {
        return extractObjectFields!(T)(this.main_object);
    }

    /**************************************************************************

        Parse a json string to a D structure

        Params:
            T = The data type that will result after deserialization
            json_string = The json string that will be parsed

        Returns:
            The parsed structure. If the structure is not found, an exception
            is thrown.

    **************************************************************************/

    public T fromJsonString ( T ) ( string json_string )
    {
        this.load(json_string);

        return this.getStruct!(T);
    }
}

/******************************************************************************

    Copies the Json object attributes to a new struct

    Params:
        T = The new struct type
        object = The Json value

    Returns:
        The deserialized value

******************************************************************************/

private T extractObjectFields ( T ) ( JsonReader.JsonObject* object )
{
    T result;

    foreach ( member, value; object.attributes() )
    {
        mixin(genAttributeReader!(T));
    }

    return result;
}

/******************************************************************************

    Deserialize a Typedef type from Json values

    Params:
        T = The deserialized type
        source = The Json value

    Returns:
        The deserialized Typedef value

******************************************************************************/

private T deserializeJson ( T ) ( JsonReader.Value source )
    if ( is(T.IsTypedef) )
{
    T destination = deserializeJson!(typeof(T.value))(source);

    return destination;
}


/******************************************************************************

    Deserialize D basic types from Json values

    Params:
        T = The deserialized type
        source = The Json value

    Returns:
        The deserialized D value

******************************************************************************/

private T deserializeJson ( T ) ( JsonReader.Value source )
    if ( __traits(isScalar, T) )
{
    return cast(T) source.toNumber();
}

/******************************************************************************

    Deserialize an array of D structs

    Params:
        T = The deserialized type
        source = The Json list

    Returns:
        The deserialized D list

******************************************************************************/

private T[] deserializeJson ( T: T[] ) ( JsonReader.Value source )
    if ( is(Unqual!T == struct) && !is(T.IsTypedef) )
{
    Unqual!(T)[] destination;

    auto items = source.toArray();
    destination.length = items.length;

    foreach ( i, item; items )
    {
        destination[i] = extractObjectFields!(T)(item.toObject);
    }

    return cast(T[])destination;
}



/******************************************************************************

    Deserialize a struct that has a push method and a list of elements

    Params:
        T = The deserialized type
        source = The Json list

    Returns:
        The deserialized D list

******************************************************************************/

private U deserializeJson ( U ) ( JsonReader.Value source ) if ( __traits ( hasMember, U, "push" ) &&
    __traits ( hasMember, U, "elements" ) )
{
    alias T = ElementTypeOf!(typeof(U.elements));
    U destination;

    auto items = source.toArray();

    foreach(i, item; items)
    {
        destination.push(deserializeJson!(T)(item));
    }

    return destination;
}

/******************************************************************************

    Convert a Json string to a D string

    Params:
        T = The deserialized string type
        source = The Json string

    Returns:
        The deserialized string

******************************************************************************/

private T deserializeJson ( T ) ( JsonReader.Value source )
    if ( is(T == mstring) || is(T == cstring) || is(T == istring) )
{
    char[] destination;
    copy(destination, source.toString());

    return cast(T)destination;
}

/******************************************************************************

    Convert a Json array of basic types to a D array. Json has a dedicated
    type for strings, because of that this function deserializes only arrays
    of strings.

    Params:
        T = The deserialized type
        source = The Json array value

    Returns:
        The array of the deserialized data

******************************************************************************/

private T[] deserializeJson ( T: T[] ) ( JsonReader.Value source )
    if( (__traits(isScalar, T) && !is(Unqual!T == char)) || is(T == mstring) ||
    is(T == cstring) || is(T == istring) )
{
    Unqual!(T)[] destination;

    auto items = source.toArray();
    destination.length = items.length;

    foreach ( i, item; items )
    {
        destination[i] = deserializeJson!(T)(item);
    }

    return cast(T[])destination;
}

/// It should parse a struct with a double
unittest
{
    struct TestData
    {
        double some_value;
    }

    auto parser = new JsonDeserializer();

    string serializedTestData = `{ "some_value": 2 }`;

    auto data = parser.fromJsonString!TestData(serializedTestData);

    test!("==")(data, TestData(2));
}

/// It should parse a struct with an int
unittest
{
    struct TestData
    {
        int some_value;
    }

    auto parser = new JsonDeserializer();

    string serializedTestData = `{ "some_value": 2 }`;

    auto data = parser.fromJsonString!TestData(serializedTestData);

    test!("==")(data, TestData(2));
}

/// It should parse a struct with a string
unittest
{
    struct TestData
    {
        string some_value;
    }

    auto parser = new JsonDeserializer();

    string serializedTestData = `{ "some_value": "The best test string ever" }`;

    auto data = parser.fromJsonString!TestData(serializedTestData);

    test!("==")(data, TestData("The best test string ever"));
}

/// It should parse a struct with a list of strings
unittest
{
    struct TestData
    {
        string[] some_values;
    }

    auto parser = new JsonDeserializer();

    string serializedTestData = `{ "some_values": ["Test1", "Test2"] }`;

    auto data = parser.fromJsonString!TestData(serializedTestData);

    test!("==")(data, TestData(["Test1", "Test2"]));
}

/// It should parse a nested struct
unittest
{
    mixin(Typedef!(int, "Other", 41));

    struct NestedStruct
    {
        ulong price;
        Other other;
    }

    struct TestStruct
    {
        int id;
        string name;

        NestedStruct[] items;
    }

    string serializedTestData = `{
        "id": 1,
        "name": "didibao",
        "items": [{
            "price": 777,
            "other": 1999
        }]
    }`;

    auto parser = new JsonDeserializer();
    auto result = parser.fromJsonString!(TestStruct)(serializedTestData);

    TestStruct expected;
    expected.id = 1;
    expected.name = "didibao";
    expected.items ~= NestedStruct(777, Other(1999));

    test!("==")(result, expected);
}

version (UnitTest)
{
    mixin(Typedef!(int, "BufferItem", 41));

    struct Buffer
    {
        BufferItem[] elements;

        void push (BufferItem value)
        {
            elements ~= value;
        }
    }

    struct TestStruct
    {
        Buffer buffer;
    }
}

/// It should parse a struct with push method and an elements array
unittest
{
    string serializedTestData = `{"buffer":[1,2,3]}`;

    auto parser = new JsonDeserializer();
    auto result = parser.fromJsonString!(TestStruct)(serializedTestData);

    TestStruct expected;

    expected.buffer.push(BufferItem(1));
    expected.buffer.push(BufferItem(2));
    expected.buffer.push(BufferItem(3));

    test!("==")(result, expected);
}

/******************************************************************************

    Generate D code that iterates over the struct member that can be
    deserialized and calls `deserializeJson` for them.

    Properties:
        T = The struct type that is needed to be deserialized

    Returns:
        The D code that calls `deserializeJson` for each member

******************************************************************************/

private string genAttributeReader ( T ) ( )
{
    string result;

    foreach ( member; properties!(T) )
    {
        result ~=
            `if(member == "` ~ member ~ `")
            {
                result.` ~ member ~ ` = deserializeJson!(typeof(T.` ~ member ~ `))(value);
            }`;
    }

    return result;
}

/******************************************************************************

    Get the list of struct members that can be deserialized from Json. A member
    can be deserialized if it's a mutable public instance member. All static,
    private and enum fields will be ignored.

    Properties:
        T = The struct that will be checked

    Returns:
        A list of strings containing the name of the deserializable members

******************************************************************************/

private string[] properties ( T ) ( )
{
    string[] names;

    foreach ( name; [ __traits(allMembers, T) ] )
    {
        if ( isProperty!(T)(name) )
        {
            names ~= name;
        }
    }

    return names;
}

version(UnitTest)
{
    struct OtherStruct {}

    struct TestProperties
    {
        int a;
        ulong b;
        bool c;
        string d;
        string[] e;
        OtherStruct f;

        static int ignore_static;
        const ignore_constants = 2;
        void ignore_methods() {};

        struct IgnoreStructs {}
        class IgnoreClass {}
        enum my_enum = 3;
    }
}

/// The properties function should return only the members that can be serialized
unittest
{
    test!("==")(properties!(TestProperties), [ "a", "b", "c", "d", "e", "f" ]);
}

/******************************************************************************

    Check if a struct member is a public instance member

    Params:
        T = The struct that will be checked
        member = The member name that will be checked

    Returns:
        True if the struct member is a property and can be deserialized from
        Json

******************************************************************************/

private bool isProperty ( T ) ( string member )
{
    mixin(genIsProperty!(T));
    return false;
}

/******************************************************************************

    Check if a type is a mutable scalar or struct

    Property:
        T = The type to be checked

    Returns:
        True if the type is a basic D type, a struct or a class that is not
        const or immutable

******************************************************************************/

private bool isProperty ( T ) ( )
{
    return (__traits(isScalar, T) || is(T == struct)) && !is(T == const) &&
        !is(T == immutable);
}

/******************************************************************************

    Check if an array type is a string or an array of other property type

    Properties:
        T = The array type

    Returns:
        True if the array value is a property or it is a string

******************************************************************************/

private bool isProperty ( T: T[] ) ( )
{
    return isProperty!(T) || is(Unqual!T == char);
}

/******************************************************************************

    Generate code that checks if a struct member is a property

    Properties:
        T = The struct that will be used to generate the code

    Returns:
        The code that checks if `member` is a property inside the
        given struct

******************************************************************************/

private string genIsProperty ( T ) ( )
{
    string result;

    foreach ( name; [ __traits(allMembers, T) ] ) {
        if ( name == "this" ) continue;
        if ( name == "__ctor" ) continue;

        result ~=
        `if(member == "` ~ name ~ `")
        {
            enum protection = __traits(getProtection, T.` ~ name ~ `);

            static if(
                    protection != "public" ||
                    is(T.` ~ name ~ ` == struct) ||
                    is(T.` ~ name ~ ` == class) ||
                    is(T.` ~ name ~ ` == enum) ||
                    isManifestConstant!(T, "` ~ name ~ `") ||
                    __traits(compiles, T.` ~ name ~ ` = typeof(T.` ~ name ~ `).init)) {
                return false; // because it is not public, a struct, a class, enum or static member
            }
            else
            {
                return isProperty!(typeof(T.` ~ name ~ `));
            }
        }`;
    }

    return result;
}
