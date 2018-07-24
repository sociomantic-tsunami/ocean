/*******************************************************************************

    Registry of open files, plus methods to reopen one or all.

    Copyright:
        Copyright (c) 2018 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.application.components.OpenFiles;

import ocean.transition;

/// ditto
public class OpenFiles
{
    import ocean.core.Buffer;
    import ocean.core.Verify;
    import ocean.io.device.File;
    import ocean.sys.Environment;
    import ocean.text.convert.Formatter;

    /***************************************************************************

        List of open files to be reopened when reopenAll() is called.

    ***************************************************************************/

    private File[] open_files;


    /***************************************************************************

        Current working directory. Used for building absolute paths for the
        registered files.

    ***************************************************************************/

    private istring cwd;


    /***************************************************************************

        Buffer for rendering the absolute paths.

    ***************************************************************************/

    private Buffer!(char) path_buffer;


    /***************************************************************************

        Constructor.

    ***************************************************************************/

    public this ( )
    {
        this.cwd = Environment.directory();
        verify(this.cwd[$-1] == '/');
    }


    /***************************************************************************

        Registers the specified file, to be reopened when reopenAll() is called.

        Params:
            file = file to add to the set of reopenable files

    ***************************************************************************/

    public void register ( File file )
    {
        // TODO check for presence to avoid duplicates?
        this.open_files ~= file;
    }


    /***************************************************************************

        Reopens all registered files.

    ***************************************************************************/

    public void reopenAll ( )
    {
        foreach ( file; this.open_files )
        {
            file.close();
            file.open(file.path(), file.style);
        }
    }


    /***************************************************************************

        Reopens all registered files with the given path

        Params:
            file_path = path of the file to open

        Returns:
            true if the file was registered and reopened, false otherwise.

    ***************************************************************************/

    public bool reopenFile ( cstring file_path )
    {
        // It might be the case that we have several files registered with the
        // same path. We need to reopen all of them.
        bool reopened;

        foreach (file; this.open_files)
        {
            this.path_buffer.reset();
            sformat(this.path_buffer, "{}{}", this.cwd, file.path());

            // Check both relative and absolute paths
            if (file.path() == file_path || this.path_buffer[] == file_path)
            {
                file.close();
                file.open(file.path(), file.style);
                reopened = true;
            }
        }

        return reopened;
    }
}
