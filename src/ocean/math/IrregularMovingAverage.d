/*******************************************************************************

    Struct implementation of a moving average designed to handle irregularly
    spaced data.  In principle this can also be used as a serializable record
    struct.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.math.IrregularMovingAverage;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.core.Enforce;

import ocean.core.Traits;
import ocean.math.IEEE;
import ocean.math.Math;
import core.stdc.time;


/*******************************************************************************

    Moving average designed to handle irregularly spaced data, i.e. data where
    the time intervals between successive values are not the same.

    Template_Params:
        Time = type used to indicate the observation time of individual
               data values; may be any type implicitly convertible to
               time_t, or any integral or floating point value
        Value = floating-point type used to indicate data values

    The double-exponential moving average implemented here is derived from
    section 3 (eqs. 16-22) of Cipra, T. (2006) 'Exponential smoothing for
    irregular data', Applications of Mathematics 51 (6): 597-604
    <http://dml.cz/handle/10338.dmlcz/134655>.

    Most of the parameter names are derived from their counterparts in the
    aforementioned article.

*******************************************************************************/

public struct IrregularMovingAverage (Time = time_t, Value = real)
{
    static assert(is(Time : time_t)
                  || isIntegerType!(Time)
                  || isFloatingPointType!(Time));

    static assert(isFloatingPointType!(Value));


    /***************************************************************************

        Internal helper alias

    ***************************************************************************/

    private alias typeof(*this) This;


    /***************************************************************************

        Time this moving average was last updated

    ***************************************************************************/

    private Time update_time_;


    /***************************************************************************

        Discount coefficient that determines how much weight will be given to
        new data values.  Must be in the range 0 < beta < 1 (note the strict
        inequality).

    ***************************************************************************/

    private Value beta_;


    /***************************************************************************

        Time-dependent smoothing coefficient

    ***************************************************************************/

    private Value alpha;


    /***************************************************************************

        Auxiliary values used to help calculate the moving average

    ***************************************************************************/

    private Value w;
    /// ditto
    private Value z;


    /***************************************************************************

        Single- and double-exponential smoothing statistics

    ***************************************************************************/

    private Value s;
    /// ditto
    private Value s2;


    /***************************************************************************

        (In)sanity checks on internal data

    ***************************************************************************/

    invariant ()
    {
        assert(!isNaN(this.beta_));
        assert(!isInfinity(this.beta_));
        assert(0 < this.beta_);
        assert(this.beta_ < 1);

        assert(!isNaN(this.alpha));
        assert(!isInfinity(this.alpha));
        assert(0 <= this.alpha);
        assert(this.alpha <= 1);

        assert(!isNaN(this.w));
        assert(!isInfinity(this.w));

        assert(!isNaN(this.z));
        assert(!isInfinity(this.z));

        assert(!isNaN(this.s));
        assert(!isInfinity(this.s));

        assert(!isNaN(this.s2));
        assert(!isInfinity(this.s2));

        static if (isFloatingPointType!(Time))
        {
            assert(!isNaN(this.update_time_));
            assert(!isInfinity(this.update_time_));
        }
    }



    /***************************************************************************

        "Constructor"-style static opCall

        Params:
            beta = discount coefficient that determines how much contribution
                   new values make to the average (must have 0 < beta < 1)
            expected_time_interval = expected average time interval between
                                     successive data points (must be > 0)
            first_value = initial value of the quantity being averaged
            first_value_time = observation time of the value provided

        Returns:
            IrregularMovingAverage instance based on the single provided
            data point

    ***************************************************************************/

