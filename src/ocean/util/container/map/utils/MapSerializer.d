/*******************************************************************************

    Contains extensions for Map based classes to dump the contents of maps to a
    file or to read from a file into a map. Includes struct versioning support.

    This module provides you with several ways to load/dump a map from/into
    a file:

    * Using the specialized version SerializingMap of the class Map
    * Using the provided MapExtension mixin to extend a map yourself
    * Using the class MapSerializer to use the load/dump functions directly

    See documentation of class MapSerializer for more details

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.container.map.utils.MapSerializer;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.io.digest.Fnv1,
       ocean.io.serialize.SimpleSerializer,
       ocean.io.serialize.TypeId,
       ocean.util.container.map.Map,
       ocean.core.Traits : ContainsDynamicArray;
import ocean.core.Array : copy;
import ocean.core.Exception;

import ocean.core.Exception_tango    : IOException;
import ocean.io.model.IConduit : IOStream;

import ocean.core.Traits,
       ocean.core.Tuple,
       ocean.io.stream.Buffered,
       ocean.io.device.File;

import ocean.util.serialize.contiguous.MultiVersionDecorator,
       ocean.util.serialize.contiguous.Serializer,
       ocean.util.serialize.Version;

/*******************************************************************************

    Temporary solution to expose protected `convert` method of version
    decorator to this module. Eventually MapSerializer should be rewritten
    to either inherit MultiVersionDecorator or mixin necessary methods directly.

    This is not done in first round of changes because it is potentially
    intrusive implementation change.

*******************************************************************************/

private class Converter : VersionDecorator
{
}

/*******************************************************************************

    Specialized version of class Map that includes serialization capabilities
    using the MapExtension mixin

    Everything else is identical to the class Map, that means you still need to
    implement your own hashing functionality.

    Note:
        The serializer allows simple transition from using a map with a
        non-versioned key / value to a versioned one. The version of the
        key / value must be v0 and the layout must be the same,
        otherwise loading will fail.

    Template_Params:
        V = type of the value
        K = type of the key

*******************************************************************************/

abstract class SerializingMap ( V, K ) : Map!(V, K)
{
    /***************************************************************************

        Mixin extensions for serialization

    ***************************************************************************/

    mixin MapExtension!(K, V);

    /***************************************************************************

        Constructor.

        Same as the Constructor of Map, but additionally initializes the
        serializer.

    ***************************************************************************/

    protected this ( size_t n, float load_factor = 0.75 )
    {
        this.serializer = new MapSerializer;
        super(n, load_factor);
    }

    /***************************************************************************

        Constructor.

        Same as the Constructor of Map, but additionally initializes the
        serializer.

    ***************************************************************************/

    protected this ( IAllocator allocator, size_t n, float load_factor = 0.75 )
    {
        this.serializer = new MapSerializer;
        super(allocator, n, load_factor);
    }
}

/*******************************************************************************

    Template meant to be used with mixin in classes that inherit from the class
    Map.

    Extends the class with a load() and dump() function. The mixed in class has
    to initialize the member 'serializer' in its constructor.

    See SerializingMap for an usage example

    Template_Params:
        K = key type of the map
        V = value type of the map

*******************************************************************************/

template MapExtension ( K, V )
{
    /***************************************************************************

        Delegate used to check whether a given record should be dumped or loaded

    ***************************************************************************/

    alias bool delegate ( ref K, ref V ) CheckDg;

    /***************************************************************************

        Instance of the serializer, needs to be initialized in the class
        constructor

    ***************************************************************************/

    protected MapSerializer serializer;

    /***************************************************************************

        Loads a file into the map

        Params:
            file_path = path to the file

    ***************************************************************************/

    public void load ( cstring file_path )
    {
        this.serializer.load!(K, V)(this, file_path);
    }

    /***************************************************************************

        Loads a file into the map

        Params:
            file_path = path to teh file
            check     = function called for every entry, should return true if
                        it should be loaded

    ***************************************************************************/

    public void load ( cstring file_path, CheckDg check  )
    {
        void add ( ref K k, ref V v )
        {
            if (check(k,v))
            {
                bool added = false;

                static if ( isDynamicArrayType!(V) )
                {
                    (*this.put(k, added)).copy(v);
                }
                else
                {
                    (*this.put(k, added)) = v;
                }

                // If added key is an array and new don't reuse the memory it
                // references
                static if ( isDynamicArrayType!(K) ) if ( added )
                {
                    k = k.dup;
                }
            }
        }

        this.serializer.loadDg!(K, V)(file_path, &add);
    }

    /***************************************************************************

        Dumps a map into a file

        Params:
            file_path = path to the file

    ***************************************************************************/

    public void dump ( cstring file_path )
    {
        this.serializer.dump!(K, V)(this, file_path);
    }

    /***************************************************************************

        Writes a map to a file.

        Params:
            file_path = path to where the map should be dumped to
            check     = function called for each key/value to confirm that it
                        should be dumped

     ***************************************************************************/

    public void dump ( cstring file_path, CheckDg check )
    {
        void adder ( void delegate ( ref K, ref V ) add )
        {
            foreach ( ref k, ref v; this ) if ( check(k,v) )
            {
                add(k, v);
            }
        }

        this.serializer.dumpDg!(K, V)(file_path, &adder);
    }
}

