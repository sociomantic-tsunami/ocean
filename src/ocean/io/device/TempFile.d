/******************************************************************************
 *
 * Copyright:
 *     Copyright &copy; 2007 Daniel Keep.
 *     Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
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

import Path = ocean.io.Path;
import ocean.math.random.Kiss : Kiss;
import ocean.io.device.Device : Device;
import ocean.io.device.File;
import ocean.stdc.stringz : toStringz;

/******************************************************************************
 ******************************************************************************/

version( Win32 )
{
    import ocean.sys.Common : DWORD, LONG, MAX_PATH, PCHAR, CP_UTF8;

    enum : DWORD { FILE_FLAG_OPEN_REPARSE_POINT = 0x00200000 }

    version( Win32SansUnicode )
    {
        import ocean.sys.Common :
            GetVersionExA, OSVERSIONINFO,
            FILE_FLAG_DELETE_ON_CLOSE,
            GetTempPathA;

        istring GetTempPath()
        {
            auto len = GetTempPathA(0, null);
            if( len == 0 )
                throw new Exception("could not obtain temporary path");

            auto result = new char[len+1];
            len = GetTempPathA(len+1, result.ptr);
            if( len == 0 )
                throw new Exception("could not obtain temporary path");
            return Path.standard(result[0..len]);
        }
    }
    else
    {
        import ocean.sys.Common :
            WideCharToMultiByte,
            GetVersionExW, OSVERSIONINFO,
            FILE_FLAG_DELETE_ON_CLOSE,
            GetTempPathW;

        istring GetTempPath()
        {
            auto len = GetTempPathW(0, null);
            if( len == 0 )
                throw new Exception("could not obtain temporary path");

            auto result = new wchar[len+1];
            len = GetTempPathW(len+1, result.ptr);
            if( len == 0 )
                throw new Exception("could not obtain temporary path");

            auto dir = new char [len * 3];
            auto i = WideCharToMultiByte (CP_UTF8, 0, result.ptr, len,
                                          cast(PCHAR) dir.ptr, dir.length, null, null);
            return Path.standard (dir[0..i]);
        }
    }

    // Determines if reparse points (aka: symlinks) are supported.  Support
    // was introduced in Windows Vista.
    bool reparseSupported()
    {
        OSVERSIONINFO versionInfo = void;
        versionInfo.dwOSVersionInfoSize = versionInfo.sizeof;

        void e(){throw new Exception("could not determine Windows version");}

        version( Win32SansUnicode )
        {
            if( !GetVersionExA(&versionInfo) ) e();
        }
        else
        {
            if( !GetVersionExW(&versionInfo) ) e();
        }

        return (versionInfo.dwMajorVersion >= 6);
    }
}

