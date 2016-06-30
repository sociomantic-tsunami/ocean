/*******************************************************************************

    Config extension to drop privileges.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.ext.DropPrivilegesExt;

import ocean.util.app.model.IApplicationExtension;
import ClassFiller = ocean.util.config.ClassFiller;
import ocean.util.app.ext.model.IConfigExtExtension;

import ocean.transition;
import ocean.stdc.posix.unistd : setuid, setgid;
import ocean.stdc.posix.pwd;
import ocean.stdc.string;
import ocean.stdc.stringz;
import ocean.stdc.posix.grp;
import ocean.stdc.posix.unistd;
import ocean.stdc.errno;

/*******************************************************************************

    Config extension to drop privileges files.

    User and group must be specified in the configfile under the PERMISSION
    section. If root starts the program, it will drop privileges after
    reading the config. If it is started with the configured user,
    nothing happens. If it is started as a different user, it will exit
    with an error.

    Config example:
    ----
    [PERMISSIONS]
    user = john
    group = john
    ----

*******************************************************************************/

class DropPrivilegesExt : IConfigExtExtension
{
    static class Config
    {
        /***********************************************************************

            User to run as, mandatory setting

        ***********************************************************************/

        ClassFiller.Required!(istring) user;

        /***********************************************************************

            Group to run as, mandatory setting

        ***********************************************************************/

        ClassFiller.Required!(istring) group;
    }


    /***************************************************************************

        Extension order. This extension uses -5_000 because it should be
        called pretty early, but after the ConfigExt extension.

        Returns:
            the extension order

    ***************************************************************************/

    public override int order ( )
    {
        return -5000;
    }


    /***************************************************************************

        Function executed before the program runs.

        Params:
            app = the application instance that will run
            config = configuration instance to be filled

    ***************************************************************************/

    override void processConfig ( IApplication app, ConfigParser config )
    {
        auto conf = ClassFiller.fill!(Config)("PERMISSIONS", config);

        if ( conf.group() == "root" ) throw new Exception("Group can not be root!");
        if ( conf.user()  == "root" ) throw new Exception("User can not be root!");

        setGroup(conf.group());
        setUser(conf.user());
    }


    /***************************************************************************

        Change user permissions to usr

        Params:
            usr = User to become

    ***************************************************************************/

    private void setUser ( istring usr )
    {
        passwd* result;
        passwd passwd_buf;
        char[50] user_buf;
        char[2048] buf;

        auto cuser = toStringz(usr, user_buf);

        auto res = getpwnam_r(cuser, &passwd_buf,
                              buf.ptr, buf.length, &result);

        if ( result == null )
        {
            if ( res == 0 )
            {
                throw new Exception("User " ~ usr ~ " not found!");
            }
            else
            {
                char* err = strerror(res);
                auto msg = "Error while getting user " ~ usr ~
                    ": " ~ fromStringz(err);
                throw new Exception(assumeUnique(msg));
            }
        }

        if ( result.pw_uid == geteuid() ) return;

        res = setuid(result.pw_uid);

        if ( res != 0 )
        {
            char* err = strerror(errno());
            auto msg = "Failed to set process user id to " ~ usr
                ~ ": " ~ fromStringz(err);
            throw new Exception(assumeUnique(msg));
        }
    }


    /***************************************************************************

        Change group permissions to grp

        Params:
            grp = Group to become

    ***************************************************************************/

    private void setGroup ( istring grp )
    {
        group* result;
        group group_buf;
        char[50] grp_buf;
        char[2048] buf;

        auto cgroup = toStringz(grp, grp_buf);

        auto res = getgrnam_r(cgroup, &group_buf, buf.ptr, buf.length, &result);

        if ( result == null )
        {
            if ( res == 0 )
            {
                throw new Exception("Group " ~ grp ~ " not found!");
            }
            else
            {
                char* err = strerror(res);
                auto msg = "Error while getting group " ~ grp ~
                    ": " ~ fromStringz(err);
                throw new Exception(assumeUnique(msg));
            }
        }

        if ( result.gr_gid == getegid() ) return;

        res = setgid(result.gr_gid);

        if ( res != 0 )
        {
            char* err = strerror(errno());
            auto msg = "Failed to set process user group to " ~ grp
                ~ ": " ~ fromStringz(err);
            throw new Exception(assumeUnique(msg));
        }
    }

    /***************************************************************************

        Function executed before the configuration files are parsed.
        Only present to satisfy the interface

        Params:
            app = application instance
            config = configuration parser

    ***************************************************************************/

    override void preParseConfig ( IApplication app, ConfigParser config ) {}


    /***************************************************************************

        Function to filter the list of configuration files to parse.
        Only present to satisfy the interface

        Params:
            app = application instance
            config = configuration parser
            files = current list of configuration files to parse

        Returns:
            new list of configuration files to parse

    ***************************************************************************/

    override istring[] filterConfigFiles ( IApplication app, ConfigParser config,
                                  istring[] files ) { return files; }
}
