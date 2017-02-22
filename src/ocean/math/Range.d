/*******************************************************************************

    Simple integer range struct with various comparison functions.

    Note that the range template currently only supports unsigned integer types.
    It would be possible to extend it to also work with signed and/or floating
    point types.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.math.Range;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

version ( UnitTest )
{
    import ocean.text.convert.Formatter;
    import ocean.core.Test;
}



/*******************************************************************************

    Range struct template

*******************************************************************************/

public struct Range ( T )
{
    import ocean.core.Traits : isUnsignedIntegerType;
    import ocean.core.Array;

    static assert(isUnsignedIntegerType!(T),
        "Range only works with unsigned integer types");

    import ocean.core.Enforce : enforce;

    /***************************************************************************

        The `This` alias for the type of this struct

    ***************************************************************************/

    import ocean.transition: TypeofThis, assumeUnique;
    mixin TypeofThis!();

    /***************************************************************************

        Min & max values when range is empty (magic values).

    ***************************************************************************/

    private const T null_min = T.max;
    private const T null_max = T.min;


    /***************************************************************************

        Min & max values, default to the empty range.

    ***************************************************************************/

    private T min_ = null_min;
    private T max_ = null_max;


    /***************************************************************************

        Helper structure for sortEndpoints function.  This is used to provide
        detailed information about the relative positions of endpoints in a
        sequence of ranges.

    ***************************************************************************/

    private static struct RangeEndpoint
    {
        /***********************************************************************

            Value of the endpoint: may be either min or max of the underlying
            range.

        ***********************************************************************/

        T value;

        /***********************************************************************

            Index of the owner range in the sequence of range arguments
            provided to sortEndpoints.

        ***********************************************************************/

        ubyte owner_index;

        version ( UnitTest )
        {
            // useful for test!("==")
            public istring toString ()
            {
                return format("<{}|{}>", this.value, cast(char)('A' + this.owner_index));
            }
        }
    }


    /***************************************************************************

        Checks whether the specified range is empty.

        Params:
            min = minimum value
            max = maximum value

        Returns:
            true if the range is empty (null)

    ***************************************************************************/

    static public bool isEmpty ( T min, T max )
    {
        return min == null_min && max == null_max;
    }

    unittest
    {
        test(This.isEmpty(null_min, null_max));
        test(!This.isEmpty(null_max, null_min));
        test(!This.isEmpty(1, null_max));
        test(!This.isEmpty(null_min, 1));
        test(!This.isEmpty(1, 1));
        test(!This.isEmpty(1, 2));
        test(!This.isEmpty(2, 1));
    }


    /***************************************************************************

        Checks whether the specified range is the full range of T.

        Params:
            min = minimum value
            max = maximum value

        Returns:
            true if the range is full, i.e. min == T.min and max == T.max.

    ***************************************************************************/

    static public bool isFullRange ( T min, T max )
    {
        return min == T.min && max == T.max;
    }

    unittest
    {
        test(This.isFullRange(T.min, T.max));
        test(!This.isFullRange(T.max, T.min));
        test(!This.isFullRange(1, T.max));
        test(!This.isFullRange(T.min, 1));
        test(!This.isFullRange(1, 1));
        test(!This.isFullRange(1, 2));
        test(!This.isFullRange(2, 1));
    }


    /***************************************************************************

        Checks whether the specified range is valid.

        Params:
            min = minimum value
            max = maximum value

        Returns:
            true if the range is valid (min <= max or empty)

    ***************************************************************************/

    static public bool isValid ( T min, T max )
    {
        return min <= max || This.isEmpty(min, max);
    }

    unittest
    {
        test(This.isValid(null_min, null_max));
        test(This.isValid(0, 0));
        test(This.isValid(0, 1));
        test(This.isValid(T.max, T.max));
        test(!This.isValid(1, 0));
    }


    /***************************************************************************

        The range must always be valid.

    ***************************************************************************/

    invariant()
    {
        assert(This.isValid(this.min_, this.max_));
    }

    version ( UnitTest )
    {
        public istring toString()
        {
            auto msg = format("{}({}, {}", This.stringof, this.min_, this.max_);

            if (this.is_empty)
            {
                msg ~= " empty";
            }
            else if (this.is_full_range)
            {
                msg ~= " full";
            }

            msg ~= ')';

            return assumeUnique(msg);
        }
    }


    /***************************************************************************

        Static opCall. Disables the default "constructor", with the advantage
        that the invariant is run after calling this method, making it
        impossible to construct invalid instances.

        Params:
            min = minimum value of range
            max = maximum value of range

        Returns:
            new Range instance

        Throws:
            if min and max do not describe a valid range (see isValid)

    ***************************************************************************/

    public static This opCall ( T min, T max )
    out(result)
    {
        assert(&result);
    }
    body
    {
        enforce(This.isValid(min, max));

        This r;
        r.min_ = min;
        r.max_ = max;
        return r;
    }


    /***************************************************************************

        Range factory which provides extended wrapper to opCall. It returns
        empty range when min > max or when it is impossible to respect
        the specified boundaries.

        Template_Params:
            boundaries = string which denotes which kind of boundaries
                         will be provided. Square "[" bracket denotes inclusive
                         boundary, round "$(LPAREN)" one denotes exclusive boundary

        Params:
            min = minimum value of range
            max = maximum value of range

        Returns:
            new Range instance

    ***************************************************************************/

    public static This makeRange ( istring boundaries = "[]" ) ( T min, T max )
    out(result)
    {
        assert(&result);
    }
    body
    {
        static assert(boundaries == "[]" || boundaries == "[)"
                      || boundaries == "(]" || boundaries == "()",
                      "only four kinds of range are supported: [], [), (], ()");

        if ( min > max )
            return This.init;

        static if (boundaries != "[]")
        {
            if (min == max)
            {
                return This.init;
            }
        }

        static if (boundaries == "()")
        {
            if (min + 1 == max)
            {
                return This.init;
            }
        }

        static if (boundaries[0] == '(')
        {
            assert(min < T.max);
            ++min;
        }

        static if (boundaries[1] == ')')
        {
            assert(max > T.min);
            --max;
        }

        assert(min <= max);

        return This(min, max);
    }

