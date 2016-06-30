/*******************************************************************************

    Class for parsing streams of CSV data with handling of column headings. The
    fields of the first row are parsed as the column headings. The user delegate
    passed to the parse() methods receives the values of the fields in a row
    together with the corresponding column headings, read from the first row.

    A second parse() method allows only certain columns in the CSV stream to be
    processed.

    See ocean.text.csv.CSV for details on the basic format support of the
    parser.

    Usage:

    ---

        import ocean.io.Stdout;
        import ocean.io.device.File;

        scope file = new File("example.csv", File.ReadExisting);
        scope csv = new HeadingsCSV;

        const include_headings = ["Criteria ID", "Country Code", "Canonical Name"];

        // Parse method allowing only certain columns to be passed to the
        // delegate.
        csv.parse(file, include_headings,
        (HeadingsCSV.Field[] fields)
        {
            Stdout.format("Row=[");
            foreach ( f; fields )
            {
                Stdout.format("{}:{}, ", f.name, f.value);
            }
            Stdout.formatln("]");
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

module ocean.text.csv.HeadingsCSV;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.text.csv.CSV;

import ocean.util.container.AppendBuffer;
import ocean.util.container.ConcatBuffer : SliceBuffer;

import ocean.core.Array : contains, find;

import ocean.io.model.IConduit;



/*******************************************************************************

    CSV parser with special handling of column headings. Passes extracted
    fields, one row at a time to a user-provided delegate, along with the column
    heading of each field.

*******************************************************************************/

public class HeadingsCSV
{
    /***************************************************************************

        Type of delegate which receives parsed CSV rows.

    ***************************************************************************/

    public alias bool delegate ( Field[] fields ) RowDg;


    /***************************************************************************

        Struct containing the name and value of a field. Field names are sliced
        from the 'headings' array (see below). A list of Field structs is passed
        to the user's delegate which is passed to the parse method.

    ***************************************************************************/

    public struct Field
    {
        cstring name;
        cstring value;
    }


    /***************************************************************************

        Internal simple CSV parser.

    ***************************************************************************/

    private CSV csv;


    /***************************************************************************

        List of heading names, read from the first CSV row.

    ***************************************************************************/

    private SliceBuffer!(char) headings;


    /***************************************************************************

        List of bools specifying whether each heading is to be passed to the
        user's delegate. (Used by the second parse() method.) The flags in this
        list are ordered the same as the column names in 'headings'.

    ***************************************************************************/

    private AppendBuffer!(bool) heading_included;


    /***************************************************************************

        List of Field structs extracted from the current row, to be passed to
        the user's delegate.

    ***************************************************************************/

    private AppendBuffer!(Field) fields;


    /***************************************************************************

        Constructor.

    ***************************************************************************/

    public this ( )
    {
        this.csv = new CSV;
        this.headings = new SliceBuffer!(char);
        this.heading_included = new AppendBuffer!(bool);
        this.fields = new AppendBuffer!(Field);
    }


    version (D_Version2) {}
    else
    {
        /***********************************************************************

            Disposer.

        ***********************************************************************/

        override void dispose ( )
        {
            delete this.csv;
            delete this.headings;
            delete this.heading_included;
            delete this.fields;
        }
    }


    /***************************************************************************

        Parses CSV data from the provided stream. Parsing ends when an EOF is
        encountered. As rows are extracted and parsed, they are passed to the
        provided delegate.

        Note that if a row is read which has more fields than there are headings
        (i.e. fields in the first row of the CSV stream), then its name is set
        to "unknown".

        Params:
            stream = stream to read CSV data from
            row_dg = delegate to receive parsed rows

    ***************************************************************************/

    public void parse ( InputStream stream, RowDg row_dg )
    {
        this.headings.clear();

        size_t row;
        this.csv.parse(stream,
        ( cstring[] parsed_fields )
        {
            // First row (headings)
            if ( row++ == 0 )
            {
                foreach ( f; parsed_fields )
                {
                    this.headings.add(f);
                }
            }
            // Subsequent rows
            else
            {
                this.fields.length = 0;

                foreach ( i, f; parsed_fields )
                {
                    auto heading = i < this.headings.length
                        ? this.headings[i] : "unknown";
                    this.fields ~= Field(heading, f);
                }

                if ( !row_dg(this.fields[]) )
                {
                    return false;
                }
            }

            return true;
        });
    }


    /***************************************************************************

        Parses CSV data from the provided stream. Parsing ends when an EOF is
        encountered. As rows are extracted and parsed, they are passed to the
        provided delegate.

        An additional parameter (include_headings) allows the user to specify
        which columns in the CSV stream are passed to the row delegate. In this
        way, unnecessary columns can be ignored.

        Params:
            stream = stream to read CSV data from
            include_headings = list of column headings to be included in the
                fields passed to the row delegate
            row_dg = delegate to receive parsed rows

    ***************************************************************************/

