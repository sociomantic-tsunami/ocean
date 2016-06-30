/*******************************************************************************

        A more direct route to the file-system than FilePath. Use this
        if you don't need path editing features. For example, if all you
        want is to check some path exists, using this module would likely
        be more convenient than FilePath:
        ---
        if (exists ("some/file/path"))
            ...
        ---

        These functions may be less efficient than FilePath because they
        generally attach a null to the filename for each underlying O/S
        call. Use Path when you need pedestrian access to the file-system,
        and are not manipulating the path components. Use FilePath where
        path-editing or mutation is desired.

        We encourage the use of "named import" with this module, such as:
        ---
        import Path = ocean.io.Path;

        if (Path.exists ("some/file/path"))
            ...
        ---

        Also residing here is a lightweight path-parser, which splits a
        filepath into constituent components. FilePath is based upon the
        same PathParser:
        ---
        auto p = Path.parse ("some/file/path");
        auto path = p.path;
        auto name = p.name;
        auto suffix = p.suffix;
        ...
        ---

        Path normalization and pattern-matching is also hosted here via
        the normalize() and pattern() functions. See the doc towards the
        end of this module.

        Compile with -version=Win32SansUnicode to enable Win95 &amp; Win32s
        file support.

        Copyright:
            Copyright (c) 2008 Kris Bell.
            Normalization & Patterns copyright (c) 2006-2009 Max Samukha,
                Thomas Kühne, Grzegorz Adam Hankiewicz
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version:
            Mar 2008: Initial version$(BR)
            Oct 2009: Added PathUtil code

*******************************************************************************/

module ocean.io.Path;

import ocean.transition;

import ocean.sys.Common;

public  import ocean.time.Time : Time, TimeSpan;

import ocean.io.model.IFile : FileConst, FileInfo;

public  import ocean.core.Exception_tango : IOException, IllegalArgumentException;

import ocean.stdc.string : memmove;


/*******************************************************************************

        Various imports

*******************************************************************************/

version (Posix)
        {
        import ocean.stdc.stdio;
        import ocean.stdc.string;
        import ocean.stdc.posix.utime;
        import ocean.stdc.posix.dirent;
        }


/*******************************************************************************

        Wraps the O/S specific calls with a D API. Note that these accept
        null-terminated strings only, which is why it's not public. We need
        this declared first to avoid forward-reference issues.

*******************************************************************************/

