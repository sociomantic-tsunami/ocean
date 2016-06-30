/*******************************************************************************

    Application extension to parse command line arguments.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.ext.ArgumentsExt;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.app.model.ExtensibleClassMixin;
import ocean.util.app.model.IApplicationExtension;
import ocean.util.app.ext.model.IArgumentsExtExtension;

import ocean.text.Arguments;
import ocean.io.Stdout : Stdout, Stderr;

import ocean.transition;
import ocean.io.stream.Format : FormatOutput;



/*******************************************************************************

    Application extension to parse command line arguments.

    This extension is an extension itself, providing new hooks via
    IArgumentsExtExtension.

    By default it adds a --help command line argument to show a help message.

*******************************************************************************/

class ArgumentsExt : IApplicationExtension
{

    /***************************************************************************

        Adds a list of extensions (this.extensions) and methods to handle them.
        See ExtensibleClassMixin documentation for details.

    ***************************************************************************/

    mixin ExtensibleClassMixin!(IArgumentsExtExtension);


    /***************************************************************************

        Formatted output stream to use to print normal messages.

    ***************************************************************************/

    protected FormatOutput!(char) stdout;


    /***************************************************************************

        Formatted output stream to use to print error messages.

    ***************************************************************************/

    protected FormatOutput!(char) stderr;


    /***************************************************************************

        Command line arguments parser and storage.

    ***************************************************************************/

    public Arguments args;


    /***************************************************************************

        Constructor.

        See ocean.text.Arguments for details on format of the parameters.

        Params:
            name = Name of the application (to show in the help message)
            desc = Short description of what the program does (should be
                         one line only, preferably less than 80 characters)
            usage = How the program is supposed to be invoked
            help = Long description of what the program does and how to use it
            stdout = Formatted output stream to use to print normal messages
            stderr = Formatted output stream to use to print error messages

    ***************************************************************************/

    public this ( istring name = null, istring desc = null,
            istring usage = null, istring help = null,
            FormatOutput!(char) stdout = Stdout,
            FormatOutput!(char) stderr = Stderr )
    {
        this.stdout = stdout;
        this.stderr = stderr;
        this.args = new Arguments(name, desc, usage, help);
    }


    /***************************************************************************

        Extension order. This extension uses -100_000 because it should be
        called very early.

        Returns:
            the extension order

    ***************************************************************************/

    public override int order ( )
    {
        return -100_000;
    }


    /***************************************************************************

        Setup, parse, validate and process command line args (Application hook).

        This function does all the extension processing invoking all the
        extension hooks. It also adds the --help option, which when present,
        shows the help and exits the program.

        If argument parsing or validation fails (including extensions
        validation), it also prints an error message and exits. Note that if
        argument parsing fails, validation is not performed.

        Params:
            app = the application instance
            cl_args = command line arguments

    ***************************************************************************/

    public override void preRun ( IApplication app, istring[] cl_args )
    {
        auto args = this.args;

        args("help").aliased('h').params(0)
            .help("display this help message and exit");

        foreach (ext; this.extensions)
        {
            ext.setupArgs(app, args);
        }

        cstring[] errors;
        auto args_ok = args.parse(cl_args[1 .. $]);

        if ( args.exists("help") )
        {
            args.displayHelp(this.stdout);
            app.exit(0);
        }

        foreach (ext; this.extensions)
        {
            ext.preValidateArgs(app, args);
        }

        if ( args_ok )
        {
            foreach (ext; this.extensions)
            {
                auto error = ext.validateArgs(app, args);
                if (error != "")
                {
                    errors ~= error;
                    args_ok = false;
                }
            }
        }

        if (!args_ok)
        {
            auto ocean_stderr = cast (typeof(Stderr)) this.stderr;
            if (ocean_stderr !is null)
                ocean_stderr.red;
            args.displayErrors(this.stderr);
            foreach (error; errors)
            {
                this.stderr(error).newline;
            }
            if (ocean_stderr !is null)
                ocean_stderr.default_colour;
            this.stderr.formatln("\nType {} -h for help", app.name);
            app.exit(2);
        }

        foreach (ext; this.extensions)
        {
            ext.processArgs(app, args);
        }
    }


    /***************************************************************************

        Unused IApplicationExtension methods.

        We just need to provide an "empty" implementation to satisfy the
        interface.

    ***************************************************************************/

    public override void postRun ( IApplication app, istring[] args, int status )
    {
        // Unused
    }

    public override void atExit ( IApplication app, istring[] args, int status,
            ExitException exception )
    {
        // Unused
    }

    public override ExitException onExitException ( IApplication app,
            istring[] args, ExitException exception )
    {
        // Unused
        return exception;
    }

}



/*******************************************************************************

    Tests

*******************************************************************************/

version (UnitTest)
{
    import ocean.core.Test;
    import ocean.util.app.Application;
    import ocean.io.device.MemoryDevice;
    import ocean.io.stream.Text : TextOutput;
    import ocean.core.Array : find;

    class App : Application
    {
        this ( ) { super("app", "A test application"); }
        protected override int run ( istring[] args ) { return 10; }
    }
}


/*******************************************************************************

    Test --help can be used even when required arguments are not specified

*******************************************************************************/

unittest
{

    auto stdout_dev = new MemoryDevice;
    auto stdout = new TextOutput(stdout_dev);

    auto stderr_dev = new MemoryDevice;
    auto stderr = new TextOutput(stderr_dev);

    istring usage_text = "test: usage";
    istring help_text = "test: help";
    auto arg = new ArgumentsExt("test-name", "test-desc", usage_text, help_text,
            stdout, stderr);
    arg.args("--required").params(1).required;

    auto app = new App;

    try
    {
        arg.preRun(app, ["./app", "--help"]);
        test(false, "An ExitException should have been thrown");
    }
    catch (ExitException e)
    {
        // Status should be 0 (success)
        test!("==")(e.status, 0);
        // No errors should be printed
        test!("==")(stderr_dev.bufferSize, 0);
        // Help should be printed to stdout
        auto s = cast(mstring) stdout_dev.peek();
        test(s.length > 0,
                "Stdout should have some help message but it's empty");
        test(s.find(arg.args.short_desc) < s.length,
             "No application description found in help message:\n" ~ s);
        test(s.find(usage_text) < s.length,
             "No usage text found in help message:\n" ~ s);
        test(s.find(help_text) < s.length,
             "No help text found in help message:\n" ~ s);
        test(s.find("--help"[]) < s.length,
             "--help should be found in help message:\n" ~ s);
    }
}
