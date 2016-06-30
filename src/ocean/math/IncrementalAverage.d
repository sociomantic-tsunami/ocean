/*******************************************************************************

    Calculates the average using an accumulative technique (i.e, not all the
    values are provided at once).
    The struct doesn't store any previous values.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.math.IncrementalAverage;


/*******************************************************************************

    Calculates the average using an accumulative technique (i.e, not all the
    values are provided at once).
    The struct doesn't store any previous values.

*******************************************************************************/

public struct IncrementalAverage
{
    import ocean.math.Math : sqrt;

    /***************************************************************************

        Counts the number of averages that has been previously performed.
        This helps in giving the correct weight to a new number being added
        to the average in comparison to the previous numbers.

    ***************************************************************************/

    private ulong count_ = 0;


    /***************************************************************************

        Holds the average value calculated so far.

    ***************************************************************************/

    private double average_ = 0;


    /***************************************************************************

        Holds the mean of square of the added elements used by the variance()
        and stdDeviation() methods.

    ***************************************************************************/

    private double mean_of_square = 0;


    /***************************************************************************

        Adds a new number (giving it an appropriate weight) to the average.

        Note that if too many numbers were added (more than ulong.max) then the
        the internal counter will overflow (and as a result the average value
        would be corrupt).

        Params:
            value = the new value to add to the current average.
            count = if that value represent in itself the average of other
                numbers, then this param should define the number of elements
                that this average stands for. A count = 0 has no effect on the
                average and gets discarded.

    ***************************************************************************/

    public void addToAverage (T)(T value, ulong count = 1)
    {
        if (count == 0)
            return;

        this.count_ += count;

        auto delta = (value - this.average_) * count;

        this.average_ += delta / this.count_;

        this.mean_of_square += delta * (value - this.average_);
    }


    /***************************************************************************

        Returns:
            the average calculated so far.

    ***************************************************************************/

    public double average ()
    {
        return this.average_;
    }


    /***************************************************************************

        Returns:
            the count of elements added.

    ***************************************************************************/

    public ulong count ()
    {
        return this.count_;
    }


    /***************************************************************************

        Resets the average incremental instance.

    ***************************************************************************/

    public void clear ()
    {
        this.average_ = 0;
        this.count_ = 0;
        this.mean_of_square = 0;
    }

    /***************************************************************************

        Computes the variance, a measure of the spread of a distribution to
        quantify how far a set of data values is spread out.

        Note that the Welford's algorithm implementation is used to compute
        the spread of a distribution incrementally when a value is added
        through addToAverage().
        http://en.wikipedia.org/wiki/Algorithms_for_calculating_variance
        #Online_algorithm

        In standard statistical practice, a correction factor of 0 provides a
        maximum likelihood estimate of the variance for normally distributed
        variables, while a correction factor of 1 provides an unbiased
        estimator of the variance of a hypothetical infinite population.
        The correction factor will be subtracted from the number of elements
        added (sample points) when working out the divisor.
        For more information about correction factors that could be set please
        see http://en.wikipedia.org/wiki/Standard_deviation#Estimation

        Params:
            correction_factor = correction factor to normalise the divisor used
                                in the calculation

        Returns:
            The variance of the set of data values added

    ***************************************************************************/

    public double variance (double correction_factor = 0)
    {
        if (this.count_ < 2)
            return 0;

        assert(this.count_ > correction_factor, "Correction factor is same "
               "size or bigger than the number of elements added.");

        return this.mean_of_square / (this.count_ - correction_factor);
    }

    /***************************************************************************

        Returns the standard deviation, a measure of the spread of a
        distribution to quantify the amount of variation or dispersion of a
        set of data values.

        See notes on variance()

        Params:
            correction_factor = correction factor to normalise the divisor used
                                in the calculation

        Returns:
            The standard deviation of the set of data values added

    ***************************************************************************/

    public double stdDeviation (double correction_factor = 0)
    {
        return sqrt(this.variance(correction_factor));
    }
}


version (UnitTest)
{
    import ocean.core.Test : NamedTest;

    import ocean.math.IEEE;

    // Bit count to avoid deliberate loss of precision.
    // Ensures only 8 bits of precision could be lost.
    const PRECISION = double.mant_dig - 8;
}

unittest
{
    auto t = new NamedTest("Incremental Average - basic unit tests");

	IncrementalAverage inc_avg;

    t.test!("==")(inc_avg.count, 0);
    t.test!(">=")(feqrel(inc_avg.average(), 0.0), PRECISION);

	inc_avg.addToAverage(1);
    t.test!(">=")(feqrel(inc_avg.average(), 1.0), PRECISION);

	inc_avg.clear();
	t.test!("==")(inc_avg.count, 0);
    t.test!(">=")(feqrel(inc_avg.average(), 0.0), PRECISION);

	inc_avg.addToAverage(10);
	inc_avg.addToAverage(20);
    t.test!("==")(inc_avg.count, 2);
    t.test!(">=")(feqrel(inc_avg.average(), 15.0), PRECISION);

	inc_avg.clear();
	inc_avg.addToAverage(-10);
    t.test!(">=")(feqrel(inc_avg.average(), -10.0), PRECISION);
	inc_avg.addToAverage(-20);
    t.test!(">=")(feqrel(inc_avg.average(), -15.0), PRECISION);

	inc_avg.clear();
	inc_avg.addToAverage(-10, uint.max);
	inc_avg.addToAverage(10, uint.max);
    t.test!("==")(inc_avg.count, 2UL * uint.max);
    t.test!(">=")(feqrel(inc_avg.average(), 0.0), PRECISION);

	inc_avg.clear();
	inc_avg.addToAverage(long.max);
    t.test!(">=")(feqrel(inc_avg.average(), cast(double)long.max), PRECISION);
	inc_avg.addToAverage(cast(ulong)long.max + 10);
    t.test!(">=")(feqrel(inc_avg.average(), cast(double)long.max) + 5,
                  PRECISION);

	inc_avg.clear();
	inc_avg.addToAverage(long.max / 2.0);
	inc_avg.addToAverage(long.max * 1.25);
    // (0.5 + 1.25) / 2 = 0.875
    t.test!(">=")(feqrel(inc_avg.average(), long.max * 0.875), PRECISION);

	inc_avg.clear();
	inc_avg.addToAverage(long.min);
    t.test!(">=")(feqrel(inc_avg.average(), cast(double)long.min), PRECISION);
	inc_avg.addToAverage(cast(double)long.min - 10);
    t.test!(">=")(feqrel(inc_avg.average(), cast(double)long.min - 5),
                  PRECISION);

	inc_avg.clear();
	const ADD = ulong.max/1_000_000;
	for (ulong i = 0; i < ulong.max; i += (ADD < ulong.max - i ? ADD : 1))
		inc_avg.addToAverage(i%2); // 1 or 0
	inc_avg.addToAverage(1); // One more add is missing
    t.test!(">=")(feqrel(inc_avg.average(), 0.5), PRECISION);
}