package struct FS
{
        /***********************************************************************

                TimeStamp information. Accurate to whatever the F/S supports.

        ***********************************************************************/

        struct Stamps
        {
                Time created;  /// Time created.
                Time accessed; /// Last time accessed.
                Time modified; /// Last time modified.
        }

        /***********************************************************************

                Some fruct glue for directory listings.

        ***********************************************************************/

        struct Listing
        {
                cstring folder;
                bool   allFiles;

                int opApply (int delegate(ref FileInfo) dg)
                {
                        char[256] tmp = void;
                        auto path = strz (folder, tmp);

                        return list (path, dg, allFiles);
                }
        }

        /***********************************************************************

                Throw an exception using the last known error.

        ***********************************************************************/

        static void exception (cstring filename)
        {
                exception (filename[0..$-1] ~ ": ", SysError.lastMsg);
        }

        /***********************************************************************

                Throw an IO exception.

        ***********************************************************************/

        static void exception (cstring prefix, cstring error)
        {
                throw new IOException (idup(prefix ~ error));
        }

        /***********************************************************************

                Return an adjusted path such that non-empty instances always
                have a trailing separator.

                Note: Allocates memory where path is not already terminated.

        ***********************************************************************/

        static cstring padded (cstring path, char c = '/')
        {
                if (path.length && path[$-1] != c)
                    path = path ~ c;
                return path;
        }

        /***********************************************************************

                Return an adjusted path such that non-empty instances always
                have a leading separator.

                Note: Allocates memory where path is not already terminated.

        ***********************************************************************/

        static cstring paddedLeading (cstring path, char c = '/')
        {
                if (path.length && path[0] != c)
                    path = c ~ path;
                return path;
        }

        /***********************************************************************

                Return an adjusted path such that non-empty instances do not
                have a trailing separator.

        ***********************************************************************/

        static cstring stripped (cstring path, char c = '/')
        {
                if (path.length && path[$-1] is c)
                    path = path [0 .. $-1];
                return path;
        }

        /***********************************************************************

                Join a set of path specs together. A path separator is
                potentially inserted between each of the segments.

                Note: Allocates memory.

        ***********************************************************************/

        static mstring join (Const!(char[])[] paths...)
        {
                mstring result;

                if (paths.length)
                {
                    result ~= stripped(paths[0]);

                    foreach (path; paths[1 .. $-1])
                        result ~= paddedLeading (stripped(path));

                    result ~= paddedLeading(paths[$-1]);

                   return result;
                }

                return null;
        }

        /***********************************************************************

                Append a terminating null onto a string, cheaply where
                feasible.

                Note: Allocates memory where the dst is too small.

        ***********************************************************************/

        static mstring strz (cstring src, mstring dst)
        {
                auto i = src.length + 1;
                if (dst.length < i)
                    dst.length = i;
                dst [0 .. i-1] = src;
                dst[i-1] = 0;
                return dst [0 .. i];
        }

        /***********************************************************************

                Posix-specific code.

        ***********************************************************************/

        version (Posix)
        {
                /***************************************************************

                        Get info about this path.

                ***************************************************************/

                private static uint getInfo (cstring name, ref stat_t stats)
                {
                        if (posix.stat (name.ptr, &stats))
                            exception (name);

                        return stats.st_mode;
                }

                /***************************************************************

                        Return whether the file or path exists.

                ***************************************************************/

                static bool exists (cstring name)
                {
                        stat_t stats = void;
                        return posix.stat (name.ptr, &stats) is 0;
                }

                /***************************************************************

                        Return the file length (in bytes.)

                ***************************************************************/

                static ulong fileSize (cstring name)
                {
                        stat_t stats = void;

                        getInfo (name, stats);
                        return cast(ulong) stats.st_size;
                }

                /***************************************************************

                        Is this file writable?

                ***************************************************************/

                static bool isWritable (cstring name)
                {
                        stat_t stats = void;

                        return (getInfo(name, stats) & O_RDONLY) is 0;
                }

                /***************************************************************

                        Is this file actually a folder/directory?

                ***************************************************************/

                static bool isFolder (cstring name)
                {
                        stat_t stats = void;

                        return (getInfo(name, stats) & S_IFMT) is S_IFDIR;
                }

                /***************************************************************

                        Is this a normal file?

                ***************************************************************/

                static bool isFile (cstring name)
                {
                        stat_t stats = void;

                        return (getInfo(name, stats) & S_IFMT) is S_IFREG;
                }

                /***************************************************************

                        Return timestamp information.

                        Timestamps are returns in a format dictated by the
                        file-system. For example NTFS keeps UTC time,
                        while FAT timestamps are based on the local time.

                ***************************************************************/

                static Stamps timeStamps (cstring name)
                {
                        static Time convert (typeof(stat_t.st_mtime) secs)
                        {
                                return Time.epoch1970 +
                                       TimeSpan.fromSeconds(secs);
                        }

                        stat_t stats = void;
                        Stamps time  = void;

                        getInfo (name, stats);

                        time.modified = convert (stats.st_mtime);
                        time.accessed = convert (stats.st_atime);
                        time.created  = convert (stats.st_ctime);
                        return time;
                }

                /***************************************************************

                        Set the accessed and modified timestamps of the
                        specified file.

                ***************************************************************/

                static void timeStamps (cstring name, Time accessed, Time modified)
                {
                        utimbuf time = void;
                        time.actime = (accessed - Time.epoch1970).seconds;
                        time.modtime = (modified - Time.epoch1970).seconds;
                        if (utime (name.ptr, &time) is -1)
                            exception (name);
                }

                /***********************************************************************

                        Transfer the content of another file to this one. Returns a
                        reference to this class on success, or throws an IOException
                        upon failure.

                        Note: Allocates a memory buffer.

                ***********************************************************************/

                static void copy (cstring source, mstring dest)
                {
                        auto src = posix.open (source.ptr, O_RDONLY, Octal!("640"));
                        scope (exit)
                               if (src != -1)
                                   posix.close (src);

                        auto dst = posix.open (dest.ptr, O_CREAT | O_RDWR, Octal!("660"));
                        scope (exit)
                               if (dst != -1)
                                   posix.close (dst);

                        if (src is -1 || dst is -1)
                            exception (source);

                        // copy content
                        ubyte[] buf = new ubyte [16 * 1024];
                        auto read = posix.read (src, buf.ptr, buf.length);
                        while (read > 0)
                              {
                              auto p = buf.ptr;
                              do {
                                 auto written = posix.write (dst, p, read);
                                 p += written;
                                 read -= written;
                                 if (written is -1)
                                     exception (dest);
                                 } while (read > 0);
                              read = posix.read (src, buf.ptr, buf.length);
                              }
                        if (read is -1)
                            exception (source);

                        // copy timestamps
                        stat_t stats;
                        if (posix.stat (source.ptr, &stats))
                            exception (source);

                        utimbuf utim;
                        utim.actime = stats.st_atime;
                        utim.modtime = stats.st_mtime;
                        if (utime (dest.ptr, &utim) is -1)
                            exception (dest);
                }

                /***************************************************************

                        Remove the file/directory from the file-system.
                        Returns true on success - false otherwise.

                ***************************************************************/

                static bool remove (cstring name)
                {
                        return ocean.stdc.stdio.remove(name.ptr) != -1;
                }

                /***************************************************************

                       Change the name or location of a file/directory.

                ***************************************************************/

                static void rename (cstring src, cstring dst)
                {
                        if (ocean.stdc.stdio.rename (src.ptr, dst.ptr) is -1)
                            exception (src);
                }

                /***************************************************************

                        Create a new file.

                ***************************************************************/

                static void createFile (cstring name)
                {
                        int fd;

                        fd = posix.open (name.ptr, O_CREAT | O_WRONLY | O_TRUNC, Octal!("660"));
                        if (fd is -1)
                            exception (name);

                        if (posix.close(fd) is -1)
                            exception (name);
                }

                /***************************************************************

                        Create a new directory.

                ***************************************************************/

                static void createFolder (cstring name)
                {
                        if (posix.mkdir (name.ptr, Octal!("777")))
                            exception (name);
                }

                /***************************************************************

                        List the set of filenames within this folder.

                        Each path and filename is passed to the provided
                        delegate, along with the path prefix and whether
                        the entry is a folder or not.

                        Note: Allocates and reuses a small memory buffer.

                ***************************************************************/

                static int list (cstring folder, int delegate(ref FileInfo) dg, bool all=false)
                {
                        int             ret;
                        DIR*            dir;
                        dirent          entry;
                        dirent*         pentry;
                        stat_t          sbuf;
                        mstring          prefix;
                        mstring          sfnbuf;

                        dir = ocean.stdc.posix.dirent.opendir (folder.ptr);
                        if (! dir)
                              return ret;

                        scope (exit)
                        {
                            ocean.stdc.posix.dirent.closedir (dir);
                            delete sfnbuf;

                            // only delete when we dupped it
                            if (folder[$-2] != '/')
                                delete prefix;
                        }

                        // ensure a trailing '/' is present
                        if (folder[$-2] != '/')
                        {
                            prefix = folder.dup;
                            prefix[$-1] = '/';
                        }
                        else
                            prefix = folder[0 .. $-1].dup;

                        // prepare our filename buffer
                        sfnbuf = new char[prefix.length + 256];
                        sfnbuf[0 .. prefix.length] = prefix[];

                        while (true)
                              {
                              // pentry is null at end of listing, or on an error
                              readdir_r (dir, &entry, &pentry);
                              if (pentry is null)
                                  break;

                              auto len = ocean.stdc.string.strlen (entry.d_name.ptr);
                              auto str = entry.d_name.ptr [0 .. len];
                              ++len;  // include the null

                              // resize the buffer as necessary ...
                              if (sfnbuf.length < prefix.length + len)
                                  sfnbuf.length = prefix.length + len;

                              sfnbuf [prefix.length .. prefix.length + len]
                                      = entry.d_name.ptr [0 .. len];

                              // skip "..." names
                              if (str.length > 3 || str != "..."[0 .. str.length])
                                 {
                                 FileInfo info = void;
                                 info.bytes  = 0;
                                 info.name   = idup(str);
                                 info.path   = idup(prefix);
                                 info.hidden = str[0] is '.';
                                 info.folder = info.system = false;

                                 if (! stat (sfnbuf.ptr, &sbuf))
                                 {
                                     info.folder = (sbuf.st_mode & S_IFDIR) != 0;
                                     if (info.folder is false)
                                     {
                                         if ((sbuf.st_mode & S_IFREG) is 0)
                                             info.system = true;
                                         else
                                             info.bytes = cast(ulong) sbuf.st_size;
                                     }
                                 }
                                 if (all || (info.hidden | info.system) is false)
                                     if ((ret = dg(info)) != 0)
                                          break;
                                 }
                              }
                        return ret;
                        assert(false);
                }
        }
}


