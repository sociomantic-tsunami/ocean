/*******************************************************************************

    An utility class to interact with collectd-unixsock plugin

    This class is a simple wrapper around Collectd's functionalities,
    providing parsing and communication means.

    Most users will not want to use this module directly and should prefer
    the high-level stats API provided in `ocean.util.log.Stats`.

    See_Also:
        https://collectd.org/documentation/manpages/collectd-unixsock.5.shtml

    Copyright:
        Copyright (c) 2015-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.net.collectd.Collectd;


/*******************************************************************************

    Usage example

*******************************************************************************/

unittest
{
    void sendCollectdData ()
    {
        // Every call to collectd (but `listval`) needs to use an `Identifier`.
        // See Collectd's documentation for more information. Here we create an
        // app-global identifier.
        Identifier id =
        {
            host:               "example.com",
            plugin:             "http_server",
            type:               "requests",       // how much traffic it handles
            plugin_instance:    "1",              // the instance number
            type_instance:      "worker-1"
        };

        // Note that if you have a Collectd-provided identifier, you can
        // read it using `Identifier.create`
        // Here we use the convenience overload that throws on error, however
        // there is one version which returns a message if the parsing failed.
        auto id2 = Identifier.create("sociomantic.com/http_server-1/requests-worker-1");

        // Construct a Collectd instance that connect() to the socket.
        // If the connect() fails, an `ErrnoIOException` is thrown.
        // The parameter is the path of the Collectd socket
        auto collectd = new Collectd("/var/run/collectd.socket");

        // From this point on you can use the instance to talk to the socket.
        // Once a function that returns a set of data is called (e.g. `listval`),
        // no other function should be called until the result is fully
        // processed, as this class internally uses a rotating buffer to
        // minimize memory allocations.
        // If a new request is started while the previous one isn't
        // fully processed, a `CollectdException` will be thrown.

        // When writing a value, you need a structure that match a definition
        // in your `types.db` file.
        //
        // The documentation of `types.db` can be found here:
        // https://collectd.org/documentation/manpages/types.db.5.shtml
        //
        // The name of the struct doesn't matter, only what's in `id`.
        // To simplify the example, we use a struct that is defined by default
        // in `types.db`.
        // Note: the definition is `bytes value:GAUGE:0:U`
        static struct Charge { double value; }
        Charge charge = Charge(42.0);

        // Write an entry to collectd.
        collectd.putval(id, charge);
        // Will send `PUTVAL current_unix_timestamp:42` on the wire
    }
}


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;
import ocean.core.Enforce;
import ocean.core.Exception;
import ocean.core.Traits;
import ocean.net.device.LocalSocket; // LocalAddress
import ocean.stdc.time; // time
import ocean.stdc.posix.sys.types; // time_t
import ocean.sys.ErrnoException;
import ocean.sys.linux.consts.socket;  // SOCK_DGRAM
import ocean.sys.socket.UnixSocket;
import ocean.text.Util;
import Float = ocean.text.convert.Float;
import ocean.text.convert.Format;
import ocean.text.convert.Integer;
import Conv = ocean.util.Convert;
import ocean.text.util.StringSearch; // locateChar

import ocean.net.collectd.SocketReader;
public import ocean.net.collectd.Identifier;

version (UnitTest)
{
    import ocean.core.Test;
    import ocean.io.Stdout : Stdout;
}


/*******************************************************************************

    Collectd wrapper class

    Encapsulate communication with the Collectd socket, as well as parsing
    of its messages.

    Note:
        You must be careful when mixing calls. Returned data are transient
        (sits in an internal buffer), and might get invalidated on the next
        call to a member function.

        For example, don't do:

        ````
        Collectd inst = ...;
        foreach (v; inst.listval())
        {
            inst.getval!(Counter)(v);
        }
        ````
        Because this might invalidate the data returned by `listval()` on the
        first call to `getval()`

    Note:
        PUTNOTIF is not implemented

*******************************************************************************/

public final class Collectd
{
    /***************************************************************************

        Values returned by 'listval'

    ***************************************************************************/

    public static struct Value
    {
        /***********************************************************************

            The timestamp - as a floating point value - of the last update

        ***********************************************************************/

        public double last_update;