unittest
{
    auto t = new NamedTest("Initialise to zero");

    IncrementalAverage distribution;
    t.test!("==")(distribution.count(), 0);
    t.test!(">=")(feqrel(distribution.average(), 0.0), PRECISION);
    t.test!(">=")(feqrel(distribution.stdDeviation(), 0.0), PRECISION);
    t.test!(">=")(feqrel(distribution.variance(), 0.0), PRECISION);
}

unittest
{
    auto t = new NamedTest("Mean (average)");

    IncrementalAverage distribution;

    // test with signed int
    distribution.clear();
    int[] int_values = [-2, -3, -4, -5, -6];
    foreach (value; int_values)
    {
        distribution.addToAverage(value);
    }
    t.test!(">=")(feqrel(distribution.average(), -4.0), PRECISION);

    // test with unsigned long
    distribution.clear();
    ulong[] ulong_values = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
    foreach (value; ulong_values)
    {
        distribution.addToAverage(value);
    }
    t.test!(">=")(feqrel(distribution.average(), 4.5), PRECISION);

    // test with double
    distribution.clear();
    double[] double_values = [2.4, 5.0, 7.6];
    foreach (value; double_values)
    {
        distribution.addToAverage(value);
    }
    t.test!(">=")(feqrel(distribution.average(), 5.0), PRECISION);
}

unittest
{
    auto t = new NamedTest("Standard Deviation & Variance");

    IncrementalAverage distribution;

    int[] values = [1, 2, 3, 4];
    distribution.clear();
    foreach (value; values)
    {
        distribution.addToAverage(value);
    }

    t.test!(">=")(feqrel(distribution.average(), 2.5), PRECISION);

    t.test!(">=")(feqrel(distribution.stdDeviation(0), 1.1180339887498949),
                  PRECISION);
    t.test!(">=")(feqrel(distribution.stdDeviation(1), 1.2909944487358056),
                  PRECISION);

    t.test!(">=")(feqrel(distribution.variance(0), 1.25), PRECISION);
    t.test!(">=")(feqrel(distribution.variance(1), 1.66666666666666666),
                  PRECISION);

    values = [10, 20, 30, 40, 50, 60];
    distribution.clear();
    foreach (value; values)
    {
        distribution.addToAverage(value);
    }

    t.test!(">=")(feqrel(distribution.average(), 35.0), PRECISION);

    t.test!(">=")(feqrel(distribution.stdDeviation(0), 17.0782512765993317),
                  PRECISION);
    t.test!(">=")(feqrel(distribution.stdDeviation(1), 18.708286933869708),
                  PRECISION);

    t.test!(">=")(feqrel(distribution.variance(0), 291.6666666666666),
                  PRECISION);
    t.test!(">=")(feqrel(distribution.variance(1), 350.0), PRECISION);
}

unittest
{
    auto t = new NamedTest("Multiple insertion precision");

    const value_1 = 3;
    const value_2 = 7;
    const value_3 = 11;
    const freq = 1001;

    IncrementalAverage single, multiple;

    multiple.addToAverage(value_1);
    single.addToAverage(value_1);

    multiple.addToAverage(value_2, freq);
    for (auto i = 0; i < freq; ++i)
    {
        single.addToAverage(value_2);
    }

    multiple.addToAverage(value_3, freq);
    for (auto i = 0; i < freq; ++i)
    {
        single.addToAverage(value_3);
    }

    t.test!(">=")(feqrel(single.average(), multiple.average()), PRECISION);
    t.test!(">=")(feqrel(single.stdDeviation(0), multiple.stdDeviation(0)),
                  PRECISION);
    t.test!(">=")(feqrel(single.stdDeviation(1), multiple.stdDeviation(1)),
                  PRECISION);
    t.test!(">=")(feqrel(single.variance(0), multiple.variance(0)), PRECISION);
    t.test!(">=")(feqrel(single.variance(1), multiple.variance(1)), PRECISION);
}

unittest
{
    auto t = new NamedTest("Add only one element");

    IncrementalAverage distribution;

    const value = 8.0;

    distribution.addToAverage(value);

    t.test!("==")(distribution.average(), value);

    t.test!("==")(distribution.stdDeviation(0), 0.0);
    t.test!("==")(distribution.stdDeviation(1), 0.0);

    t.test!("==")(distribution.variance(0), 0.0);
    t.test!("==")(distribution.variance(1), 0.0);
}