    unittest
    {
        test!("==")(This(3, 7), This.makeRange!("[]")(3, 7));
        test!("==")(This(3, 7), This.makeRange(3, 7));
        test!("==")(This(5, 5), This.makeRange(5, 5));
        test!("==")(This.init, This.makeRange(7, 3));
        test!("==")(This(0, 0), This.makeRange(0, 0));
        test!("==")(This(T.max, T.max), This.makeRange(T.max, T.max));
        test!("==")(This(0, T.max), This.makeRange(0, T.max));
        test!("==")(This.init, This.makeRange(T.max, 0));

        test!("==")(This(3, 6), This.makeRange!("[)")(3, 7));
        test!("==")(This.init, This.makeRange!("[)")(5, 5));
        test!("==")(This(4, 4), This.makeRange!("[)")(4, 5));
        test!("==")(This.init, This.makeRange!("[)")(7, 3));
        test!("==")(This.init, This.makeRange!("[)")(0, 0));
        test!("==")(This.init, This.makeRange!("[)")(T.max, T.max));
        test!("==")(This(0, T.max - 1), This.makeRange!("[)")(0, T.max));
        test!("==")(This.init, This.makeRange!("[)")(T.max, 0));
        test!("==")(This(0, 0), This.makeRange!("[)")(0, 1));
        test!("==")(This(T.max - 1, T.max - 1), This.makeRange!("[)")(T.max - 1, T.max));

        test!("==")(This(4, 7), This.makeRange!("(]")(3, 7));
        test!("==")(This.init, This.makeRange!("(]")(5, 5));
        test!("==")(This(5, 5), This.makeRange!("(]")(4, 5));
        test!("==")(This.init, This.makeRange!("(]")(7, 3));
        test!("==")(This.init, This.makeRange!("(]")(0, 0));
        test!("==")(This.init, This.makeRange!("(]")(T.max, T.max));
        test!("==")(This(1, T.max), This.makeRange!("(]")(0, T.max));
        test!("==")(This.init, This.makeRange!("(]")(T.max, 0));
        test!("==")(This(1, 1), This.makeRange!("(]")(0, 1));
        test!("==")(This(T.max, T.max), This.makeRange!("(]")(T.max - 1, T.max));

        test!("==")(This(4, 6), This.makeRange!("()")(3, 7));
        test!("==")(This.init, This.makeRange!("()")(5, 5));
        test!("==")(This.init, This.makeRange!("()")(4, 5));
        test!("==")(This(5, 5), This.makeRange!("()")(4, 6));
        test!("==")(This.init, This.makeRange!("()")(7, 3));
        test!("==")(This.init, This.makeRange!("()")(0, 0));
        test!("==")(This.init, This.makeRange!("()")(T.max, T.max));
        test!("==")(This(1, T.max - 1), This.makeRange!("()")(0, T.max));
        test!("==")(This.init, This.makeRange!("()")(T.max, 0));
        test!("==")(This.init, This.makeRange!("()")(0, 1));
        test!("==")(This.init, This.makeRange!("()")(T.max - 1, T.max));
        test!("==")(This(1, 1), This.makeRange!("()")(0, 2));
        test!("==")(This(T.max - 1, T.max - 1), This.makeRange!("()")(T.max - 2, T.max));
    }


    /***************************************************************************

        Returns:
            the minimum value of the range

    ***************************************************************************/

    public T min ( )
    {
        return this.min_;
    }


    /***************************************************************************

        Returns:
            the maximum value of the range

    ***************************************************************************/

    public T max ( )
    {
        return this.max_;
    }


    /***************************************************************************

        Sets the minimum value of the range.

        Params:
            min = new minimum value

        Returns:
            The newly set value which was given as parameter

    ***************************************************************************/

    public T min ( T min )
    {
        return this.min_ = min;
    }


    /***************************************************************************

        Sets the maximum value of the range.

        Params:
            max = new maximum value

        Returns:
            The newly set value which was given as parameter

    ***************************************************************************/

    public T max ( T max )
    {
        return this.max_ = max;
    }


    /***************************************************************************

        Returns:
            true if the range is empty (null)

    ***************************************************************************/

    public bool is_empty ( )
    {
        return This.isEmpty(this.min_, this.max_);
    }


    /***************************************************************************

        Returns:
            true if this instance covers the full range of hash values

    ***************************************************************************/

    public bool is_full_range ( )
    {
        return This.isFullRange(this.min_, this.max_);
    }


    /***************************************************************************

        Note that in non-release builds, the struct invariant ensures that
        instances are always valid. This method can be called by user code to
        explicitly check the validity of a range, for example when creating a
        range from run-time data.

        Returns:
            true if the range is valid (min < max, or empty)

    ***************************************************************************/

    public bool is_valid ( )
    {
        return This.isValid(this.min_, this.max_);
    }


    /***************************************************************************

        Returns:
            the number of values in the range

        Throws:
            Exception if the full range is covered, i.e. `this.is_full_range` is
            true. (This is to prevent an integer overflow.)

    ***************************************************************************/

    public size_t length ( )
    {
        enforce(!this.is_full_range, This.stringof ~ ".length(): full range");

        if ( this.is_empty ) return 0;

        return (this.max_ - this.min_) + 1;
    }

    unittest
    {
        test!("==")(This.init.length, 0);
        test!("==")(This(0, 0).length, 1);
        test!("==")(This(5, 5).length, 1);
        test!("==")(This(0, 1).length, 2);
        test!("==")(This(5, 10).length, 6);
    }


    /***************************************************************************

        Predicate that checks whether the specified value is inside this range.

        Params:
            x = value to check

        Returns:
            true if this range includes x, false otherwise

    ***************************************************************************/

    public bool contains ( T x )
    {
        if (this.is_empty)
            return false;

        return this.min_ <= x && x <= this.max_;
    }

    unittest
    {
        // empty
        test(!This.init.contains(0), "Empty range can't contain any value");
        test(!This.init.contains(17), "Empty range can't contain any value");
        test(!This.init.contains(T.max), "Empty range can't contain any value");

        // one point
        test(This(0, 0).contains(0), "One point range should contain this point");
        test(This(17, 17).contains(17), "One point range should contain this point");
        test(This(T.max, T.max).contains(T.max), "One point range should contain this point");

        test(!This(0, 0).contains(1), "One point range can't contain other point");
        test(!This(17, 17).contains(16), "One point range can't contain other point");
        test(!This(T.max, T.max).contains(T.max - 1), "One point range can't contain other point");

        // more-point
        test(!This(3, 24).contains(2), "This can't contain outside point");
        test(This(3, 24).contains(3), "This should contain boundary point");
        test(This(3, 24).contains(11), "This should contain inner point");
        test(This(3, 24).contains(24), "This should contain boundary point");
        test(!This(3, 24).contains(25), "This can't contain outside point");
    }


    /***************************************************************************

        Checks whether the specified range is exactly identical to this range.

        Params:
            other = instance to compare this with

        Returns:
            true if both ranges are identical

    ***************************************************************************/

    public equals_t opEquals ( This other )
    {
        return this.min_ == other.min && this.max_ == other.max_;
    }

    unittest
    {
        // empty == empty
        test!("==")(This.init, This.init);

        // empty != a
        test!("!=")(This.init, This(0, 1));

        // a != empty
        test!("!=")(This(0, 1), This.init);

        // a == b
        test!("==")(This(0, 1), This(0, 1));

        // a != b
        test!("!=")(This(0, 1), This(1, 2));
    }

    /***************************************************************************

        Compares this instance with rhs. An empty range is considered to be <
        all non-empty ranges. Otherwise, the comparison always considers the
        range's minimum value before comparing the maximum value.

        Params:
            rhs = instance to compare with this

        Returns:
            a value less than 0 if this < rhs,
            a value greater than 0 if this > rhs
            or 0 if this == rhs.

    ***************************************************************************/

    mixin (genOpCmp(
    `{
        auto _this = cast(Unqual!(typeof(this))) this;
        auto _rhs = cast(Unqual!(typeof(rhs))) rhs;

        if ( _this.is_empty )  return _rhs.is_empty ? 0 : -1;
        if ( _rhs.is_empty ) return 1;

        if ( _this.min_ < _rhs.min_ ) return -1;
        if ( _rhs.min_ < _this.min_ ) return 1;
        assert(_this.min_ == _rhs.min_);
        if ( _this.max_ < _rhs.max_ ) return -1;
        if ( _rhs.max_ < _this.max_ ) return 1;
        return 0;
    }`));

