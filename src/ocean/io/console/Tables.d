/*******************************************************************************

    Classes to draw auto-formatted tables to the console.

    The number of columns in the table must be specified either at construction,
    or by calling the init() method. Rows can be be added using the firstRow() &
    nextRow() methods. (firstRow() is essentially a reset method.)

    Usage example:

    ---

        // A table with 3 columns
        scope table = new Table(3);

        // First row is just a divider
        table.firstRow.setDivider();

        // Next row contains the headings, a series of strings
        table.nextRow.set(
            Table.Cell.String("Address"),
            Table.Cell.String("Port"),
            Table.Cell.String("Connections"));

        // Next row is another divider
        table.nextRow.setDivider();

        // Now we add one row for each of a set of 'nodes'
        foreach ( node; this.nodes )
        {
            table.nextRow.set(
                Table.Cell.String(node.address),
                Table.Cell.Integer(node.port),
                Table.Cell.Integer(node.connections));
        }

        // The last row is another divider
        table.nextRow.setDivider();

        // Display the table to Stdout
        table.display();

    ---

    It's also possible to draw smart tables where certain cells in some rows
    are merged together, something like this, for example:

    ---

        |-----------------------------------------------------|
        | 0xdb6db6e4 .. 0xedb6db76 | 0xedb6db77 .. 0xffffffff |
        |-----------------------------------------------------|
        |    Records |       Bytes |    Records |       Bytes |
        |-----------------------------------------------------|
        |     26,707 |  11,756,806 |     27,072 |  11,918,447 |
        |      6,292 |   1,600,360 |      6,424 |   1,628,086 |
        |  1,177,809 |  56,797,520 |  1,176,532 |  56,736,224 |
        |-----------------------------------------------------|

    ---

    In this example, columns 0 & 1 and 2 & 3 in row 1 are merged.

    Merged cells usage example:

    ---

        // A table with 4 columns
        scope table = new Table(4);

        // First row is just a divider
        table.firstRow.setDivider();

        // Next row contains a hash range occupying two (merged) cells. Note
        // that this is the widest column -- the other columns adapt to allow it
        // to fit.
        table.nextRow.set(Table.Cell.Merged, Table.Cell.String("0xdb6db6e4 .. 0xedb6db76"),
                          Table.Cell.Merged, Table.Cell.String("0xedb6db77 .. 0xffffffff"));

        // Next row is another divider
        table.nextRow.setDivider();

        // Next row contains the headings, a series of strings
        table.nextRow.set(Table.Cell.String("Records"), Table.Cell.String("Bytes"),
                          Table.Cell.String("Records"), Table.Cell.String("Bytes"));

        // Next row is another divider
        table.nextRow.setDivider();

        // Now we add one row for each of a set of 'nodes'
        foreach ( node; this.nodes )
        {
            table.nextRow.set(Table.Cell.Integer(node.records1), Table.Cell.Integer(node.bytes1),
                              Table.Cell.Integer(node.records2), Table.Cell.Integer(node.bytes2));
        }

        // The last row is another divider
        table.nextRow.setDivider();

        // Display the table to Stdout
        table.display();

    ---

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.console.Tables;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.core.Array : copy, appendCopy, concat;

import ocean.text.utf.UtfUtil;

import ocean.text.util.DigitGrouping;
import ocean.text.util.MetricPrefix;

import ocean.io.stream.Format;

import ocean.text.convert.Format;

import ocean.io.Stdout;

import ocean.io.Terminal;


/*******************************************************************************

    Table

*******************************************************************************/

public class Table
{
    /***************************************************************************

        Alias for a console outputter (basically Stdout / Stderr)

    ***************************************************************************/

    public alias FormatOutput!(char) Output;


    /***************************************************************************

        Row

    ***************************************************************************/

    public class Row
    {
        /***********************************************************************

            Cell

        ***********************************************************************/

        public struct Cell
        {
            /*******************************************************************

                Number of characters in-between each cell

            *******************************************************************/

            public const inter_cell_spacing = 3; // = " | "


            /*******************************************************************

                Static opCall method to create a cell containing a string.

                Params:
                    str = string to put in cell

                Returns:
                    new cell struct

            *******************************************************************/

            static public Cell String ( cstring str )
            {
                Cell cell;
                cell.setString(str);
                return cell;
            }