    public void parse ( InputStream stream, cstring[] include_headings,
        RowDg row_dg )
    {
        this.headings.clear();
        this.heading_included.length = 0;

        size_t row;
        this.csv.parse(stream,
        ( cstring[] parsed_fields )
        {
            //First row (headings)
            if ( row++ == 0 )
            {
                foreach ( i, f; parsed_fields )
                {
                    this.headings.add(f);
                }
                // TODO: duplicate headings?

                this.heading_included.length = this.headings.length;

                foreach ( i, ref included; this.heading_included[] )
                {
                    included = !!include_headings.contains(this.headings[i]);
                }
            }
            //Subsequent rows
            else
            {
                this.fields.length = 0;

                foreach ( i, f; parsed_fields )
                {
                    if ( i < this.headings.length && this.heading_included[i] )
                    {
                        this.fields ~= Field(this.headings[i], f);
                    }
                }

                if ( !row_dg(this.fields[]) )
                {
                    return false;
                }
            }

            return true;
        });
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
    class Tester
    {
        private HeadingsCSV.Field[][] expected;
        private size_t test_row;

        bool rowDg ( HeadingsCSV.Field[] parsed_fields )
        {
            auto expected_fields = this.expected[this.test_row++];

            foreach ( i, f; parsed_fields )
            {
                assert(f.name == expected_fields[i].name);
                assert(f.value == expected_fields[i].value);
            }

            return true;
        }

        void test ( HeadingsCSV csv, cstring str, HeadingsCSV.Field[][] expected )
        {
            this.expected = expected;
            this.test_row = 0;

            scope array = new Array(1024);
            array.append(str);

            csv.parse(array, &this.rowDg);
        }

        void test_inc ( HeadingsCSV csv, cstring str, cstring[] included_headings,
            HeadingsCSV.Field[][] expected )
        {
            this.expected = expected;
            this.test_row = 0;

            scope array = new Array(1024);
            array.append(str);

            csv.parse(array, included_headings, &this.rowDg);
        }
    }


    scope csv = new HeadingsCSV;
    scope tester = new Tester;

    // Headings + single row test
    tester.test(csv,
`Heading1,Heading2,Heading3,Heading4,Heading5
This,Time,With,Two,Rows`,
       [[HeadingsCSV.Field("Heading1", "This"),
        HeadingsCSV.Field("Heading2", "Time"),
        HeadingsCSV.Field("Heading3", "With"),
        HeadingsCSV.Field("Heading4", "Two"),
        HeadingsCSV.Field("Heading5", "Rows")]]);

    // Headings + longer row test
    tester.test(csv,
`Heading1,Heading2,Heading3,Heading4,Heading5
This,Time,With,Two,Rows,But,Longer`,
       [[HeadingsCSV.Field("Heading1", "This"),
        HeadingsCSV.Field("Heading2", "Time"),
        HeadingsCSV.Field("Heading3", "With"),
        HeadingsCSV.Field("Heading4", "Two"),
        HeadingsCSV.Field("Heading5", "Rows"),
        HeadingsCSV.Field("unknown", "But"),
        HeadingsCSV.Field("unknown", "Longer")]]);

    // Headings + two rows test
    tester.test(csv,
`Heading1,Heading2,Heading3,Heading4,Heading5
This,Time,With,Two,Rows
Yes,There,Are,Really,Three`,
       [[HeadingsCSV.Field("Heading1", "This"),
        HeadingsCSV.Field("Heading2", "Time"),
        HeadingsCSV.Field("Heading3", "With"),
        HeadingsCSV.Field("Heading4", "Two"),
        HeadingsCSV.Field("Heading5", "Rows")],
        [HeadingsCSV.Field("Heading1", "Yes"),
        HeadingsCSV.Field("Heading2", "There"),
        HeadingsCSV.Field("Heading3", "Are"),
        HeadingsCSV.Field("Heading4", "Really"),
        HeadingsCSV.Field("Heading5", "Three")]]);

    // Excluded headings
    tester.test_inc(csv,
`Heading1,Heading2,Heading3,Heading4,Heading5
This,Time,With,Two,Rows
Yes,There,Are,Really,Three`,
        ["Heading2", "Heading4", "Heading5"],
       [[HeadingsCSV.Field("Heading2", "Time"),
        HeadingsCSV.Field("Heading4", "Two"),
        HeadingsCSV.Field("Heading5", "Rows")],
       [HeadingsCSV.Field("Heading2", "There"),
        HeadingsCSV.Field("Heading4", "Really"),
        HeadingsCSV.Field("Heading5", "Three")]]);

    // Excluded headings + long row
    tester.test_inc(csv,
`Heading1,Heading2,Heading3,Heading4,Heading5
This,Time,With,Two,Rows
Yes,There,Are,Really,Three,Some,Extra,Fields`,
        ["Heading2", "Heading4", "Heading5"],
       [[HeadingsCSV.Field("Heading2", "Time"),
        HeadingsCSV.Field("Heading4", "Two"),
        HeadingsCSV.Field("Heading5", "Rows")],
       [HeadingsCSV.Field("Heading2", "There"),
        HeadingsCSV.Field("Heading4", "Really"),
        HeadingsCSV.Field("Heading5", "Three")]]);
}

