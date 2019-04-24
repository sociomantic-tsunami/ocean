/*******************************************************************************

    Class for parsing streams of CSV data.

    Currently the class is capable of parsing only fairly simple, well-formatted
    CSV. The following basic format features are supported:

        * Newline (\n) separated lines.
        * Comma (or arbitrary character) -separated fields.
        * Quoted fields (a " character, followed by any number of characters,
          and delimited by another " and a separator character). Separators
          (commas) and newlines (\n) may both appear inside quoted fields.

    Usage:

    ---

        import ocean.io.Stdout;
        import ocean.io.device.File;

        scope file = new File("example.csv", File.ReadExisting);
        scope csv = new CSV;

        csv.parse(file,
        (char[][] fields)
        {
            Stdout.formatln("Row={}", fields);
            return true; // tells CSV instance to continue parsing
        });

    ---

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.text.csv.CSV;


import ocean.core.Enforce;

import ocean.transition;

import ocean.util.container.AppendBuffer;

import ocean.io.model.IConduit;

import ocean.core.Verify;

version(UnitTest) import ocean.core.Test;


/*******************************************************************************

    Simple CSV parser. Passes extracted fields, one row at a time to a
    user-provided delegate.

*******************************************************************************/

public class CSV
{
    /***************************************************************************

        Type of delegate which receives parsed CSV rows.

    ***************************************************************************/

    public alias bool delegate ( cstring[] fields ) RowDg;


    /***************************************************************************

        Separator character. Defaults to comma, but may be set before calling
        parse().

    ***************************************************************************/

    public char separator = ',';


    /***************************************************************************

        Buffer used to build up a full row as data is read from the input
        stream.

    ***************************************************************************/

    private AppendBuffer!(char) row;


    /***************************************************************************

        List of slices into the row buffer, used to split the row into fields.

    ***************************************************************************/

    private AppendBuffer!(cstring) fields;

    /***************************************************************************

        Fixed size buffer for reading for stream

    ***************************************************************************/

    private mstring buffer;


    /***************************************************************************

        Constructor.

    ***************************************************************************/

    public this ( )
    {
        this.row = new AppendBuffer!(char);
        this.fields = new AppendBuffer!(cstring);
        this.buffer = new char[512];
    }

    /***************************************************************************

        Parses CSV data from the provided stream. Parsing ends when an EOF is
        encountered. As rows are extracted and parsed, they are passed to the
        provided delegate.

        Params:
            stream = stream to read CSV data from
            row_dg = delegate to receive parsed rows

    ***************************************************************************/

    public void parse ( InputStream stream, scope RowDg row_dg )
    {
        verify(stream !is null, "InputStream is null");
        verify(row_dg !is null, "Row delegate is null");

        this.row.clear();

        // appends chunk of data from stream when encountering any of control
        // symbols
        scope append_chunk = ( mstring data, ref size_t start, size_t end )
        {
            this.row ~= data[start .. end];
            start = end + 1;
        };

        // indicates that the beginning of a stream chunk is already in the
        // middle of a quote
        bool in_quote = false;

        size_t bytes_read;

        while ((bytes_read = stream.read(this.buffer)) != InputStream.Eof)
        {
            size_t chunk_start = 0;
            auto data = this.buffer[0 .. bytes_read];

            foreach (i, c; data)
            {
                verify(c != '\0');

                if (c == this.separator && !in_quote)
                {
                    // trick: make use of the fact there won't be a \0 symbol
                    // in the input stream and replace separator symbol with \0
                    // to disambugate from escaped separator and make parsing
                    // a single row trivial
                    append_chunk(data, chunk_start, i);
                    this.row ~= '\0';
                    continue;
                }

                if (c == '"')
                {
                    in_quote = !in_quote;

                    if (data[i-1] == '"')
                    {
                        // need adjustment, it was escaped quote last time and
                        // not the end of quote
                        this.row ~= "\"";
                        chunk_start++;
                    }
                    else
                        append_chunk(data, chunk_start, i);
                    continue;
                }

                if (c == '\n')
                {
                    if (in_quote)
                        continue;
                    append_chunk(data, chunk_start, i);

                    // if row_dg returns 'false', no further parsing is needed
                    if (!this.parseRow(row_dg))
                        return;
                    this.row.clear();
                    continue;
                }
            }

            if (chunk_start < data.length )
                this.row ~= data[chunk_start .. $];
        }

        if (row.length)
            this.parseRow(row_dg);
    }


    /***************************************************************************

        Parses the current row (contained in this.row) and passes the parsed
        fields to the provided delegate.

        Params:
            row_dg = delegate to receive parsed rows

    ***************************************************************************/

    private bool parseRow ( scope RowDg row_dg )
    {
        this.fields.clear();

        size_t field_start;

        foreach (i, c; this.row[])
        {
            if (c == '\0')
            {
                this.fields ~= this.row[field_start .. i];
                field_start = i + 1;
            }
        }

        this.fields ~= this.row[field_start .. this.row.length];
        return row_dg(this.fields[]);
    }
}



/*******************************************************************************

    UnitTest

*******************************************************************************/

version ( UnitTest )
{
    import ocean.io.device.Array;
}

unittest
{
    void test ( NamedTest t, CSV csv, cstring str, cstring[][] expected )
    {
        scope array = new Array(1024);
        array.append(str);

        size_t test_row;
        csv.parse(array,
        ( cstring[] parsed_fields )
        {
            auto fields = expected[test_row++];

            foreach ( i, f; parsed_fields )
            {
                t.test!("==")(f, fields[i]);
            }
            return true;
        });
    }

    scope csv = new CSV;

    test(new NamedTest("Single Row"), csv,
`An,Example,Simple,CSV,Row`,
        [["An", "Example", "Simple", "CSV", "Row"]]);

    test(new NamedTest("Single row + quoted comma"), csv,
`An,Example,"Quoted,Field",CSV,Row`,
        [["An", "Example", "Quoted,Field", "CSV", "Row"]]);

    test(new NamedTest("Single row + quoted newline"), csv,
`An,Example,"Quoted
Field",CSV,Row`,
        [["An", "Example", "Quoted\nField", "CSV", "Row"]]);

    test(new NamedTest("Two rows"), csv,
`An,Example,Simple,CSV,Row
This,Time,With,Two,Rows`,
        [["An", "Example", "Simple", "CSV", "Row"],
         ["This","Time","With","Two","Rows"]]);

    test(new NamedTest("Quoted field last"), csv,
`An,Example,"Quoted"`,
        [["An", "Example", "Quoted"]]);

    test(new NamedTest("Partially quoted field"), csv,
`An,Example,"Quot"ed`,
        [["An", "Example", "Quoted"]]);

    test(new NamedTest("Escaped quote"), csv,
`An,""Example"","Quoted"`,
        [["An", "\"Example\"", "Quoted"]]);

}

