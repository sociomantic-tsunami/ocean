/*******************************************************************************

    Simple serializer for reading / writing generic data from / to IOStreams

    Usage example, writing:

    ---

        import ocean.io.serialize.SimpleSerializer;

        scope file = new File("myfile.dat", File.WriteCreate);

        char[] some_data = "data to be written to the file first";
        char[][] more_data = ["second", "third", "fourth", "etc"];

        SimpleSerializer.write(file, some_data);
        SimpleSerializer.write(file, more_data);

    ---

    Usage example, reading:

    ---

        import ocean.io.serialize.SimpleSerializer;

        scope file = new File("myfile.dat", File.ReadExisting);

        char[] some_data;
        char[][] more_data;

        SimpleSerializer.read(file, some_data);
        SimpleSerializer.read(file, more_data);

    ---

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.serialize.SimpleSerializer;


import ocean.io.serialize.SimpleStreamSerializer;


deprecated("Use ocean.io.serialize.SimpleStreamSerializer.SimpleStreamSerializer.")
public alias SimpleStreamSerializer SimpleSerializer;
deprecated("Use ocean.io.serialize.SimpleStreamSerializer.SimpleStreamSerializerArrays.")
public alias SimpleStreamSerializerArrays SimpleSerializerArrays;