            /*******************************************************************

                Static opCall method to create a cell containing an integer.

                Params:
                    integer = integer to put in cell
                    use_thousands_separator = if true the integer will be
                                              "thousands" comma-separated.

                Returns:
                    new cell struct

            *******************************************************************/

            static public Cell Integer ( ulong integer,
                bool use_thousands_separator = true )
            {
                Cell cell;
                cell.setInteger(integer, use_thousands_separator);
                return cell;
            }


            /*******************************************************************

                Static opCall method to create a cell containing an integer
                scaled into a binary metric representation (Ki, Mi, Gi, Ti,
                etc).

                Params:
                    integer = integer to put in cell
                    metric_string = metric identifier (eg bytes, Kbytes, Mbytes,
                        etc.)

                Returns:
                    new cell struct

            *******************************************************************/

            static public Cell BinaryMetric ( ulong integer, cstring metric_string = "" )
            {
                Cell cell;
                cell.setBinaryMetric(integer, metric_string);
                return cell;
            }


            /*******************************************************************

                Static opCall method to create a cell containing an integer
                scaled into a decimal metric representation (K, M, G, T, etc).

                Params:
                    integer = integer to put in cell
                    metric_string = metric identifier (eg bytes, Kbytes, Mbytes,
                        etc.)

                Returns:
                    new cell struct

            *******************************************************************/

            static public Cell DecimalMetric ( ulong integer, cstring metric_string = "" )
            {
                Cell cell;
                cell.setDecimalMetric(integer, metric_string);
                return cell;
            }


            /*******************************************************************

                Static opCall method to create a cell containing a float.

                Params:
                    floating = float to put in cell

                Returns:
                    new cell struct

            *******************************************************************/

            static public Cell Float ( double floating )
            {
                Cell cell;
                cell.setFloat(floating);
                return cell;
            }


            /*******************************************************************

                Static opCall method to create a cell merged with the one to the
                right.

                Returns:
                    new cell struct

            *******************************************************************/

            static public Cell Merged ( )
            {
                Cell cell;
                cell.setMerged();
                return cell;
            }


            /*******************************************************************

                Static opCall method to create an empty cell.

                Returns:
                    new cell struct

            *******************************************************************/

            static public Cell Empty ( )
            {
                Cell cell;
                cell.setEmpty();
                return cell;
            }


            /*******************************************************************

                Cell types enum

            *******************************************************************/

            public enum Type
            {
                Empty,          // no content
                Divider,        // horizontal dividing line ------------------
                Integer,        // contains an integer
                BinaryMetric,   // contains an integer scaled to a binary metric
                DecimalMetric,  // contains an integer scaled to a decimal metric
                Float,          // contains a floating point number
                String,         // contains a string
                Merged          // merged with cell to the right
            }

            public Type type;


            /*******************************************************************

                Cell contents union

            *******************************************************************/

            public union Contents
            {
                public ulong integer;
                public double floating;
                public mstring utf8;
            }

            public Contents contents;


            /*******************************************************************

                Metric postfix string (used by BinaryMetric and DecimalMetric
                cell types)

            *******************************************************************/

            public mstring metric_string;


            /*******************************************************************

                Colour code strings, used to determine the color of this cell's
                contents for output. One for foreground colour, and one for
                background colour. If a string is empty, terminal's default
                colour will be used for output.

            *******************************************************************/

            private mstring fg_colour_string;

            private mstring bg_colour_string;


            /*******************************************************************

                When enabled and the type is an integer, the output will be
                "thousands" comma-separated, e.g.: "1,234,567"

            *******************************************************************/

            private bool use_thousands_separator;


            /*******************************************************************

                Sets the cell to contain a string.

                Params:
                    str = string to set

                Returns:
                    this instance for method chaining

            *******************************************************************/

            public typeof(this) setString ( cstring str )
            {
                this.type = Type.String;
                this.contents.utf8.copy(str);

                return this;
            }


            /*******************************************************************

                Sets the cell to contain an integer.

                Params:
                    num = integer to set
                    use_thousands_separator = if true the integer will be
                                              "thousands" comma-separated.

                Returns:
                    this instance for method chaining

            *******************************************************************/

