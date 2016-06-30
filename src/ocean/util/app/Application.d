/*******************************************************************************

    Utility class to do more common tasks an application have to do to start
    running.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.Application;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.util.app.model.ExtensibleClassMixin;
import ocean.util.app.model.IApplicationExtension;
import ocean.util.app.model.IApplication;
import ocean.util.app.ExitException;

import ocean.io.Stdout;



/*******************************************************************************

    Extensible class to do all the common task needed for an application to run.

    This class also implements its own extension interface, so it's easy to
    write an application using the hooks in extensions without having to write
    a separate extension. The order of this extension is 0, establishing
    a reference order for all the other extensions. Extensions that should be
    executed before the application hooks should have a negative order, while
    extensions that have to be executed after the application hooks should have
    a positive order value.

    The common usage is to derive from Application and override the run()
    method. Optionally you can override the extensions methods too.

    Example:

    ---

    import ocean.util.app.Application;
    import ocean.io.Stdout;

    class MyApp : Application
    {
        this ( )
        {
            super("myapp", "A test application");
        }
        protected override void preRun ( Application app, istring[] args )
        {
            if ( args.length < 4 )
            {
                this.exit(1, "Too few arguments");
            }
        }
        protected override int run ( istring[] args )
        {
            Stdout.formatln("Application is running!");

            return 0;
        }
        protected override void postRun ( Application app, istring[] args,
                int status )
        {
            Stdout.formatln("Application returned {}", status);

        }
    }

    int main(istring[] args)
    {
        auto app = new MyApp;
        return app.main(args);
    }

    ---

    As seen in the example, this class also provides a clean way to exit an
    application from anywhere in the program, the exit() method.

    The main() method is the real only needed public API, and the one calling
    all the extension code. The real application call must be in the run()
    method, which is abstract, and mandatory to implement.

    The full power and usefulness of this class comes from extensions though.

*******************************************************************************/

class Application : IApplication
{

    /***************************************************************************

        Adds a list of extensions (this.extensions) and methods to handle them.
        See ExtensibleClassMixin documentation for details.

    ***************************************************************************/

    mixin ExtensibleClassMixin!(IApplicationExtension);


    /***************************************************************************

        Alias of Application, for use by sub-classes without needing to import
        ocean.util.app.Application.

    ***************************************************************************/

    protected alias .Application Application;


    /***************************************************************************

        Name of the application.

        Set in the constructor and remains read-only for the rest of the life of
        the program.

    ***************************************************************************/

    private istring name_;


    /***************************************************************************

        Short description of the application.

        Usually should be set in the constructor and remain read-only for the
        rest of the life of the program.

    ***************************************************************************/

    public istring desc;


    /***************************************************************************

        Command line arguments passed to the application.

        This is only set after the main() method is called. It's available for
        all the extensions methods though. It is usually passed as argument to
        extension methods, so it should not be necessary to use it directly (use
        the method extensions arguments whenever you can).

    ***************************************************************************/

    public istring[] args;


    /***************************************************************************

        Application exit status code.

        This is only set after the main() method finishes. It is usually passed
        as argument to extension methods as soon as it has a meaningful value,
        so it should not be necessary to use it directly (use the method
        extensions arguments whenever you can).

    ***************************************************************************/

    public int status;


    /***************************************************************************

        Constructor.

        This constructor only setup the internal state of the class, but does
        not call any extension or user code. The application runs only when the
        main() method is called.

        Params:
            name = name of the application
            desc = short description of the application

    ***************************************************************************/

    public this ( istring name, istring desc )
    {
        this.name_ = name;
        this.desc = desc;
        this.status = -1;
        this.registerExtension(this);
    }


    /***************************************************************************

        Returns:
            the name of the application

    ***************************************************************************/

    public istring name ( )
    {
        return this.name_;
    }


    /***************************************************************************

        Exit cleanly from the application.

        Calling exit() will properly unwind the stack and all the destructors
        will be called. Should be used only from the main application thread
        though.

        Params:
            status = status code to return to the OS
            msg = optional message to show just before exiting

    ***************************************************************************/

    public void exit(int status, istring msg = null)
    {
        throw new ExitException(status, msg);
    }


    /***************************************************************************

        Runs the application.

        This method is the main public interface of the class. It triggers all
        the extension methods and eventually calls the run() method, which is
        the one having the actual user code.

        Params:
            args = Command line arguments received by the application

        Returns:
            status code to return to the OS

    ***************************************************************************/

    public int main(istring[] args)
    {
        ExitException exit_except = null;
        this.args = args;

        try
        {
            foreach (ext; this.extensions)
            {
                ext.preRun(this, args);
            }

            this.status = this.run(args);

            foreach (ext; this.extensions)
            {
                ext.postRun(this, args, this.status);
            }
        }
        catch (ExitException e)
        {
            foreach (ext; this.extensions)
            {
                e = ext.onExitException(this, args, e);
            }

            exit_except = e;
            this.status = e.status;
            this.printExitException(e);
        }

        foreach (ext; this.extensions)
        {
            ext.atExit(this, args, this.status, exit_except);
        }

        return this.status;
    }


    /***************************************************************************

        Prints the message in an ExitException.

        The message is only printed if there is one, and is printed in red if
        the exit status is not 0 (and we are in a tty).

        Params:
            e = ExitException to print

    ***************************************************************************/

    protected void printExitException ( ExitException e )
    {
        if (getMsg(e) == "")
        {
            return;
        }
        if (e.status == 0)
        {
            Stdout.formatln("{}", getMsg(e));
        }
        else
        {
            Stderr.red.format("{}", getMsg(e)).default_colour.newline;
        }
    }


    /***************************************************************************

        Do the actual application work.

        This method is meant to be implemented by subclasses to do the actual
        application work.

        Params:
            args = Command line arguments as a raw list of strings

        Returns:
            status code to return to the OS

    ***************************************************************************/

    protected abstract int run ( istring[] args );


    /***************************************************************************

        Default application extension order.

    ***************************************************************************/

    public override int order ( )
    {
        return 0;
    }


    /***************************************************************************

        IApplicationExtension methods dummy implementation.

        This methods are implemented with "empty" implementation to ease
        deriving from this class.

        See IApplicationExtension documentation for more information on how to
        override this methods.

    ***************************************************************************/

    public void preRun ( IApplication app, istring[] args )
    {
        // Dummy implementation of the interface
    }

    public void postRun ( IApplication app, istring[] args, int status )
    {
        // Dummy implementation of the interface
    }

    public void atExit ( IApplication app, istring[] args, int status,
            ExitException exception )
    {
        // Dummy implementation of the interface
    }

    public ExitException onExitException ( IApplication app,
            istring[] args, ExitException exception )
    {
        // Dummy implementation of the interface
        return exception;
    }

}
