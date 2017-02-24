/*******************************************************************************

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

deprecated module ocean.sys.linux.termios;
pragma(msg, "Please use core.sys.linux.termios or core.sys.posix.termios");

public import core.sys.linux.termios;
public import core.sys.posix.termios;

import ocean.transition;

const B57600    = Octal!("0010001");