    unittest
    {
        // empty < smallest range
        test!("<")(This.init, This(0, 0));

        // smallest range, empty
        test!(">")(This(0, 0), This.init);

        // a, b
        test!("<")(This(0, 1), This(2, 3));

        // a, b
        test!(">")(This(2, 3), This(0, 1));

        // a, b (overlapping)
        test!("<")(This(0, 1), This(1, 2));

        // a, b (overlapping)
        test!(">")(This(1, 2), This(0, 1));

        // a, b and a.min == b.min
        test!("<")(This(1, 3), This(1, 5));

        // a, b and a.min == b.min
        test!(">")(This(1, 5), This(1, 3));
    }


    /***************************************************************************

        Determines whether this instance is non-empty subset of the specified
        range. All values in this range must be within the other range.

        Note: For practical reasons, this isn't conforming strictly to
        the mathematical definition, where an empty set is considered to be
        a subset of any set. However, two equal ranges will be considered
        to be subsets of one another.

        Params:
            other = instance to compare with this

        Returns:
            true if this range is a subset of the other range

    ***************************************************************************/

    public bool isSubsetOf ( This other )
    {
        if ( this.is_empty || other.is_empty )
            return false;

        return this.min_ >= other.min_ && this.max_ <= other.max_;
    }

    unittest
    {
        // empty
        test(!This.init.isSubsetOf(This(0, 10)), "Empty range doesn't count as subset");
        test(!This(0, 10).isSubsetOf(This.init), "Empty range can't be superset");

        // very proper subset
        test(This(1, 9).isSubsetOf(This(0, 10)));

        // equal
        test(This(0, 10).isSubsetOf(This(0, 10)), "Equal range is a subset too");

        // ends touch, inside
        test(This(0, 9).isSubsetOf(This(0, 10)));
        test(This(1, 10).isSubsetOf(This(0, 10)));

        // ends touch, outside
        test(!This(0, 5).isSubsetOf(This(5, 10)));
        test(!This(10, 15).isSubsetOf(This(5, 10)));

        // very proper superset
        test(!This(0, 10).isSubsetOf(This(1, 9)), "Proper superset can't be subset");

        // overlap
        test(!This(0, 10).isSubsetOf(This(5, 15)));

        // no overlap
        test(!This(5, 10).isSubsetOf(This(15, 20)));
    }

    /***************************************************************************

        Determines whether this instance is a superset of the non-empty
        specified range. All values in the other range must be within this range.

        Note: For practical reasons, this isn't conforming strictly to
        the mathematical definition, where an empty set is considered to be
        a subset of any set. However, two equal ranges will be considered
        to be supersets of one another.

        Params:
            other = instance to compare with this

        Returns:
            true if this range is a superset of the other range

    ***************************************************************************/

    public bool isSupersetOf ( This other )
    {
        return other.isSubsetOf(*this);
    }

    unittest
    {
        // empty
        test(!This.init.isSupersetOf(This(0, 10)), "Empty range can't be superset");
        test(!This(0, 10).isSupersetOf(This.init),  "Empty range doesn't count as subset");

        // very proper superset
        test(This(0, 10).isSupersetOf(This(1, 9)));

        // equal
        test(This(0, 10).isSupersetOf(This(0, 10)), "Equal range is a superset too");

        // ends touch, inside
        test(This(0, 10).isSupersetOf(This(0, 9)));
        test(This(0, 10).isSupersetOf(This(1, 10)));

        // ends touch, outside
        test(!This(5, 10).isSupersetOf(This(0, 5)));
        test(!This(5, 10).isSupersetOf(This(10, 15)));

        // very proper subset
        test(!This(1, 9).isSupersetOf(This(0, 10)), "Proper subset can't be superset");

        // overlap
        test(!This(0, 10).isSupersetOf(This(5, 15)));

        // no overlap
        test(!This(5, 10).isSupersetOf(This(15, 20)));
    }

    /***************************************************************************

        Predicate that checks whether the provided array of ranges exactly
        tessellates this range.  The term "tessellation" means that this
        range is a union of the given ranges and that the given ranges form
        a contiguous chain without gap or overlap.

        It is assumed that the array is already sorted.

        This method can be used as a replacement for the now-deprecated
        opEquals ( This[] )

        Params:
            ranges = a sorted array of This!T

        Returns:
            true if this instance is tessellated by the given array
            of ranges, false otherwise

    ***************************************************************************/

    public bool isTessellatedBy ( This[] ranges )
    {
        return (*this == extent(ranges)) && isContiguous(ranges);
    }

    unittest
    {
        // minimal case: one range, test covers and not-covers
        test(This(0, 0).isTessellatedBy([This(0, 0)]));
        test(!This(0, 0).isTessellatedBy([This(1, 1)]));

        // tessellation by itself
        test(This(3, 12).isTessellatedBy([This(3, 12)]), "Any range should tessellate itself");

        // proper subset or proper superset can't be tessellation
        test(!This(3, 12).isTessellatedBy([This(4, 11)]), "Proper superset can't be tessellation");
        test(!This(3, 12).isTessellatedBy([This(3, 11)]), "Proper superset can't be tessellation");
        test(!This(3, 12).isTessellatedBy([This(4, 12)]), "Proper superset can't be tessellation");
        test(!This(3, 12).isTessellatedBy([This(2, 13)]), "Proper subset can't be tessellation");
        test(!This(3, 12).isTessellatedBy([This(3, 13)]), "Proper subset can't be tessellation");
        test(!This(3, 12).isTessellatedBy([This(2, 12)]), "Proper subset can't be tessellation");

        // complete
        test(This(0, 10).isTessellatedBy([This(0, 1),
                                           This(2, 5),
                                           This(6, 10)]));

        // missing start
        test(!This(0, 10).isTessellatedBy([This(1, 1),
                                            This(2, 5),
                                            This(6, 10)]));

        // missing middle
        test(!This(0, 10).isTessellatedBy([This(0, 1),
                                                  This(3, 5),
                                                  This(6, 10)]));

        // missing end
        test(!This(0, 10).isTessellatedBy([This(0, 1),
                                            This(2, 5),
                                            This(6, 9)]));

        // overlapped ranges in list
        test(!This(0, 10).isTessellatedBy([This(0, 2),
                                            This(2, 5),
                                            This(6, 10)]));

        // empty ranges skipped
        This empty;
        test(This(0, 10).isTessellatedBy([empty,
                                           empty,
                                           This(0, 1),
                                           This(2, 5),
                                           This(6, 10)]));

        // union of empty ranges and empty list
        test(!This(0, 10).isTessellatedBy([empty,
                                            empty,
                                            empty]));
        test(!This(0, 10).isTessellatedBy([empty]));
        test(!This(0, 10).isTessellatedBy([]));
        test(!This(0, 10).isTessellatedBy(null));
    }


    /***************************************************************************

        Predicate that checks whether this range is covered by the given array
        of ranges (i.e. whether it is a subset of the union of the array
        of ranges).

        It is assumed that the array is already sorted.

        Params:
            ranges = a sorted array of This!T to be checked
                     that covers this instance

        Returns:
            true if this range instance is covered by the given array of ranges,
            false otherwise

    ***************************************************************************/

    public bool isCoveredBy ( This[] ranges )
    {
        return this.isSubsetOf(extent(ranges)) && !hasGap(ranges);
    }