/*******************************************************************************

        Parses a file path.

        File paths containing non-ansi characters should be UTF-8 encoded.
        Supporting Unicode in this manner was deemed to be more suitable
        than providing a wchar version of PathParser, and is both consistent
        & compatible with the approach taken with the Uri class.

        Note that patterns of adjacent '.' separators are treated specially
        in that they will be assigned to the name where there is no distinct
        suffix. In addition, a '.' at the start of a name signifies it does
        not belong to the suffix i.e. ".file" is a name rather than a suffix.
        Patterns of intermediate '.' characters will otherwise be assigned
        to the suffix, such that "file....suffix" includes the dots within
        the suffix itself. See method ext() for a suffix without dots.

        Note also that normalization of path-separators does *not* occur by
        default. This means that usage of '\' characters should be explicitly
        converted beforehand into '/' instead (an exception is thrown in those
        cases where '\' is present). On-the-fly conversion is avoided because
        (a) the provided path is considered immutable and (b) we avoid taking
        a copy of the original path. Module FilePath exists at a higher level,
        without such contraints.

*******************************************************************************/

struct PathParser
{
        package mstring  fp;                     // filepath with trailing
        package int     end_,                   // before any trailing 0
                        ext_,                   // after rightmost '.'
                        name_,                  // file/dir name
                        folder_,                // path before name
                        suffix_;                // including leftmost '.'

        /***********************************************************************

                Parse the path spec.

        ***********************************************************************/

        PathParser parse (mstring path)
        {
                return parse (path, path.length);
        }

        /***********************************************************************

                Duplicate this path.

                Note: Allocates memory for the path content.

        ***********************************************************************/

        PathParser dup ()
        {
                auto ret = *this;
                ret.fp = fp.dup;
                return ret;
        }

        /***********************************************************************

                Return the complete text of this filepath.

        ***********************************************************************/

        istring toString ()
        {
                return idup(fp [0 .. end_]);
        }

        /***********************************************************************

                Return the root of this path. Roots are constructs such as
                "C:".

        ***********************************************************************/

        mstring root ()
        {
                return fp [0 .. folder_];
        }

        /***********************************************************************

                Return the file path. Paths may start and end with a "/".
                The root path is "/" and an unspecified path is returned as
                an empty string. Directory paths may be split such that the
                directory name is placed into the 'name' member; directory
                paths are treated no differently than file paths.

        ***********************************************************************/