            public typeof(this) setInteger ( ulong num,
                bool use_thousands_separator = true )
            {
                this.type = Type.Integer;
                this.use_thousands_separator = use_thousands_separator;
                this.contents.integer = num;

                return this;
            }


            /*******************************************************************

                Sets the cell to contain an integer scaled into a binary metric
                representation (Ki, Mi, Gi, Ti, etc).

                Params:
                    num = integer to set
                    metric_string = metric identifier (eg bytes, Kbytes, Mbytes,
                        etc.)

                Returns:
                    this instance for method chaining

            *******************************************************************/

            public typeof(this) setBinaryMetric ( ulong num, cstring metric_string = "" )
            {
                this.type = Type.BinaryMetric;
                this.contents.integer = num;
                this.metric_string.copy(metric_string);

                return this;
            }


            /*******************************************************************

                Sets the cell to contain an integer scaled into a decimal metric
                representation (K, M, G, T, etc).

                Params:
                    num = integer to set
                    metric_string = metric identifier (eg bytes, Kbytes, Mbytes,
                        etc.)

                Returns:
                    this instance for method chaining

            *******************************************************************/

            public typeof(this) setDecimalMetric ( ulong num, cstring metric_string = "" )
            {
                this.type = Type.DecimalMetric;
                this.contents.integer = num;
                this.metric_string.copy(metric_string);

                return this;
            }


            /*******************************************************************

                Sets the cell to contain a float.

                Params:
                    num = float to set

                Returns:
                    this instance for method chaining

            *******************************************************************/

            public typeof(this) setFloat ( double num )
            {
                this.type = Type.Float;
                this.contents.floating = num;

                return this;
            }


            /*******************************************************************

                Sets the cell to contain nothing.

                Returns:
                    this instance for method chaining

            *******************************************************************/

            public typeof(this) setEmpty ( )
            {
                this.type = Type.Empty;

                return this;
            }


            /*******************************************************************

                Sets the cell to contain a horizontal divider.

                Returns:
                    this instance for method chaining

            *******************************************************************/

            public typeof(this) setDivider ( )
            {
                this.type = Type.Divider;

                return this;
            }


            /*******************************************************************

                Sets the cell to be merged with the cell to its right.

                Returns:
                    this instance for method chaining

            *******************************************************************/

            public typeof(this) setMerged ( )
            {
                this.type = Type.Merged;

                return this;
            }


            /*******************************************************************

                Sets the foreground colour of this cell

                Params:
                    colour = The colour to use

                Returns:
                    this instance for method chaining

            *******************************************************************/

            public typeof(this) setForegroundColour ( Terminal.Colour colour )
            {
                auto colour_str = Terminal.fg_colour_codes[colour];
                this.fg_colour_string.concat(Terminal.CSI, colour_str);

                return this;
            }


            /*******************************************************************

                Sets the background colour of this cell

                Params:
                    colour = The colour to use

                Returns:
                    this instance for method chaining

            *******************************************************************/

            public typeof(this) setBackgroundColour ( Terminal.Colour colour )
            {
                auto colour_str = Terminal.bg_colour_codes[colour];
                this.bg_colour_string.concat(Terminal.CSI, colour_str);

                return this;
            }


            /*******************************************************************

                Returns:
                    the width of cell's contents, in characters

            *******************************************************************/

            public size_t width ( )
            {
                switch ( this.type )
                {
                    case Cell.Type.Merged:
                    case Cell.Type.Empty:
                    case Cell.Type.Divider:
                        return 0;
                    case Cell.Type.BinaryMetric:
                        MetricPrefix metric;
                        metric.bin(this.contents.integer);
                        return this.floatWidth(metric.scaled) + 3 +
                            this.metric_string.length;
                    case Cell.Type.DecimalMetric:
                        MetricPrefix metric;
                        metric.dec(this.contents.integer);
                        return this.floatWidth(metric.scaled) + 2 +
                            this.metric_string.length;
                    case Cell.Type.Integer:
                        return this.integerWidth(this.contents.integer);
                    case Cell.Type.Float:
                        return this.floatWidth(this.contents.floating);
                    case Cell.Type.String:
                        return utf8Length(this.contents.utf8);

                    default:
                        assert(0);
                }
            }