    unittest
    {
        // minimal case: one hash range, test covers and not-covers
        test(This(0, 0).isCoveredBy([This(0, 0)]));
        test(!This(0, 0).isCoveredBy([This(1, 1)]));

        // coverage by itself
        test(This(3, 12).isCoveredBy([This(3, 12)]), "Any range should cover itself");

        // any superset can be coverage
        test(This(3, 12).isCoveredBy([This(3, 13)]), "Proper superset should be coverage");
        test(This(3, 12).isCoveredBy([This(2, 12)]), "Proper superset should be coverage");
        test(This(3, 12).isCoveredBy([This(2, 13)]), "Proper superset should be coverage");

        // any subset can't be coverage
        test(!This(3, 12).isCoveredBy([This(3, 11)]), "Proper subset can't be coverage");
        test(!This(3, 12).isCoveredBy([This(4, 12)]), "Proper subset can't be coverage");
        test(!This(3, 12).isCoveredBy([This(4, 11)]), "Proper subset can't be coverage");

        // a tessellation is a coverage
        test(This(3, 12).isCoveredBy([This(3, 5), This(6, 12)]));

        // overlap allowed
        test(This(3, 12).isCoveredBy([This(3, 7), This(4, 12)]));
        test(This(3, 12).isCoveredBy([This(1, 7), This(4, 15)]));

        // gap not allowed
        test(!This(3, 12).isCoveredBy([This(3, 5), This(7, 12)]));
        test(!This(3, 12).isCoveredBy([This(1, 5), This(7, 15)]));

        // empty ranges skipped
        This empty;
        test(This(0, 10).isCoveredBy([empty,
                                       empty,
                                       This(0, 3),
                                       This(2, 5),
                                       This(6, 11)]));

        // union of empty ranges and empty list
        test(!This(0, 10).isCoveredBy([empty,
                                        empty,
                                        empty]));
        test(!This(0, 10).isCoveredBy([empty]));
        test(!This(0, 10).isCoveredBy([]));
        test(!This(0, 10).isCoveredBy(null));
    }


    /***************************************************************************

        Special unittest which checks that isTessellatedBy implies isCoveredBy
        (but isCoveredBy does not necessarily imply isTessellatedBy).

    ***************************************************************************/

    unittest
    {
        // Note that given two logical conditions A and B,
        // "A implies B" is equivalent to (A == true) <= (B == true)

        auto target = This(12, 17);
        This[] ranges;

        // neither tessellated nor covered
        test!("<=")(target.isTessellatedBy(ranges), target.isCoveredBy(ranges));

        ranges ~= [This(1, 5)];
        test!("<=")(target.isTessellatedBy(ranges), target.isCoveredBy(ranges));
        ranges.length = 0;
        enableStomping(ranges);

        ranges ~= [This(12, 15)];
        test!("<=")(target.isTessellatedBy(ranges), target.isCoveredBy(ranges));
        ranges.length = 0;
        enableStomping(ranges);

        ranges ~= [This(14, 17)];
        test!("<=")(target.isTessellatedBy(ranges), target.isCoveredBy(ranges));
        ranges.length = 0;
        enableStomping(ranges);

        ranges ~= [This(18, 25)];
        test!("<=")(target.isTessellatedBy(ranges), target.isCoveredBy(ranges));
        ranges.length = 0;
        enableStomping(ranges);

        ranges ~= [This(1, 5), This(19, 20)];
        test!("<=")(target.isTessellatedBy(ranges), target.isCoveredBy(ranges));
        ranges.length = 0;
        enableStomping(ranges);

        ranges ~= [This(1, 13), This(16, 20)];
        test!("<=")(target.isTessellatedBy(ranges), target.isCoveredBy(ranges));
        ranges.length = 0;
        enableStomping(ranges);

        test!("<=")(target.isTessellatedBy(ranges), target.isCoveredBy(ranges));

        // covered, but not tessellated
        ranges ~= [This(11, 17)];
        test!("<=")(target.isTessellatedBy(ranges), target.isCoveredBy(ranges));
        ranges.length = 0;
        enableStomping(ranges);

        ranges ~= [This(12, 18)];
        test!("<=")(target.isTessellatedBy(ranges), target.isCoveredBy(ranges));
        ranges.length = 0;
        enableStomping(ranges);

        ranges ~= [This(11, 18)];
        test!("<=")(target.isTessellatedBy(ranges), target.isCoveredBy(ranges));
        ranges.length = 0;
        enableStomping(ranges);

        ranges ~= [This(1, 15), This(14, 20)];
        test!("<=")(target.isTessellatedBy(ranges), target.isCoveredBy(ranges));
        ranges.length = 0;
        enableStomping(ranges);

        ranges ~= [This(12, 15), This(15, 17)];
        test!("<=")(target.isTessellatedBy(ranges), target.isCoveredBy(ranges));
        ranges.length = 0;
        enableStomping(ranges);

        ranges ~= [This(12, 16), This(14, 17)];
        test!("<=")(target.isTessellatedBy(ranges), target.isCoveredBy(ranges));
        ranges.length = 0;
        enableStomping(ranges);

        // tessellated
        ranges ~= [This(12, 17)];
        test!("<=")(target.isTessellatedBy(ranges), target.isCoveredBy(ranges));
        ranges.length = 0;
        enableStomping(ranges);

        ranges ~= [This(12, 14), This(15, 17)];
        test!("<=")(target.isTessellatedBy(ranges), target.isCoveredBy(ranges));
        ranges.length = 0;
        enableStomping(ranges);
    }


    /***************************************************************************

        Calculates the number of values shared by this range and the other range
        specified.

        Params:
            other = instance to compare with this

        Returns:
            the number of values shared by the two ranges

        Throws:
            Exception if both this instance and other cover the full range, i.e.
            `this.is_full_range && other.full_range` is true. (This is to
            prevent an integer overflow.)

    ***************************************************************************/

    public size_t overlapAmount ( Range other )
    {
        enforce(!(this.is_full_range && other.is_full_range),
                 This.stringof ~ ".overlapAmount(): both ranges are full");

        if ( this.is_empty || other.is_empty ) return 0;

        RangeEndpoint[4] a;
        This.sortEndpoints(*this, other, a);

        return a[0].owner_index != a[1].owner_index
               ? This(a[1].value, a[2].value).length : 0;
    }

    unittest
    {
        // empty
        test!("==")(This.init.overlapAmount(This.init), 0);
        test!("==")(This.init.overlapAmount(This(0, 10)), 0);
        test!("==")(This(0, 10).overlapAmount(This.init), 0);

        // empty vs. full
        test!("==")(This(T.min, T.max).overlapAmount(This.init), 0);
        test!("==")(This.init.overlapAmount(This(T.min, T.max)), 0);

        // full
        testThrown!()(Range(T.min, T.max).overlapAmount(Range(T.min, T.max)));

        // equal
        test!("==")(This(0, 10).overlapAmount(This(0, 10)), 11);

        // proper subset
        test!("==")(This(0, 10).overlapAmount(This(1, 9)), 9);

        // proper superset
        test!("==")(This(1, 9).overlapAmount(This(0, 10)), 9);

        // proper superset of the full range
        test!("==")(This(1, 10).overlapAmount(This(T.min, T.max)), 10);
        test!("==")(This(T.min, T.max).overlapAmount(This(1, 10)), 10);

        // ends touch
        test!("==")(This(0, 10).overlapAmount(This(10, 20)), 1);
        test!("==")(This(10, 20).overlapAmount(This(0, 10)), 1);

        // subset + ends touch
        test!("==")(This(0, 10).overlapAmount(This(0, 9)), 10);
        test!("==")(This(0, 10).overlapAmount(This(1, 10)), 10);

        // superset + ends touch
        test!("==")(This(0, 9).overlapAmount(This(0, 10)), 10);
        test!("==")(This(1, 10).overlapAmount(This(0, 10)), 10);

        // overlaps
        test!("==")(This(0, 10).overlapAmount(This(9, 20)), 2);
        test!("==")(This(10, 20).overlapAmount(This(0, 11)), 2);

        // no overlap
        test!("==")(This(0, 10).overlapAmount(This(11, 20)), 0);
        test!("==")(This(10, 20).overlapAmount(This(0, 9)), 0);
    }


