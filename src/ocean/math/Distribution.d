/*******************************************************************************

    Helper class useful for producing apache bench style output about value
    distributions. For example:

    ---

        Time distribution of 10000 requests:
         50.0% <= 234μs
         66.0% <= 413μs
         75.0% <= 498μs
         80.0% <= 575μs
         90.0% <= 754μs
         95.0% <= 787μs
         98.0% <= 943μs
         99.0% <= 1054μs
         99.5% <= 1183μs
         99.9% <= 7755μs
        100.0% <= 8807μs (longest request)

        146 requests (1.5%) took longer than 1000μs

    ---

    Performance note: the lessThanCount(), greaterThanCount() and percentValue()
    methods all sort the list of values stored in the Distribution instance. In
    general it is thus best to add all the values you're interested in, then
    call the results methods, so the list only needs to be sorted once.

    Usage example:

    ---

        import ocean.math.Distribution;

        import ocean.io.Stdout_tango;

        import ocean.time.StopWatch;

        // Stopwatch instance.
        StopWatch sw;

        // Create a distribution instance initialised to contain 10_000 values.
        // (The size can be extended, but it's set initially for the sake of
        // pre-allocation.)
        const num_requests = 10_000;
        auto dist = new Distribution!(ulong)(num_requests);

        // Perform a series of imaginary requests, timing each one and adding
        // the time value to the distribution
        for ( int i; i < num_requests; i++ )
        {
            sw.start;
            doRequest();
            auto time = sw.microsec;

            dist ~= time;
        }

        // Display the times taken by 50%, 66% etc of the requests.
        // (This produces output like apache bench.)
        const percentages = [0.5, 0.66, 0.75, 0.8, 0.9, 0.95, 0.98, 0.99, 0.995, 0.999, 1];

        foreach ( i, percentage; percentages )
        {
            auto value = dist.percentValue(percentage);

            Stdout.formatln("{,5:1}% <= {}μs", percentage * 100, value);
        }

        // Display the number of requests which took longer than 1ms.
        const timeout = 1_000; // 1ms
        auto timed_out = dist.greaterThanCount(timeout);

        Stdout.formatln("{} requests ({,3:1}%) took longer than {}μs",
                timed_out,
                (cast(float)timed_out / cast(float)dist.length) * 100.0,
                timeout);

        // Clear distribution ready for next test.
        dist.clear;

    ---

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.math.Distribution;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.core.Enforce;
import ocean.core.Array : bsearch, sort;

import ocean.util.container.AppendBuffer;



/*******************************************************************************

    Class to report on the distribution of a series of values.

    Template params:
        T = The type of the values in the distribution

*******************************************************************************/

public class Distribution ( T )
{
    /***************************************************************************

        List of values, appended to by the opAddAssign method.

    ***************************************************************************/

    private AppendBuffer!(T) values;


    /***************************************************************************

        Indicates whether the list of values has been sorted (which is required
        by the methods: lessThanCount, greaterThanCount, percentValue).
        opAddAssign() and clear() reset the sorted flag to false.

        TODO: it might be better to always maintain the list in sorted order?

    ***************************************************************************/

    private bool sorted;


    /***************************************************************************

        Constructor.

        Params:
            num_values = initial size of list (for pre-allocation)

    ***************************************************************************/

    public this ( size_t num_values = 0 )
    {
        this.values = new AppendBuffer!(T)(num_values);
    }


    /***************************************************************************

        Adds a value to the list.

        Params:
            value = value to add

    ***************************************************************************/

    public void opCatAssign ( T value )
    {
        this.values.append(value);
        this.sorted = false;
    }


    /***************************************************************************

        Clears all values from the list.

    ***************************************************************************/

    public void clear ( )
    {
        this.values.length = 0;
        this.sorted = false;
    }


    /***************************************************************************

        Returns:
            the number of values in the list

        Note: aliased as length.

    ***************************************************************************/

    public ulong count ( )
    {
        return this.values.length;
    }

    public alias count length;