else version( Posix )
{
    import ocean.stdc.posix.pwd : getpwnam;
    import ocean.stdc.posix.unistd : access, getuid, lseek, unlink, W_OK;
    import ocean.stdc.posix.sys.types : off_t;
    import ocean.stdc.posix.sys.stat : stat, stat_t;
    import ocean.stdc.posix.fcntl : O_NOFOLLOW;
    import ocean.stdc.posix.stdlib : getenv;
    import ocean.stdc.string : strlen;
}

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
    /+enum Visibility : ubyte
    {
        /**
         * The temporary file will have read and write access to it restricted
         * to the current user.
         */
        User,
        /**
         * The temporary file will have read and write access available to any
         * user on the system.
         */
        World
    }+/

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

    /+enum Sensitivity : ubyte
    {
        /**
         * Transient files will be truncated to zero length immediately
         * before closure to prevent casual filesystem inspection to recover
         * their contents.
         *
         * No additional action is taken on permanent files.
         */
        None,
        /**
         * Transient files will be zeroed-out before truncation, to mask their
         * contents from more thorough filesystem inspection.
         *
         * This option is not compatible with permanent files.
         */
        Low
        /+
        /**
         * Transient files will be overwritten first with zeroes, then with
         * ones, and then with a random 32- or 64-bit pattern (dependant on
         * which is most efficient.)  The file will then be truncated.
         *
         * This option is not compatible with permanent files.
         */
        Medium
        +/
    }+/

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
    const TempStyle Transient = {Transience.Transient};
    /**
     * TempStyle for creating a permanent temporary file that only the current
     * user can access.
     */
    const TempStyle Permanent = {Transience.Permanent};

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

    version( Win32 )
    {
        private const DEFAULT_LENGTH = 6;
        private const DEFAULT_PREFIX = "~t";
        private const DEFAULT_SUFFIX = ".tmp";

        private const JUNK_CHARS =
            "abcdefghijklmnopqrstuvwxyz0123456789";

       /**********************************************************************
         *
         * Returns the path to the directory where temporary files will be
         * created.  The returned path is safe to mutate.
         *
         **********************************************************************/
        public static istring tempPath()
        {
            return GetTempPath;
        }

        /*
         * Creates a new temporary file at the given path, with the specified
         * style.
         */
        private bool openTempFile(cstring path, TempStyle style)
        {
            // TODO: Check permissions directly and throw an exception;
            // otherwise, we could spin trying to make a file when it's
            // actually not possible.

            Style filestyle = {Access.ReadWrite, Open.New,
                               Share.None, Cache.None};

            DWORD attr;

            // Set up flags
            attr = reparseSupported ? FILE_FLAG_OPEN_REPARSE_POINT : 0;
            if( style.transience == Transience.Transient )
                attr |= FILE_FLAG_DELETE_ON_CLOSE;

            if (!super.open (path, filestyle, attr))
                return false;

            _style = style;
            return true;
        }
    }
    else version( Posix )
    {
        private const DEFAULT_LENGTH = 6;
        private const DEFAULT_PREFIX = ".tmp";

        // Use "~" to work around a bug in DMD where it elides empty constants
        private const DEFAULT_SUFFIX = "~";

        private const JUNK_CHARS =
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            "abcdefghijklmnopqrstuvwxyz0123456789";

       /**********************************************************************
         *
         * Returns the path to the directory where temporary files will be
         * created.  The returned path is safe to mutate.
         *
         **********************************************************************/
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
                auto parentz = toStringz(Path.parse(path.dup).path);

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
                    if( unlink(toStringz(path)) == -1 )
                        error("could not remove transient file");
                }

                _style = style;

                return true;
            }
        }
    }
    else
    {
        static assert(false, "Unsupported platform");
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
            assert(JUNK_CHARS.length < uint.max);
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

version( TempFile_SelfTest ):

import ocean.io.Console : Cin;
import ocean.io.Stdout_tango : Stdout;

void main()
{
    Stdout(r"
Please ensure that the transient file no longer exists once the TempFile
object is destroyed, and that the permanent file does.  You should also check
the following on both:

 * the file should be owned by you,
 * the owner should have read and write permissions,
 * no other permissions should be set on the file.

For POSIX systems:

 * the temp directory should be owned by either root or you,
 * if anyone other than root or you can write to it, the sticky bit should be
   set,
 * if the directory is writable by anyone other than root or the user, and the
   sticky bit is *not* set, then creating the temporary file should fail.

You might want to delete the permanent one afterwards, too. :)")
    .newline;

    Stdout.formatln("Creating a transient file:");
    {
        scope tempFile = new TempFile(/*TempFile.UserPermanent*/);

        Stdout.formatln(" .. path: {}", tempFile);

        tempFile.write("Transient temp file.");

        auto buffer = new char[1023];
        tempFile.seek(0);
        buffer = buffer[0..tempFile.read(buffer)];

        Stdout.formatln(" .. contents: \"{}\"", buffer);

        Stdout(" .. press Enter to destroy TempFile object.").newline;
        Cin.copyln();
    }

    Stdout.newline;

    Stdout.formatln("Creating a permanent file:");
    {
        scope tempFile = new TempFile(TempFile.Permanent);

        Stdout.formatln(" .. path: {}", tempFile);

        tempFile.write("Permanent temp file.");

        auto buffer = new char[1023];
        tempFile.seek(0);
        buffer = buffer[0..tempFile.read(buffer)];

        Stdout.formatln(" .. contents: \"{}\"", buffer);

        Stdout(" .. press Enter to destroy TempFile object.").flush;
        Cin.copyln();
    }

    Stdout("\nDone.").newline;
}