    /***************************************************************************

        Checks whether this range shares any values with the other range
        specified.

        Params:
            other = instance to compare with this

        Returns:
            true if the two ranges share any values

    ***************************************************************************/

    public bool overlaps ( This other )
    {
        if ( this.is_empty || other.is_empty ) return false;

        return !(other.max_ < this.min_ || other.min > this.max_);
    }

    unittest
    {
        // empty
        test(!This.init.overlaps(This.init));
        test(!This.init.overlaps(This(0, 10)));
        test(!This(0, 10).overlaps(This.init));

        // equal
        test(This(0, 10).overlaps(This(0, 10)));

        // proper subset
        test(This(0, 10).overlaps(This(1, 9)));

        // proper superset
        test(This(1, 9).overlaps(This(0, 10)));

        // ends touch
        test(This(0, 10).overlaps(This(10, 20)));
        test(This(10, 20).overlaps(This(0, 10)));

        // subset + ends touch
        test(This(0, 10).overlaps(This(0, 9)));
        test(This(0, 10).overlaps(This(1, 10)));

        // superset + ends touch
        test(This(0, 9).overlaps(This(0, 10)));
        test(This(1, 10).overlaps(This(0, 10)));

        // overlaps
        test(This(0, 10).overlaps(This(9, 20)));
        test(This(10, 20).overlaps(This(0, 11)));

        // no overlap
        test(!This(0, 10).overlaps(This(11, 20)));
        test(!This(10, 20).overlaps(This(0, 9)));
    }


    /***************************************************************************

        Subtracts the specified range from this range, returning the remaining
        range(s) via the out parameters. Two separate ranges can result from a
        subtraction if the range being subtracted bisects the range being
        subtracted from, like:

            subtract        ------
            from        --------------
            remainder   ----      ----

        Params:
            other = range to subtract from this
            lower = lower output range. If only a single range results from the
                subtraction, it will be returned via this parameter
            upper = upper output range. Only set when the subtraction results in
                two ranges

    ***************************************************************************/

    public void subtract ( This other, out This lower, out This upper )
    {
        // this empty -- empty result
        if ( this.is_empty ) return;

        // other empty -- no change
        if ( other.is_empty )
        {
            lower = *this;
            return;
        }

        RangeEndpoint[4] a;
        This.sortEndpoints(*this, other, a);

        // no overlap
        if (a[0].owner_index == a[1].owner_index)
        {
            lower = *this;
            return;
        }

        auto first = a[0].owner_index < a[1].owner_index
                     ? This.makeRange!("[)")(a[0].value, a[1].value) : This.init;
        auto second = a[2].owner_index > a[3].owner_index
                      ? This.makeRange!("(]")(a[2].value, a[3].value) : This.init;

        if (first.is_empty)
        {
            lower = second;
        }
        else
        {
            lower = first;
            upper = second;
        }
    }

    unittest
    {
        static void testSubtract ( This r1, This r2,
                                   This l_expected, This u_expected = This.init,
                                   istring file = __FILE__, int line = __LINE__ )
        {
            This l, u;
            r1.subtract(r2, l, u);
            test!("==")(l, l_expected, file, line);
            test!("==")(u, u_expected, file, line);
        }

        // empty
        testSubtract(This.init, This.init, This.init);
        testSubtract(This.init, This(0, 0), This.init);
        testSubtract(This(0, 0), This.init, This(0, 0));

        // equal
        testSubtract(This(0, 0), This(0, 0), This.init);
        testSubtract(This(T.max, T.max), This(T.max, T.max), This.init);
        testSubtract(This(0, 10), This(0, 10), This.init);
        testSubtract(This(0, T.max), This(0, T.max), This.init);

        // superset
        testSubtract(This(1, 9), This(0, 10), This.init);

        // subset
        testSubtract(This(0, 10), This(1, 9), This(0, 0), This(10, 10));
        testSubtract(This(0, 10), This(5, 5), This(0, 4), This(6, 10));

        // no overlap
        testSubtract(This(0, 10), This (11, 20), This(0, 10));
        testSubtract(This(11, 20), This (0, 10), This(11, 20));

        // ends touch
        testSubtract(This(10, 20), This(0, 10), This(11, 20));
        testSubtract(This(10, 20), This(20, 30), This(10, 19));

        // overlap
        testSubtract(This(5, 15), This(0, 10), This(11, 15));
        testSubtract(This(5, 15), This(5, 10), This(11, 15));
        testSubtract(This(5, 15), This(10, 20), This(5, 9));
        testSubtract(This(5, 15), This(10, 15), This(5, 9));
    }


    /***************************************************************************

        Helper function used by overlapAmount and subtract.  Calculates a
        specially sorted static array of RangeEndpoint values corresponding
        to the endpoints of the two non-empty ranges 'first' and 'second'
        provided as input.  The sorting is stable (i.e. initial order of
        equal values is preserved).

        The owner_index values of the RangeEndpoints correspond to the first
        and second parameters, so e.g. if a given endpoint comes from the
        first range, its owner_index will be 0; if from the second, it will
        be 1.

        Note: the sort will preserve the order {second.min, first.max} if
        their values are equal.

        Note: In D2 it may be better to rewrite this function to:
                    RangeEndpoint[4] sortEndpoints ( This first, This second )

        Params:
            first = the first of the two Ranges
            second = the second of the two Ranges
            array = (preferably static) array of 4 RangeEndpoints,
                    which will be filled with the sorted endpoints
                    of the first and second ranges

    ***************************************************************************/

    private static void sortEndpoints ( This first, This second,
                                        RangeEndpoint[] array )
    in
    {
        assert(!first.is_empty);
        assert(!second.is_empty);
        assert(array.length == 4);
    }
    body
    {
        // N.B!  the initial order is sufficient
        // being that stable sort preserve order of equal elements
        array[0] = RangeEndpoint(first.min_, 0);
        array[1] = RangeEndpoint(second.min_, 1);
        array[2] = RangeEndpoint(first.max_, 0);
        array[3] = RangeEndpoint(second.max_, 1);

        // stable insert sort
        for (size_t i = 1; i < array.length; ++i)
        {
            auto pivot_index = i;
            auto pivot = array[pivot_index];
            while (pivot_index > 0  && array[pivot_index - 1].value > pivot.value)
            {
                array[pivot_index] = array[pivot_index - 1];
                --pivot_index;
            }
            array[pivot_index] = pivot;
        }
    }