    /***************************************************************************

        Gets the count of values in the list which are less than the specified
        value.

        Params:
            max = value to count less than

        Returns:
            number of values less than max

    ***************************************************************************/

    public size_t lessThanCount ( T max )
    {
        if ( this.values.length == 0 )
        {
            return 0;
        }

        this.sort;

        size_t less;
        bsearch(this.values[], max, less);
        return less;
    }


    /***************************************************************************

        Gets the count of values in the list which are greater than the
        specified value.

        Params:
            min = value to count greater than

        Returns:
            number of values greater than min

    ***************************************************************************/

    public size_t greaterThanCount ( T min )
    {
        auto less = this.lessThanCount(min);
        return this.values.length - less;
    }


    /***************************************************************************

        Gets the value which X% of the values in the list are less than or equal
        to.

        For example, if values contains [1, 2, 3, 4, 5, 6, 7, 8], then
        percentValue(0.5) returns 4, while percentValue(0.25) returns 2, and
        percentValue(1.0) returns 8.

        Throws an error if passed a value <= 0 or >= 1.

        Params:
            fraction = percentage as a fraction

        Returns:
            value which X% of the values in the list are less than or equal to

    ***************************************************************************/

    public T percentValue ( double fraction )
    out ( result )
    {
        if ( this.values.length == 0 )
        {
            assert(result == 0, "percentValue should be 0 for empty distributions");
        }
    }
    body
    {
        enforce(fraction >= 0.0 && fraction <= 1.0,
            "fraction must be within [0.0 ... 1.0]");

        if ( this.values.length == 0 )
        {
            return 0;
        }

        this.sort;

        auto index = cast(size_t)(fraction * (this.values.length - 1));

        assert(index < this.values.length, "index greater than or equal to length of value list");

        if ( index >= this.values.length )
        {
            index = this.values.length - 1;
        }

        return this.values[index];
    }


    unittest
    {
        // test with ulong
        percentValueTests!(ulong)([1, 2, 3, 4, 5, 6, 7, 8], 4);

        // test with odd amount of numbers
        percentValueTests!(ulong)([1, 2, 3, 4, 5, 6, 7, 8, 9], 5);

        // test with signed int
        percentValueTests!(int)([-8, -7, -6, -5, -4, -3, -2, -1], -5);

        // test with double
        percentValueTests!(double)([1.5, 2.5, 3.5, 4.5, 5.5, 7.5, 8.5], 4.5);
    }


    /***************************************************************************

        Calculates the mean (average) value of this distribution

        Returns:
            The average of the values contained in this distribution

    ***************************************************************************/

    public double mean ( )
    {
        if ( this.values.length == 0 )
        {
            return 0;
        }

        double total = 0.0;

        for ( int i = 0; i < this.values.length; i++ )
        {
            total += this.values[i];
        }

        return total / this.values.length;
    }


    unittest
    {
        // test with ulong
        meanTests!(ulong)([2, 3, 4, 5, 6], 4);

        // test with signed int
        meanTests!(int)([-2, -3, -4, -5, -6], -4);

        // test with double
        meanTests!(double)([2.4, 5.0, 7.6], 5.0);
    }


    /***************************************************************************

        Calculates the median value of this distribution
        For an odd number of values, the middle value is returned
        For an even number, the average of the 2 middle values is returned

        Returns:
            The median of the values contained in this distribution

    ***************************************************************************/

    public double median ( )
    {
        if ( this.values.length == 0 )
        {
            return 0;
        }

        this.sort;

        auto count = this.values.length;
        double median;

        if ( count % 2 == 0 )
        {
            double lval = this.values[( count / 2 ) - 1];
            double rval = this.values[count / 2];
            median = ( lval + rval ) / 2;
        }
        else
        {
            median = this.values[count / 2];
        }

        return median;
    }