    public static This opCall (Value beta, Time expected_time_interval,
                               Value first_value, Time first_value_time)
    in
    {
        assert(!isNaN(beta));
        assert(!isInfinity(beta));
        assert(0.0 < beta);
        assert(beta < 1.0);

        assert(!isNaN(first_value));
        assert(!isInfinity(first_value));

        static if (isFloatingPointType!(Time))
        {
            assert(!isNaN(expected_time_interval));
            assert(!isInfinity(expected_time_interval));

            assert(!isNaN(first_value_time));
            assert(!isInfinity(first_value_time));
        }

        assert(expected_time_interval > 0);
    }
    out (ima)
    {
        assert(&ima); // confirm the invariant holds
    }
    body
    {
        // cast to real is necessary to satisfy 'pow' overrides
        Value beta_pow = pow(beta, cast(real) expected_time_interval);
        Value alpha_start = 1.0 - beta_pow;
        Value wz_start =
            (alpha_start * alpha_start) / (expected_time_interval * beta_pow);

        This ima =
        {
            update_time_: first_value_time,
            beta_: beta,
            alpha: alpha_start,
            w: wz_start,
            z: wz_start,
            s: first_value,
            s2: first_value
        };

        return ima;
    }


    /***************************************************************************

        Generates an updated moving average with a new data point, using the
        specified discount coefficient.  The new moving average is returned
        as a new struct instance, rather than mutating the internal struct
        data.

        Params:
            value = new data value to include in the average
            value_time = observation time of the value provided

    ***************************************************************************/

    public void update (Value value, Time value_time)
    in
    {
        assert(!isNaN(value));
        assert(!isInfinity(value));

        static if (isFloatingPointType!(Time))
        {
            assert(!isNaN(value_time));
            assert(!isInfinity(value_time));
        }
    }
    body
    {
        enforce(value_time > this.update_time,
                "Cannot incorporate data point from the past!");

        // values re-used multiple times updating parameters
        Value time_diff = value_time - this.update_time;
        Value beta_pow  = pow(this.beta, time_diff);

        this.update_time_ = value_time;

        // update w based using old alpha value
        this.w = this.w /
            (beta_pow + (time_diff * beta_pow * this.w / this.alpha));

        this.alpha = this.alpha / (beta_pow + this.alpha);

        // update z using new alpha and w values
        this.z = this.z /
            (beta_pow + (this.alpha * this.z / this.w));

        // update s using new alpha value
        this.s  = (this.alpha * value)  + ((1.0 - this.alpha) * this.s);

        // update s2 using new alpha and new s value
        this.s2 = (this.alpha * this.s) + ((1.0 - this.alpha) * this.s2);
    }


    /***************************************************************************

        Returns:
            the current double-exponentially-smoothed moving average

    ***************************************************************************/

    public Value value ()
    {
        return this.s2;
    }


    /***************************************************************************

        Calculates the predicted future value of the moving average

        Params:
            t = time for which to calculate the predicted value; must be
                greater than or equal to the update time of the average
                (if not provided, current time will be used)

        Returns:
            the predicted value of the averaged quantity at time t

        Throws:
            exception if t is less than the update time of the average

    ***************************************************************************/

    public Value predicted_value (Time t)
    out (estimate)
    {
        assert(!isNaN(estimate));
        assert(!isInfinity(estimate));
    }
    body
    {
        enforce(t >= this.update_time_,
                "Cannot calculate predicted value from the past!");

        Time k = t - this.update_time;

        assert(k >= 0);

        Value estimate = this.s +
            ( ((this.z / this.w) + ((this.z / this.alpha) * k)) * (this.s - this.s2) );

        return estimate;
    }


    /***************************************************************************

        Returns:
            most recent update time of the moving average (i.e. the time
            of the last data point included)

    ***************************************************************************/

    public Time update_time ()
    {
        return this.update_time_;
    }


    /***************************************************************************

        Private setter for update_time, used internally only

        Params:
            t = new update time to set; must be greater than existing value

        Returns:
            the newly-set update time value (i.e. t)

    ***************************************************************************/

    private Time update_time (Time t)
    in
    {
        static if (isFloatingPointType!(Time))
        {
            assert(!isNaN(value_time));
            assert(!isInfinity(value_time));
        }

        assert(t > this.update_time_);
    }
    body
    {
        return this.update_time_ = t;
    }


    /***************************************************************************

        Returns:
            currently-set discount coefficient beta for this moving average

    ***************************************************************************/

    public Value beta ()
    {
        return this.beta_;
    }


