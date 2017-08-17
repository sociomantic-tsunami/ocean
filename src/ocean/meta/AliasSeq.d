/*******************************************************************************

    Defines utility with same semantics as Phobos `AliasSeq`.

    Copyright:
        Copyright (c) 2017 sociomantic Labs GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.meta.AliasSeq;

template AliasSeq (T...)
{
    alias T AliasSeq;
}
