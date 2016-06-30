/*******************************************************************************

    Bindings to Readline library's main operations.

    This module contains the D binding of the library functions of readline.h.
    Please consult the original header documentation for details.

    You need to have the library installed and link with -lreadline.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

        Bear in mind this module provides bindings to an external library that
        has its own license, which might be more restrictive. Please check the
        external library license to see which conditions apply for linking.

*******************************************************************************/

module ocean.io.console.readline.c.readline;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;


public extern (C)
{
    /***************************************************************************

        Function signature for functions used with the rl_bind_key functions and
        various other functions.

    ***************************************************************************/

    alias int function (int count, int c) rl_command_func_t;

    /***************************************************************************

        Abort pushing back character param ''c'' to input stream

    ***************************************************************************/

    extern mixin(global("rl_command_func_t rl_abort;"));

    /***************************************************************************

        Insert character param  ``c'' back into input stream for param ``count''
        times

    ***************************************************************************/

    extern mixin(global("rl_command_func_t rl_insert;"));

    /***************************************************************************

        Binds a key.

    ***************************************************************************/

    int rl_bind_key(int key, rl_command_func_t* _function);

    /***************************************************************************

        Reads input.

    ***************************************************************************/

    char* readline(char*);
}
