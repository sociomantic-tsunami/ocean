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
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.text.csv.CSV;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.util.container.AppendBuffer;

import ocean.io.model.IConduit;




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

        Constructor.

    ***************************************************************************/

    public this ( )
    {
        this.row = new AppendBuffer!(char);
        this.fields = new AppendBuffer!(cstring);
    }


    version (D_Version2) {}
    else
    {
        /***********************************************************************

            Disposer.

        ***********************************************************************/

        override void dispose ( )
        {
            delete this.row;
            delete this.fields;
        }
    }


    /***************************************************************************

        Parses CSV data from the provided stream. Parsing ends when an EOF is
        encountered. As rows are extracted and parsed, they are passed to the
        provided delegate.

        Params:
            stream = stream to read CSV data from
            row_dg = delegate to receive parsed rows

    ***************************************************************************/

    public void parse ( InputStream stream, RowDg row_dg )
    in
    {
        assert(stream !is null, "InputStream is null");
        assert(row_dg !is null, "Row delegate is null");
    }
    body
    {
        char[512] buf;
        this.row.length = 0;

        size_t bytes_read;
        bool in_quote;
        for ( bytes_read = 0; bytes_read != InputStream.Eof;
              bytes_read = stream.read(buf) )
        {
            auto chunk = buf[0 .. bytes_read];

            size_t row_start;
            foreach ( i, c; chunk )
            {
                switch ( c )
                {
                    case '"':
                        in_quote = !in_quote;
                        break;

                    case '\n':
                        if ( !in_quote )
                        {
                            this.row ~= chunk[row_start .. i];
                            if ( !this.parseRow(row_dg) )
                            {
                                return;
                            }

                            this.row.length = 0;
                            row_start = i + 1;
                        }
                        break;

                    default:
                }
            }

            if ( row_start < chunk.length )
            {
                this.row ~= chunk[row_start .. $];
            }
        }

        if ( row.length )
        {
            this.parseRow(row_dg);
        }
    }


    /***************************************************************************

        Parses the current row (contained in this.row) and passes the parsed
        fields to the provided delegate.

        Params:
            row_dg = delegate to receive parsed rows

    ***************************************************************************/

    private bool parseRow ( RowDg row_dg )
    {
        this.fields.length = 0;

        bool in_quote;
        bool field_was_quoted;
        size_t field_start;

        foreach ( i, c; this.row[] )
        {
            if ( c == '"' )
            {
                if ( in_quote )
                {
                    // FIXME: if we need to be able to successfully parse
                    // fields like `"hello"world,` then we'll need to come
                    // up with something clever here instead of this assert.
                    assert(i == row.length - 1 || row[i + 1] == this.separator,
                        "Quoted field not delimited by separator");
                    field_start++; // Skip leading "
                    field_was_quoted = true;
                }

                in_quote = !in_quote;
            }
            else if ( c == this.separator )
            {
                if ( !in_quote )
                {
                    size_t end = field_was_quoted ? i - 1 : i; // Skip trailing "
                    this.fields ~= this.row[field_start .. end];
                    field_start = i + 1;
                    field_was_quoted = false;
                }
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
    void test ( CSV csv, cstring str, cstring[][] expected )
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
                assert(f == fields[i]);
            }
            return true;
        });
    }

    scope csv = new CSV;

    // Single row
    test(csv,
`An,Example,Simple,CSV,Row`,
        [["An", "Example", "Simple", "CSV", "Row"]]);

    // Single row + quoted comma
    test(csv,
`An,Example,"Quoted,Field",CSV,Row`,
        [["An", "Example", "Quoted,Field", "CSV", "Row"]]);

    // Single row + quoted newline
    test(csv,
`An,Example,"Quoted
Field",CSV,Row`,
        [["An", "Example", "Quoted\nField", "CSV", "Row"]]);

    // Two rows
    test(csv,
`An,Example,Simple,CSV,Row
This,Time,With,Two,Rows`,
        [["An", "Example", "Simple", "CSV", "Row"],
         ["This","Time","With","Two","Rows"]]);
}

