/******************************************************************************

    Flexible unittest runner

    This module provides a more flexible unittest runner.

    The goals for this test runner is to function as a standalone program,
    instead of being run before another program's main(), as is common in D.

    To achieve this, the main() function is provided by this module too.

    To use it, just import this module and any other module you want to test,
    for example:

    ---
    module tester;
    import ocean.core.UnitTestRunner;
    import mymodule;
    ---

    That's it. Compile with: dmd -unittest tester.d mymodule.d

    You can control the unittest execution, try ./tester -h for help on the
    available options.

    Tester status codes:

    0  - All tests passed
    2  - Wrong command line arguments
    4  - One or more tests failed
    8  - One or more tests had errors (unexpected problems)
    16 - Error writing to XML file

    Status codes can be aggregated via ORing, so for example, a status of 12
    means both failures and errors were encountered, and status of 20 means
    failures were encountered and there was an error writing the XML file.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.core.UnitTestRunner;

import ocean.transition;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.stdc.string: strdup, strlen, strncmp;
import ocean.stdc.posix.unistd: unlink;
import ocean.stdc.posix.libgen: basename;
import ocean.stdc.posix.sys.time: gettimeofday, timeval, timersub;
import ocean.core.Runtime: Runtime;
import ocean.core.Exception_tango : AssertException;
import ocean.io.Stdout_tango: Stdout, Stderr;
import ocean.io.stream.Format: FormatOutput;
import ocean.io.stream.TextFile: TextFileOutput;
import ocean.text.xml.Document: Document;
import ocean.text.xml.DocPrinter: DocPrinter;
import ocean.text.convert.Formatter;
import ocean.core.Test: TestException, test;
import core.memory;



/******************************************************************************

    Handle all the details about unittest execution.

******************************************************************************/