        mstring folder ()
        {
                return fp [folder_ .. name_];
        }

        /***********************************************************************

                Returns a path representing the parent of this one. This
                will typically return the current path component, though
                with a special case where the name component is empty. In
                such cases, the path is scanned for a prior segment:
                $(UL
                  $(LI normal:  /x/y/z => /x/y)
                  $(LI special: /x/y/  => /x)
                  $(LI normal:  /x     => /)
                  $(LI normal:  /      => [empty]))

                Note that this returns a path suitable for splitting into
                path and name components (there's no trailing separator).

        ***********************************************************************/

        cstring parent ()
        {
                auto p = path;
                if (name.length is 0)
                    for (int i=(cast(int) p.length) - 1; --i > 0;)
                         if (p[i] is FileConst.PathSeparatorChar)
                            {
                            p = p[0 .. i];
                            break;
                            }
                return FS.stripped (p);
        }

        /***********************************************************************

                Pop the rightmost element off this path, stripping off a
                trailing '/' as appropriate:
                $(UL
                  $(LI /x/y/z => /x/y)
                  $(LI /x/y/  => /x/y  (note trailing '/' in the original))
                  $(LI /x/y   => /x)
                  $(LI /x     => /)
                  $(LI /      => [empty]))

                Note that this returns a path suitable for splitting into
                path and name components (there's no trailing separator).

        ***********************************************************************/

        cstring pop ()
        {
                return FS.stripped (path);
        }

        /***********************************************************************

                Return the name of this file, or directory.

        ***********************************************************************/

        mstring name ()
        {
                return fp [name_ .. suffix_];
        }

        /***********************************************************************

                Ext is the tail of the filename, rightward of the rightmost
                '.' separator e.g. path "foo.bar" has ext "bar". Note that
                patterns of adjacent separators are treated specially - for
                example, ".." will wind up with no ext at all.

        ***********************************************************************/

        mstring ext ()
        {
                auto x = suffix;
                if (x.length)
                {
                    if (ext_ is 0)
                       foreach (c; x)
                       {
                           if (c is '.')
                               ++ext_;
                           else
                               break;
                       }
                    x = x [ext_ .. $];
                }
                return x;
        }

        /***********************************************************************

                Suffix is like ext, but includes the separator e.g. path
                "foo.bar" has suffix ".bar".

        ***********************************************************************/

        mstring suffix ()
        {
                return fp [suffix_ .. end_];
        }

        /***********************************************************************

                Return the root + folder combination.

        ***********************************************************************/

        mstring path ()
        {
                return fp [0 .. name_];
        }

        /***********************************************************************

                Return the name + suffix combination.

        ***********************************************************************/

        mstring file ()
        {
                return fp [name_ .. end_];
        }

        /***********************************************************************

                Returns true if this path is *not* relative to the
                current working directory.

        ***********************************************************************/

        bool isAbsolute ()
        {
                return (folder_ > 0) ||
                       (folder_ < end_ && fp[folder_] is FileConst.PathSeparatorChar);
        }

        /***********************************************************************

                Returns true if this FilePath is empty.

        ***********************************************************************/

        bool isEmpty ()
        {
                return end_ is 0;
        }

        /***********************************************************************

                Returns true if this path has a parent. Note that a
                parent is defined by the presence of a path-separator in
                the path. This means 'foo' within "/foo" is considered a
                child of the root.

        ***********************************************************************/

        bool isChild ()
        {
                return folder.length > 0;
        }

        /***********************************************************************

                Does this path equate to the given text? We ignore trailing
                path-separators when testing equivalence.

        ***********************************************************************/

        equals_t opEquals (cstring s)
        {
                return FS.stripped(s) == FS.stripped(toString);
        }

        /***********************************************************************

            Comparison to another PathParser, to avoid falling back to
            auto-generated one 

        ***********************************************************************/

        equals_t opEquals (PathParser rhs)
        {
            return FS.stripped(rhs.toString()) == FS.stripped(toString());
        }

        /***********************************************************************

                Parse the path spec with explicit end point. A '\' is
                considered illegal in the path and should be normalized
                out before this is invoked (the content managed here is
                considered immutable, and thus cannot be changed by this
                function.)

        ***********************************************************************/

        package PathParser parse (mstring path, size_t end)
        {
                end_ = cast(int) end;
                fp = path;
                folder_ = 0;
                name_ = suffix_ = -1;

                for (int i=end_; --i >= 0;)
                     switch (fp[i])
                            {
                            case FileConst.FileSeparatorChar:
                                 if (name_ < 0)
                                     if (suffix_ < 0 && i && fp[i-1] != '.')
                                         suffix_ = i;
                                 break;

                            case FileConst.PathSeparatorChar:
                                 if (name_ < 0)
                                     name_ = i + 1;
                                 break;

                            // Windows file separators are illegal. Use
                            // standard() or equivalent to convert first
                            case '\\':
                                 FS.exception ("unexpected '\\' character in path: ", path[0..end]);
                                 break;

                            default:
                                 break;
                            }

                if (name_ < 0)
                    name_ = folder_;

                if (suffix_ < 0 || suffix_ is name_)
                    suffix_ = end_;

                return *this;
        }
}