            /*******************************************************************

                Displays the cell to the specified output.

                Params:
                    output = output to send cell to
                    width = display width of cell
                    content_buf = string buffer to use for formatting cell
                        contents
                    spacing_buf = string buffer to use for formatting spacing to
                        the left of the cell's contents

            *******************************************************************/

            public void display ( Output output, size_t width, ref mstring
                content_buf, ref mstring spacing_buf )
            {
                // sequence of control characters to reset output colors to default
                istring default_colours =
                    Terminal.CSI ~ Terminal.fg_colour_codes[Terminal.Colour.Default] ~
                    Terminal.CSI ~ Terminal.bg_colour_codes[Terminal.Colour.Default];

                // set the colour of this cell
                if ( this.fg_colour_string.length > 0 ||
                     this.bg_colour_string.length > 0 )
                {
                    output.format("{}{}", this.fg_colour_string, this.bg_colour_string);
                }

                if ( this.type == Type.Divider )
                {
                    content_buf.length = width + inter_cell_spacing;
                    enableStomping(content_buf);
                    content_buf[] = '-';

                    output.format("{}", content_buf);

                    // reset colour to default
                    if ( this.fg_colour_string.length > 0 ||
                         this.bg_colour_string.length > 0 )
                    {
                        output.format("{}", default_colours);
                    }
                }
                else
                {
                    switch ( this.type )
                    {
                        case Type.Empty:
                            content_buf.length = 0;
                            enableStomping(content_buf);
                            break;
                        case Type.BinaryMetric:
                            content_buf.length = 0;
                            enableStomping(content_buf);

                            MetricPrefix metric;
                            metric.bin(this.contents.integer);

                            if ( metric.prefix == ' ' )
                            {
                                Format.format(content_buf,
                                    "{}      {}", cast(uint)metric.scaled,
                                    this.metric_string);
                            }
                            else
                            {
                                Format.format(content_buf,
                                    "{} {}i{}", metric.scaled, metric.prefix,
                                    this.metric_string);
                            }
                            break;
                        case Type.DecimalMetric:
                            content_buf.length = 0;
                            enableStomping(content_buf);

                            MetricPrefix metric;
                            metric.dec(this.contents.integer);

                            if ( metric.prefix == ' ' )
                            {
                                Format.format(content_buf,
                                    "{}     {}", cast(uint)metric.scaled,
                                    this.metric_string);
                            }
                            else
                            {
                                Format.format(content_buf,
                                    "{} {}{}", metric.scaled, metric.prefix,
                                    this.metric_string);
                            }
                            break;
                        case Type.Integer:
                            if ( this.use_thousands_separator )
                            {
                                DigitGrouping.format(this.contents.integer, content_buf);
                            }
                            else
                            {
                                content_buf.length = 0;
                                enableStomping(content_buf);
                                Format.format(content_buf,
                                    "{}", this.contents.integer);
                            }
                            break;
                        case Type.Float:
                            content_buf.length = 0;
                            enableStomping(content_buf);
                            Format.format(content_buf,
                                    "{}", this.contents.floating);
                            break;
                        case Type.String:
                            content_buf = this.contents.utf8;
                            break;
                        default:
                            return;
                    }

                    assert(width >= utf8Length(content_buf), "column not wide enough");

                    spacing_buf.length = width - utf8Length(content_buf);
                    enableStomping(spacing_buf);
                    spacing_buf[] = ' ';
                    output.format(" {}{} ", spacing_buf, content_buf);

                    // reset colour to default
                    output.format("{}", default_colours);

                    output.format("|");
                }
            }


            /*******************************************************************

                Calculates the number of characters required to display
                an integer (the number of digits)

                Params:
                    i = integer to calculate width of

                Returns:
                    number of characters required to display i

            *******************************************************************/

            private size_t integerWidth ( ulong i )
            {
                if ( this.use_thousands_separator )
                {
                    return DigitGrouping.length(i);
                }

                size_t digits;
                while (i)
                {
                    i /= 10;
                    ++digits;
                }

                return digits;
            }


            /*******************************************************************

                Calculates the number of characters required to display a float.

                Params:
                    f = float to calculate width of

                Returns:
                    number of character required to display f

            *******************************************************************/

            private size_t floatWidth ( double f )
            {
                size_t width = 4; // 0.00
                if ( f < 0 )
                {
                    f = -f;
                    width++; // minus symbol
                }

                double dec = 10;
                while ( f >= dec )
                {
                    width++;
                    dec *= 10;
                }

                return width;
            }
        }


