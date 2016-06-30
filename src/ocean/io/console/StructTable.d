/*******************************************************************************

    Helper template to display tables to the console where the headings of the
    columns are the names of the fields of a struct, and where the contents of
    each row of the table are the values of the fields of an instance of the
    struct type.

    Usage example:

    ---

        import ocean.io.console.StructTable;

        struct Test
        {
            int number;
            float fraction;
            char[] name;
        }

        scope table = new StructTable!(Test);

        table.addRow(Test(23, 12.12, "gavin"));
        table.addRow(Test(17, 99.9, "david"));
        table.addRow(Test(11, 10.0, "luca"));

        table.display();

    ---

    The output of the usage example would be:

    ---

        ----------------------------
         number | fraction |  name |
        ----------------------------
             23 |    12.12 | gavin |
             17 |    99.90 | david |
             11 |    10.00 |  luca |
        ----------------------------

    ---

    The StructTable template class internally generates one protected method for
    each field of the struct it is based on (the template parameter). These
    methods are named <field name>_string, and return a char[] which is to be
    displayed in the approrpiate column of the table. By default these methods
    simply format the struct fields using Layout. However, due to the way this
    is implemented, it is possible to derive a class which overrides the
    stringifying method of one or more struct fields, enabling special output
    behaviour to be implemented.

    Class overriding usage example (extends above example):

    ---

        import ocean.text.convert.Format;

        class TestTable : StructTable!(Test)
        {
            override protected char[] fraction_string ( float* field )
            {
                this.format_buffer.length = 0;
                Format.format(this.format_buffer, "{}%", *field * 100.0);
                return this.format_buffer;
            }
        }

        scope table2 = new TestTable;

        table2.addRow(Test(23, 0.12, "gavin"));
        table2.addRow(Test(17, 0.999, "david"));
        table2.addRow(Test(11, 0.1, "luca"));

        table2.display();

    ---

    The output of the usage example would be:

    ---

        -----------------------------
         number |  fraction |  name |
        ----------------------------
             23 |    12.00% | gavin |
             17 |    0.999% | david |
             11 |     0.10% |  luca |
        -----------------------------

    ---

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.console.StructTable;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.core.Traits;

import ocean.io.console.Tables;

import ocean.text.convert.Format;



/*******************************************************************************

    Struct table template class.

    Note: as this class formats and copies the string for each field in each
    row, it is generally not advisable to instantiate it as scope.

    Template_Params:
        S = type whose fields specify the columns of the table

*******************************************************************************/

public class StructTable ( S )
{
    /***************************************************************************

        Table used for output.

    ***************************************************************************/

    private Table table;


    /***************************************************************************

        Array of cells used while building up rows (one cell per field of S).

    ***************************************************************************/

    private Table.Row.Cell[] cells;


    /***************************************************************************

        Buffer used for string formatting.

    ***************************************************************************/

    protected char[] format_buffer;


    /***************************************************************************

        Template to mix in a protected method per field of S.

        The generated methods are of the form:

            protected char[] <field_name>_string ( <field_type>* field )

    ***************************************************************************/

    private template CellMethods ( size_t i = 0 )
    {
        static if ( i == S.tupleof.length )
        {
            const istring CellMethods = "";
        }
        else
        {
            const istring CellMethods = "protected char[] " ~ FieldName!(i, S)
                ~ "_string(" ~ FieldType!(S, i).stringof
                ~ "* field){return this.defaultFieldString(field);}"
                ~ CellMethods!(i + 1);
        }
    }

    // pragma(msg, CellMethods!());
    mixin(CellMethods!());


    /***************************************************************************

        Constructor.

    ***************************************************************************/

    public this ( )
    {
        this.table = new Table(S.tupleof.length);

        this.clear();
    }


    /***************************************************************************

        Adds a row to the table.

    ***************************************************************************/

    public void addRow ( ref S item )
    {
        this.cells.length = 0;
        // pragma(msg, ContentsRow!());
        mixin(ContentsRow!());
        this.table.nextRow.set(this.cells);
    }


    /***************************************************************************

        Displays the table to the console.

        TODO: allow specification of output (like in Tables)

    ***************************************************************************/

    public void display ( )
    {
        this.table.nextRow.setDivider();
        this.table.display();
    }


    /***************************************************************************

        Clears all rows from the table and adds the header row (containing the
        names of all struct fields).

    ***************************************************************************/

    public void clear ( )
    {
        this.table.firstRow.setDivider();

        this.cells.length = 0;
        mixin(HeaderRow!());

        this.table.nextRow.set(this.cells);
        this.table.nextRow.setDivider();
    }


    /***************************************************************************

        Default field formatting method template. Simply uses Layout to generate
        a string for a field.

        Template_Params:
            T = type of field in S

        Params:
            field = pointer to a field of type T in a struct of type S

        Returns:
            string representation of the passed field

    ***************************************************************************/

    private char[] defaultFieldString ( T ) ( T* field )
    {
        this.format_buffer.length = 0;
        Format.format(this.format_buffer, "{}", *field);
        return this.format_buffer;
    }


    /***************************************************************************

        Adds a cell to the current row.

    ***************************************************************************/

    private void addCell ( cstring str )
    {
        this.cells ~= Table.Row.Cell.String(str);
    }


    /***************************************************************************

        Template to mix in a call to the addCell() method for each field of a
        struct. It is assumed that an instance of the struct S exists in scope
        with the name 'item'.

    ***************************************************************************/

    private template ContentsRow ( size_t i = 0 )
    {
        static if ( i == S.tupleof.length )
        {
            const istring ContentsRow = "";
        }
        else
        {
            const istring ContentsRow = "this.addCell(this." ~ FieldName!(i, S)
                ~ "_string(GetField!(" ~ i.stringof ~ ")(&item)));"
                ~ ContentsRow!(i + 1);
        }
    }


    /***************************************************************************

        Template to mix in a call to the addCell() method for each field of a
        struct. The names of the struct's fields are added as headers for each
        column in the table.

    ***************************************************************************/

    private template HeaderRow ( size_t i = 0 )
    {
        static if ( i == S.tupleof.length )
        {
            const istring HeaderRow = "";
        }
        else
        {
            const istring HeaderRow = `this.addCell("` ~ FieldName!(i, S) ~
                `");` ~ HeaderRow!(i + 1);
        }
    }
}

unittest
{
    struct Entry
    {
        int field;
        double field2;
    }

    alias StructTable!(Entry) Instance;
}