/*******************************************************************************

        Does this path currently exist?

*******************************************************************************/

bool exists (cstring name)
{
        char[512] tmp = void;
        return FS.exists (FS.strz(name, tmp));
}

/*******************************************************************************

        Returns the time of the last modification. Accurate
        to whatever the F/S supports, and in a format dictated
        by the file-system. For example NTFS keeps UTC time,
        while FAT timestamps are based on the local time.

*******************************************************************************/

Time modified (cstring name)
{
        return timeStamps(name).modified;
}

/*******************************************************************************

        Returns the time of the last access. Accurate to
        whatever the F/S supports, and in a format dictated
        by the file-system. For example NTFS keeps UTC time,
        while FAT timestamps are based on the local time.

*******************************************************************************/

Time accessed (cstring name)
{
        return timeStamps(name).accessed;
}

/*******************************************************************************

        Returns the time of file creation. Accurate to
        whatever the F/S supports, and in a format dictated
        by the file-system. For example NTFS keeps UTC time,
        while FAT timestamps are based on the local time.

*******************************************************************************/

Time created (cstring name)
{
        return timeStamps(name).created;
}

/*******************************************************************************

        Return the file length (in bytes.)

*******************************************************************************/

ulong fileSize (cstring name)
{
        char[512] tmp = void;
        return FS.fileSize (FS.strz(name, tmp));
}

/*******************************************************************************

        Is this file writable?

*******************************************************************************/

bool isWritable (cstring name)
{
        char[512] tmp = void;
        return FS.isWritable (FS.strz(name, tmp));
}

/*******************************************************************************

        Is this file actually a folder/directory?

*******************************************************************************/

bool isFolder (cstring name)
{
        char[512] tmp = void;
        return FS.isFolder (FS.strz(name, tmp));
}

/*******************************************************************************

        Is this file actually a normal file?
        Not a directory or (on unix) a device file or link.

*******************************************************************************/

bool isFile (cstring name)
{
        char[512] tmp = void;
        return FS.isFile (FS.strz(name, tmp));
}

/*******************************************************************************

        Return timestamp information.

        Timestamps are returns in a format dictated by the
        file-system. For example NTFS keeps UTC time,
        while FAT timestamps are based on the local time.

*******************************************************************************/

FS.Stamps timeStamps (cstring name)
{
        char[512] tmp = void;
        return FS.timeStamps (FS.strz(name, tmp));
}

/*******************************************************************************

        Set the accessed and modified timestamps of the specified file.

*******************************************************************************/

void timeStamps (cstring name, Time accessed, Time modified)
{
        char[512] tmp = void;
        FS.timeStamps (FS.strz(name, tmp), accessed, modified);
}

/*******************************************************************************

        Remove the file/directory from the file-system. Returns true if
        successful, false otherwise.

*******************************************************************************/

bool remove (cstring name)
{
        char[512] tmp = void;
        return FS.remove (FS.strz(name, tmp));
}

/*******************************************************************************

        Remove the files and folders listed in the provided paths. Where
        folders are listed, they should be preceded by their contained
        files in order to be successfully removed. Returns a set of paths
        that failed to be removed (where .length is zero upon success).

        The collate() function can be used to provide the input paths:
        ---
        remove (collate (".", "*.d", true));
        ---

        Use with great caution.

        Note: May allocate memory.

*******************************************************************************/

cstring[] remove (Const!(char[])[] paths)
{
        cstring[] failed;
        foreach (path; paths)
                 if (! remove (path))
                       failed ~= path;
        return failed;
}

/*******************************************************************************

        Create a new file.

*******************************************************************************/

void createFile (cstring name)
{
        char[512] tmp = void;
        FS.createFile (FS.strz(name, tmp));
}

/*******************************************************************************

        Create a new directory.

*******************************************************************************/

void createFolder (cstring name)
{
        char[512] tmp = void;
        FS.createFolder (FS.strz(name, tmp));
}

/*******************************************************************************

        Create an entire path consisting of this folder along with
        all parent folders. The path should not contain '.' or '..'
        segments, which can be removed via the normalize() function.

        Note that each segment is created as a folder, including the
        trailing segment.

        Throws: IOException upon system errors.

        Throws: IllegalArgumentException if a segment exists but as a
        file instead of a folder.

*******************************************************************************/

void createPath (cstring path)
{
        void test (cstring segment)
        {
            if (segment.length)
            {
                if (! exists (segment))
                    createFolder (segment);
                else
                    if (! isFolder (segment))
                        throw new IllegalArgumentException ("Path.createPath :: file/folder conflict: " ~ idup(segment));
            }
        }

        foreach (i, char c; path)
                 if (c is '/')
                     test (path [0 .. i]);
        test (path);
}

/*******************************************************************************

       Change the name or location of a file/directory.

*******************************************************************************/

void rename (cstring src, cstring dst)
{
        char[512] tmp1 = void;
        char[512] tmp2 = void;
        FS.rename (FS.strz(src, tmp1), FS.strz(dst, tmp2));
}

/*******************************************************************************

        Transfer the content of one file to another. Throws
        an IOException upon failure.

*******************************************************************************/

void copy (cstring src, cstring dst)
{
        char[512] tmp1 = void;
        char[512] tmp2 = void;
        FS.copy (FS.strz(src, tmp1), FS.strz(dst, tmp2));
}