/*******************************************************************************

    Offers functionality to load/dump the content of Maps (optionally of
    anything actually, using the delegate version of the dump/load functions).

    Features include backwards compability with auto-conversion to the requested
    struct version. It makes use of the same functions that the
    StructLoader/StructDumper use for the conversion.

    This means that structs used with this function should have the const
    member StructVersion as well as an alias to the old version (if one exists)
    called "StructPrevious" (this is identical to the requirements for vesioned
    struct in the StructDumper/Loader).

    Additionally, a validation using the struct hash is done too, to exclude
    potential human errors while setting up the version info.

    If you have a map saved in the old version (2) and at the same time updated
    the struct definition of that map, you can still take advantage of the
    auto-conversion functionality if you simply define the old struct version as
    version 0 and your current one as version 1. The loader is smart enough to
    figure out the old version by hash and converts it to the newer one.

    Usage Example:
    ---
    struct MyValue0
    {
        const StructVersion = 0;
        int my_value;
    }

    auto serializer = new MapSerializer;
    auto myMap = new HashMap!(MyValue0)(10);

    // Assume code to fill map with values here
    //...
    //

    serializer.dump(myMap, "version0.map");

    // Later...

    serilizer.load(myMap, "version0.map");


    // Now, if you have changed the struct, create a new version of it

    struct MyValue1
    {
        const StructVersion = 1;
        int my_value;

        int my_new_value;

        void convert_my_new_value ( ref MyValue0 old )
        {
            this.my_new_value = old.my_value * 2;
        }
    }

    // This is our map with the new version
    auto myNewMap = new HashMap!(MyValue1)(10);

    // Load old version
    serializer.load(myNewMap, "version0.map");

    // .. use map as desired.

    // You can do the same thing with the key in case it is a struct.
    ---
*******************************************************************************/

class MapSerializer
{
    import ocean.io.digest.Fnv1: StaticFnv1a64;

    /***************************************************************************

        Magic Marker for HashMap files, part of the header

     ***************************************************************************/

    private const uint MAGIC_MARKER = 0xCA1101AF;

    /***************************************************************************

        Current file header version

    ***************************************************************************/

    private const ubyte HEADER_VERSION = 5;

    /***************************************************************************

        Exception thrown when the file that was loaded is incomplete. Will soon
        be unused

    ***************************************************************************/

    class UnexpectedEndException : Exception
    {
        mixin DefaultExceptionCtor;
    }

    /***************************************************************************

        Helper template for version handling.
        Takes a tuple of types and changes the type and position index to what
        ever it has as .StructPrevious member.

        Only works with tuples of length 2

        Template_Params:
            index = index of the type that will be made into StructPrevious
            T...  = tuple of the types

    ***************************************************************************/

    template AddStructPrevious ( ubyte index, T... )
    {
        static assert ( T.length == 2 );
        static assert ( index <= 1 );

        static if ( index == 0 )
        {
            alias Tuple!(T[0].StructPrevious, T[1]) AddStructPrevious;
        }
        else
        {
            alias Tuple!(T[0], T[1].StructPrevious) AddStructPrevious;
        }
    }

    /***************************************************************************

        Takes a type tuple and transforms it into the same type tuple but with
        the types being pointers to the original types.

        Template_Params:
            T... = tuple to convert

    ***************************************************************************/

    template AddPtr ( T... )
    {
        static if ( T.length > 0 )
        {
            alias Tuple!(T[0]*, AddPtr!(T[1..$])) AddPtr;
        }
        else
        {
            alias T AddPtr;
        }
    }

    /***************************************************************************

        Struct to be used for creating unique hash

    ***************************************************************************/

    private struct KeyValueStruct( K, V)
    {
        K k;
        V v;
    }

    /***************************************************************************

        Evaluates to the fnv1 hash of the types that make up the struct.
        If S is no struct, mangled name of the type is used.

        Template_Params:
            S = struct containing key & value

    ***************************************************************************/

    template StructHash ( S )
    {
        static if ( is (typeof(TypeHash!(S))) )
        {
            const StructHash = TypeHash!(S);
        }
        else
        {
            const StructHash = StaticFnv1a64!(typeof(S.k).mangleof ~
                                             typeof(S.v).mangleof);
        }
    }

