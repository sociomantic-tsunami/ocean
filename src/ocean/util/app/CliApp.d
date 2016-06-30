/*******************************************************************************

    Application class that provides the standard features needed by command
    line tools:
        * Command line parsing
        * Version support

    Usage example:
        See CliApp class' documented unittest

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.CliApp;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.app.Application : Application;
import ocean.util.app.ext.model.IArgumentsExtExtension;

import ocean.transition;

/*******************************************************************************

    CliApp class

*******************************************************************************/

abstract class CliApp : Application, IArgumentsExtExtension
{
    import ocean.text.Arguments : Arguments;
    import ocean.util.app.ext.VersionInfo : VersionInfo;
    import ocean.util.app.ext.ArgumentsExt;
    import ocean.util.app.ext.VersionArgsExt;

    /***************************************************************************

        Command line arguments used by the application.

    ***************************************************************************/

    public Arguments args;

    /***************************************************************************

        Command line arguments extension used by the application.

    ***************************************************************************/

    public ArgumentsExt args_ext;

    /***************************************************************************

        Version information.

    ***************************************************************************/

    public VersionInfo ver;

    /***************************************************************************

        Version information extension.

    ***************************************************************************/

    public VersionArgsExt ver_ext;

    /***************************************************************************

        Struct containing optional constructor arguments. There are enough of
        these that handling them as default arguments to the ctor is cumbersome.

    ***************************************************************************/

    public static struct OptionalSettings
    {
        /***********************************************************************

            How the program is supposed to be invoked.

        ***********************************************************************/

        istring usage = null;

        /***********************************************************************

            Long description of what the program does and how to use it.

        ***********************************************************************/

        istring help = null;
    }

    /***************************************************************************

        This constructor only sets up the internal state of the class, but does
        not call any extension or user code.

        Params:
            name = Name of the application (to show in the help message)
            desc = Short description of what the program does (should be
                         one line only, preferably less than 80 characters)
            ver = application's version information
            settings = optional settings (see OptionalSettings, above)

    ***************************************************************************/

    public this ( istring name, istring desc, VersionInfo ver,
        OptionalSettings settings = OptionalSettings.init )
    {
        super(name, desc);

        // Create and register arguments extension
        this.args_ext = new ArgumentsExt(name, desc, settings.usage,
            settings.help);
        this.args = this.args_ext.args;
        this.args_ext.registerExtension(this);
        this.registerExtension(this.args_ext);

        // Create and register version extension
        this.ver_ext = new VersionArgsExt(ver);
        this.ver = this.ver_ext.ver;
        this.args_ext.registerExtension(this.ver_ext);
        this.registerExtension(this.ver_ext);
    }

    /***************************************************************************

        Run implementation that forwards to the abstract
        run(Arguments, ConfigParser).

        Params:
            args = raw command line arguments

        Returns:
            status code to return to the OS

    ***************************************************************************/

    override protected int run ( istring[] args )
    {
        return this.run(this.args);
    }

    /***************************************************************************

        This method must be implemented by subclasses to do the actual
        application work.

        Params:
            args = parsed command line arguments

        Returns:
            status code to return to the OS

    ***************************************************************************/

    abstract protected int run ( Arguments args );

    /***************************************************************************

        IArgumentsExtExtension methods dummy implementation.

        These methods are implemented with an "empty" implementation to ease
        deriving from this class.

        See IArgumentsExtExtension documentation for more information on how to
        override these methods.

    ***************************************************************************/

    override public void setupArgs ( IApplication app, Arguments args )
    {
        // Dummy implementation of the interface
    }

    override public void preValidateArgs ( IApplication app, Arguments args )
    {
        // Dummy implementation of the interface
    }

    override public cstring validateArgs ( IApplication app, Arguments args )
    {
        // Dummy implementation of the interface
        return null;
    }

    override public void processArgs ( IApplication app, Arguments args )
    {
        // Dummy implementation of the interface
    }
}

///
unittest
{
    /***************************************************************************

        Example CLI application class.

    ***************************************************************************/

    class MyApp : CliApp
    {
        this ( )
        {
            // The name of your app and a short description of what it does.
            istring name = "my_app";
            istring desc = "Dummy app for unittest.";

            // The version info for your app. Normally you get this by importing
            // Version and passing the AA which contains the version info
            // (called Version) to CliApp's constructor.
            auto ver = VersionInfo.init;

            // You may also pass an instance of OptionalSettings to CliApp's
            // constructor, to specify non-mandatory options. In this example,
            // we specify the help text.
            CliApp.OptionalSettings settings;
            settings.help = "Actually, this program does nothing. Sorry!";

            // Call the super class' ctor.
            super(name, desc, VersionInfo.init, settings);
        }

        // Called after arguments and config file parsing.
        override protected int run ( Arguments args )
        {
            // Application main logic.

            return 0; // return code to OS
        }
    }

    /***************************************************************************

        Your application's main() function should look something like this.
        (This function is not called here as we don't want to actually run the
        application in this unittest.)

    ***************************************************************************/

    int main ( istring[] cl_args )
    {
        // Instantiate an instance of your app class.
        auto my_app = new MyApp;

        // Pass the raw command line arguments to its main function.
        auto ret = my_app.main(cl_args);

        // Return ret to the OS.
        return ret;
    }
}

