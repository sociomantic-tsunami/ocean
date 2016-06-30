/*******************************************************************************

        Copyright:
            Copyright (c) 2005 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: March 2005

        Authors: Kris

*******************************************************************************/

module ocean.io.model.IFile;

import ocean.transition;

/*******************************************************************************

        Generic file-oriented attributes.

*******************************************************************************/

interface FileConst
{
        /***********************************************************************

                A set of file-system specific constants for file and path
                separators (chars and strings).

                Keep these constants mirrored for each OS.

        ***********************************************************************/

        version (Posix)
        {
                ///
                enum : char
                {
                        /// The current directory character.
                        CurrentDirChar = '.',

                        /// The file separator character.
                        FileSeparatorChar = '.',

                        /// The path separator character.
                        PathSeparatorChar = '/',

                        /// The system path character.
                        SystemPathChar = ':',
                }

                /// The parent directory string.
                const ParentDirString = "..";

                /// The current directory string.
                const CurrentDirString = ".";

                /// The file separator string.
                const FileSeparatorString = ".";

                /// The path separator string.
                const PathSeparatorString = "/";

                /// The system path string.
                const SystemPathString = ":";

                /// The newline string.
                const NewlineString = "\n";
        }
}

/*******************************************************************************

        Passed around during file-scanning.

*******************************************************************************/

struct FileInfo
{
        istring         path,
                        name;
        ulong           bytes;
        bool            folder,
                        hidden,
                        system;
}