    unittest
    {
        RangeEndpoint[] a;
        a.length = 4;

        // no overlap
        This.sortEndpoints(This(0, 10), This(15, 20), a);
        test!("==")(a, [RangeEndpoint(0, 0), RangeEndpoint(10, 0),
                        RangeEndpoint(15, 1), RangeEndpoint(20, 1)][]);
        This.sortEndpoints(This(15, 20), This(0, 10), a);
        test!("==")(a, [RangeEndpoint(0, 1), RangeEndpoint(10, 1),
                        RangeEndpoint(15, 0), RangeEndpoint(20, 0)][]);

        // overlap
        This.sortEndpoints(This(0, 15), This(10, 20), a);
        test!("==")(a, [RangeEndpoint(0, 0), RangeEndpoint(10, 1),
                        RangeEndpoint(15, 0), RangeEndpoint(20, 1)][]);
        This.sortEndpoints(This(10, 20), This(0, 15), a);
        test!("==")(a, [RangeEndpoint(0, 1), RangeEndpoint(10, 0),
                        RangeEndpoint(15, 1), RangeEndpoint(20, 0)][]);

        // outer touch
        This.sortEndpoints(This(0, 10), This(10, 20), a);
        test!("==")(a, [RangeEndpoint(0, 0), RangeEndpoint(10, 1),
                        RangeEndpoint(10, 0), RangeEndpoint(20, 1)][]);
        This.sortEndpoints(This(10, 20), This(0, 10), a);
        test!("==")(a, [RangeEndpoint(0, 1), RangeEndpoint(10, 0),
                        RangeEndpoint(10, 1), RangeEndpoint(20, 0)][]);

        // inner touch
        This.sortEndpoints(This(0, 10), This(5, 10), a);
        test!("==")(a, [RangeEndpoint(0, 0), RangeEndpoint(5, 1),
                        RangeEndpoint(10, 0), RangeEndpoint(10, 1)][]);
        This.sortEndpoints(This(5, 10), This(0, 10), a);
        test!("==")(a, [RangeEndpoint(0, 1), RangeEndpoint(5, 0),
                        RangeEndpoint(10, 0), RangeEndpoint(10, 1)][]);
        This.sortEndpoints(This(0, 10), This(0, 5), a);
        test!("==")(a, [RangeEndpoint(0, 0), RangeEndpoint(0, 1),
                        RangeEndpoint(5, 1), RangeEndpoint(10, 0)][]);
        This.sortEndpoints(This(0, 5), This(0, 10), a);
        test!("==")(a, [RangeEndpoint(0, 0), RangeEndpoint(0, 1),
                        RangeEndpoint(5, 0), RangeEndpoint(10, 1)][]);

        // ultra proper subrange
        This.sortEndpoints(This(0, 10), This(3, 7), a);
        test!("==")(a, [RangeEndpoint(0, 0), RangeEndpoint(3, 1),
                        RangeEndpoint(7, 1), RangeEndpoint(10, 0)][]);
        This.sortEndpoints(This(3, 7), This(0, 10), a);
        test!("==")(a, [RangeEndpoint(0, 1), RangeEndpoint(3, 0),
                        RangeEndpoint(7, 0), RangeEndpoint(10, 1)][]);

        // equal
        This.sortEndpoints(This(0, 10), This(0, 10), a);
        test!("==")(a, [RangeEndpoint(0, 0), RangeEndpoint(0, 1),
                        RangeEndpoint(10, 0), RangeEndpoint(10, 1)][]);
        This.sortEndpoints(This(5, 5), This(5, 5), a);
        test!("==")(a, [RangeEndpoint(5, 0), RangeEndpoint(5, 1),
                        RangeEndpoint(5, 0), RangeEndpoint(5, 1)][]);

        // one point range
        This.sortEndpoints(This(4, 4), This(5, 5), a);
        test!("==")(a, [RangeEndpoint(4, 0), RangeEndpoint(4, 0),
                        RangeEndpoint(5, 1), RangeEndpoint(5, 1)][]);
        This.sortEndpoints(This(5, 5), This(4, 4), a);
        test!("==")(a, [RangeEndpoint(4, 1), RangeEndpoint(4, 1),
                        RangeEndpoint(5, 0), RangeEndpoint(5, 0)][]);
        This.sortEndpoints(This(5, 5), This(0, 10), a);
        test!("==")(a, [RangeEndpoint(0, 1), RangeEndpoint(5, 0),
                        RangeEndpoint(5, 0), RangeEndpoint(10, 1)][]);
        This.sortEndpoints(This(0, 10), This(5, 5), a);
        test!("==")(a, [RangeEndpoint(0, 0), RangeEndpoint(5, 1),
                        RangeEndpoint(5, 1), RangeEndpoint(10, 0)][]);
        This.sortEndpoints(This(5, 5), This(5, 10), a);
        test!("==")(a, [RangeEndpoint(5, 0), RangeEndpoint(5, 1),
                        RangeEndpoint(5, 0), RangeEndpoint(10, 1)][]);
        This.sortEndpoints(This(5, 10), This(5, 5), a);
        test!("==")(a, [RangeEndpoint(5, 0), RangeEndpoint(5, 1),
                        RangeEndpoint(5, 1), RangeEndpoint(10, 0)][]);
        This.sortEndpoints(This(5, 5), This(0, 5), a);
        test!("==")(a, [RangeEndpoint(0, 1), RangeEndpoint(5, 0),
                        RangeEndpoint(5, 0), RangeEndpoint(5, 1)][]);
        This.sortEndpoints(This(0, 5), This(5, 5), a);
        test!("==")(a, [RangeEndpoint(0, 0), RangeEndpoint(5, 1),
                        RangeEndpoint(5, 0), RangeEndpoint(5, 1)][]);
    }
}



/*******************************************************************************

    Unittest to instantiate the Range template with all supported types, in turn
    running the unittests for each of them.

*******************************************************************************/

unittest
{
    Range!(ubyte) br;
    Range!(ushort) sr;
    Range!(ulong) lr;
}


/*******************************************************************************

    Predicate that checks for the existence of one or more gaps
    in an array of Range!T.

    It is assumed that the array is already sorted. All empty ranges are ignored.

    Params:
        ranges = a sorted array of Range!T to be checked

    Returns:
        true if at least one gap exists in the array

*******************************************************************************/

public bool hasGap ( T ) ( Range!(T)[] ranges )
{
    trimEmptyRanges(ranges);

    if (ranges.length > 0)
    {
        auto current_threshold = ranges[0].max_;

        for (size_t i = 1; i < ranges.length; ++i)
        {
            if (ranges[i].min_ > current_threshold + 1)
                return true;

            if (ranges[i].max_ > current_threshold)
                current_threshold = ranges[i].max_;
        }
    }

    return false;
}