    /***************************************************************************

        File header writen at the beginning of a dumped HashMap

    ***************************************************************************/

    private struct FileHeader ( K, V, ubyte VERSION )
    {
        /***********************************************************************

            Magic Marker, making sure that this file is really what we expect it
            to be

        ***********************************************************************/

        uint marker         = MAGIC_MARKER;

        /***********************************************************************

            Version of the FileHeader. Should be changed for any modification

        ***********************************************************************/

        ubyte versionNumber = VERSION;

        /***********************************************************************

            Hash or Version of the struct types, making sure that the key and
            value types are the same as when this file was saved.

        ***********************************************************************/

        static if ( VERSION <= 2 &&
                    !is ( K == class) && !is (V == class) &&
                    !is ( K == interface) && !is (V == interface) )
        {
            ulong hash = TypeHash!(KeyValueStruct!(K,V));
        }

        static if ( VERSION >= 3 && VERSION <= 4 )
        {
            static if ( Version.Info!(K).exists )
            {
                ubyte key_version = Version.Info!(K).number;
            }

            static if ( Version.Info!(V).exists )
            {
                ubyte value_version = Version.Info!(V).number;
            }

            static if ( !Version.Info!(K).exists &&
                        !Version.Info!(V).exists &&
                        !is ( K == class) && !is (V == class) &&
                        !is ( K == interface) && !is (V == interface) )
            {
                ulong hash = TypeHash!(KeyValueStruct!(K,V));
            }
        }
        else static if ( VERSION >= 5 )
        {
            ubyte key_version = Version.Info!(K).number;
            ubyte value_version = Version.Info!(V).number;
            ulong hash = StructHash!(KeyValueStruct!(K,V));
        }
    }

    /***************************************************************************

        Delegate used to put values in a map

    ***************************************************************************/

    template PutterDg ( K, V )
    {
        alias void delegate ( ref K, ref V ) PutterDg;
    }

    /***************************************************************************

        Delegate used to add new values from a map

    ***************************************************************************/

    template AdderDg ( K, V )
    {
        alias void delegate ( void delegate ( ref K, ref V ) ) AdderDg;
    }

    /***************************************************************************

        Pair of buffers used for conversion

    ***************************************************************************/

    struct BufferPair
    {
        void[] first, second;
    }

    /***************************************************************************

        buffered output instance

    ***************************************************************************/

    private BufferedOutput buffered_output;

    /***************************************************************************

        buffered input instance

    ***************************************************************************/

    private BufferedInput buffered_input;

    /***************************************************************************

        Temporary buffers to convert value structs

    ***************************************************************************/

    private BufferPair value_convert_buffer;

    /***************************************************************************

        Temporary buffers to convert key structs

    ***************************************************************************/

    private BufferPair key_convert_buffer;

    /***************************************************************************

        Writing buffer for the StructDumper

    ***************************************************************************/

    private void[] dump_buffer;

    /***************************************************************************

        Struct converter with internal buffer

    ***************************************************************************/

    private Converter converter;

    /***************************************************************************

        Constructor

        Params:
            buffer_size = optional, size of the input/output buffers used for
                          reading/writing

    ***************************************************************************/

    this ( size_t buffer_size = 64 * 1024 )
    {
        this.buffered_output = new BufferedOutput(null, buffer_size);
        this.buffered_input  = new BufferedInput(null, buffer_size);

        this.converter       = new Converter;
    }


    /***************************************************************************

        Writes a map to a file.

        Params:
            map        = instance of the array map to dump
            file_path  = path to where the map should be dumped to

    ***************************************************************************/

    public void dump ( K, V ) ( Map!(V, K) map, cstring file_path )
    {
        void adder ( void delegate ( ref K, ref V ) add )
        {
            foreach ( ref k, ref v; map )
            {
                add(k, v);
            }
        }

        this.dumpDg!(K, V)(file_path, &adder);
    }


    /***************************************************************************

        Writes a map to a file.

        Params:
            file_path = path to where the map should be dumped to
            adder     = function called with a delegate that can be used to add
                        elements that are to be dumped. Once that delegate
                        returns, the rest will be written.

    ***************************************************************************/

    public void dumpDg ( K, V ) ( cstring file_path, AdderDg!(K, V) adder )
    {
        scope file = new File(file_path, File.Style(File.Access.Write,
                                                    File.Open.Create,
                                                    File.Share.None));

        this.buffered_output.output(file);
        this.buffered_output.clear();

        this.dumpInternal!(K,V)(this.buffered_output, adder);
    }