/*******************************************************************************

        Provides foreach support via a fruct, as in
        ---
        foreach (info; children("myfolder"))
            ...
        ---

        Each path and filename is passed to the foreach
        delegate, along with the path prefix and whether
        the entry is a folder or not. The info construct
        exposes the following attributes:
        ---
        mstring  path
        mstring  name
        ulong   bytes
        bool    folder
        ---

        Argument 'all' controls whether hidden and system
        files are included - these are ignored by default.

*******************************************************************************/

FS.Listing children (cstring path, bool all=false)
{
        return FS.Listing (path, all);
}

/*******************************************************************************

        Collate all files and folders from the given path whose name matches
        the given pattern. Folders will be traversed where recurse is enabled,
        and a set of matching names is returned as filepaths (including those
        folders which match the pattern.)

        Note: Allocates memory for returned paths.

*******************************************************************************/

mstring[] collate (cstring path, cstring pattern, bool recurse=false)
{
        mstring[] list;

        foreach (info; children (path))
                {
                if (info.folder && recurse)
                    list ~= collate (join(info.path, info.name), pattern, true);

                if (patternMatch (info.name, pattern))
                    list ~= join (info.path, info.name);
                }
        return list;
}

/*******************************************************************************

        Join a set of path specs together. A path separator is
        potentially inserted between each of the segments.

        Note: May allocate memory.

*******************************************************************************/

mstring join (Const!(char[])[] paths...)
{
        return FS.join (paths);
}

/*******************************************************************************

        Convert path separators to a standard format, using '/' as
        the path separator. This is compatible with Uri and all of
        the contemporary O/S which Tango supports. Known exceptions
        include the Windows command-line processor, which considers
        '/' characters to be switches instead. Use the native()
        method to support that.

        Note: Mutates the provided path.

*******************************************************************************/

mstring standard (mstring path)
{
        return replace (path, '\\', '/');
}

/*******************************************************************************

        Convert to native O/S path separators where that is required,
        such as when dealing with the Windows command-line.

        Note: Mutates the provided path. Use this pattern to obtain a
        copy instead: native(path.dup);

*******************************************************************************/

mstring native (mstring path)
{
        return path;
}

/*******************************************************************************

        Returns a path representing the parent of this one, with a special
        case concerning a trailing '/':
        $(UL
          $(LI normal:  /x/y/z => /x/y)
          $(LI normal:  /x/y/  => /x/y)
          $(LI special: /x/y/  => /x)
          $(LI normal:  /x     => /)
          $(LI normal:  /      => empty))

        The result can be split via parse().

*******************************************************************************/

cstring parent (cstring path)
{
        return pop (FS.stripped (path));
}

/*******************************************************************************

        Returns a path representing the parent of this one:
        $(UL
          $(LI normal:  /x/y/z => /x/y)
          $(LI normal:  /x/y/  => /x/y)
          $(LI normal:  /x     => /)
          $(LI normal:  /      => empty))

        The result can be split via parse().

*******************************************************************************/

cstring pop (cstring path)
{
        size_t i = path.length;
        while (i && path[--i] != '/') {}
        return path [0..i];
}

/*******************************************************************************

        Break a path into "head" and "tail" components. For example:
        $(UL
          $(LI "/a/b/c" -> "/a","b/c")
          $(LI "a/b/c" -> "a","b/c"))

*******************************************************************************/

mstring split (mstring path, out mstring head, out mstring tail)
{
        head = path;
        if (path.length > 1)
            foreach (i, char c; path[1..$])
                     if (c is '/')
                        {
                        head = path [0 .. i+1];
                        tail = path [i+2 .. $];
                        break;
                        }
        return path;
}

/*******************************************************************************

        Replace all path 'from' instances with 'to', in place (overwrites
        the provided path).

*******************************************************************************/

mstring replace (mstring path, char from, char to)
{
        foreach (ref char c; path)
                 if (c is from)
                     c = to;
        return path;
}

/*******************************************************************************

        Parse a path into its constituent components.

        Note that the provided path is sliced, not duplicated.

*******************************************************************************/

PathParser parse (mstring path)
{
        PathParser p;

        p.parse (path);
        return p;
}

/*******************************************************************************

*******************************************************************************/

unittest
{
    auto p = parse ("/foo/bar/file.ext".dup);
    assert (p == "/foo/bar/file.ext");
    assert (p.folder == "/foo/bar/");
    assert (p.path == "/foo/bar/");
    assert (p.file == "file.ext");
    assert (p.name == "file");
    assert (p.suffix == ".ext");
    assert (p.ext == "ext");
    assert (p.isChild == true);
    assert (p.isEmpty == false);
    assert (p.isAbsolute == true);
}