    /***************************************************************************

        Set the discount coefficient for this moving average.  It may be
        useful to adjust this value if, for example, the average waiting
        time between data points turns out to be very different from
        initial expectations.

        Params:
            b = new value to set for the discount coefficient beta; must
                have 0 < b < 1.

        Returns:
            newly-set discount coefficient beta for this moving average
            (i.e. b).

    ***************************************************************************/

    public Value beta (Value b)
    in
    {
        assert(!isNaN(b));
        assert(!isInfinity(b));
        assert(0 < b);
        assert(b < 1);
    }
    body
    {
        return this.beta_ = b;
    }
}

unittest
{
    // --- basic initialization tests ---

    real val0  = 23.5;
    time_t t0 = 123456;

    auto avg0 = IrregularMovingAverage!()(0.5, 60, val0, t0);

    assert(avg0.value is val0);
    assert(avg0.update_time == t0);

    /* Without multiple statistics, cannot make
     * predictions about the future
     */
    assert(avg0.predicted_value(t0) == val0);
    assert(avg0.predicted_value(time(null)) == val0);
    assert(avg0.predicted_value(123456789) == val0);


    // --- test updates where discount coefficient is altered ---

    real val1 = 36.5;
    time_t t1 = 123459;

    /* Create a copy and update with an
     * increased discount coefficient
     */
    auto avg1a = avg0;
    avg1a.beta = 0.9;
    avg1a.update(val1, t1);

    // larger data second value ==> increase in the average
    assert(avg1a.update_time == t1);
    assert(avg1a.value > val0);
    assert(avg1a.value < val1);

    time_t t_future = 1234560;

    /* Predicted value for update time should
     * be equal to the observed value, but note
     * that precise equality here is extremely
     * unlikely due to floating point arithmetic.
     * For this reason, these tests are disabled
     * until we identify a nice "approximately
     * equal" method to use.
     */
    //assert(avg1a.predicted_value(t1) is val1);
    //assert(avg1a.predicted_value(avg1a.update_time) is val1);

    // should now have an increasing trend
    assert(avg1a.predicted_value(t_future) > avg1a.value);
    assert(avg1a.predicted_value(t_future) > avg1a.predicted_value(t1));

    /* Now we create another copy of avg0 and update
     * with a _decreased_ discount coefficient, but
     * the same second data point as avg1a
     */
    auto avg1b = avg0;
    avg1b.beta = 0.1;
    avg1b.update(val1, t1);

    // larger second data value ==> increase in the average
    assert(avg1b.update_time == t1);
    assert(avg1b.value > val0);
    assert(avg1b.value < val1);

    /* Predicted value for update time should
     * be equal to the observed value, but note
     * that precise equality here is extremely
     * unlikely due to floating point arithmetic.
     * For this reason, these tests are disabled
     * until we identify a nice "approximately
     * equal" method to use.
     */
    //assert(avg1b.predicted_value(t1) is val1);
    //assert(avg1b.predicted_value(avg1b.update_time) is val1);

    // should now have an increasing trend
    assert(avg1b.predicted_value(t_future) > avg1b.value);
    assert(avg1b.predicted_value(t_future) > avg1b.predicted_value(t1));

    /* greater weight to newer records should
     * make for larger values
     */
    assert(avg1b.value > avg1a.value);


    // --- test updates where discount coefficient is not altered ---

    real val2 = 19.5;
    time_t t2 = t1;

    /* Create a copy of avg0 and update with
     * a new (smaller-valued) data point
     */
    auto avg2a = avg0;
    avg2a.update(val2, t2);

    // smaller second value ==> decrease in the average
    assert(avg2a.update_time == t2);
    assert(avg2a.value < val0);
    assert(avg2a.value > val2);

    // should now have an decreasing trend
    assert(avg2a.predicted_value(t_future) < avg2a.value);
    assert(avg2a.predicted_value(t_future) < avg2a.predicted_value(t2));

    /* should get identical results if we repeat
     * the same moving-average update
     */
    auto avg2b = avg0;
    avg2b.update(val2, t2);
    assert(avg2a == avg2b);
}