        /***********************************************************************

            An identifier the can be passed to `getval()`

        ***********************************************************************/

        public Identifier identifier;
    }


    /***************************************************************************

        Options that can be passed to Putval

    ***************************************************************************/

    public struct PutvalOptions
    {
        /***********************************************************************

            Gives the interval in which the data is being collected.

        ***********************************************************************/

        public time_t interval;
    }


    /***************************************************************************

        Constructor

        Params:
            socket_path = Path of the local socket of the collectd daemon.

        Throws:
            If it can't create the socket or connect to the collectd daemon,
            an Exception is thrown.

    ***************************************************************************/

    public this (istring socket_path)
    {
        auto socketaddr = new LocalAddress(socket_path);
        this.socket = new UnixSocket();

        this.e_errno = new ErrnoException();
        this.e = new CollectdException(256);
        this.reader.e = this.e_errno;

        auto sockRet = this.socket.socket();
        if (sockRet < 0)
            throw this.e_errno.useGlobalErrno("socket");

        if (auto connectRet = this.socket.connect(socketaddr))
            throw this.e_errno.useGlobalErrno("connect");

        // This ought to be enough for any numeric argument
        this.format_buff = new mstring(256);
        this.format_buff.length = 0;
        enableStomping(this.format_buff);
    }


    /***************************************************************************

        Submits one or more values, identified by Identifier to the daemon
        which will dispatch it to all its write-plugins

        Params:
            id      = Uniquely identifies what value is being collected.
                      Note the `type` must be defined in `types.db`.

            data    = A struct containing only numeric types. Values can either
                      be an integer if the data-source is a counter,
                      or a double if the data-source is of type "gauge".
                      NaN and infinity are translated to undefined values ('U').
                      The current UNIX time is submitted along.

            options = The options list is an optional parameter, where each
                      option is sent as a key-value-pair.
                      See `PutvalOptions`'s documentation for a list
                      of all currently recognized options, however be aware
                      that an outdated Collectd which doesn't support all
                      the options will silently ignore them.

        Throws:
            `ErrnoException` if writing to the socket produced an error,
            or `CollectdException` if an error happened while communicating
            (Collectd returns an error, the internal buffer wasn't empty (which
            means the caller haven't fully processed the last query),
            or we get unexpected / inconsistent data), or if more than
            10 millions records where found

    ***************************************************************************/

    public void putval (T) (Identifier id, ref T data,
                            PutvalOptions options = PutvalOptions.init)
    {
        static assert (is (T == struct) || is (T == class),
                       "Only struct and classes can be sent to Collectd");
        static assert (T.tupleof.length,
                       "Cannot send empty aggregate of type "
                       ~ T.stringof ~ " to Collectd");

        this.startNewRequest!("putval");

        this.format("PUTVAL ", id);

        // Write the options
        if (options.interval)
            this.format(` interval="`, options.interval, `"`);

        // Every line should start with the timestamp
        this.format(" ", time(null));

        // Write all the data
        foreach (idx, ref v; data.tupleof)
            this.format(":", v);

        // All lines need to end with a \n
        this.format("\n");
        this.write(this.format_buff);

        this.reader.popFront(this.socket, 0);

        // Check for success
        this.e.enforce(this.reader.front()[0 .. PutvalSuccessLineBegin.length]
                       == PutvalSuccessLineBegin,
                       this.reader.front());
        this.reader.popFront();
        if (!this.reader.empty())
            throw this.e.set("Unexpected line received from Collectd: ")
                .append(this.reader.front());
    }


    /***************************************************************************

        Read a status line as sent by collectd

        Params:
            line = The status line read from collectd. It should be in the form
                    "X Values found", where X is a number greater than 1, or
                    "1 Value found".

        Throws:
            `CollectdException` if the status line is non conformant

        Returns:
            On success the number of values found (that is, 'X' or 'Y')

    ***************************************************************************/

    private size_t processStatusLine (cstring line)
    {
        size_t values = void;
        auto spIdx = StringSearch!(false).locateChar(line, ' ');

        auto vfound = line[spIdx .. $];
        if (vfound != " Values found" && vfound != " Value found")
            throw this.e.set("Expected 'Value(s) found' in status line, got ")
                .append(vfound);

        auto vstring = line[0 .. spIdx];
        if (!toInteger(vstring, values))
            throw this.e.set("Could not convert '").append(vstring)
                .append("' to integer");

        return values;
    }