    /***************************************************************************

        Internal dump function

        Template_Params:
            K = Key type of the map
            V = Value type of the map
            HeaderVersion = version of the file header we're trying to load

        Params:
            buffered = stream to write to
            adder    = function called with a delegate that can be used to add
                       elements that aare to be dumped. Once the delegate
                       returns the writing process will be finalized

    ***************************************************************************/

    private void dumpInternal ( K, V, ubyte HeaderVersion = HEADER_VERSION )
                              ( BufferedOutput buffered, AdderDg!(K, V) adder )
    {
        size_t nr_rec = 0;

        FileHeader!(K,V, HeaderVersion) fh;

        SimpleSerializer.write(buffered, fh);
        // Write dummy value first
        SimpleSerializer.write(buffered, nr_rec);

        void addKeyVal ( ref K key, ref V val )
        {
            SimpleSerializerArrays.write!(K)(buffered, key);
            SimpleSerializerArrays.write!(V)(buffered, val);
            nr_rec++;
        }

        scope(exit)
        {
            buffered.flush();

            // Write actual length now
            buffered.seek(fh.sizeof);
            SimpleSerializer.write(buffered, nr_rec);

            buffered.flush();
        }

        adder(&addKeyVal);
    }


    /***************************************************************************

        loads dumped map content from the file system

        Does not support structs with dynamic arrays yet.

        Throws:
            Exception when the file has not the expected fileheader and
            other Exceptions for various kinds of errors (file not found, etc)

        Template_Params:
            K = key of the array map
            V = value of the corresponding key

        Params:
            map       = instance of the array map
            file_path = path to the file to load from

    ***************************************************************************/

    public void load ( K, V ) ( Map!(V, K) map, cstring file_path )
    {
        void putter ( ref K k, ref V v )
        {
            bool added = false;

            static if ( isDynamicArrayType!(V) )
            {
                copy(*map.put(k, added), v);
            }
            else
            {
                (*map.put(k, added)) = v;
            }

            // If added key is an array and new don't reuse the memory it
            // references
            static if ( isDynamicArrayType!(K) ) if ( added )
            {
                k = k.dup;
            }
        }

        this.loadDg!(K, V)(file_path, &putter);
    }


    /***************************************************************************

        Loads dumped map content from the file system

        Does not support structs with dynamic arrays yet.

        Throws:
            Exception when the file has not the expected fileheader and
            other Exceptions for various kinds of errors (file not found, etc)

        Template_Params:
            K = key of the array map
            V = value of the corresponding key

        Params:
            file_path = path to the file to load from
            putter    = function called for each entry to insert it into the map

    ***************************************************************************/

    public void loadDg ( K, V ) ( cstring file_path, PutterDg!(K, V) putter )
    {
        scope file = new File(file_path, File.ReadExisting);

        this.buffered_input.input(file);

        loadInternal!(K,V)(this.buffered_input, putter);
    }


    /***************************************************************************

        Loads dumped map content from a input stream

        Does not support structs with dynamic arrays yet.

        Throws:
            Exception when the file has not the expected fileheader and
            other Exceptions for various kinds of errors (file not found, etc)

        Template_Params:
            K = key of the array map
            V = value of the corresponding key
            HeaderVersion = version of the file header we're trying to load

        Params:
            buffered  = input stream to read from
            putter    = function called for each entry to insert it into the map

    ***************************************************************************/

    private void loadInternal ( K, V, ubyte HeaderVersion = HEADER_VERSION )
                              ( BufferedInput buffered, PutterDg!(K, V) putter )
    {
        bool raw_load = false;

        FileHeader!(K,V, HeaderVersion) fh_expected;
        FileHeader!(K,V, HeaderVersion) fh_actual;

        fh_actual.versionNumber = ubyte.max;

        buffered.seek(0);
        buffered.compress();
        buffered.populate();

        SimpleSerializer.read(buffered, fh_actual);

        if ( fh_actual.marker != fh_expected.marker )
        {
            throw new Exception("Magic Marker mismatch");
        }
        else if ( fh_actual.versionNumber != fh_expected.versionNumber )
        {
            if ( fh_actual.versionNumber == 2 )
            {
                return this.loadOld!(K,V)(buffered, putter);
            }
            if ( fh_actual.versionNumber == 3 )
            {
                raw_load = true;
            }
            else if ( fh_actual.versionNumber == 4 )
            {
                return this.loadInternal!(K, V, 4)(buffered, putter);
            }
            else
            {
                throw new Exception("Version of file header "
                                    " does not match our version, aborting!");
            }
        }

        bool conv;

        // Code for converting from older Key/Value structs
        static if ( is ( typeof ( fh_expected.key_version ) ) )
        {
            if ( fh_expected.key_version != 0 )
            {
                conv = this.handleVersion!(MapSerializer.loadInternal, 0, K, V)
                            (fh_actual.key_version, fh_expected.key_version,
                             this.key_convert_buffer, putter, buffered);

                if ( conv ) return;
            }
        }

        static if ( is ( typeof ( fh_expected.value_version ) ) )
        {
            if ( fh_expected.value_version != 0 )
            {
                conv = this.handleVersion!(MapSerializer.loadInternal, 1, K, V)
                            (fh_actual.value_version, fh_expected.value_version,
                             this.value_convert_buffer, putter, buffered);

                if ( conv ) return;
            }
        }

        static if ( is ( typeof ( fh_expected.hash ) ) )
        {
            if ( fh_expected.hash != fh_actual.hash )
            {
                throw new Exception("File struct differ from struct used to "
                                    "load!", __FILE__, __LINE__);
            }
        }

        size_t nr_rec;

        if ( buffered.readable < nr_rec.sizeof )
        {
            buffered.compress();
            buffered.populate();
        }
        SimpleSerializerArrays.read(buffered, nr_rec);

        for ( ulong i=0; i < nr_rec;i++ )
        {
            K key;
            V value;

            if ( buffered.readable < V.sizeof + K.sizeof )
            {
                buffered.compress();
                buffered.populate();
            }

            if ( raw_load )
            {
                SimpleSerializer.read!(K)(buffered, key);
                SimpleSerializer.read!(V)(buffered, value);
            }
            else
            {
                SimpleSerializerArrays.read!(K)(buffered, key);
                SimpleSerializerArrays.read!(V)(buffered, value);
            }

            putter(key, value);
        }
    }