private scope class UnitTestRunner
{

    /**************************************************************************

        Options parsed from the command-line

    ***************************************************************************/

    private cstring prog;
    private bool help = false;
    private size_t verbose = 0;
    private bool summary = false;
    private bool keep_going = false;
    private cstring[] packages = null;
    private cstring xml_file;


    /**************************************************************************

        Aliases for easier access to symbols with long and intricate names

    ***************************************************************************/

    private alias Document!(char)           XmlDoc;
    private alias XmlDoc.Node               XmlNode; /// ditto


    /**************************************************************************

        Buffer used for text conversions

    ***************************************************************************/

    private mstring buf;


    /**************************************************************************

        XML document used to produce the XML test results report

    ***************************************************************************/

    private XmlDoc xml_doc;


    /**************************************************************************

        Static constructor replacing the default Tango unittest runner

    ***************************************************************************/

    static this ( )
    {
        Runtime.moduleUnitTester(&this.dummyUnitTestRunner);
    }


    /**************************************************************************

        Dummy unittest runner.

        This runner does nothing because we handle all the unittest execution
        directly in the main() function, so we can parse the program's argument
        before running the unittests.

        Returns:
            true to tell the runtime we want to run main()

    ***************************************************************************/

    private static bool dummyUnitTestRunner()
    {
        return true;
    }


    /**************************************************************************

        Run all the unittest registered by the runtime.

        The parseArgs() function must be called before this method.

        Returns:
            exit status to pass to the operating system.

    ***************************************************************************/

    private int run ( )
    {
        assert (prog);

        timeval start_time = this.now();

        size_t passed = 0;
        size_t failed = 0;
        size_t errored = 0;
        size_t skipped = 0;
        size_t no_tests = 0;
        size_t no_match = 0;
        size_t gc_usage_before, gc_usage_after, mem_free;
        bool collect_gc_usage = !!this.verbose;

        if (this.verbose)
            Stdout.formatln("{}: unit tests started", this.prog);

        foreach ( m; ModuleInfo )
        {
            if (!this.shouldTest(m.name))
            {
                no_match++;
                if (this.verbose > 1)
                    Stdout.formatln("{}: {}: skipped (not in packages to test)",
                            this.prog, m.name);
                continue;
            }

            if (m.unitTest is null)
            {
                no_tests++;
                if (this.verbose > 1)
                    Stdout.formatln("{}: {}: skipped (no unittests)",
                            this.prog, m.name);
                this.xmlAddSkipped(m.name);
                continue;
            }

            if ((failed || errored) && !this.keep_going)
            {
                skipped++;
                if (this.verbose > 2)
                    Stdout.formatln(
                        "{}: {}: skipped (one failed and no --keep-going)",
                        this.prog, m.name);
                this.xmlAddSkipped(m.name);
                continue;
            }

            if (this.verbose)
            {
                Stdout.format("{}: {}: testing ...", this.prog, m.name).flush();
            }

            // we have a unittest, run it
            timeval t;
            // XXX: We can't use this.buf because it will be messed up when
            //      calling toHumanTime() and the different xmlAdd*() methods
            static mstring e;
            e.length = 0;
            enableStomping(e);
            scope (exit)
            {
                if (this.verbose)
                    Stdout.newline();
                if (e !is null)
                    Stdout.formatln("{}", e);
            }
            if (collect_gc_usage)
            {
                GC.collect();
                ocean.transition.gc_usage(gc_usage_before, mem_free);
            }
            switch (this.timedTest(m, t, e))
            {
                case Result.Pass:
                    passed++;
                    if (this.verbose)
                    {
                        ocean.transition.gc_usage(gc_usage_after, mem_free);
                        Stdout.format(" PASS [{}, {} bytes ({} -> {})]",
                                      this.toHumanTime(t),
                                      cast(long)(gc_usage_after - gc_usage_before),
                                      gc_usage_before, gc_usage_after);
                    }
                    this.xmlAddSuccess(m.name, t);
                    continue;

                case Result.Fail:
                    failed++;
                    if (this.verbose)
                        Stdout.format(" FAIL [{}]", this.toHumanTime(t));
                    this.xmlAddFailure(m.name, t, e);
                    break;

                case Result.Error:
                    errored++;
                    if (this.verbose)
                        Stdout.format(" ERROR [{}]", this.toHumanTime(t));
                    this.xmlAddFailure!("error")(m.name, t, e);
                    break;

                default:
                    assert(false);
            }

            if (!this.keep_going)
                continue;

            if (this.verbose > 2)
                Stdout.format(" (continuing, --keep-going used)");
        }

        timeval total_time = elapsedTime(start_time);

        if (this.summary)
        {
            Stdout.format("{}: {} modules passed, {} failed, "
                    ~ "{} with errors, {} without unittests",
                    this.prog, passed, failed, errored, no_tests);
            if (!this.keep_going && failed)
                Stdout.format(", {} skipped", skipped);
            if (this.verbose > 1)
                Stdout.format(", {} didn't match --package", no_match);
            Stdout.formatln(" [{}]", this.toHumanTime(total_time));
        }

        bool xml_ok = this.writeXml(
                passed + failed + errored + no_tests + skipped,
                no_tests + skipped, failed, errored, total_time);

        int ret = 0;

        if (!xml_ok)
            ret |= 16;

        if (errored)
            ret |= 8;

        if (failed)
            ret |= 4;

        return ret;
    }


    /**************************************************************************

        Add a skipped test node to the XML document

        Params:
            name = name of the test to add to the XML document

        Returns:
            new XML node, suitable for call chaining

    ***************************************************************************/

    private XmlNode xmlAddSkipped ( cstring name )
    {
        if (this.xml_doc is null)
            return null;

        return this.xmlAddTestcase(name).element(null, "skipped");
    }


    /**************************************************************************

        Add a successful test node to the XML document

        Params:
            name = name of the test to add to the XML document
            tv = time it took the test to run

        Returns:
            new XML node, suitable for call chaining

    ***************************************************************************/

    private XmlNode xmlAddSuccess ( cstring name, timeval tv )
    {
        if (this.xml_doc is null)
            return null;

        return this.xmlAddTestcase(name)
                .attribute(null, "time", toXmlTime(tv).dup);
    }


    /**************************************************************************

        Add a failed test node to the XML document

        Template_Params:
            type = type of failure (either "failure" or "error")

        Params:
            name = name of the test to add to the XML document
            tv = time it took the test to run
            msg = reason why the test failed

        Returns:
            new XML node, suitable for call chaining

    ***************************************************************************/

    private XmlNode xmlAddFailure (istring type = "failure") (
            cstring name, timeval tv, cstring msg )
    {
        static assert (type == "failure" || type == "error");

        if (this.xml_doc is null)
            return null;

        // TODO: capture test output
        return this.xmlAddSuccess(name, tv)
                .element(null, type)
                        .attribute(null, "type", type)
                        .attribute(null, "message", msg.dup);
    }


    /**************************************************************************

        Add a test node to the XML document

        Params:
            name = name of the test to add to the XML document

        Returns:
            new XML node, suitable for call chaining

    ***************************************************************************/

    private XmlNode xmlAddTestcase ( cstring name )
    {
        return this.xml_doc.elements
                .element(null, "testcase")
                        .attribute(null, "classname", name)
                        .attribute(null, "name", "unittest");
    }


    /**************************************************************************

        Write the XML document to the file passed by command line arguments

        Params:
            tests = total amount of tests found
            skipped = number of skipped tests
            failures = number of failed tests
            errors = number of errored tests
            time = total time it took the tests to run

        Returns:
            true if the file was written successfully, false otherwise

    ***************************************************************************/

    private bool writeXml ( size_t tests, size_t skipped, size_t failures,
            size_t errors, timeval time)
    {
        if (this.xml_doc is null)
            return true;

        this.xml_doc.elements // root node: <testsuite>
                    .attribute(null, "tests", this.convert(tests).dup)
                    .attribute(null, "skipped", this.convert(skipped).dup)
                    .attribute(null, "failures", this.convert(failures).dup)
                    .attribute(null, "errors", this.convert(errors).dup)
                    .attribute(null, "time", this.toXmlTime(time).dup);

        auto printer = new DocPrinter!(char);
        try
        {
            auto output = new TextFileOutput(this.xml_file);
            // At this point we don't care about errors anymore, is best effort
            scope (failure)
            {
                // Make sure it ends with a null char, before passing it to
                // the C function unlink()
                this.xml_file ~= '\0';
                unlink(this.xml_file.ptr);
            }
            scope (exit)
            {
                // Workarround for the issue where buffered output is not flushed
                // before close
                output.flush();
                output.close();
            }
            output(printer.print(this.xml_doc)).newline;
        }
        catch (Exception e)
        {
            Stderr.formatln("{}: error: writing XML file '{}': {} [{}:{}]",
                    this.prog, this.xml_file, getMsg(e), e.file, e.line);
            return false;
        }

        return true;
    }


    /**************************************************************************

        Convert a timeval to a string with a format suitable for the XML file

        The format used is seconds, expressed as a floating point number, with
        miliseconds resolution (i.e. 3 decimals precision).

        Params:
            tv = timeval to convert to string

        Returns:
            string with the XML compatible form of tv

    ***************************************************************************/

    private cstring toXmlTime ( timeval tv )
    {
        return this.convert(tv.tv_sec + tv.tv_usec / 1_000_000.0, "{:f3}");
    }


    /**************************************************************************

        Convert a timeval to a human readable string.

        If it is in the order of hours, then "N.Nh" is used, if is in the order
        of minutes, then "N.Nm" is used, and so on for seconds ("s" suffix),
        milliseconds ("ms" suffix) and microseconds ("us" suffix).

        Params:
            tv = timeval to print

        Returns:
            string with the human readable form of tv.

    ***************************************************************************/

    private cstring toHumanTime ( timeval tv )
    {
        if (tv.tv_sec >= 60*60)
            return this.convert(tv.tv_sec / 60.0 / 60.0, "{:f1}h");

        if (tv.tv_sec >= 60)
            return this.convert(tv.tv_sec / 60.0, "{:f1}m");

        if (tv.tv_sec > 0)
            return this.convert(tv.tv_sec + tv.tv_usec / 1_000_000.0, "{:f1}s");

        if (tv.tv_usec >= 1000)
            return this.convert(tv.tv_usec / 1_000.0, "{:f1}ms");

        return this.convert(tv.tv_usec, "{}us");
    }

    unittest
    {
        scope t = new UnitTestRunner;
        timeval tv;
        test!("==")(t.toHumanTime(tv), "0us"[]);
        tv.tv_sec = 1;
        test!("==")(t.toHumanTime(tv), "1.0s"[]);
        tv.tv_sec = 1;
        test!("==")(t.toHumanTime(tv), "1.0s"[]);
        tv.tv_usec = 100_000;
        test!("==")(t.toHumanTime(tv), "1.1s"[]);
        tv.tv_usec = 561_235;
        test!("==")(t.toHumanTime(tv), "1.6s"[]);
        tv.tv_sec = 60;
        test!("==")(t.toHumanTime(tv), "1.0m"[]);
        tv.tv_sec = 61;
        test!("==")(t.toHumanTime(tv), "1.0m"[]);
        tv.tv_sec = 66;
        test!("==")(t.toHumanTime(tv), "1.1m"[]);
        tv.tv_sec = 60*60;
        test!("==")(t.toHumanTime(tv), "1.0h"[]);
        tv.tv_sec += 10;
        test!("==")(t.toHumanTime(tv), "1.0h"[]);
        tv.tv_sec += 6*60;
        test!("==")(t.toHumanTime(tv), "1.1h"[]);
        tv.tv_sec = 0;
        test!("==")(t.toHumanTime(tv), "561.2ms"[]);
        tv.tv_usec = 1_235;
        test!("==")(t.toHumanTime(tv), "1.2ms"[]);
        tv.tv_usec = 1_000;
        test!("==")(t.toHumanTime(tv), "1.0ms"[]);
        tv.tv_usec = 235;
        test!("==")(t.toHumanTime(tv), "235us"[]);
    }


    /**************************************************************************

        Convert an arbitrary value to string using the internal temporary buffer

        Note: the return value can only be used temporarily, as it is stored in
              the internal, reusable, buffer.

        Params:
            val = value to convert to string
            fmt = Tango format string used to convert the value to string

        Returns:
            string with the value as specified by fmt

    ***************************************************************************/

    private cstring convert ( T ) ( T val, cstring fmt = "{}" )
    {
        this.buf.length = 0;
        enableStomping(this.buf);
        return sformat(this.buf, fmt, val);
    }


    /**************************************************************************

        Possible test results.

    ***************************************************************************/

    enum Result
    {
        Pass,
        Fail,
        Error,
    }

    /**************************************************************************

        Test a single module, catching and reporting any errors.

        Params:
            m = module to be tested
            tv = the time the test took to run will be written here
            err = buffer where to write the error message if the test was
                  unsuccessful (is only written if the return value is !=
                  Result.Pass

        Returns:
            the result of the test (passed, failure or error)

    ***************************************************************************/

    private Result timedTest ( ModuleInfoPtr m, out timeval tv, ref mstring err )
    {
        timeval start = this.now();
        scope (exit) tv = elapsedTime(start);

        try
        {
            version (D_Version2)
                m.unitTest()();
            else
                m.unitTest();
            return Result.Pass;
        }
        catch (TestException e)
        {
            version (D_Version2)
                e.toString((d) { err ~= d; });
            else
                err = sformat(err, "{}:{}: test error: {}", e.file, e.line, getMsg(e));
            return Result.Fail;
        }
        catch (AssertException e)
        {
            version (D_Version2)
                e.toString((d) { err ~= d; });
            else
                err = sformat(err, "{}:{}: assert error: {}", e.file, e.line, getMsg(e));
        }
        catch (Exception e)
        {
            version (D_Version2)
                e.toString((d) { err ~= d; });
            else
                err = sformat(err, "{}:{}: unexpected exception {}: {}",
                              e.file, e.line, e.classinfo.name, getMsg(e));
        }

        return Result.Error;
    }


    /**************************************************************************

        Gets the elapsed time between start and now

        Returns:
            a timeval with the elapsed time

    ***************************************************************************/

    private static timeval elapsedTime ( timeval start )
    {
        timeval elapsed;
        timeval end = now();
        timersub(&end, &start, &elapsed);

        return elapsed;
    }


    /**************************************************************************

        Gets the current time with microseconds resolution

        Returns:
            a timeval representing the current date and time

    ***************************************************************************/

    private static timeval now ( )
    {
        timeval t;
        int e = gettimeofday(&t, null);
        assert (e == 0, "gettimeofday returned != 0");

        return t;
    }


    /**************************************************************************

        Check if a module with name `name` should be tested.

        Params:
            name = Name of the module to check if it should be tested.

        Returns:
            true if it should be tested, false otherwise.

    ***************************************************************************/

    bool shouldTest ( cstring name )
    {
        // No packages specified, matches all
        if (this.packages.length == 0)
            return true;

        foreach (pkg; this.packages)
        {
            if (name.length >= pkg.length &&
                    strncmp(pkg.ptr, name.ptr, pkg.length) == 0)
                return true;
        }

        return false;
    }


    /**************************************************************************

        Parse command line arguments filling the internal options and program
        name.

        This function also print help and error messages.

        Params:
            args = command line arguments as received by main()

        Returns:
            true if the arguments are OK, false otherwise.

    ***************************************************************************/

    private bool parseArgs ( cstring[] args )
    {
        // we don't care about freeing anything, is just a few bytes and the program
        // will quite after we are done using these variables
        char* bin_c = strdup(args[0].ptr);
        char* prog_c = basename(bin_c);
        this.prog = prog_c[0..strlen(prog_c)];

        cstring[] unknown;

        bool skip_next = false;

        args = args[1..$];

        cstring getOptArg ( size_t i )
        {
            if (args.length <= i+1)
            {
                this.printUsage(Stderr);
                Stderr.formatln("\n{}: error: missing argument for {}",
                        this.prog, args[i]);
                return null;
            }
            skip_next = true;
            return args[i+1];
        }

        foreach (i, arg; args)
        {
            if (skip_next)
            {
                skip_next = false;
                continue;
            }

            switch (arg)
            {
            case "-h":
            case "--help":
                this.help = true;
                this.printHelp(Stdout);
                return true;

            case "-vvv":
                this.verbose++;
                goto case;
            case "-vv":
                this.verbose++;
                goto case;
            case "-v":
            case "--verbose":
                this.verbose++;
                break;

            case "-s":
            case "--summary":
                this.summary = true;
                break;

            case "-k":
            case "--keep-going":
                this.keep_going = true;
                break;

            case "-p":
            case "--package":
                auto opt_arg = getOptArg(i);
                if (opt_arg is null)
                    return false;
                this.packages ~= opt_arg;
                break;

            case "-x":
            case "--xml-file":
                this.xml_file = getOptArg(i);
                if (this.xml_file is null)
                    return false;
                if (this.xml_doc is null)
                {
                    this.xml_doc = new XmlDoc;
                    this.xml_doc.header();
                    this.xml_doc.tree.element(null, "testsuite")
                                          .attribute(null, "name", "unittests");
                }
                break;

            default:
                unknown ~= arg;
                break;
            }
        }

        if (unknown.length)
        {
            this.printUsage(Stderr);
            Stderr.format("\n{}: error: Unknown arguments:", this.prog);
            foreach (arg; unknown)
            {
                Stderr.format(" {}", arg);
            }
            Stderr.newline();
            return false;
        }

        return true;
    }


    /**************************************************************************

        Print the program's usage string.

        Params:
            fp = File pointer where to print the usage.

    ***************************************************************************/

    private void printUsage ( FormatOutput!(char) output )
    {
        output.formatln("Usage: {} [-h] [-v] [-s] [-k] [-p PKG] [-x FILE]",
                this.prog);
    }


    /**************************************************************************

        Print the program's full help string.

        Params:
            fp = File pointer where to print the usage.

    ***************************************************************************/

    private void printHelp ( FormatOutput!(char) output )
    {
        this.printUsage(output);
        output.print(`
optional arguments:
  -h, --help        print this message and exit
  -v, --verbose     print more information about unittest progress, can be
                    specified multiple times (even as -vvv, 3 is the maximum),
                    the first level only prints the executed tests, the second
                    level print the tests skipped because there are no unit
                    tests in the module or because it doesn't match the -p
                    patterns, and the third level print also tests skipped
                    because no -k is used and a test failed
  -s, --summary     print a summary with the passed, skipped and failed number
                    of tests
  -k, --keep-going  don't stop after the first module unittest failed
  -p, --package PKG
                    only run tests in the PKG package (effectively any module
                    which fully qualified name starts with PKG), can be
                    specified multiple times to indicate more packages to test
  -x, --xml-file FILE
                    write test results in FILE in a XML format that Jenkins
                    understands.
`);
    }
}



/******************************************************************************

    Main function that run all the modules unittests using UnitTestRunner.

******************************************************************************/

int main(cstring[] args)
{
    scope runner = new UnitTestRunner;

    auto args_ok = runner.parseArgs(args);

    if (runner.help)
        return 0;

    if (!args_ok)
        return 2;

    return runner.run();
}