/******************************************************************************

        Matches a pattern against a filename.

        Some characters of pattern have special a meaning (they are
        $(EM meta-characters)) and $(B can't) be escaped. These are:

        $(TABLE
          $(TR
            $(TD $(B *))
            $(TD Matches 0 or more instances of any character.))
          $(TR
            $(TD $(B ?))
            $(TD Matches exactly one instances of any character.))
          $(TR
            $(TD $(B [)$(EM chars)$(B ]))
            $(TD Matches one instance of any character that appears
          between the brackets.))
          $(TR
            $(TD $(B [!)$(EM chars)$(B ]))
            $(TD Matches one instance of any character that does not appear
          between the brackets after the exclamation mark.))
        )

        Internally individual character comparisons are done calling
        charMatch(), so its rules apply here too. Note that path
        separators and dots don't stop a meta-character from matching
        further portions of the filename.

        Returns: true if pattern matches filename, false otherwise.

        Throws: Nothing.
        -----
        version (Posix)
        {
          patternMatch("Go*.bar", "[fg]???bar"); // => false
          patternMatch("/foo*home/bar", "?foo*bar"); // => true
          patternMatch("foobar", "foo?bar"); // => true
        }
        -----

******************************************************************************/

bool patternMatch (cstring filename, cstring pattern)
in
{
        // Verify that pattern[] is valid
        bool inbracket = false;
        for (auto i=0; i < pattern.length; i++)
            {
            switch (pattern[i])
                   {
                   case '[':
                        assert(!inbracket);
                        inbracket = true;
                        break;
                   case ']':
                        assert(inbracket);
                        inbracket = false;
                        break;
                   default:
                        break;
                   }
            }
}
body
{
        int pi;
        int ni;
        char pc;
        char nc;
        int j;
        int not;
        int anymatch;

        bool charMatch (char c1, char c2)
        {
            version (Posix)
                 return c1 == c2;
        }

        ni = 0;
        for (pi = 0; pi < pattern.length; pi++)
            {
            pc = pattern [pi];
            switch (pc)
                   {
                   case '*':
                        if (pi + 1 == pattern.length)
                            goto match;
                        for (j = ni; j < filename.length; j++)
                            {
                            if (patternMatch(filename[j .. filename.length],
                                pattern[pi + 1 .. pattern.length]))
                               goto match;
                            }
                        goto nomatch;

                   case '?':
                        if (ni == filename.length)
                            goto nomatch;
                        ni++;
                        break;

                   case '[':
                        if (ni == filename.length)
                            goto nomatch;
                        nc = filename[ni];
                        ni++;
                        not = 0;
                        pi++;
                        if (pattern[pi] == '!')
                           {
                           not = 1;
                           pi++;
                           }
                        anymatch = 0;
                        while (1)
                              {
                              pc = pattern[pi];
                              if (pc == ']')
                                  break;
                              if (!anymatch && charMatch(nc, pc))
                                   anymatch = 1;
                              pi++;
                              }
                        if (!(anymatch ^ not))
                              goto nomatch;
                        break;

                   default:
                        if (ni == filename.length)
                            goto nomatch;
                        nc = filename[ni];
                        if (!charMatch(pc, nc))
                             goto nomatch;
                        ni++;
                        break;
                   }
            }
        if (ni < filename.length)
            goto nomatch;

        match:
            return true;

        nomatch:
            return false;
}

/*******************************************************************************

*******************************************************************************/

unittest
{
    version (Posix)
        assert(!patternMatch("foo", "Foo"));

    assert(patternMatch("foo", "*"));
    assert(patternMatch("foo.bar", "*"));
    assert(patternMatch("foo.bar", "*.*"));
    assert(patternMatch("foo.bar", "foo*"));
    assert(patternMatch("foo.bar", "f*bar"));
    assert(patternMatch("foo.bar", "f*b*r"));
    assert(patternMatch("foo.bar", "f???bar"));
    assert(patternMatch("foo.bar", "[fg]???bar"));
    assert(patternMatch("foo.bar", "[!gh]*bar"));

    assert(!patternMatch("foo", "bar"));
    assert(!patternMatch("foo", "*.*"));
    assert(!patternMatch("foo.bar", "f*baz"));
    assert(!patternMatch("foo.bar", "f*b*x"));
    assert(!patternMatch("foo.bar", "[gh]???bar"));
    assert(!patternMatch("foo.bar", "[!fg]*bar"));
    assert(!patternMatch("foo.bar", "[fg]???baz"));
}

/*******************************************************************************

        Normalizes a path component.
        $(UL
          $(LI $(B .) segments are removed)
          $(LI &lt;segment&gt;$(B /..) are removed))

        Multiple consecutive forward slashes are replaced with a single
        forward slash. On Windows, \ will be converted to / prior to any
        normalization.

        Note that any number of .. segments at the front is ignored,
        unless it is an absolute path, in which case they are removed.

        The input path is copied into either the provided buffer, or a heap
        allocated array if no buffer was provided. Normalization modifies
        this copy before returning the relevant slice.
        -----
        normalize("/home/foo/./bar/../../john/doe"); // => "/home/john/doe"
        -----

        Note: Allocates memory.

*******************************************************************************/