    /***************************************************************************

        Checks if a struct needs to be converted and converts it if required

        Template_Params:
            loadFunc = function to use to load older version of the struct
            index    = index of the type in the tuple that should be
                       checked/converted
            T...     = tuple of key/value types

        Params:
            actual   = version that was found in the data
            expected = version that is desired
            buffer   = conversion buffer to use
            putter   = delegate to use to put the data into the map
            buffered = buffered input stream

        Returns:
            true if conversion happened, else false

        Throws:
            if conversion failed

    ***************************************************************************/

    private bool handleVersion ( alias loadFunc, size_t index, T... )
                               ( Version.Type actual,
                                 Version.Type expected,
                                 ref BufferPair buffer,
                                 void delegate ( ref T ) putter,
                                 BufferedInput buffered )
    {
        if ( actual < expected )
        {
            return this.tryConvert!(true, MapSerializer.loadInternal, index, T)
                                   (buffer, putter, buffered);
        }

        return false;
    }


    /***************************************************************************

        Checks if a struct needs to be converted and converts it if required

        Template_Params:
            throw_if_unable = if true, an exception is thrown if we can't
                              convert this struct
            loadFunc = function to use to load older version of the struct
            index    = index of the type in the tuple that should be
                       checked/converted
            T...     = tuple of key/value types

        Params:
            buffer   = conversion buffer to use
            putter   = delegate to use to put the data into the map
            buffered = buffered input stream

        Returns:
            true if a conversion happened, false if we can't convert it and
            throw_if_unable is false

        Throws:
            if throw_if_unable is true and we couldn't convert it

    ***************************************************************************/

    private bool tryConvert ( bool throw_if_unable, alias loadFunc,
                              size_t index, T... )
                            ( ref BufferPair buffer,
                              void delegate ( ref T ) putter,
                              BufferedInput buffered )
    {
        static assert ( T.length == 2 );

        const other = index == 1 ? 0 : 1;

        static if ( Version.Info!(T[index]).exists )
        {
            const can_convert = (Version.Info!(T[index]).number > 0);
        }
        else
        {
            const can_convert = false;
        }

        static if ( can_convert )
        {
            alias AddStructPrevious!(index, T) TWithPrev;

            void convPut ( ref TWithPrev keyval )
            {
                auto buf = &keyval[index] is buffer.first.ptr ?
                                &buffer.second : &buffer.first;

                AddPtr!(T) res;

                Serializer.serialize(keyval[index], *buf);
                res[index] = this.converter.convert!(T[index], TWithPrev[index])(*buf).ptr;
                res[other] = &keyval[other];

                putter(*res[0], *res[1]);
            }

            loadFunc!(TWithPrev)(buffered, &convPut);

            return true;
        }
        else static if ( throw_if_unable )
        {
            throw new Exception("Cannot convert to new version!");
        }
        else
        {
            return false;
        }
    }


    /***************************************************************************

        Previous load function, kept so that old versions can still be loaded

        Template_Params:
            K = type of the key
            V = type of the value

        Params:
            buffered = stream to read from
            putter   = delegate used to write loaded records to the map

    ***************************************************************************/

