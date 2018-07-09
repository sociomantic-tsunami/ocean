/*******************************************************************************

    Unittest for ocean.io.Path

    Copyright:
        Copyright (c) 2017 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module integrationtest.pathutils.main;

import ocean.transition;

import ocean.core.Enforce;

import ocean.io.device.File;

import ocean.io.device.TempFile;

import ocean.io.Path;

import ocean.core.Test;

import ocean.util.test.DirectorySandbox;

import core.sys.posix.sys.stat;

/// Test method
version(UnitTest) {} else
void main ( )
{
    auto sandbox = DirectorySandbox.create();
    scope (exit)
        sandbox.exitSandbox();

    auto temp_file = new TempFile(TempFile.Permanent);
    auto path = temp_file.toString();

    test!("==")(isWritable(path), true);
    enforce(chmod((path ~ '\0').ptr, S_IRUSR) == 0);
    test!("==")(isWritable(path), false);
}
