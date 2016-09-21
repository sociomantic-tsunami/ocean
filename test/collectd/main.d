/*******************************************************************************

    Tests for ocean.net.collectd

    This test requires a Collectd socket, thus it is disabled by default.
    If you wish to run it, install collectd-core, setup a config file
    that starts a socket at /var/run/collectd.socket which you can write
    to, and run it.

    Copyright:
        Copyright (c) 2015-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/
module test.collectd.main;

import ocean.transition;
import ocean.core.Test;
import ocean.net.Collectd;
import ocean.net.device.LocalSocket; // LocalAddress
import ocean.stdc.posix.sys.types; // time_t


void main (istring[] args)
{
    auto address = args.length > 1
        ? args[1]
        : "/var/run/collectd.socket";

    auto list = new Collectd(address);
    auto get = new Collectd(address);
    auto put = new Collectd(address);

    auto baseId = Identifier.create("localhost/ocean_unittest/bytes");
    istring[8] inst = [ "0", "1", "2", "3", "4", "5", "6", "7" ];
    Collectd.KVP options = [ "interval": "60" ];
    Bytes c = void;
    for (size_t idx = 0; idx < 8; ++idx)
    {
        c.value = idx;
        baseId.type_instance = inst[idx];
        put.putval(baseId, c, options);
    }

    foreach (ref val; list.listval())
    {
        if (val.identifier.plugin == "ocean_unittest") {
            auto _ = get.getval!(Bytes)(val.identifier);
            test!("==")(val.identifier.type_instance[0] - '0', _.value);
        }
    }
}

public struct Bytes
{
    public double value;
}
