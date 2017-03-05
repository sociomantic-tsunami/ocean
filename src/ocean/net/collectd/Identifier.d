/*******************************************************************************

    An identifier as defined by collectd

    An Identifier is of the form 'host/plugin-instance/type-instance'.
    Both '-instance' parts are optional.
    'plugin' and each '-instance' part may be chosen freely as long as
    the tuple (plugin, plugin instance, type instance) uniquely identifies
    the plugin within collectd.
    'type' identifies the type and number of values (i. e. data-set)
    passed to collectd.
    A large list of predefined data-sets is available in the types.db file.

    See_Also:
        https://collectd.org/documentation/manpages/collectd-unixsock.5.shtml
        https://collectd.org/documentation/manpages/types.db.5.shtml

    Copyright:
        Copyright (c) 2015-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.net.collectd.Identifier;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;
import ocean.core.ExceptionDefinitions; // IllegalArgumentException
import ocean.text.convert.Formatter;
import ocean.text.util.StringSearch; // locateChar

version (UnitTest)
{
    import ocean.core.Test;
}

/// Convenience alias
private alias StringSearch!(false).locateChar locateChar;



/******************************************************************************/

public struct Identifier
{
    /***************************************************************************

        Hostname

        If null, infered from a call to hostname. This call will only take
        place once, at application startup, so it won't have any
        performance impact on running applications.
        It is recommended to use null.

    ***************************************************************************/

    public cstring host;


    /***************************************************************************

        Should be set to the application name

    ***************************************************************************/

    public cstring plugin;


    /***************************************************************************

        Application defined type

        Types are defined in the file 'types.db'.
        Each type correspond to a set of values, with a particular meaning.
        For example, the type that would be used to log repeated invokation
        of the 'df' command line utility would be a data type consisting of
        two fields, 'used' and 'free'.

    ***************************************************************************/

    public cstring type;


    /***************************************************************************

        Application instance

        It is recommanded to use fixed number, such as [ 1, 2, 3, 4 ] if
        you have, for example 4 instances of the application running
        on the same 'host'.
        You can also use names for an instance, however, the identifier should
        be unique for this 'host', and should not change for the lifetime of
        the application (so using PID as instance is discouraged for example);

    ***************************************************************************/

    public cstring plugin_instance;


    /***********************************************************************

        Application defined instance of the category ('type')

        Each 'type' uniquely identify a kind of data, while 'type_instance'
        link this to an instance of the data. For example, to continue
        with the 'df' example (see 'type' documentation), 'type_instance'
        would probably be set to mount points, such as 'dev', 'run', 'boot'.

    ***********************************************************************/

    public cstring type_instance;


    /***********************************************************************

        Sanity checks

    ***********************************************************************/

    invariant ()
    {
        assert(this.host.length, "No host for identifier");
        assert(this.plugin.length, "No plugin for identifier");
        assert(this.type.length, "No type for identifier");
    }


    /***************************************************************************

        Convenience wrapper around `Identifier.create(cstring, Identifier)`
        that throws on parsing error.

        Params:
            line = An string matching 'host/plugin-instance/type-instance'.
                   Both `instance` part are optionals, in which case the '-'
                   should be omitted.

        Throws:
            If the argument `line` is not a valid identifier.

        Returns:
            The parsed identifier.

    ***************************************************************************/

    public static Identifier create (cstring line)
    {
        Identifier ret = void; // 'out' params are default initialized
        if (auto msg = Identifier.create(line, ret))
        {
            // Because the ctor doesn't expose it...
            auto e = new IllegalArgumentException(format("{}: {}", line, msg));
            e.file = __FILE__;
            e.line = __LINE__;
            throw e;
        }
        return ret;
    }

    unittest
    {
        testThrown!(IllegalArgumentException)(Identifier.create(""));
        testThrown!(IllegalArgumentException)(Identifier.create("/"));
        testThrown!(IllegalArgumentException)(Identifier.create("//"));
        testThrown!(IllegalArgumentException)(Identifier.create("a/b/-"));
        testThrown!(IllegalArgumentException)(Identifier.create("a/-/c"));
        testThrown!(IllegalArgumentException)(Identifier.create("a/b-/c"));
        testThrown!(IllegalArgumentException)(Identifier.create("a/b-/c-"));
        testThrown!(IllegalArgumentException)(Identifier.create("a/b/c/d"));

        Identifier expected = { host: "a", plugin: "b", type: "c" };
        testStructEquality(Identifier.create("a/b/c"), expected);

        expected.plugin_instance = "foo";
        testStructEquality(Identifier.create("a/b-foo/c"), expected);

        expected.type_instance = "bar";
        testStructEquality(Identifier.create("a/b-foo/c-bar"), expected);

        expected.type = "com.sociomantic.bytes_sent";
        testStructEquality(
            Identifier.create("a/b-foo/com.sociomantic.bytes_sent-bar"),
            expected);
    }


