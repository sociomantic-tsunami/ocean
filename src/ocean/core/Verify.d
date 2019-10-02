/*******************************************************************************

    Utility intended as a replacement for `assert` to check for programming
    errors and sanity violations in situations when neither removing the check
    in -release mode nor bringing down the application by throwing an `Error`
    is acceptable.

    This module must have as few import dependencies as possible so that it can
    be used in place of `assert` freely without introducing cyclic imports.

    Copyright: Copyright (c) 2017 dunnhumby Germany GmbH. All rights reserved

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.core.Verify;

import ocean.meta.types.Qualifiers : istring;

/*******************************************************************************

    Verifies that certain condition is met.

    Params:
        ok = boolean condition to check
        msg = optional exception message

    Throws:
        SanityException if `ok` condition is `false`.

*******************************************************************************/

public void verify ( bool ok, lazy istring msg = "",
    istring file = __FILE__, int line = __LINE__ )
{
    static SanityException exc;

    if (!ok)
    {
        if (exc is null)
            exc = new SanityException("");

        exc.file = file;
        exc.line = line;
        exc.msg = msg;

        throw exc;
    }
}

unittest
{
    try
    {
        verify(false);
    }
    catch (SanityException e) { }

    verify(true);
}

/*******************************************************************************

    Indicates some internal sanity violation in the app, essentially a less
    fatal version of `AssertError`.

*******************************************************************************/

public class SanityException : Exception
{
    public this ( istring msg, istring file = __FILE__, int line = __LINE__ )
    {
        super(msg, file, line);
    }
}