        /***********************************************************************

            List of cells in row

        ***********************************************************************/

        public Cell[] cells;


        /***********************************************************************

            Returns:
                the number of cells in this row

        ***********************************************************************/

        public size_t length ( )
        {
            return this.cells.length;
        }


        /***********************************************************************

            Sets the number of cells in this row.

            Params:
                width = numebr of cells

        ***********************************************************************/

        public void setWidth ( size_t width )
        {
            this.cells.length = width;
            enableStomping(this.cells);
        }


        /***********************************************************************

            Gets the cell in this row at the specified column.

            Params:
                col = column number

            Returns:
                pointer to cell in specified column, null if out of range

        ***********************************************************************/

        public Cell* opIndex ( size_t col )
        {
            Cell* c;

            if ( col < this.cells.length )
            {
                return &this.cells[col];
            }

            return c;
        }


        /***********************************************************************

            foreach iterator over the cells in this row.

        ***********************************************************************/

        public int opApply ( int delegate ( ref Cell cell ) dg )
        {
            int res;
            foreach ( cell; this.cells )
            {
                res = dg(cell);
                if ( !res ) break;
            }

            return res;
        }


        /***********************************************************************

            foreach iterator over the cells in this row and their indices.

        ***********************************************************************/

        public int opApply ( int delegate ( ref size_t i, ref Cell cell ) dg )
        {
            int res;
            foreach ( i, cell; this.cells )
            {
                res = dg(i, cell);
                if ( res ) break;
            }

            return res;
        }


        /***********************************************************************

            Sets the cells in this row. The passed list must be of equal length
            to the length of this row.

            Params:
                cells = variadic list of cells

        ***********************************************************************/

        public void set ( Cell[] cells ... )
        in
        {
            assert(cells.length == this.cells.length, "row length mismatch");
        }
        body
        {
            foreach ( i, cell; cells )
            {
                this.cells[i] = cell;
            }
        }


        /***********************************************************************

            Sets all the cells in this row to be dividers, optionally with some
            empty cells at the left.

            Params:
                empty_cells_at_left = number of empty cells to leave at the left
                    of the row (all others will be dividers)

        ***********************************************************************/

        public void setDivider ( size_t empty_cells_at_left = 0 )
        {
            foreach ( i, ref cell; this.cells )
            {
                if ( i < empty_cells_at_left )
                {
                    cell.setEmpty();
                }
                else
                {
                    cell.setDivider();
                }
            }
        }


        /***********************************************************************

            Displays this row to the specified output, terminated with a
            newline.

            Params:
                output = output to send cell to
                column_widths = display width of cells
                content_buf = string buffer to use for formatting cell
                    contents
                spacing_buf = string buffer to use for formatting spacing to
                    the left of the cells' contents

        ***********************************************************************/

        public void display ( Output output, size_t[] column_widths, ref mstring
            content_buf, ref mstring spacing_buf )
        {
            assert(column_widths.length == this.length);

            uint merged;
            size_t merged_width;

            foreach ( i, cell; this.cells )
            {
                if ( cell.type == Cell.Type.Merged )
                {
                    merged++;
                    merged_width += column_widths[i] + Cell.inter_cell_spacing;
                }
                else
                {
                    cell.display(output, merged_width + column_widths[i], content_buf,  spacing_buf);

                    merged = 0;
                    merged_width = 0;
                }
            }

            output.formatln("");
        }
    }


    /***************************************************************************

        Convenience alias, allows the Cell struct to be accessed from the
        outside as Table.Cell.

    ***************************************************************************/

    public alias Row.Cell Cell;


    /***************************************************************************

        Number of columns in the table

    ***************************************************************************/

    private size_t num_columns;


    /***************************************************************************

        Number of characters in each column (auto calculated by the
        calculateColumnWidths() method)

    ***************************************************************************/

    private size_t[] column_widths;


    /***************************************************************************

        List of table rows

    ***************************************************************************/

    private Row[] rows;


    /***************************************************************************

        Index of the current row

    ***************************************************************************/

    private size_t row_index;


    /***************************************************************************

        String buffers used for formatting.

    ***************************************************************************/

    private char[] content_buf, spacing_buf;