unittest
{
    // contiguous
    test(!hasGap([Range!(uint)(1, 5),
                  Range!(uint)(6, 12),
                  Range!(uint)(13, 15)]), "Contiguous ranges can't have gap");

    // overlap, but no gaps
    test(!hasGap([Range!(uint)(1, 5),
                  Range!(uint)(3, 14),
                  Range!(uint)(13, 15)]));
    test(!hasGap([Range!(uint)(1, 12),
                  Range!(uint)(4, 7),
                  Range!(uint)(13, 15)]));
    test(!hasGap([Range!(uint)(1, 13),
                  Range!(uint)(4, 7),
                  Range!(uint)(13, 15)]));
    test(!hasGap([Range!(uint)(1, 14),
                  Range!(uint)(4, 7),
                  Range!(uint)(13, 15)]));

    // gap
    test(hasGap([Range!(uint)(1, 11),
                 Range!(uint)(4, 7),
                 Range!(uint)(13, 15)]));

    // two equal range
    test(!hasGap([Range!(uint)(3, 17),
                  Range!(uint)(3, 17)]));

    // any count of empty ranges has no effect
    test(!hasGap([Range!(uint).init,
                  Range!(uint)(1, 13),
                  Range!(uint)(4, 7),
                  Range!(uint)(13, 15)]));
    test(!hasGap([Range!(uint).init,
                  Range!(uint)(1, 14),
                  Range!(uint)(4, 7),
                  Range!(uint)(13, 15)]));
    test(hasGap([Range!(uint).init,
                 Range!(uint)(1, 11),
                 Range!(uint)(4, 7),
                 Range!(uint)(13, 15)]));
    test(!hasGap([Range!(uint).init,
                  Range!(uint).init,
                  Range!(uint)(1, 14),
                  Range!(uint)(4, 7),
                  Range!(uint)(13, 15)]));
    test(hasGap([Range!(uint).init,
                 Range!(uint).init,
                 Range!(uint)(1, 11),
                 Range!(uint)(4, 7),
                 Range!(uint)(13, 15)]));

    // any combination of empty sets has no gaps
    test(!hasGap!(uint)(null));
    test(!hasGap!(uint)([]));
    test(!hasGap([Range!(uint).init]));
    test(!hasGap([Range!(uint).init,
                  Range!(uint).init]));
    test(!hasGap([Range!(uint).init,
                  Range!(uint).init,
                  Range!(uint).init]));
}


/*******************************************************************************

    Predicate that checks for the existence of overlaps in array of Range!T.

    It is assumed that the array is already sorted. All empty ranges are ignored.

    Params:
        ranges = a sorted array of Range!T to be checked

    Returns:
        true if at least one overlap exists in the array

*******************************************************************************/

public bool hasOverlap ( T ) ( Range!(T)[] ranges )
{
    trimEmptyRanges(ranges);

    if (ranges.length > 0)
    {
        auto current_threshold = ranges[0].max_;

        for (size_t i = 1; i < ranges.length; ++i)
        {
            if (ranges[i].min_ <= current_threshold)
                return true;

            if (ranges[i].max_ > current_threshold)
                current_threshold = ranges[i].max_;
        }
    }

    return false;
}

unittest
{
    // contiguous
    test(!hasOverlap([Range!(uint)(1, 5),
                      Range!(uint)(6, 12),
                      Range!(uint)(13, 15)]), "Contiguous ranges can't overlap");

    // one common point
    test(hasOverlap([Range!(uint)(1, 5),
                     Range!(uint)(5, 12),
                     Range!(uint)(13, 15)]));
    test(hasOverlap([Range!(uint)(1, 5),
                     Range!(uint)(6, 13),
                     Range!(uint)(13, 15)]));

    // overlap range
    test(hasOverlap([Range!(uint)(1, 5),
                     Range!(uint)(3, 14),
                     Range!(uint)(13, 15)]));

    // has gap
    test(!hasOverlap([Range!(uint)(1, 4),
                      Range!(uint)(6, 12),
                      Range!(uint)(13, 15)]));
    test(hasOverlap([Range!(uint)(1, 4),
                     Range!(uint)(6, 13),
                     Range!(uint)(13, 15)]));
    test(hasOverlap([Range!(uint)(1, 4),
                     Range!(uint)(6, 14),
                     Range!(uint)(13, 15)]));

    // the first range mask the second
    test(hasOverlap([Range!(uint)(1, 12),
                     Range!(uint)(6, 8),
                     Range!(uint)(13, 15)]));
    // the second range mask the first
    test(hasOverlap([Range!(uint)(3, 8),
                     Range!(uint)(3, 12),
                     Range!(uint)(13, 15)]));

    // equal
    test(hasOverlap([Range!(uint)(3, 17),
                     Range!(uint)(3, 17)]));

    // any count of empty ranges has no effect
    test(!hasOverlap([Range!(uint).init,
                      Range!(uint)(1, 5),
                      Range!(uint)(6, 12),
                      Range!(uint)(13, 15)]));
    test(hasOverlap([Range!(uint).init,
                     Range!(uint)(1, 5),
                     Range!(uint)(5, 12),
                     Range!(uint)(13, 15)]));
    test(!hasOverlap([Range!(uint).init,
                      Range!(uint).init,
                      Range!(uint)(1, 5),
                      Range!(uint)(6, 12),
                      Range!(uint)(13, 15)]));
    test(hasOverlap([Range!(uint).init,
                     Range!(uint).init,
                     Range!(uint)(1, 5),
                     Range!(uint)(5, 12),
                     Range!(uint)(13, 15)]));

    // any combination of empty sets has no overlaps
    test(!hasOverlap!(uint)(null));
    test(!hasOverlap!(uint)([]));
    test(!hasOverlap([Range!(uint).init]));
    test(!hasOverlap([Range!(uint).init,
                      Range!(uint).init]));
    test(!hasOverlap([Range!(uint).init,
                      Range!(uint).init,
                      Range!(uint).init]));
}

/*******************************************************************************

    Predicate that checks contiguity of the array of Range!T.

    This function's result is equivalent to !hasGap && !hasOverlap. There is
    a special unittest which asserts this (see below). It has been implemented
    as a separate function because a more efficient implementation is possible.

    It is assumed that the array is already sorted in lexicographical
    order: first check left boundaries of ranges if equal then right boundaries
    will be checked (that is current status quo of opCmp). All empty ranges
    are ignored.

    Params:
        ranges = a sorted array of Range!T to be checked

    Returns:
        true if collection is contiguous

*******************************************************************************/

public bool isContiguous ( T ) ( Range!(T)[] ranges )
{
    trimEmptyRanges(ranges);

    for (size_t i = 1; i < ranges.length; ++i)
    {
        if (ranges[i].min_ != ranges[i - 1].max_ + 1)
            return false;
    }

    return true;
}

unittest
{
    // contiguous
    test(isContiguous([Range!(uint)(1, 5),
                       Range!(uint)(6, 12),
                       Range!(uint)(13, 15)]));

    // one common point
    test(!isContiguous([Range!(uint)(1, 5),
                        Range!(uint)(5, 12),
                        Range!(uint)(13, 15)]));
    test(!isContiguous([Range!(uint)(1, 5),
                        Range!(uint)(6, 13),
                        Range!(uint)(13, 15)]));

    // gap
    test(!isContiguous([Range!(uint)(1, 4),
                        Range!(uint)(6, 12),
                        Range!(uint)(13, 15)]));
    test(!isContiguous([Range!(uint)(1, 5),
                        Range!(uint)(6, 11),
                        Range!(uint)(13, 15)]));

    // gap and common point
    test(!isContiguous([Range!(uint)(1, 4),
                        Range!(uint)(6, 13),
                        Range!(uint)(13, 15)]));

    // two equal range
    test(!isContiguous([Range!(uint)(6, 13),
                        Range!(uint)(6, 13)]));

    // any count of empty ranges has no effect
    test(isContiguous([Range!(uint).init,
                       Range!(uint)(1, 5),
                       Range!(uint)(6, 12),
                       Range!(uint)(13, 15)]));
    test(!isContiguous([Range!(uint).init,
                        Range!(uint)(1, 5),
                        Range!(uint)(6, 13),
                        Range!(uint)(13, 15)]));
    test(!isContiguous([Range!(uint).init,
                        Range!(uint)(1, 4),
                        Range!(uint)(6, 12),
                        Range!(uint)(13, 15)]));
    test(!isContiguous([Range!(uint).init,
                        Range!(uint)(1, 4),
                        Range!(uint)(6, 13),
                        Range!(uint)(13, 15)]));
    test(isContiguous([Range!(uint).init,
                       Range!(uint).init,
                       Range!(uint)(1, 5),
                       Range!(uint)(6, 12),
                       Range!(uint)(13, 15)]));

    // any combination of empty sets is contiguous
    test(isContiguous!(uint)(null));
    test(isContiguous!(uint)([]));
    test(isContiguous([Range!(uint).init]));
    test(isContiguous([Range!(uint).init,
                       Range!(uint).init]));
    test(isContiguous([Range!(uint).init,
                       Range!(uint).init,
                       Range!(uint).init]));
}


