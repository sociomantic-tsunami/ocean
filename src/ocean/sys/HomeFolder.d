/*******************************************************************************

        Copyright:
            Copyright (c) 2006-2009 Lars Ivar Igesund, Thomas Kühne,
              Grzegorz Adam Hankiewicz, sleek
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version:
            Initial release: December 2006
            Updated and readded: August 2009

        Authors:
            Lars Ivar Igesund, Thomas Kühne,
            Grzegorz Adam Hankiewicz, sleek

*******************************************************************************/

module ocean.sys.HomeFolder;

import ocean.transition;

import TextUtil = ocean.text.Util;
import Path = ocean.io.Path;
import ocean.sys.Environment;

version (Posix)
{
    import ocean.core.Exception_tango;
    import ocean.stdc.stdlib;
    import ocean.stdc.posix.pwd;
    import ocean.stdc.errno;

    private extern (C) size_t strlen (in char *);
}


/******************************************************************************

  Returns the home folder set in the current environment.

******************************************************************************/

char[] homeFolder()
{
    return Path.standard(Environment.get("HOME").dup);
}

version (Posix)
{

    /******************************************************************************

        Performs tilde expansion in paths.

        There are two ways of using tilde expansion in a path. One
        involves using the tilde alone or followed by a path separator. In
        this case, the tilde will be expanded with the value of the
        environment variable <i>HOME</i>.  The second way is putting
        a username after the tilde (i.e. <tt>~john/Mail</tt>). Here,
        the username will be searched for in the user database
        (i.e. <tt>/etc/passwd</tt> on Unix systems) and will expand to
        whatever path is stored there.  The username is considered the
        string after the tilde ending at the first instance of a path
        separator.

        Note that using the <i>~user</i> syntax may give different
        values from just <i>~</i> if the environment variable doesn't
        match the value stored in the user database.

        When the environment variable version is used, the path won't
        be modified if the environment variable doesn't exist or it
        is empty. When the database version is used, the path won't be
        modified if the user doesn't exist in the database or there is
        not enough memory to perform the query.

        Returns: inputPath with the tilde expanded, or just inputPath
        if it could not be expanded.

        Throws: OutOfMemoryException if there is not enough memory to
                perform the database lookup for the <i>~user</i> syntax.

        Examples:
        -----
        import ocean.sys.HomeFolder;

        void processFile(char[] filename)
        {
             char[] path = expandTilde(filename);
            ...
        }
        -----

        -----
        import ocean.sys.HomeFolder;

        const char[] RESOURCE_DIR_TEMPLATE = "~/.applicationrc";
        char[] RESOURCE_DIR;    // This gets expanded below.

        static this()
        {
            RESOURCE_DIR = expandTilde(RESOURCE_DIR_TEMPLATE);
        }
        -----
    ******************************************************************************/

    cstring expandTilde (cstring inputPath)
    {
            // Return early if there is no tilde in path.
            if (inputPath.length < 1 || inputPath[0] != '~')
                return inputPath;

            if (inputPath.length == 1 || inputPath[1] == '/')
                return expandFromEnvironment(inputPath);
            else
                return expandFromDatabase(inputPath);
    }

    /*******************************************************************************

            Replaces the tilde from path with the environment variable
            HOME.

    ******************************************************************************/

    private cstring expandFromEnvironment(cstring path)
    in
    {
        assert(path.length >= 1);
        assert(path[0] == '~');
    }
    body
    {
        // Get HOME and use that to replace the tilde.
        char[] home = homeFolder;
        if (home is null)
            return path;

        if (home[$-1] == '/')
            home = home[0..$-1];

        return Path.join(home, path[1..$]);

    }

    /*******************************************************************************

            Replaces the tilde from path with the path from the user
            database.

    ******************************************************************************/

    private cstring expandFromDatabase(cstring path)
    {
        assert(path.length > 2 || (path.length == 2 && path[1] != '/'));
        assert(path[0] == '~');

        // Extract username, searching for path separator.
        cstring username;
        auto last_char = TextUtil.locate(path, '/');

        if (last_char == path.length)
        {
            username = path[1..$] ~ '\0';
        }
        else
        {
            username = path[1..last_char] ~ '\0';
        }

        assert(last_char > 1);

        // Reserve C memory for the getpwnam_r() function.
        passwd result;
        int extra_memory_size = 5 * 1024;
        void* extra_memory;

        scope (exit) if(extra_memory) ocean.stdc.stdlib.free(extra_memory);

        while (1)
        {
            extra_memory = ocean.stdc.stdlib.malloc(extra_memory_size);
            if (extra_memory is null)
                throw new OutOfMemoryException("Not enough memory for user lookup in tilde expansion.", __LINE__);

            // Obtain info from database.
            passwd *verify;
            ocean.stdc.errno.errno(0);
            if (getpwnam_r(username.ptr, &result, cast(char*)extra_memory, extra_memory_size,
                &verify) == 0)
            {
                // Failure if verify doesn't point at result.
                if (verify == &result)
                {
                    auto pwdirlen = strlen(result.pw_dir);

                    path = Path.join(result.pw_dir[0..pwdirlen].dup, path[last_char..$]);
                }

                return path;
            }

            if (ocean.stdc.errno.errno() != ERANGE)
                throw new OutOfMemoryException("Not enough memory for user lookup in tilde expansion.", __LINE__);

            // extra_memory isn't large enough
            ocean.stdc.stdlib.free(extra_memory);
            extra_memory_size *= 2;
        }
    }

}

/*******************************************************************************

*******************************************************************************/

unittest
{
    version (Posix)
    {
        // Retrieve the current home variable.
        auto home = Environment.get("HOME");

        // Testing when there is no environment variable.
        Environment.set("HOME", null);
        assert(expandTilde("~/") == "~/");
        assert(expandTilde("~") == "~");

        // Testing when an environment variable is set.
        Environment.set("HOME", "ocean/test");
        assert (Environment.get("HOME") == "ocean/test");

        assert(expandTilde("~/") == "ocean/test/");
        assert(expandTilde("~") == "ocean/test");

        // The same, but with a variable ending in a slash.
        Environment.set("HOME", "ocean/test/");
        assert(expandTilde("~/") == "ocean/test/");
        assert(expandTilde("~") == "ocean/test");

        // Recover original HOME variable before continuing.
        if (home)
            Environment.set("HOME", home);
        else
            Environment.set("HOME", null);

        // Test user expansion for root. Are there unices without /root?
        assert(expandTilde("~root") == "/root" || expandTilde("~root") == "/var/root");
        assert(expandTilde("~root/") == "/root/" || expandTilde("~root") == "/var/root");
        assert(expandTilde("~Idontexist/hey") == "~Idontexist/hey");
    }
}