    /***************************************************************************

        Information on merged cells -- used by scanMergedCells().

    ***************************************************************************/

    private struct MergeInfo
    {
        size_t total_width;
        size_t first_column;
        size_t last_column;
    }

    private MergeInfo[] merged;


    /***************************************************************************

        Constructor.

        Note: if you create a Table with this default constructor, you must call
        init() when you're ready to use it.

    ***************************************************************************/

    public this ( )
    {
    }


    /***************************************************************************

        Constructor. Sets the number of columns in the table.

        Params:
            num_columns = number of columns in the table

    ***************************************************************************/

    public this ( size_t num_columns )
    {
        this.init(num_columns);
    }


    /***************************************************************************

        Init method. Must be called before any other methods are used.

        Params:
            num_columns = number of columns in the table

    ***************************************************************************/

    public void init ( size_t num_columns )
    {
        this.num_columns = num_columns;
        this.rows.length = 0;
        this.row_index = 0;
    }


    /***************************************************************************

        Gets the first row in the table.

        Returns:
            reference to the table's first row

    ***************************************************************************/

    public Row firstRow ( )
    {
        this.rows.length = 0;
        this.row_index = 0;
        return this.currentRow();
    }


    /***************************************************************************

        Gets the current row in the table.

        Returns:
            reference to the table's current row

    ***************************************************************************/

    public Row currentRow ( )
    {
        this.ensureRowExists();
        return this.rows[this.row_index];
    }


    /***************************************************************************

        Gets the next row in the table, adding a new row if the current row is
        currently the last.

        Returns:
            reference to the table's next row

    ***************************************************************************/

    public Row nextRow ( )
    {
        this.row_index++;
        this.ensureRowExists();
        return this.rows[this.row_index];
    }


    /***************************************************************************

        Displays the table to the specified output.

        Returns:
            output = output to display table to

    ***************************************************************************/

    public void display ( Output output = Stdout )
    {
        this.calculateColumnWidths();

        foreach ( row; this.rows )
        {
            row.display(output, this.column_widths, this.content_buf, this.spacing_buf);
        }
    }


    /***************************************************************************

        Checks whether the current row already exists, and creates it if it
        doesn't.

    ***************************************************************************/

    private void ensureRowExists ( )
    in
    {
        assert(this.num_columns, "num_columns not set, please call init()");
    }
    body
    {
        if ( this.rows.length <= this.row_index )
        {
            this.rows.length = this.row_index + 1;
            foreach ( ref row; this.rows )
            {
                if ( !row )
                {
                    // TODO: repeatedly calling init() will cause a memory leak
                    row = new Row;
                }
                row.setWidth(this.num_columns);
            }
        }
    }


    /***************************************************************************

        Calculates the optimal width for each column, setting the column_widths
        member.

    ***************************************************************************/

    private void calculateColumnWidths ( )
    {
        this.column_widths.length = this.num_columns;
        this.column_widths[] = 0;

        if ( !this.rows.length )
        {
            return;
        }

        // Find basic column widths, excluding merged cells
        bool in_merge;
        foreach ( row; this.rows )
        {
            in_merge = false;

            foreach ( i, cell; row )
            {
                if ( in_merge )
                {
                    if ( cell.type != Row.Cell.Type.Merged )
                    {
                        in_merge = false;
                    }
                }
                else
                {
                    if ( cell.type == Row.Cell.Type.Merged )
                    {
                        in_merge = true;
                    }
                    else
                    {
                        this.column_widths[i] =
                            cell.width > this.column_widths[i]
                                ? cell.width
                                : this.column_widths[i];
                    }
                }
            }
        }

        // Find merged columns and work out how many cells they span
        auto merged = this.scanMergedCells();

        // Adjust widths of non-merged columns to fit merged columns
        foreach ( i, row; this.rows )
        {
            foreach ( merge; merged )
            {
                if ( row.cells[merge.first_column].type != Row.Cell.Type.Merged )
                {
                    // Calculate current width of all columns which merged cells
                    // cover
                    size_t width;
                    foreach ( w; this.column_widths[merge.first_column..merge.last_column + 1] )
                    {
                        width += w;
                    }

                    // Add extra width to columns if the merged cells are larger
                    // than the currently set column widths.
                    if ( merge.total_width > width )
                    {
                        auto      num_merged = merge.last_column - merge.first_column;
                        ptrdiff_t difference = merge.total_width - width - num_merged
                            * Row.Cell.inter_cell_spacing;

                        if ( difference > 0 )
                        {
                            this.expandColumns(merge.first_column,
                                merge.last_column, difference);
                        }
                    }
                }
            }
        }
    }