/*******************************************************************************

    Special unittest which checks that:
    isContiguous <=> !hasGap && !hasOverlap

*******************************************************************************/

unittest
{
    Range!(uint)[] ranges;

    // ranges is null
    test!("==")(isContiguous(ranges), !hasGap(ranges) && !hasOverlap(ranges));

    // contiguous ranges
    ranges ~= [Range!(uint)(1, 5), Range!(uint)(6, 12), Range!(uint)(13, 15)];
    test!("==")(isContiguous(ranges), !hasGap(ranges) && !hasOverlap(ranges));
    ranges.length = 0;
    enableStomping(ranges);

    // overlap
    ranges ~= [Range!(uint)(1, 5), Range!(uint)(6, 13), Range!(uint)(13, 15)];
    test!("==")(isContiguous(ranges), !hasGap(ranges) && !hasOverlap(ranges));
    ranges.length = 0;
    enableStomping(ranges);

    // gap
    ranges ~= [Range!(uint)(1, 4), Range!(uint)(6, 12), Range!(uint)(13, 15)];
    test!("==")(isContiguous(ranges), !hasGap(ranges) && !hasOverlap(ranges));
    ranges.length = 0;
    enableStomping(ranges);

    // gap and overlap
    ranges ~= [Range!(uint)(1, 4), Range!(uint)(6, 13), Range!(uint)(13, 15)];
    test!("==")(isContiguous(ranges), !hasGap(ranges) && !hasOverlap(ranges));
    ranges.length = 0;
    enableStomping(ranges);

    // range.length == 0
    test!("==")(isContiguous(ranges), !hasGap(ranges) && !hasOverlap(ranges));

    // only empty ranges
    ranges ~= Range!(uint).init;
    test!("==")(isContiguous(ranges), !hasGap(ranges) && !hasOverlap(ranges));
    ranges ~= Range!(uint).init;
    test!("==")(isContiguous(ranges), !hasGap(ranges) && !hasOverlap(ranges));
    ranges ~= Range!(uint).init;
    test!("==")(isContiguous(ranges), !hasGap(ranges) && !hasOverlap(ranges));
}


/*******************************************************************************

    Generate a single Range!T that covers the entire set of values found
    in an array of Range!T, i.e. whose min, max values reflect the smallest
    and largest min and max found in the array.

    It is assumed that the array is sorted already in lexicographical order:
    first compare the left boundaries of the range, if they are equal then
    the right boundaries will be compared (that is current status quo of opCmp).
    All empty ranges are ignored.

    Note: Although this method assumes sorted input, it would be possible
    to provide another implementation without this assumption.
    However, such an implementation would be more expensive, with
    an asymptotic complexity of O(n), whereas this version is O(1).

    Params:
        ranges = a sorted array of Range!T

    Returns:
        resulting minimal covering range, or an empty range
        if the input array is empty

*******************************************************************************/

public Range!(T) extent (T) ( Range!(T)[] ranges )
{
    trimEmptyRanges(ranges);

    return ranges.length == 0 ? Range!(T).init : Range!(T)(ranges[0].min_, ranges[$ - 1].max_);
}

unittest
{
    // one range
    test!("==")(extent([Range!(uint)(3, 5)]), Range!(uint)(3, 5));

    // two equal ranges
    test!("==")(extent([Range!(uint)(3, 5),
                        Range!(uint)(3, 5)]), Range!(uint)(3, 5));

    // overlap
    test!("==")(extent([Range!(uint)(3, 5),
                        Range!(uint)(4, 8)]), Range!(uint)(3, 8));

    // gap
    test!("==")(extent([Range!(uint)(3, 5),
                        Range!(uint)(7, 9)]), Range!(uint)(3, 9));

    // gap and overlap
    test!("==")(extent([Range!(uint)(3, 5),
                        Range!(uint)(7, 12),
                        Range!(uint)(12, 15)]), Range!(uint)(3, 15));

    // the first has the same min as the second
    test!("==")(extent([Range!(uint)(3, 5),
                        Range!(uint)(3, 7)]), Range!(uint)(3, 7));

    // any count of empty ranges has no effect
    test!("==")(extent([Range!(uint).init,
                        Range!(uint)(3, 5)]), Range!(uint)(3, 5));
    test!("==")(extent([Range!(uint).init,
                        Range!(uint)(3, 5),
                        Range!(uint)(7, 100)]), Range!(uint)(3, 100));
    test!("==")(extent([Range!(uint).init,
                        Range!(uint).init,
                        Range!(uint)(3, 5),
                        Range!(uint)(7, 100)]), Range!(uint)(3, 100));

    // any combination of empty sets has emty extent
    test!("==")(extent!(uint)(null), Range!(uint).init);
    test!("==")(extent!(uint)([]), Range!(uint).init);
    test!("==")(extent([Range!(uint).init]), Range!(uint).init);
    test!("==")(extent([Range!(uint).init,
                        Range!(uint).init]), Range!(uint).init);
}


/*******************************************************************************

    Trims any empty ranges from the start of a sorted array of Range!T.

    It is assumed that the array is already sorted, which means all empty ranges
    will be at the beginning of the array.

    Params:
        ranges = sorted array of Range!T from which empties drop out

*******************************************************************************/

private void trimEmptyRanges ( T ) ( ref Range!(T)[] ranges )
{
    while (ranges.length > 0 && ranges[0].is_empty)
    {
        ranges = ranges[1 .. $];
    }
}

unittest
{
    // empty and non-empty ranges
    {
        Range!(uint)[] a = [Range!(uint).init, Range!(uint).init,
                            Range!(uint)(2, 9), Range!(uint)(12, 19)];
        trimEmptyRanges(a);
        test!("==")(a, [Range!(uint)(2, 9), Range!(uint)(12, 19)][]);
    }

    // only non-empty ranges
    {
        Range!(uint)[] a = [Range!(uint)(2, 9), Range!(uint)(12, 19)];
        trimEmptyRanges(a);
        test!("==")(a, [Range!(uint)(2, 9), Range!(uint)(12, 19)][]);
    }

    // array of empty ranges
    {
        Range!(uint)[] a = [Range!(uint).init, Range!(uint).init];
        trimEmptyRanges(a);
        test!("==")(a.length, 0);
    }

    // empty array
    {
        Range!(uint)[] a;
        trimEmptyRanges(a);
        test!("==")(a.length, 0);
    }
}
