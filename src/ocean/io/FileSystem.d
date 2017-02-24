/*******************************************************************************

        Copyright:
            Copyright (c) 2004 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version:
            Mar 2004: Initial release
            Feb 2007: Now using mutating paths

        Authors: Kris, Chris Sauls (Win95 file support)

*******************************************************************************/

module ocean.io.FileSystem;

import ocean.transition;

import ocean.sys.Common;

import ocean.io.FilePath_tango;

import ocean.core.Exception_tango;

import ocean.io.Path : standard, native;

/*******************************************************************************

*******************************************************************************/

version (Posix)
        {
        import ocean.stdc.string;
        import core.sys.posix.unistd,
                       core.sys.posix.sys.statvfs;

        import ocean.io.device.File;
        import Integer = ocean.text.convert.Integer_tango;
        }

/*******************************************************************************

        Models an OS-specific file-system. Included here are methods to
        manipulate the current working directory, and to convert a path
        to its absolute form.

*******************************************************************************/

struct FileSystem
{
        /***********************************************************************

        ***********************************************************************/

        private static void exception (istring msg)
        {
                throw new IOException (msg);
        }

        /***********************************************************************

        ***********************************************************************/

        version (Posix)
        {
                /***************************************************************

                        List the set of root devices.

                 ***************************************************************/

                static istring[] roots ()
                {
                        version(darwin)
                        {
                            assert(0);
                        }
                        else
                        {
                            istring path = "";
                            istring[] list;
                            int spaces;

                            auto fc = new File("/etc/mtab");
                            scope (exit)
                                   fc.close;

                            auto content = new char[cast(int) fc.length];
                            fc.input.read (content);

                            for(int i = 0; i < content.length; i++)
                            {
                                if(content[i] == ' ') spaces++;
                                else if(content[i] == '\n')
                                {
                                    spaces = 0;
                                    list ~= path;
                                    path = "";
                                }
                                else if(spaces == 1)
                                {
                                    if(content[i] == '\\')
                                    {
                                        path ~= cast(char) Integer.parse(content[++i..i+3], 8u);
                                        i += 2;
                                    }
                                    else path ~= content[i];
                                }
                            }

                            return list;
                        }
                }

                /***************************************************************

                        Request how much free space in bytes is available on the
                        disk/mountpoint where folder resides.

                        If a quota limit exists for this area, that will be taken
                        into account unless superuser is set to true.

                        If a user has exceeded the quota, a negative number can
                        be returned.

                        Note that the difference between total available space
                        and free space will not equal the combined size of the
                        contents on the file system, since the numbers for the
                        functions here are calculated from the used blocks,
                        including those spent on metadata and file nodes.

                        If actual used space is wanted one should use the
                        statistics functionality of ocean.io.vfs.

                        See_also: totalSpace()

                ***************************************************************/

                static long freeSpace(char[] folder, bool superuser = false)
                {
                    scope fp = new FilePath(folder);
                    statvfs_t info;
                    int res = statvfs(fp.native.cString.ptr, &info);
                    if (res == -1)
                        exception ("freeSpace->statvfs failed:"
                                   ~ SysError.lastMsg);

                    if (superuser)
                        return cast(long)info.f_bfree *  cast(long)info.f_bsize;
                    else
                        return cast(long)info.f_bavail * cast(long)info.f_bsize;
                }

                /***************************************************************

                        Request how large in bytes the
                        disk/mountpoint where folder resides is.

                        If a quota limit exists for this area, then
                        that quota can be what will be returned unless superuser
                        is set to true. On Posix systems this distinction is not
                        made though.

                        NOTE Access to this information when _superuser is
                        set to true may only be available if the program is
                        run in superuser mode.

                        See_also: freeSpace()

                ***************************************************************/

                static long totalSpace(char[] folder, bool superuser = false)
                {
                    scope fp = new FilePath(folder);
                    statvfs_t info;
                    int res = statvfs(fp.native.cString.ptr, &info);
                    if (res == -1)
                        exception ("totalSpace->statvfs failed:"
                                   ~ SysError.lastMsg);

                    return cast(long)info.f_blocks *  cast(long)info.f_frsize;
                }
        }
}


/******************************************************************************

******************************************************************************/

debug (FileSystem)
{
        import ocean.io.Stdout_tango;

        static void foo (FilePath path)
        {
        Stdout("all: ") (path).newline;
        Stdout("path: ") (path.path).newline;
        Stdout("file: ") (path.file).newline;
        Stdout("folder: ") (path.folder).newline;
        Stdout("name: ") (path.name).newline;
        Stdout("ext: ") (path.ext).newline;
        Stdout("suffix: ") (path.suffix).newline.newline;
        }

        void main()
        {
        Stdout.formatln ("dir: {}", FileSystem.getDirectory);

        auto path = new FilePath (".");
        foo (path);

        path.set ("..");
        foo (path);

        path.set ("...");
        foo (path);

        path.set (r"/x/y/.file");
        foo (path);

        path.suffix = ".foo";
        foo (path);

        path.set ("file.bar");
        path.absolute("c:/prefix");
        foo(path);

        path.set (r"arf/test");
        foo(path);
        path.absolute("c:/prefix");
        foo(path);

        path.name = "foo";
        foo(path);

        path.suffix = ".d";
        path.name = path.suffix;
        foo(path);

        }
}
