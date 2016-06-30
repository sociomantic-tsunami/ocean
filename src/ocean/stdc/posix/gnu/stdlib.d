/*******************************************************************************

    glibc stdlib functions.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

*******************************************************************************/

module ocean.stdc.posix.gnu.stdlib;

version (GLIBC):

extern (C):

int mkstemps(char*, int); // BSD and other systems too
int mkostemp(char*, int);
int mkostemps(char*, int, int);

