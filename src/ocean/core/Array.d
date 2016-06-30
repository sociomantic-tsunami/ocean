/*******************************************************************************

    Array manipulation functions.

    It's often convenient to use these functions with D's 'function as array
    property' syntax, so:

    ---
        mstring dest;
        concat(dest, "hello ", "world");
    ---

    could also be written as:

    ---
        mstring dest;
        dest.concat("hello ", "world");
    ---

    TODO: Extend unittest to test all functions in this module.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.core.Array;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.core.Test;
import ocean.core.Buffer;

public import ocean.core.array.Mutation;;
public import ocean.core.array.Transformation;;
public import ocean.core.array.Search;

/*******************************************************************************

    Unittest

*******************************************************************************/

unittest
{
    Buffer!(char) str;
    assert (copy(str, "Die Katze tritt die Treppe krumm.") == "Die Katze tritt die Treppe krumm.");

    str.length = 0;
    assert (concat(str, "Die "[], "Katze "[], "tritt "[], "die "[], "Treppe "[], "krumm."[]) == "Die Katze tritt die Treppe krumm.");

    mstring nothing = null;

    str.length = 0;
    assert (concat(str, "Die "[], ""[], "Katze "[], "tritt "[], nothing, "die "[], "Treppe "[], "krumm."[]) == "Die Katze tritt die Treppe krumm.");

    str.length = 0;
    append(str, "Die Katze "[]);
    assert (str[] == "Die Katze ");
    append(str, "tritt "[], "die "[]);
    assert (append(str, "Treppe "[], "krumm."[]) == "Die Katze tritt die Treppe krumm.");

    alias bsearch!(long) bs;

    long[] arr = [1, 2, 3,  5, 8, 13, 21];

    size_t n;

    assert (bs(arr, 5, n));
}

version ( UnitTest )
{

    // Tests string concatenation function against results of the normal ~ operator
    bool concat_test ( T... ) ( T strings )
    {
        Buffer!(char) dest;
        concat(dest, strings);

        mstring concat_result;
        foreach ( str; strings )
        {
            concat_result ~= str;
        }
        return dest[] == concat_result ;
    }
}

unittest
{
    mstring dest;
    istring str1 = "hello";
    istring str2 = "world";
    istring str3 = "something";

    // Check dynamic array concatenation
    test(concat_test(dest, str1, str2, str3), "Concatenation test failed");

    // Check that modifying one of the concatenated strings doesn't modify the result
    mstring result = dest.dup;
    str1 = "goodbye";
    test!("==")(dest, result);

    // Check null concatenation
    test(concat_test(dest), "Null concatenation test 1 failed");
    test(concat_test(dest, "", ""), "Null concatenation test 2 failed");

    // Check static array concatenation
    char[3] staticstr1 = "hi ";
    char[5] staticstr2 = "there";
    test(concat_test(dest, staticstr1, staticstr2), "Static array concatenation test failed");

    // Check manifest constant array concatenation
    const conststr1 = "hi ";
    const conststr2 = "there";
    test(concat_test(dest, conststr1, conststr2), "Const array concatenation test failed");
}