    /***************************************************************************

        Find sets of merged cells.

        Returns:
            list of merged cells sets

    ***************************************************************************/

    private MergeInfo[] scanMergedCells ( )
    {
        this.merged.length = 0;

        foreach ( row; this.rows )
        {
            bool in_merge = false;

            foreach ( i, cell; row )
            {
                if ( in_merge )
                {
                    this.merged[$-1].last_column = i;
                    this.merged[$-1].total_width += cell.width;

                    if ( cell.type != Row.Cell.Type.Merged )
                    {
                        in_merge = false;
                    }
                }
                else
                {
                    if ( cell.type == Row.Cell.Type.Merged )
                    {
                        in_merge = true;
                        this.merged.length = this.merged.length + 1;
                        this.merged[$-1].first_column = i;
                        this.merged[$-1].total_width += cell.width;
                    }
                }
            }
        }

        return this.merged;
    }


    /***************************************************************************

        Adds extra width to a specified range of columns. Extra width is
        distriubuted evenly between all columns in the specified range.

        Params:
            first_column = index of first column in range to add extra width to
            last_column = index of last column in range to add extra width to
            extra_width = characters of extra width to distribute between all
                columns in the specified range

    ***************************************************************************/

    private void expandColumns ( size_t first_column, size_t last_column, size_t extra_width )
    {
        size_t column = first_column;
        while ( extra_width > 0 )
        {
            this.column_widths[column]++;
            if ( ++column > last_column )
            {
                column = first_column;
            }
            extra_width--;
        }
    }
}

version ( UnitTest ) import ocean.io.device.Array : Array;

unittest
{
    auto buffer = new Array(1024, 1024);

    scope output = new FormatOutput!(char) (buffer);

    scope table = new Table(4);

    table.firstRow.setDivider();

    table.nextRow.set(Table.Cell.Merged, Table.Cell.String("0xdb6db6e4 .. 0xedb6db76"),
                      Table.Cell.Merged, Table.Cell.String("0xedb6db77 .. 0xffffffff"));

    table.nextRow.setDivider();

    table.nextRow.set(Table.Cell.String("Records"), Table.Cell.String("Bytes"),
                      Table.Cell.String("Records"), Table.Cell.String("Bytes"));

    table.nextRow.setDivider();

    struct Node
    {
        int records1, records2, bytes1, bytes2;
    }

    const nodes =
    [
        Node(123456, 789012, 345678, 901234),
        Node(901234, 123456, 789012, 345678),
        Node(345678, 901234, 123456, 789012),
    ];

    static bool use_thousands = true;
    static bool dont_use_thousands = false;

    foreach ( node; nodes )
    {
        table.nextRow.set(Table.Cell.Integer(node.records1),
                          Table.Cell.Integer(node.bytes1, use_thousands),
                          Table.Cell.Integer(node.records2, dont_use_thousands),
                          Table.Cell.Integer(node.bytes2, dont_use_thousands));
    }

    table.nextRow.setDivider();

    table.display(output);

    // note: The string literal embeds escape characters, which are used by
    // the table functions to set foreground/background colors in the console.
const check =
`------------------------------------------------------
 0xdb6db6e4 .. 0xedb6db76 [39m[49m| 0xedb6db77 .. 0xffffffff [39m[49m|
------------------------------------------------------
     Records [39m[49m|      Bytes [39m[49m|     Records [39m[49m|      Bytes [39m[49m|
------------------------------------------------------
     123,456 [39m[49m|    345,678 [39m[49m|      789012 [39m[49m|     901234 [39m[49m|
     901,234 [39m[49m|    789,012 [39m[49m|      123456 [39m[49m|     345678 [39m[49m|
     345,678 [39m[49m|    123,456 [39m[49m|      901234 [39m[49m|     789012 [39m[49m|
------------------------------------------------------
`;

    auto result = cast(char[])buffer.slice();

    assert(result == check, result);
}