    private void loadOld ( K, V ) ( BufferedInput buffered,
                                    void delegate ( ref K, ref V ) putter )
    {
        size_t nr_rec;

        FileHeader!(K,V,2) fh_expected;
        FileHeader!(K,V,2) fh_actual;

        buffered.seek(0);
        buffered.compress();
        buffered.populate();

        SimpleSerializer.read(buffered, fh_actual);

        if ( fh_actual.marker != fh_expected.marker )
        {
            throw new Exception("Magic Marker mismatch");
        }
        else if ( fh_actual.versionNumber != fh_expected.versionNumber )
        {
            throw new Exception("Version of file header "
                                " does not match our version, aborting!");
        }
        else static if ( is ( typeof ( fh_expected.hash ) ) )
        if ( fh_actual.hash != fh_expected.hash )
        {
            bool conv;

            // convert from a previous key struct to the current
            conv = this.tryConvert!(false, MapSerializer.loadOld, 0, K, V)
                (this.key_convert_buffer, putter, buffered);

            if ( conv ) return;

            // convert from a previous value struct to the current
            conv = this.tryConvert!(false, MapSerializer.loadOld, 1, K, V)
                                   (this.value_convert_buffer, putter, buffered);

            if ( conv ) return;

            throw new Exception("Unable to convert structs " ~ K.stringof ~ ", " ~
                                V.stringof ~
                                " to our structs, aborting!");
        }

        if ( buffered.readable < nr_rec.sizeof )
        {
            buffered.compress();
            buffered.populate();
        }
        SimpleSerializerArrays.read(buffered, nr_rec);

        for ( ulong i=0; i < nr_rec;i++ )
        {
            K key;
            V value;

            if ( buffered.readable < V.sizeof + K.sizeof )
            {
                buffered.compress();
                buffered.populate();
            }

            SimpleSerializer.read!(K)(buffered, key);
            SimpleSerializer.read!(V)(buffered, value);
            putter(key, value);
        }
    }
}


/*******************************************************************************

    Unittests

*******************************************************************************/