    /***************************************************************************

        An instance to the socket used to communicate with collectd daemon

        When reading from the socket, collectd always send *at least* one line,
        the status line. Lines are always send in full.
        The socket is a streaming (TCP) socket.

        The minimal status line one can get is "0 Value found\n", which has a
        length of 14. If we limit ourselve to a max value of
        size_t.length, or 18_446_744_073_709_551_615 on 64 bits machines,
        we can get a status line which size is comprised between 14 and 34.

    ***************************************************************************/

    private UnixSocket socket;


    /***************************************************************************

        Exception when a non-IO error happen while communicating with Collectd

    ***************************************************************************/

    private CollectdException e;


    /***************************************************************************

        Exception when an IO error happen

    ***************************************************************************/

    private ErrnoException e_errno;


    /***************************************************************************

        An instance of the line reader

    ***************************************************************************/

    private SocketReader!() reader;


    /***************************************************************************

        Internal buffer used to format non-string arguments

    ***************************************************************************/

    private mstring format_buff;


    /***************************************************************************

        What putval returns on success

    ***************************************************************************/

    private const istring PutvalSuccessLineBegin = "0 Success: ";


    /***************************************************************************

        Write the content of an identifier to a buffer

        Params:
            identifier = Identifier instance to write

    ***************************************************************************/

    private void formatIdentifier (ref Const!(Identifier) identifier)
    in
    {
        assert(identifier.host.length, "No host for identifier");
        assert(identifier.plugin.length, "No plugin for identifier");
        assert(identifier.type.length, "No type for identifier");
    }
    body
    {
        auto pi = identifier.plugin_instance.length ? "-" : null;
        auto ti = identifier.type_instance.length ? "-" : null;

        this.format_buff ~= identifier.host;
        this.format_buff ~= '/';
        this.format_buff ~= identifier.plugin;
        this.format_buff ~= pi;
        this.format_buff ~= identifier.plugin_instance;
        this.format_buff ~= '/';
        this.format_buff ~= identifier.type;
        this.format_buff ~= ti;
        this.format_buff ~= identifier.type_instance;
    }


    /***************************************************************************

        Append stringified arguments into `this.format_buff`

        Params:
            args = Array of arguments to write to `this.format_buff`.
                   `Identifier`, string types and numeric values are supported.

    ***************************************************************************/

    private void format (T...) (in T args)
    {
        scope sink = (Const!(char)[] v)
                     {
                         this.format_buff ~= v;
                         return v.length;
                     };

        foreach (arg; args)
        {
            static if (is(typeof(arg) : Unqual!(Identifier)))
                this.formatIdentifier(arg);
            else static if (is(typeof(arg) == struct)
                            || is(typeof(arg) == class)
                            || is(typeof(arg) == enum))
                static assert(0, "Cannot send an aggregate of type "
                              ~ typeof(arg).stringof ~ " to Collectd");
            else
                Format(sink, "{}", arg);
        }
    }


    /***************************************************************************

        Helper to write data to a socket

        Params:
            str = String to send on the socket.
                  Usually a literal, or the formatted buffer.

        Throws:
            `CollectdException` if writing to the Collectd socket failed

    ***************************************************************************/

    private void write (cstring str)
    {
        auto r = this.socket.write(str);
        if (r != str.length)
            throw this.e_errno.useGlobalErrno("write");
    }


    /***************************************************************************

        Sanity check to ensure a request is started with a clean slate

        Also reset the formatting buffer.

        Template_Params:
            reqname = Name of the request that is started, for more informative
                      error message.

        Throws:
            `CollectdException` if there is data in the buffer.

    ***************************************************************************/

    private void startNewRequest (istring reqname /*= __FUNCTION__*/) ()
    {
        this.format_buff.length = 0;
        enableStomping(this.format_buff);

        this.e.enforce(this.reader.empty(),
                       "Called " ~ reqname ~ " with a non-empty buffer");
    }
}


/*******************************************************************************

    Exception to be thrown when an error happens in Collectd

*******************************************************************************/

public class CollectdException : Exception
{
    mixin ReusableExceptionImplementation!();
}
