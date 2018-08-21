/******************************************************************************
 *
 * Copyright:
 *     Copyright &copy; 2007 Daniel Keep.
 *     Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
 *     All rights reserved.
 *
 * License:
 *     Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
 *     See LICENSE_TANGO.txt for details.
 *
 * Version:
 *     Dec 2007: Initial release$(BR)
 *     May 2009: Inherit File
 *
 * Authors: Daniel Keep
 *
 * Credits:
 *     Thanks to John Reimer for helping test this module under Linux.
 *
 *
 ******************************************************************************/

module ocean.io.device.TempFile;

import ocean.transition;
import ocean.core.Verify;

import Path = ocean.io.Path;
import ocean.math.random.Kiss : Kiss;
import ocean.io.device.Device : Device;
import ocean.io.device.File;
import ocean.text.util.StringC;

import core.sys.posix.pwd : getpwnam;
import core.sys.posix.unistd : access, getuid, lseek, unlink, W_OK;
import ocean.stdc.posix.sys.types : off_t;
import ocean.stdc.posix.sys.stat : stat, stat_t;
import ocean.stdc.posix.fcntl : O_NOFOLLOW;
import core.sys.posix.stdlib : getenv;
import ocean.stdc.string : strlen;

/******************************************************************************
 *
 * The TempFile class aims to provide a safe way of creating and destroying
 * temporary files.  The TempFile class will automatically close temporary
 * files when the object is destroyed, so it is recommended that you make
 * appropriate use of scoped destruction.
 *
 * Temporary files can be created with one of several styles, much like normal
 * Files.  TempFile styles have the following properties:
 *
 * $(UL
 * $(LI $(B Transience): this determines whether the file should be destroyed
 * as soon as it is closed (transient,) or continue to persist even after the
 * application has terminated (permanent.))
 * )
 *
 * Eventually, this will be expanded to give you greater control over the
 * temporary file's properties.
 *
 * For the typical use-case (creating a file to temporarily store data too
 * large to fit into memory,) the following is sufficient:
 *
 * -----
 *  {
 *      scope temp = new TempFile;
 *
 *      // Use temp as a normal conduit; it will be automatically closed when
 *      // it goes out of scope.
 *  }
 * -----
 *
 * Important:
 * It is recommended that you $(I do not) use files created by this class to
 * store sensitive information.  There are several known issues with the
 * current implementation that could allow an attacker to access the contents
 * of these temporary files.
 *
 * Todo: Detail security properties and guarantees.
 *
 ******************************************************************************/

class TempFile : File
{
    /**************************************************************************
     *
     * This enumeration is used to control whether the temporary file should
     * persist after the TempFile object has been destroyed.
     *
     **************************************************************************/

    enum Transience : ubyte
    {
        /**
         * The temporary file should be destroyed along with the owner object.
         */
        Transient,
        /**
         * The temporary file should persist after the object has been
         * destroyed.
         */
        Permanent
    }

    /**************************************************************************
     *
     * This structure is used to determine how the temporary files should be
     * opened and used.
     *
     **************************************************************************/
    align(1) struct TempStyle
    {
        align(1):
        //Visibility visibility;      ///
        Transience transience;        ///
        //Sensitivity sensitivity;    ///
        //Share share;                ///
        //Cache cache;                ///
        ubyte attempts = 10;          ///
    }

    /**
     * TempStyle for creating a transient temporary file that only the current
     * user can access.
     */
    static immutable TempStyle Transient = {Transience.Transient};
    /**
     * TempStyle for creating a permanent temporary file that only the current
     * user can access.
     */
    static immutable TempStyle Permanent = {Transience.Permanent};

    // Path to the temporary file
    private istring _path;

    // TempStyle we've opened with
    private TempStyle _style;

    ///
    this(TempStyle style = TempStyle.init)
    {
        open (style);
    }

    ///
    this(istring prefix, TempStyle style = TempStyle.init)
    {
        open (prefix, style);
    }

    /**************************************************************************
     *
     * Indicates the style that this TempFile was created with.
     *
     **************************************************************************/
    TempStyle tempStyle()
    {
        return _style;
    }

    /*
     * Creates a new temporary file with the given style.
     */
    private void open (TempStyle style)
    {
        open (tempPath, style);
    }

    private void open (istring prefix, TempStyle style)
    {
        for( ubyte i=style.attempts; i--; )
        {
            if( openTempFile(Path.join(prefix, randomName), style) )
                return;
        }

        error("could not create temporary file");
    }

    private static immutable DEFAULT_LENGTH = 6;
    private static immutable DEFAULT_PREFIX = ".tmp";

    // Use "~" to work around a bug in DMD where it elides empty constants
    private static immutable DEFAULT_SUFFIX = "~";

    private static immutable JUNK_CHARS =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

    /***************************************************************************
     *
     * Returns the path to the directory where temporary files will be
     * created.  The returned path is safe to mutate.
     *
     **************************************************************************/

    public static istring tempPath()
    {
        // Check for TMPDIR; failing that, use /tmp
        char* ptr = getenv ("TMPDIR".ptr);
        if (ptr is null)
            return "/tmp/";
        else
            return idup(ptr[0 .. strlen (ptr)]);
    }

    /*
     * Creates a new temporary file at the given path, with the specified
     * style.
     */
    private bool openTempFile(cstring path, TempStyle style)
    {
        // Check suitability
        {
            mstring path_mut = Path.parse(path.dup).path;
            enableStomping(path_mut);
            auto parentz = StringC.toCString(path_mut);

            // Make sure we have write access
            if( access(parentz, W_OK) == -1 )
                error("do not have write access to temporary directory");

            // Get info on directory
            stat_t sb;
            if( stat(parentz, &sb) == -1 )
                error("could not stat temporary directory");

            // Get root's UID
            auto pwe = getpwnam("root".ptr);
            if( pwe is null ) error("could not get root's uid");
            auto root_uid = pwe.pw_uid;

            // Make sure either we or root are the owner
            if( !(sb.st_uid == root_uid || sb.st_uid == getuid) )
                error("temporary directory owned by neither root nor user");

            // Check to see if anyone other than us can write to the dir.
            if( (sb.st_mode & Octal!("22")) != 0 && (sb.st_mode & Octal!("1000")) == 0 )
                error("sticky bit not set on world-writable directory");
        }

        // Create file
        {
            Style filestyle = {Access.ReadWrite, Open.New,
                               Share.None, Cache.None};

            auto addflags = O_NOFOLLOW;

            if (!super.open(path, filestyle, addflags, Octal!("600")))
                return false;

            if( style.transience == Transience.Transient )
            {
                // BUG TODO: check to make sure the path still points
                // to the file we opened.  Pity you can't unlink a file
                // descriptor...

                // NOTE: This should be an exception and not simply
                // returning false, since this is a violation of our
                // guarantees.
                if( unlink((path ~ "\0").ptr) == -1 )
                    error("could not remove transient file");
            }

            _style = style;

            return true;
        }
    }

    /*
     * Generates a new random file name, sans directory.
     */
    private istring randomName(uint length=DEFAULT_LENGTH,
            istring prefix=DEFAULT_PREFIX,
            istring suffix=DEFAULT_SUFFIX)
    {
        auto junk = new char[length];
        scope(exit) delete junk;

        foreach( ref c ; junk )
        {
            verify(JUNK_CHARS.length < uint.max);
            c = JUNK_CHARS[Kiss.instance.toInt(cast(uint) $)];
        }

        return prefix ~ assumeUnique(junk) ~ suffix;
    }

    override void detach()
    {
        static assert( !is(Sensitivity) );
        super.detach();
    }
}
