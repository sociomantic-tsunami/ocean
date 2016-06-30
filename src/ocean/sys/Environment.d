/*******************************************************************************

        Copyright:
            Copyright (c) 2007 Tango contributors.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Feb 2007: Initial release

        Authors: Deewiant, Maxter, Gregor, Kris

*******************************************************************************/

module ocean.sys.Environment;

import ocean.transition;

import ocean.sys.Common;

import ocean.io.Path,
       ocean.io.FilePath_tango;

import ocean.core.Exception_tango;

import ocean.io.model.IFile;

import Text = ocean.text.Util;

/*******************************************************************************

        Platform decls

*******************************************************************************/

version (darwin)
{
    extern (C) char*** _NSGetEnviron();
    private char** environ;

    static this ()
    {
        environ = *_NSGetEnviron();
    }
}
else
{
    private
    {
        mixin(global("extern (C) extern char** environ"));
    }
}

import ocean.stdc.posix.stdlib;
import ocean.stdc.string;

/*******************************************************************************

        Exposes the system Environment settings, along with some handy
        utilities

*******************************************************************************/

struct Environment
{
        public alias cwd directory;

        /***********************************************************************

                Throw an exception

        ***********************************************************************/

        private static void exception (istring msg)
        {
                throw new PlatformException (msg);
        }

        /***********************************************************************

            Returns an absolute version of the provided path, where cwd is used
            as the prefix.

            The provided path is returned as is if already absolute.

        ***********************************************************************/

        static istring toAbsolute(mstring path)
        {
            scope fp = new FilePath(path);
            if (fp.isAbsolute)
                return idup(path);

            fp.absolute(cwd);
            return fp.toString;
        }

        /***********************************************************************

                Returns the full path location of the provided executable
                file, rifling through the PATH as necessary.

                Returns null if the provided filename was not found

        ***********************************************************************/

        static FilePath exePath (cstring file)
        {
                auto bin = new FilePath (file);

                // is this a directory? Potentially make it absolute
                if (bin.isChild && !bin.isAbsolute)
                    return bin.absolute (cwd);

                // rifle through the path (after converting to standard format)
                foreach (_pe; Text.patterns (standard(get("PATH").dup), FileConst.SystemPathString))
                {
                    auto pe = assumeUnique(_pe); // only acessible via foreach args

                    if (bin.path(pe).exists)
                    {
                        stat_t stats;
                        stat(bin.cString.ptr, &stats);
                        if (stats.st_mode & Octal!("100"))
                            return bin;
                    }
                }
                return null;
        }

        /***********************************************************************

                Posix implementation

        ***********************************************************************/

        version (Posix)
        {
                /**************************************************************

                        Returns the provided 'def' value if the variable
                        does not exist

                **************************************************************/

                static istring get (cstring variable, istring def = null)
                {
                        char* ptr = getenv ((variable ~ '\0').ptr);

                        if (ptr is null)
                            return def;

                        return idup(ptr[0 .. strlen(ptr)]);
                }

                /**************************************************************

                        clears the variable, if value is null or empty

                **************************************************************/

                static void set (cstring variable, cstring value = null)
                {
                        int result;

                        if (value.length is 0)
                            unsetenv ((variable ~ '\0').ptr);
                        else
                           result = setenv ((variable ~ '\0').ptr, (value ~ '\0').ptr, 1);

                        if (result != 0)
                            exception (SysError.lastMsg);
                }

                /**************************************************************

                        Get all set environment variables as an associative
                        array.

                **************************************************************/

                static istring[istring] get ()
                {
                        istring[istring] arr;

                        for (char** p = environ; *p; ++p)
                            {
                            size_t k = 0;
                            char* str = *p;

                            while (*str++ != '=')
                                   ++k;
                            istring key = idup((*p)[0..k]);

                            k = 0;
                            char* val = str;
                            while (*str++)
                                   ++k;
                            arr[key] = idup(val[0 .. k]);
                            }

                        return arr;
                }

                /**************************************************************

                        Set the current working directory

                **************************************************************/

                static void cwd (cstring path)
                {
                        char[512] tmp = void;
                        tmp [path.length] = 0;
                        tmp[0..path.length] = path;

                        if (ocean.stdc.posix.unistd.chdir (tmp.ptr))
                            exception ("Failed to set current directory");
                }

                /**************************************************************

                        Get the current working directory

                **************************************************************/

                static istring cwd ()
                {
                        char[512] tmp = void;

                        char *s = ocean.stdc.posix.unistd.getcwd (tmp.ptr, tmp.length);
                        if (s is null)
                            exception ("Failed to get current directory");

                        auto path = s[0 .. strlen(s)+1].dup;
                        if (path[$-2] is '/') // root path has the slash
                            path.length = path.length-1;
                        else
                            path[$-1] = '/';
                        return assumeUnique(path);
                }
        }
}


/*******************************************************************************


*******************************************************************************/

debug (Environment)
{
        import ocean.io.Console;


        void main(istring[] args)
        {
        const istring VAR = "TESTENVVAR";
        const istring VAL1 = "VAL1";
        const istring VAL2 = "VAL2";

        assert(Environment.get(VAR) is null);

        Environment.set(VAR, VAL1);
        assert(Environment.get(VAR) == VAL1);

        Environment.set(VAR, VAL2);
        assert(Environment.get(VAR) == VAL2);

        Environment.set(VAR, null);
        assert(Environment.get(VAR) is null);

        Environment.set(VAR, VAL1);
        Environment.set(VAR, "");

        assert(Environment.get(VAR) is null);

        foreach (key, value; Environment.get)
                 Cout (key) ("=") (value).newline;

        if (args.length > 0)
           {
           auto p = Environment.exePath (args[0]);
           Cout (p).newline;
           }

        if (args.length > 1)
           {
           if (auto p = Environment.exePath (args[1]))
               Cout (p).newline;
           }
        }
}