    unittest
    {
        // test with ulong
        medianTests!(ulong)([2, 3, 4, 5, 6], 4);

        // test with even amount of numbers
        medianTests!(ulong)([2, 3, 4, 5, 6, 7], 4.5);

        // test with signed int
        medianTests!(int)([-2, -3, -4, -5, -6], -4);

        // test with double
        medianTests!(double)([2.4, 5.0, 7.6], 5.0);
    }


    /***************************************************************************

        Sorts the values in the list, if they are not already sorted.

    ***************************************************************************/

    private void sort ( )
    {
        if ( !this.sorted )
        {
            .sort(this.values[]);
            this.sorted = true;
        }
    }
}

unittest
{
    alias Distribution!(size_t) Instance;
}


/*******************************************************************************

    Functions that are common to the unittests in this module
    These functions are template functions, so they will not
    generate any code unless compiled with -unittest.

*******************************************************************************/



/*******************************************************************************

    Appends the given list of values to the given distribution

    Template params:
        T = the type used by the distribution

    Params:
        dist = the distribution to append to
        values = the values to put into the distribution

*******************************************************************************/

private void appendDist ( T ) ( Distribution!(T) dist, T[] values )
{
    foreach ( val; values )
    {
        dist ~= val;
    }
}


/*******************************************************************************

    Tests if an error was caught or not when calling the given delegate

    Template params:
        dummy = dummy template parameter to avoid generating
            code for this function if it is not used

    Params:
        dg = a delegate that calls an error throwing function
        error = whether an error should have been thrown or not
        msg = the error message should the assert fail

*******************************************************************************/

private void testForError ( bool dummy = false )
                          ( void delegate ( ) dg, bool error, istring msg )
{
    bool caught = false;

    try
    {
        dg();
    }
    catch ( Exception e )
    {
        caught = true;
    }

    assert(error == caught, "Error " ~ (!error ? "not " : "")  ~ "expected: " ~ msg);
}


/*******************************************************************************

    Runs a standard set of percentValue tests on the given distribution
    Tests will be checked against the given expected middle value

    Template params:
        T = the type used by the distribution

    Params:
        values = the values to test a distribution of
        middle_value = the expected middle value to check against

*******************************************************************************/

private void percentValueTests ( T ) ( T[] values, T middle_value )
{
    auto dist = new Distribution!(T);

    // test that percentValue always returns 0 for empty distributions regardless of type
    assert(dist.percentValue(0.25) == 0, "percentValue should always return 0 for an empty distribution");

    appendDist!(T)(dist, values);

    // test that exceeding the boundaries throws an error
    testForError({ dist.percentValue(-1.0); }, true, "fraction < 0 is out of bounds");
    testForError({ dist.percentValue(2.0); }, true, "fraction > 1 is out of bounds");

    // test middle value
    assert(dist.percentValue(0.5) == middle_value, "");
}


/*******************************************************************************
 *
    Runs a standard set of mean tests on the given distribution
    Tests will be checked against the given expected average value

    Template params:
        T = the type used by the distribution

    Params:
        values = the values to test a distribution of
        average_value = the expected average value to check against

*******************************************************************************/

private void meanTests ( T ) ( T[] values, T average_value )
{
    auto dist = new Distribution!(T);

    // test that mean always returns 0 for empty distributions regardless of type
    assert(dist.mean() == 0, "mean should always return 0 for an empty distribution");

    appendDist!(T)(dist, values);

    // test average value
    assert(dist.mean() == average_value, "mean returned the wrong average value");
}


/*******************************************************************************
 *
    Runs a standard set of median tests on the given distribution
    Tests will be checked against the given expected median value

    Template params:
        T = the type used by the distribution

    Params:
        values = the values to test a distribution of
        median_value = the expected median value to check against

*******************************************************************************/

private void medianTests ( T ) ( T[] values, double median_value )
{
    auto dist = new Distribution!(T);

    // test that median always returns 0 for empty distributions regardless of type
    assert(dist.median() == 0, "median should always return 0 for an empty distribution");

    appendDist!(T)(dist, values);

    // test median value
    assert(dist.median() == median_value, "median returned the wrong median value");
}
