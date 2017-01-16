/*******************************************************************************

    Implements directory sandbox support for testing. Creates and cds
    into temporary directory at construction, and provides means to
    destroy it.

    Copyright:
        Copyright (c) 2009-2017 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.test.DirectorySandbox;

/// ditto
class DirectorySandbox
{
    import ocean.transition;
    import ocean.sys.ErrnoException;
    import ocean.io.device.File;
    import Path = ocean.io.Path;
    import ocean.text.util.StringC;
    import core.sys.posix.unistd: getcwd, chdir;
    import ocean.stdc.posix.stdlib : mkdtemp;
    import core.stdc.string: strlen;

    /// reusable ErrnoException instance
    private ErrnoException exception;

    /// Path to the directory sandbox
    private cstring sandbox_path;

    /// Template to base the temporary directory name on
    private mstring path_template;

    /// Previous path before entering sandbox.
    private mstring old_cwd;

    /// List of subdirectories to create
    private Const!(cstring)[] subdirectories;

    /***************************************************************************

        Factory method to construct instances.

        Params:
            subdirectories = list of subdirectories to create
            path_template = mkdtemp style path template.

    ***************************************************************************/

    public static DirectorySandbox create (in cstring[] subdirectories,
            mstring path_template = "/tmp/Dunittest-XXXXXXXX".dup)
    {
        auto sandbox = new DirectorySandbox;
        sandbox.path_template = path_template;
        sandbox.exception = new ErrnoException;

        sandbox.subdirectories = subdirectories;
        sandbox.cd();

        return sandbox;
    }

    /***************************************************************************

        Changes the directory to the old directory. Doesn't remove the
        sandbox directory.

    ***************************************************************************/

    public void exitSandbox ()
    in
    {
        assert(this.old_cwd.length);

    }
    body
    {
        this.exception.enforceRetCode!(chdir).call(
                StringC.toCString(this.old_cwd));
    }

    /***************************************************************************

        Changes the directory to the old directory and removes the
        sandbox directory.

    ***************************************************************************/

    public void remove ()
    {
        this.exitSandbox();
        // Remove all subdirectories and files in the tmp dir
        Path.remove(Path.collate(this.sandbox_path, "*", true));
        // Remove the tmp dir itself
        Path.remove(this.sandbox_path);
    }

    /***************************************************************************

        Creates a sandbox directory, with all subdirectories and cds into it.

    ***************************************************************************/

    private void cd ()
    {
        this.old_cwd.length = 4096;
        this.exception.enforceRetPtr!(getcwd).call(
            this.old_cwd.ptr,
            this.old_cwd.length);
        this.old_cwd.length = strlen(this.old_cwd.ptr);
        enableStomping(this.old_cwd);

        this.sandbox_path = StringC.toDString(this.exception.enforceRetPtr!(mkdtemp).call(
                StringC.toCString(this.path_template)));

        this.exception.enforceRetCode!(chdir).call(this.sandbox_path.ptr);

        foreach (dir; this.subdirectories)
        {
            Path.createFolder(dir);
        }
    }

    /***************************************************************************

        Disabled constructor, use `create` method instead.


    ***************************************************************************/

    private this()
    {
    }
}

///
unittest
{
    void test()
    {
        // Creates and cds into the directory sandbox
        with (DirectorySandbox.create(["etc", "log"]))
        {
            // At the success, destroys the sandbox
            scope (success)
                remove();

            // At the failure, just cds back, leaving the
            // sandbox directory in place.
            scope (failure)
                exitSandbox();
        }
    }
}