mstring normalize (cstring in_path, mstring buf = null)
{
        size_t  idx;            // Current position
        size_t  moveTo;         // Position to move
        bool    isAbsolute;     // Whether the path is absolute
        enum    {NodeStackLength = 64}
        mstring path;           // resulting path to return

        // Starting positions of regular path segments are pushed
        // on this stack to avoid backward scanning when .. segments
        // are encountered
        size_t[NodeStackLength] nodeStack;
        size_t nodeStackTop;

        // Moves the path tail starting at the current position to
        // moveTo. Then sets the current position to moveTo.
        void move ()
        {
                auto len = path.length - idx;
                memmove (path.ptr + moveTo, path.ptr + idx, len);
                path = path[0..moveTo + len];
                idx = moveTo;
        }

        // Checks if the character at the current position is a
        // separator. If true, normalizes the separator to '/' on
        // Windows and advances the current position to the next
        // character.
        bool isSep (ref size_t i)
        {
                char c = path[i];
                if (c != '/')
                        return false;
                i++;
                return true;
        }

        if (buf is null)
            path = in_path.dup;
        else
            path = buf[0..in_path.length] = in_path[];

        if (idx == path.length)
            return path;

        moveTo = idx;
        if (isSep(idx))
           {
           moveTo++; // preserve root separator.
           isAbsolute = true;
           }

        while (idx < path.length)
              {
              // Skip duplicate separators
              if (isSep(idx))
                  continue;

              if (path[idx] == '.')
                 {
                 // leave the current position at the start of
                 // the segment
                 auto i = idx + 1;
                 if (i < path.length && path[i] == '.')
                    {
                    i++;
                    if (i == path.length || isSep(i))
                       {
                       // It is a '..' segment. If the stack is not
                       // empty, set moveTo and the current position
                       // to the start position of the last found
                       // regular segment
                       if (nodeStackTop > 0)
                           moveTo = nodeStack[--nodeStackTop];

                       // If no regular segment start positions on the
                       // stack, drop the .. segment if it is absolute
                       // path or, otherwise, advance moveTo and the
                       // current position to the character after the
                       // '..' segment
                       else
                          if (!isAbsolute)
                             {
                             if (moveTo != idx)
                                {
                                i -= idx - moveTo;
                                move();
                                }
                             moveTo = i;
                             }

                       idx = i;
                       continue;
                       }
                    }

                 // If it is '.' segment, skip it.
                 if (i == path.length || isSep(i))
                    {
                    idx = i;
                    continue;
                    }
                 }

              // Remove excessive '/', '.' and/or '..' preceeding the
              // segment
              if (moveTo != idx)
                  move();

              // Push the start position of the regular segment on the
              // stack
              assert (nodeStackTop < NodeStackLength);
              nodeStack[nodeStackTop++] = idx;

              // Skip the regular segment and set moveTo to the position
              // after the segment (including the trailing '/' if present)
              for (; idx < path.length && !isSep(idx); idx++)
                  {}
              moveTo = idx;
              }

        if (moveTo != idx)
            move();
        return path;
}

/*******************************************************************************

*******************************************************************************/

unittest
{
    assert (normalize ("") == "");
    assert (normalize ("/home/../john/../.tango/.htaccess") == "/.tango/.htaccess");
    assert (normalize ("/home/../john/../.tango/foo.conf") == "/.tango/foo.conf");
    assert (normalize ("/home/john/.tango/foo.conf") == "/home/john/.tango/foo.conf");
    assert (normalize ("/foo/bar/.htaccess") == "/foo/bar/.htaccess");
    assert (normalize ("foo/bar/././.") == "foo/bar/");
    assert (normalize ("././foo/././././bar") == "foo/bar");
    assert (normalize ("/foo/../john") == "/john");
    assert (normalize ("foo/../john") == "john");
    assert (normalize ("foo/bar/..") == "foo/");
    assert (normalize ("foo/bar/../john") == "foo/john");
    assert (normalize ("foo/bar/doe/../../john") == "foo/john");
    assert (normalize ("foo/bar/doe/../../john/../bar") == "foo/bar");
    assert (normalize ("./foo/bar/doe") == "foo/bar/doe");
    assert (normalize ("./foo/bar/doe/../../john/../bar") == "foo/bar");
    assert (normalize ("./foo/bar/../../john/../bar") == "bar");
    assert (normalize ("foo/bar/./doe/../../john") == "foo/john");
    assert (normalize ("../../foo/bar") == "../../foo/bar");
    assert (normalize ("../../../foo/bar") == "../../../foo/bar");
    assert (normalize ("d/") == "d/");
    assert (normalize ("/home/john/./foo/bar.txt") == "/home/john/foo/bar.txt");
    assert (normalize ("/home//john") == "/home/john");

    assert (normalize("/../../bar/") == "/bar/");
    assert (normalize("/../../bar/../baz/./") == "/baz/");
    assert (normalize("/../../bar/boo/../baz/.bar/.") == "/bar/baz/.bar/");
    assert (normalize("../..///.///bar/..//..//baz/.//boo/..") == "../../../baz/");
    assert (normalize("./bar/./..boo/./..bar././/") == "bar/..boo/..bar./");
    assert (normalize("/bar/..") == "/");
    assert (normalize("bar/") == "bar/");
    assert (normalize(".../") == ".../");
    assert (normalize("///../foo") == "/foo");
    assert (normalize("./foo") == "foo");
    auto buf = new char[100];
    auto ret = normalize("foo/bar/./baz", buf);
    assert (ret.ptr == buf.ptr);
    assert (ret == "foo/bar/baz");
}


/*******************************************************************************

*******************************************************************************/

debug (Path)
{
        import ocean.io.Stdout_tango;

        void main()
        {
                foreach (file; collate (".", "*.d", true))
                         Stdout (file).newline;
        }
}