    /***************************************************************************

        Parse a string and returns the corresponding `Identifier`

        If the string passed is not a valid identifier, this function will
        return the reason why, else it returns `null`.

        This function is useful to get an identifier out of Collectd, or
        from any Collectd-formatted identifier.
        To construct an identifier with known values, initializing the fields
        is enough.

        Params:
            line = An string matching 'host/plugin-instance/type-instance'.
                   Both `instance` part are optionals, in which case the '-'
                   should be omitted.
            identifier = An identifier to fill with the parsed string.
                         If this function returns non-null, the state of
                         `identifier` should not be relied upon.

        Returns:
            `null` if the parsing succeeded, else a string representing the
            error.

    ***************************************************************************/

    public static istring create (cstring line, out Identifier identifier)
    {
        if (!line.length)
            return "Empty string is not a valid identifier";

        // Parses the host
        {
            auto slash = locateChar(line, '/');
            identifier.host = line[0 .. slash];
            line = line[slash + 1 .. $];
        }

        // Parses the plugin and the optional instance
        {
            auto slash = locateChar(line, '/');
            if (slash >= line.length)
                return "No plugin name found";
            auto dash = locateChar(line[0 .. slash], '-');
            if (dash < slash)
            {
                identifier.plugin = line[0 .. dash];
                identifier.plugin_instance = line[dash + 1 .. slash];
                if (auto m = check!("plugin instance")(identifier.plugin_instance))
                    return m;
            }
            else
            {
                identifier.plugin = line[0 .. slash];
                identifier.plugin_instance = null;
            }
            line = line[slash + 1 .. $];
        }

        // Finally, parses the type and the optional instance
        {
            auto dash = locateChar(line, '-');
            if (!line.length)
                return "Empty type found";
            if (dash < line.length)
            {
                identifier.type = line[0 .. dash];
                identifier.type_instance = line[dash + 1 .. $];
                if (auto m = check!("type instance")(identifier.type_instance))
                    return m;
            }
            else
            {
                identifier.type = line;
                identifier.type_instance = null;
            }
        }

        // We don't check host for validity, only that it contains something
        if (!identifier.host.length)
            return "Empty host found";
        if (auto msg = check!("plugin")(identifier.plugin))
            return msg;
        if (auto msg = check!("type")(identifier.type))
            return msg;

        return null;
    }


    version (UnitTest)
    {
        /***********************************************************************

            Replacement for `test!("==")(identifierA, identifierB)`, as it would
            trigger an assertion failure when formatting the arguments.

        ***********************************************************************/

        private static void testStructEquality (Identifier actual,
                                                Identifier expected)
        {
            test!("==")(actual.host, expected.host);
            test!("==")(actual.plugin, expected.plugin);
            test!("==")(actual.type, expected.type);
            test!("==")(actual.plugin_instance, expected.plugin_instance);
            test!("==")(actual.type_instance, expected.type_instance);
        }
    }

    /***************************************************************************

        Helper function template for validating a field's content

    ***************************************************************************/

    private static istring check (istring fieldname) (cstring field)
    {
        if (!field.length)
            return "Empty " ~ fieldname ~ " found";

        auto idx = invalidIndex(field);
        if (field.length != idx)
            return "Invalid char found in " ~ fieldname
                ~ ", allowed chars are: [0-9][a-z][A-Z][._-]";
        return null;
    }


    /***************************************************************************

        Find the first forbidden char in an identifier, if any

        Valid identifier are solely composed of [a-z][A-Z][0-9][._-]
        If any char isn't in that list, this function returns its index.

        Params:
            str = String to validate

        Returns:
            The index at which the invalid char is, or `str.length` if there
            isn't any

    ***************************************************************************/

    public static size_t invalidIndex (cstring str)
    {
        foreach (idx, c; str)
        {
            if (!(c >= 'a' && c <= 'z')
                && !(c >= 'A' && c <= 'Z')
                && !(c >= '0' && c <= '9')
                && !(c == '.' || c == '_' || c == '-'))
                return idx;
        }
        return str.length;
    }


    /***************************************************************************

        This function is useful for debug, however it is not intended to be
        used in production code, as it allocates.

        Returns:
            A newly-allocated string suitable for printing.

    ***************************************************************************/

    public istring toString ()
    {
        auto pi = this.plugin_instance.length ? "-" : null;
        auto ti = this.type_instance.length ? "-" : null;

        return format("{}/{}{}{}/{}{}{}", this.host,
                      this.plugin, pi, this.plugin_instance,
                      this.type, ti, this.type_instance);
    }
}