version ( UnitTest )
{
    import ocean.io.device.MemoryDevice,
           ocean.io.digest.Fnv1,
           ocean.core.Test,
           ocean.util.container.map.model.StandardHash,
           ocean.util.container.map.Map,
           ocean.util.container.map.HashMap;

    import ocean.core.Traits;

    /***************************************************************************

        Slightly specialized version of Map that would simply take the raw value
        of structs to hash them

    ***************************************************************************/

    class StructhashMap (V, K) : Map!(V, K)
    {
        /***********************************************************************

            Constructor

            Params:
                n = amount of expected elements

        ***********************************************************************/

        public this ( size_t n )
        {
            super(n);
        }

        /***********************************************************************

            Dumb and easy toHash method.

            Simply takes the key and passes it directly to fnv1a.

            Parameters:
                key = key of which the hash is desired

            Returns:
                hash of the key

        ***********************************************************************/

        public override hash_t toHash ( K key )
        {
            return Fnv1a.fnv1(key);
        }

    }

    /***************************************************************************

        Dump function that dumps in the old format, to test whether we can still
        read it (and convert it)

        Template_Params:
            K = type of key
            V = type of value

        Params:
            buffered = output stream to write to
            adder    = delegate called with a delegate that can be used to add
                       values

    ***************************************************************************/

    void dumpOld ( K, V ) ( BufferedOutput buffered,
                            MapSerializer.AdderDg!(K, V) adder )
    {
        size_t nr_rec = 0;

        MapSerializer.FileHeader!(K,V,2) fh;

        SimpleSerializer.write(buffered, fh);
        // Write dummy value for now
        SimpleSerializer.write(buffered, nr_rec);

        void addKeyVal ( ref K key, ref V val )
        {
            SimpleSerializer.write!(K)(buffered, key);
            SimpleSerializer.write!(V)(buffered, val);
            nr_rec++;
        }

        scope(exit)
        {
            buffered.flush();

            // Write actual length now
            buffered.seek(fh.sizeof);
            SimpleSerializer.write(buffered, nr_rec);

            buffered.flush();
        }

        adder(&addKeyVal);
    }

    /***************************************************************************

        Test writing & loading of the given combination of struct types on a
        virtual file

        Depending on the exact combinations, the key structs should offer the
        following methods:

        * compare ( <other_key_struct> * ) - compare the two structs
        * K old() - convert this struct to the older one

        The value structs should offer only a compare function.

        Template_Params:
            K = type of the key to write
            V = type of the value to write
            KNew = type of the key to read, automatic conversion will happen
            VNew = type of the value to read, automatic conversion will happen
            custom_dump = optional, custom code to use for dumping the data.
                          The code is expected to define a variable
                          "header_size" containing the size of the header

    ***************************************************************************/

    void testCombination ( K, V, KNew, VNew, istring custom_dump = "" )
              ( size_t iterations )
    {
        auto t = new NamedTest("Combination {" ~
            "K = " ~ K.stringof ~
            ", V = " ~ V.stringof ~
            ", KNew = " ~ KNew.stringof ~
            ", VNew = " ~ VNew.stringof ~ "}"
        );
        const ValueArraySize = 200;

        scope array = new MemoryDevice;
        scope map   = new StructhashMap!(V, K)(iterations);
        scope serializer = new MapSerializer;

        // helper to get a key from size_t
        K initKey ( int i )
        {
            static if ( is ( K == struct ) )
            {
                return K(i);
            }
            else
            {
                return i;
            }
        }

        // helper to get old key from new key
        K fromNew ( KNew k )
        {
            static if ( is ( K == struct ) )
            {
                return k.old();
            }
            else
            {
                return k;
            }
        }

        V initVal ( int i )
        {
            static if ( isDynamicArrayType!(V) )
            {
                alias ElementTypeOfArray!(V) VA;

                auto r = new VA[ValueArraySize];

                foreach ( ref e; r )
                {
                    e = VA(i);
                }

                return r;
            }
            else return V(i);
        }

        // Fill test map
        for ( int i = 0; i < iterations; ++i )
        {
            *map.put(initKey(i)) = initVal(i);
        }

        void adder ( void delegate ( ref K, ref V ) add )
        {
            foreach ( ref k, ref v; map )
            {
                add(k, v);
            }
        }

        // Dump test map (to memory)
        static if ( custom_dump.length > 0 )
        {
            mixin(custom_dump);
        }
        else
        {
            serializer.buffered_output.output(array);
            serializer.dumpInternal!(K, V)(serializer.buffered_output, &adder);

            auto header_size = MapSerializer.FileHeader!(K, V, MapSerializer.HEADER_VERSION).sizeof;
        }

        // Check size of dump
        static if ( isDynamicArrayType!(V) )
        {
            t.test(array.bufferSize() ==
                        (K.sizeof + size_t.sizeof +
                            ElementTypeOfArray!(V).sizeof * ValueArraySize) *
                                iterations + header_size + size_t.sizeof,
                    "Written size is not the expected value!");
        }
        else
        {
            t.test(array.bufferSize() == (K.sizeof + V.sizeof) *
                    iterations + header_size + size_t.sizeof,
                    "Written size is not the expected value!");
        }

        // Check load function
        size_t amount_loaded = 0;
        void checker ( ref KNew k, ref VNew v )
        {
            amount_loaded++;
            static if ( isDynamicArrayType!(VNew) )
            {
                foreach ( i, el; v )
                {
                    t.test(el.compare(&(*map.get(fromNew(k)))[i]),
                        "Loaded item unequal saved item!");
                }
            }
            else
            {
                t.test(v.compare(map.get(fromNew(k))),
                    "Loaded item unequal saved item!");
            }
        }

        array.seek(0);
        serializer.buffered_input.input(array);
        serializer.loadInternal!(KNew, VNew)(serializer.buffered_input, &checker);

        t.test(amount_loaded == map.length, "Amount of loaded "
                  "items unequal amount of written items!");
    }
}

unittest
{
    const Iterations = 10_000;

    const old_load_code =
          `scope bufout = new BufferedOutput(array, 2048);
           bufout.seek(0);
           dumpOld!(K, V)(bufout, &adder);

           auto header_size = MapSerializer.FileHeader!(K, V, 2).sizeof;`;

    const version4_load_code =
          `serializer.buffered_output.output(array);
           serializer.dumpInternal!(K, V, 4)(serializer.buffered_output, &adder);

           auto header_size = MapSerializer.FileHeader!(K, V, 4).sizeof;
           `;

    static struct TestNoVersion
    {
        long i;

        static TestNoVersion opCall ( long i )
        {
            TestNoVersion t;
            t.i = i*2;
            return t;
        }

        bool compare ( TestNoVersion* other )
        {
            return i == other.i;
        }
    }

    static struct Test1
    {
        const StructVersion = 0;

        long i;
    }

    static struct Test2
    {
        const StructVersion = 1;
        alias Test1 StructPrevious;

        long i;
        long o;
        void convert_o ( ref Test1 t ) { this.o = t.i+1; }

        bool compare ( Test1* old )
        {
            return old.i == i && old.i+1 == o;
        }

        bool compare ( Test2* old )
        {
            return *old == *this;
        }
    }

    static struct OldStruct
    {
        const StructVersion = 0;

        int old;

        bool compare ( OldStruct * o )
        {
            return *o == *this;
        }
    }

    static struct NewStruct
    {
        const StructVersion = 1;
        alias OldStruct StructPrevious;

        int old;

        int a_bit_newer;
        void convert_a_bit_newer ( )
        {
            this.a_bit_newer = old+1;
        }

        bool compare ( OldStruct* old )
        {
            return old.old == this.old &&
                   old.old+1 == a_bit_newer;
        }
    }

    static struct OldKey
    {
        const StructVersion = 0;

        int old2;

        bool compare ( OldKey * o )
        {
            return *o == *this;
        }

        OldKey old ( )
        {
            return *this;
        }
    }

    static struct NewKey
    {
        const StructVersion = 1;
        alias OldKey StructPrevious;

        int old1;

        void convert_old1 ( ref OldKey o )
        {
            old1 = o.old2;
        }

        int newer;

        void convert_newer ( ref OldKey o )
        {
            newer = o.old2+1;
        }

        bool compare ( OldKey * oldk )
        {
            return oldk.old2 == old1 && oldk.old2+1 == newer;
        }

        OldKey old ( )
        {
            return OldKey(old1);
        }
    }

    static struct NewerKey
    {
        const StructVersion = 2;
        alias NewKey StructPrevious;

        int old1;
        int wops;

        void convert_wops ( ref NewKey k )
        {
            wops = k.old1;
        }

        bool compare ( NewKey * n )
        {
            return n.old1 == old1 && wops == n.old1;
        }

        OldKey old ( )
        {
            return OldKey(old1);
        }
    }

    static struct NewerStruct
    {
        const StructVersion = 2;
        alias NewStruct StructPrevious;

        int old;
        long of;

        void convert_of ( ref NewStruct n )
        {
            of = n.a_bit_newer;
        }

        bool compare ( OldStruct * olds )
        {
            return olds.old == old;
        }
    }

    // Test creation of a SerializingMap instance
    class HashingSerializingMap : SerializingMap!(int,int)
    {
        public this ( size_t n, float load_factor = 0.75 )
        {
            super(n, load_factor);
        }

        override:
            mixin StandardHash.toHash!(int);
    }


    // Test same and old version
    testCombination!(hash_t, Test1, hash_t, Test2)(Iterations);
    testCombination!(hash_t, Test2, hash_t, Test2)(Iterations);

    // Test Arrays
    testCombination!(hash_t, Test2[], hash_t, Test2[])(Iterations);

    // Test unversioned structs
    testCombination!(hash_t, TestNoVersion, hash_t, TestNoVersion)(Iterations);

    // Test old versions
    testCombination!(hash_t, TestNoVersion, hash_t, TestNoVersion, old_load_code)(Iterations);

    // Test conversion of old files to new ones
    testCombination!(hash_t, OldStruct, hash_t, NewStruct, old_load_code)(Iterations);

    // Test conversion of old files with
    // different key versions to new ones
    testCombination!(OldKey, OldStruct, OldKey, OldStruct, old_load_code)(Iterations);
    testCombination!(OldKey, OldStruct, NewKey, OldStruct, old_load_code)(Iterations);
    testCombination!(OldKey, OldStruct, NewKey, OldStruct, old_load_code)(Iterations);
    testCombination!(OldKey, OldStruct, NewKey, NewStruct, old_load_code)(Iterations);
    testCombination!(OldKey, OldStruct, NewerKey, NewStruct, old_load_code)(Iterations);
    testCombination!(OldKey, OldStruct, NewerKey, NewerStruct,old_load_code)(Iterations);


    ////////////// Test Loading of version 4 header

    // Test old versions
    testCombination!(hash_t, TestNoVersion, hash_t, TestNoVersion, version4_load_code)(Iterations);

    // Test conversion of old files to new ones
    testCombination!(hash_t, OldStruct, hash_t, NewStruct, version4_load_code)(Iterations);

    // Test conversion of old files with
    // different key versions to new ones
    testCombination!(OldKey, OldStruct, OldKey, OldStruct, version4_load_code)(Iterations);
    testCombination!(OldKey, OldStruct, NewKey, OldStruct, version4_load_code)(Iterations);
    testCombination!(OldKey, OldStruct, NewKey, OldStruct, version4_load_code)(Iterations);
    testCombination!(OldKey, OldStruct, NewKey, NewStruct, version4_load_code)(Iterations);
    testCombination!(OldKey, OldStruct, NewerKey, NewStruct, version4_load_code)(Iterations);
    testCombination!(OldKey, OldStruct, NewerKey, NewerStruct,version4_load_code)(Iterations);
}

version (UnitTest)
{
    // Make sure structs with a StructNext can be instantiated
    struct S ( ubyte V )
    {
        const StructVersion = V;

        // comment this out and it works
        static if (V == 0)
            alias S!(1) StructNext;

        static if (V == 1)
            alias S!(0) StructPrevious;
    }

    unittest
    {
        alias SerializingMap!(S!(0), ulong) Map;
    }
}
