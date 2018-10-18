/*******************************************************************************

    Subclass of ocean.io.FilePath to provide some extra functionality

    Copyright:
        Copyright (c) 2004 Kris Bell.
        Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

    Authors: Kris

*******************************************************************************/

module ocean.io.FilePath;

import ocean.transition;
import ocean.core.Verify;
import ocean.io.Path;
import ocean.io.model.IFile : FileConst, FileInfo;

import core.sys.posix.unistd : link;
import ocean.stdc.string : memmove;

version(UnitTest) import ocean.core.Test;

/*******************************************************************************

        Models a file path. These are expected to be used as the constructor
        argument to various file classes. The intention is that they easily
        convert to other representations such as absolute, canonical, or Url.

        File paths containing non-ansi characters should be UTF-8 encoded.
        Supporting Unicode in this manner was deemed to be more suitable
        than providing a wchar version of FilePath, and is both consistent
        & compatible with the approach taken with the Uri class.

        FilePath is designed to be transformed, thus each mutating method
        modifies the internal content. See module Path.d for a lightweight
        immutable variation.

        Note that patterns of adjacent '.' separators are treated specially
        in that they will be assigned to the name where there is no distinct
        suffix. In addition, a '.' at the start of a name signifies it does
        not belong to the suffix i.e. ".file" is a name rather than a suffix.
        Patterns of intermediate '.' characters will otherwise be assigned
        to the suffix, such that "file....suffix" includes the dots within
        the suffix itself. See method ext() for a suffix without dots.

        Note that Win32 '\' characters are converted to '/' by default via
        the FilePath constructor.

*******************************************************************************/

class FilePath : PathView
{
    import core.sys.posix.sys.types: mode_t;

    private PathParser      p;              // the parsed path
    private bool            dir_;           // this represents a dir?

    public alias    append  opCatAssign;    // path ~= x;

    /***********************************************************************

            Filter used for screening paths via toList().

    ***********************************************************************/

    public alias bool delegate (FilePath, bool) Filter;

    /***********************************************************************

            Call-site shortcut to create a FilePath instance. This
            enables the same syntax as struct usage, so may expose
            a migration path.

    ***********************************************************************/

    static FilePath opCall (cstring filepath = null)
    {
            return new FilePath (filepath);
    }

    /***********************************************************************

            Create a FilePath from a copy of the provided string.

            FilePath assumes both path & name are present, and therefore
            may split what is otherwise a logically valid path. That is,
            the 'name' of a file is typically the path segment following
            a rightmost path-separator. The intent is to treat files and
            directories in the same manner; as a name with an optional
            ancestral structure. It is possible to bias the interpretation
            by adding a trailing path-separator to the argument. Doing so
            will result in an empty name attribute.

            With regard to the filepath copy, we found the common case to
            be an explicit .dup, whereas aliasing appeared to be rare by
            comparison. We also noted a large proportion interacting with
            C-oriented OS calls, implying the postfix of a null terminator.
            Thus, FilePath combines both as a single operation.

            Note that Win32 '\' characters are normalized to '/' instead.

    ***********************************************************************/

    this (cstring filepath = null)
    {
            set (filepath, true);
    }

    /***********************************************************************

            Return the complete text of this filepath.

    ***********************************************************************/

    final override istring toString ()
    {
            return p.toString;
    }

    /***********************************************************************

            Duplicate this path.

    ***********************************************************************/

    final FilePath dup ()
    {
            return FilePath (toString);
    }

    /***********************************************************************

            Return the complete text of this filepath as a null
            terminated string for use with a C api. Use toString
            instead for any D api.

            Note that the nul is always embedded within the string
            maintained by FilePath, so there's no heap overhead when
            making a C call.

    ***********************************************************************/

    final mstring cString ()
    {
            return p.fp [0 .. p.end_+1];
    }

    /***********************************************************************

            Return the root of this path. Roots are constructs such as
            "C:".

    ***********************************************************************/

    final cstring root ()
    {
            return p.root;
    }

    /***********************************************************************

            Return the file path.

            Paths may start and end with a "/".
            The root path is "/" and an unspecified path is returned as
            an empty string. Directory paths may be split such that the
            directory name is placed into the 'name' member; directory
            paths are treated no differently than file paths.

    ***********************************************************************/

    final cstring folder ()
    {
            return p.folder;
    }

    /***********************************************************************

            Returns a path representing the parent of this one. This
            will typically return the current path component, though
            with a special case where the name component is empty. In
            such cases, the path is scanned for a prior segment:
            $(UL
              $(LI normal:  /x/y/z => /x/y)
              $(LI special: /x/y/  => /x))

            Note that this returns a path suitable for splitting into
            path and name components (there's no trailing separator).

            See pop() also, which is generally more useful when working
            with FilePath instances.

    ***********************************************************************/

    final cstring parent ()
    {
            return p.parent;
    }

    /***********************************************************************

            Return the name of this file, or directory.

    ***********************************************************************/

    final cstring name ()
    {
            return p.name;
    }

    /***********************************************************************

            Ext is the tail of the filename, rightward of the rightmost
            '.' separator e.g. path "foo.bar" has ext "bar". Note that
            patterns of adjacent separators are treated specially; for
            example, ".." will wind up with no ext at all.

    ***********************************************************************/

    final cstring ext ()
    {
            return p.ext;
    }

    /***********************************************************************

            Suffix is like ext, but includes the separator e.g. path
            "foo.bar" has suffix ".bar".

    ***********************************************************************/

    final cstring suffix ()
    {
            return p.suffix;
    }

    /***********************************************************************

            Return the root + folder combination.

    ***********************************************************************/

    final cstring path ()
    {
            return p.path;
    }

    /***********************************************************************

            Return the name + suffix combination.

    ***********************************************************************/

    final cstring file ()
    {
            return p.file;
    }

    /***********************************************************************

            Returns true if all fields are identical. Note that some
            combinations of operations may not produce an identical
            set of fields. For example:
            ---
            FilePath("/foo").append("bar").pop == "/foo";
            FilePath("/foo/").append("bar").pop != "/foo/";
            ---

            The latter is different due to variance in how append
            injects data, and how pop is expected to operate under
            different circumstances (both examples produce the same
            pop result, although the initial path is not identical).

            However, opEquals() can overlook minor distinctions such
            as this example, and will return a match.

    ***********************************************************************/

    final override equals_t opEquals (Object o)
    {
            return (this is o) || (o && opEquals(o.toString));
    }

    /***********************************************************************

            Does this FilePath match the given text? Note that some
            combinations of operations may not produce an identical
            set of fields. For example:
            ---
            FilePath("/foo").append("bar").pop == "/foo";
            FilePath("/foo/").append("bar").pop != "/foo/";
            ---

            The latter Is Different due to variance in how append
            injects data, and how pop is expected to operate under
            different circumstances (both examples produce the same
            pop result, although the initial path is not identical).

            However, opEquals() can overlook minor distinctions such
            as this example, and will return a match.

    ***********************************************************************/

    final int opEquals (cstring s)
    {
            return p.opEquals(s);
    }

    /***********************************************************************

            Returns true if this FilePath is *not* relative to the
            current working directory.

    ***********************************************************************/

    final bool isAbsolute ()
    {
            return p.isAbsolute;
    }

    /***********************************************************************

            Returns true if this FilePath is empty.

    ***********************************************************************/

    final bool isEmpty ()
    {
            return p.isEmpty;
    }

    /***********************************************************************

            Returns true if this FilePath has a parent. Note that a
            parent is defined by the presence of a path-separator in
            the path. This means 'foo' within "\foo" is considered a
            child of the root.

    ***********************************************************************/

    final bool isChild ()
    {
            return p.isChild;
    }

    /***********************************************************************

            Replace all 'from' instances with 'to'.

    ***********************************************************************/

    final FilePath replace (char from, char to)
    {
            .replace (p.path, from, to);
            return this;
    }

    /***********************************************************************

            Convert path separators to a standard format, using '/' as
            the path separator. This is compatible with URI and all of
            the contemporary O/S which Tango supports. Known exceptions
            include the Windows command-line processor, which considers
            '/' characters to be switches instead. Use the native()
            method to support that.

            Note: mutates the current path.

    ***********************************************************************/

    final FilePath standard ()
    {
            .standard (p.path);
            return this;
    }

    /***********************************************************************

            Convert to native O/S path separators where that is required,
            such as when dealing with the Windows command-line.

            Note: Mutates the current path. Use this pattern to obtain a
            copy instead: path.dup.native

    ***********************************************************************/

    final FilePath native ()
    {
            .native (p.path);
            return this;
    }

    /***********************************************************************

            Concatenate text to this path; no separators are added.
            See_also: $(SYMLINK FilePath.join, join)()

    ***********************************************************************/

    final FilePath cat (cstring[] others...)
    {
            foreach (other; others)
                    {
                    auto len = p.end_ + other.length;
                    expand (len);
                    p.fp [p.end_ .. len] = other;
                    p.fp [len] = 0;
                    p.end_ = cast(int) len;
                    }
            return parse;
    }

    /***********************************************************************

            Append a folder to this path. A leading separator is added
            as required.

    ***********************************************************************/

    final FilePath append (cstring path)
    {
            if (file.length)
                path = prefixed (path);
            return cat (path);
    }

    /***********************************************************************

            Prepend a folder to this path. A trailing separator is added
            if needed.

    ***********************************************************************/

    final FilePath prepend (cstring path)
    {
            adjust (0, p.folder_, p.folder_, padded (path));
            return parse;
    }

    /***********************************************************************

            Reset the content of this path to that of another and
            reparse.

    ***********************************************************************/

    FilePath set (FilePath path)
    {
            return set (path.toString, false);
    }

    /***********************************************************************

            Reset the content of this path, and reparse. There's an
            optional boolean flag to convert the path into standard
            form, before parsing (converting '\' into '/').

    ***********************************************************************/

    final FilePath set (cstring path, bool convert = false)
    {
            p.end_ = cast(int) path.length;

            expand (p.end_);
            if (p.end_)
               {
               p.fp[0 .. p.end_] = path;
               if (convert)
                   .standard (p.fp [0 .. p.end_]);
               }

            p.fp[p.end_] = '\0';
            return parse;
    }

    /***********************************************************************

            Sidestep the normal lookup for paths that are known to
            be folders. Where folder is true, file system lookups
            will be skipped.

    ***********************************************************************/

    final FilePath isFolder (bool folder)
    {
            dir_ = folder;
            return this;
    }

    /***********************************************************************

            Replace the root portion of this path.

    ***********************************************************************/

    final FilePath root (cstring other)
    {
            auto x = adjust (0, p.folder_, p.folder_, padded (other, ':'));
            p.folder_ += x;
            p.suffix_ += x;
            p.name_ += x;
            return this;
    }

    /***********************************************************************

            Replace the folder portion of this path. The folder will be
            padded with a path-separator as required.

    ***********************************************************************/

    final FilePath folder (cstring other)
    {
            auto x = adjust (p.folder_, p.name_, p.name_ - p.folder_, padded (other));
            p.suffix_ += x;
            p.name_ += x;
            return this;
    }

    /***********************************************************************

            Replace the name portion of this path.

    ***********************************************************************/

    final FilePath name (cstring other)
    {
            auto x = adjust (p.name_, p.suffix_, p.suffix_ - p.name_, other);
            p.suffix_ += x;
            return this;
    }

    /***********************************************************************

            Replace the suffix portion of this path. The suffix will be
            prefixed with a file-separator as required.

    ***********************************************************************/

    final FilePath suffix (cstring other)
    {
            adjust (p.suffix_, p.end_, p.end_ - p.suffix_, prefixed (other, '.'));
            return this;
    }

    /***********************************************************************

            Replace the root and folder portions of this path and
            reparse. The replacement will be padded with a path
            separator as required.

    ***********************************************************************/

    final FilePath path (cstring other)
    {
            adjust (0, p.name_, p.name_, padded (other));
            return parse;
    }

    /***********************************************************************

            Replace the file and suffix portions of this path and
            reparse. The replacement will be prefixed with a suffix
            separator as required.

    ***********************************************************************/

    final FilePath file (cstring other)
    {
            adjust (p.name_, p.end_, p.end_ - p.name_, other);
            return parse;
    }

    /***********************************************************************

            Pop to the parent of the current filepath (in situ - mutates
            this FilePath). Note that this differs from parent() in that
            it does not include any special cases.

    ***********************************************************************/

    final FilePath pop ()
    {
            version (SpecialPop)
                     p.end_ = p.parent.length;
               else
                  p.end_ = cast(int) p.pop.length;
            p.fp[p.end_] = '\0';
            return parse;
    }

    /***********************************************************************

            Join a set of path specs together. A path separator is
            potentially inserted between each of the segments.

    ***********************************************************************/

    static istring join (Const!(char[][]) paths...)
    {
            auto s = FS.join (paths);
            return assumeUnique(s);
    }

    /***********************************************************************

            Convert this FilePath to absolute format, using the given
            prefix as necessary. If this FilePath is already absolute,
            return it intact.

            Returns this FilePath, adjusted as necessary.

    ***********************************************************************/

    final FilePath absolute (cstring prefix)
    {
            if (! isAbsolute)
                  prepend (padded(prefix));
            return this;
    }

    /***********************************************************************

            Return an adjusted path such that non-empty instances do not
            have a trailing separator.

    ***********************************************************************/

    static cstring stripped (cstring path, char c = FileConst.PathSeparatorChar)
    {
            return FS.stripped (path, c);
    }

    /***********************************************************************

            Return an adjusted path such that non-empty instances always
            have a trailing separator.

    ***********************************************************************/

    static cstring padded (cstring path, char c = FileConst.PathSeparatorChar)
    {
            return FS.padded (path, c);
    }

    /***********************************************************************

            Return an adjusted path such that non-empty instances always
            have a prefixed separator.

    ***********************************************************************/

    static cstring prefixed (cstring s, char c = FileConst.PathSeparatorChar)
    {
            if (s.length && s[0] != c)
                s = c ~ s;
            return s;
    }

    /***********************************************************************

            Parse the path spec, and mutate '\' into '/' as necessary.

    ***********************************************************************/

    private final FilePath parse ()
    {
            p.parse (p.fp, p.end_);
            return this;
    }

    /***********************************************************************

            Potentially make room for more content.

    ***********************************************************************/

    private final void expand (size_t size)
    {
            ++size;
            if (p.fp.length < size)
                p.fp.length = (size + 127) & ~127;
    }

    /***********************************************************************

            Insert/delete internal content.

    ***********************************************************************/

    private final int adjust (int head, int tail, int len, cstring sub)
    {
            len = (cast(int) sub.length) - len;

            // don't destroy self-references!
            if (len && sub.ptr >= p.fp.ptr+head+len && sub.ptr < p.fp.ptr+p.fp.length)
               {
               char[512] tmp = void;
               verify(sub.length < tmp.length);
               sub = tmp[0..sub.length] = sub;
               }

            // make some room if necessary
            expand (len + p.end_);

            // slide tail around to insert or remove space
            memmove (p.fp.ptr+tail+len, p.fp.ptr+tail, p.end_ +1 - tail);

            // copy replacement
            memmove (p.fp.ptr + head, sub.ptr, sub.length);

            // adjust length
            p.end_ += len;
            return len;
    }


    /* ****************************************************************** */
    /* ******************** file system methods ************************* */
    /* ****************************************************************** */


    /***********************************************************************

            Create an entire path consisting of this folder along with
            all parent folders. The path must not contain '.' or '..'
            segments. Related methods include PathUtil.normalize() and
            absolute().

            Note that each segment is created as a folder, including the
            trailing segment.

            Returns: A chaining reference (this).

            Throws: IOException upon systen errors.

            Throws: IllegalArgumentException if a segment exists but as
            a file instead of a folder.

    ***********************************************************************/

    final FilePath create ()
    {
            createPath (this.toString);
            return this;
    }

    /***********************************************************************

            List the set of filenames within this folder, using
            the provided filter to control the list:
            ---
            bool delegate (FilePath path, bool isFolder) Filter;
            ---

            Returning true from the filter includes the given path,
            whilst returning false excludes it. Parameter 'isFolder'
            indicates whether the path is a file or folder.

            Note that paths composed of '.' characters are ignored.

    ***********************************************************************/

    final FilePath[] toList (scope Filter filter = null)
    {
            FilePath[] paths;

            foreach (info; this)
                    {
                    auto p = from (info);

                    // test this entry for inclusion
                    if (filter is null || filter (p, info.folder))
                        paths ~= p;
                    else
                       delete p;
                    }
            return paths;
    }

    /***********************************************************************

            Construct a FilePath from the given FileInfo.

    ***********************************************************************/

    static FilePath from (ref FileInfo info)
    {
            char[512] tmp = void;

            auto len = info.path.length + info.name.length;
            verify(tmp.length - len > 1);

            // construct full pathname
            tmp [0 .. info.path.length] = info.path;
            tmp [info.path.length .. len] = info.name;
            return FilePath(tmp[0 .. len]).isFolder(info.folder);
    }

    /***********************************************************************

            Does this path currently exist?.

    ***********************************************************************/

    final bool exists ()
    {
            return FS.exists (cString);
    }

    /***********************************************************************

            Returns the time of the last modification. Accurate
            to whatever the OS supports, and in a format dictated
            by the file system. For example NTFS keeps UTC time,
            while FAT timestamps are based on the local time.

    ***********************************************************************/

    final Time modified ()
    {
            return timeStamps.modified;
    }

    /***********************************************************************

            Returns the time of the last access. Accurate to
            whatever the OS supports, and in a format dictated
            by the file system. For example NTFS keeps UTC time,
            while FAT timestamps are based on the local time.

    ***********************************************************************/

    final Time accessed ()
    {
            return timeStamps.accessed;
    }

    /***********************************************************************

            Returns the time of file creation. Accurate to
            whatever the OS supports, and in a format dictated
            by the file system. For example NTFS keeps UTC time,
            while FAT timestamps are based on the local time.

    ***********************************************************************/

    final Time created ()
    {
            return timeStamps.created;
    }

    /***********************************************************************

            Change the name or location of a file/directory, and
            adopt the provided Path.

    ***********************************************************************/

    final FilePath rename (FilePath dst)
    {
            FS.rename (cString, dst.cString);
            return this.set (dst);
    }

    /***********************************************************************

            Transfer the content of another file to this one. Returns a
            reference to this class on success, or throws an IOException
            upon failure.

    ***********************************************************************/

    final FilePath copy (cstring source)
    {
            auto src = source~'\0';
            FS.copy (assumeUnique(src), cString);
            return this;
    }

    /***********************************************************************

            Return the file length (in bytes).

    ***********************************************************************/

    final ulong fileSize ()
    {
            return FS.fileSize (cString);
    }

    /***********************************************************************

            Is this file writable?

    ***********************************************************************/

    final bool isWritable ()
    {
            return FS.isWritable (cString);
    }

    /***********************************************************************

            Is this file actually a folder/directory?

    ***********************************************************************/

    final bool isFolder ()
    {
            if (dir_)
                return true;

            return FS.isFolder (cString);
    }

    /***********************************************************************

            Is this a regular file?

    ***********************************************************************/

    final bool isFile ()
    {
            if (dir_)
                return false;

            return FS.isFile (cString);
    }

    /***********************************************************************

            Return timestamp information.

            Timstamps are returns in a format dictated by the
            file system. For example NTFS keeps UTC time,
            while FAT timestamps are based on the local time.

    ***********************************************************************/

    final Stamps timeStamps ()
    {
            return FS.timeStamps (cString);
    }

    /***********************************************************************

            Transfer the content of another file to this one. Returns a
            reference to this class on success, or throws an IOException
            upon failure.

    ***********************************************************************/

    final FilePath copy (FilePath src)
    {
            FS.copy (src.cString, cString);
            return this;
    }

    /***********************************************************************

            Remove the file/directory from the file system.

    ***********************************************************************/

    final FilePath remove ()
    {
            FS.remove (cString);
            return this;
    }

    /***********************************************************************

           change the name or location of a file/directory, and
           adopt the provided Path.

           Note: If dst is not zero terminated, a terminated will be added
                 which means that allocation will happen.

    ***********************************************************************/

    final FilePath rename (cstring dst)
    {
        verify(dst !is null);

        if (dst[$-1] != '\0')
            dst ~= '\0';

        FS.rename (cString, dst);

        return this.set (dst, true);
    }

    /***********************************************************************

            Create a new file.

            Params:
                mode = mode for the new file (defaults to 0660)

    ***********************************************************************/

    final FilePath createFile (mode_t mode = Octal!("660"))
    {
            FS.createFile (cString, mode);
            return this;
    }

    /***********************************************************************

            Create a new directory.

            Params:
                mode = mode for the new directory (defaults to 0777)

    ***********************************************************************/

    final FilePath createFolder (mode_t mode = Octal!("777"))
    {
            FS.createFolder (cString, mode);
            return this;
    }

    /***********************************************************************

            List the set of filenames within this folder.

            Each path and filename is passed to the provided
            delegate, along with the path prefix and whether
            the entry is a folder or not.

            Returns the number of files scanned.

    ***********************************************************************/

    final int opApply (scope int delegate(ref FileInfo) dg)
    {
            return FS.list (cString, dg);
    }

    /***********************************************************************

        Create a new name for a file (also known as -hard-linking)

        Params:
            dst = FilePath with the new file name

        Returns:
            this.path set to the new destination location if it was moved,
            null otherwise.

        See_Also:
           man 2 link

    ***********************************************************************/

    public final FilePath link ( FilePath dst )
    {
        if (.link(this.cString().ptr, dst.cString().ptr) is -1)
        {
            FS.exception(this.toString());
        }

        return this;
    }
}

/*******************************************************************************

*******************************************************************************/

interface PathView
{
    alias FS.Stamps         Stamps;

    /***********************************************************************

            Return the complete text of this filepath.

    ***********************************************************************/

    abstract istring toString ();

    /***********************************************************************

            Return the complete text of this filepath.

    ***********************************************************************/

    abstract mstring cString ();

    /***********************************************************************

            Return the root of this path. Roots are constructs such as
            "C:".

    ***********************************************************************/

    abstract cstring root ();

    /***********************************************************************

            Return the file path. Paths may start and end with a "/".
            The root path is "/" and an unspecified path is returned as
            an empty string. Directory paths may be split such that the
            directory name is placed into the 'name' member; directory
            paths are treated no differently than file paths.

    ***********************************************************************/

    abstract cstring folder ();

    /***********************************************************************

            Return the name of this file, or directory, excluding a
            suffix.

    ***********************************************************************/

    abstract cstring name ();

    /***********************************************************************

            Ext is the tail of the filename, rightward of the rightmost
            '.' separator e.g. path "foo.bar" has ext "bar". Note that
            patterns of adjacent separators are treated specially; for
            example, ".." will wind up with no ext at all.

    ***********************************************************************/

    abstract cstring ext ();

    /***********************************************************************

            Suffix is like ext, but includes the separator e.g. path
            "foo.bar" has suffix ".bar".

    ***********************************************************************/

    abstract cstring suffix ();

    /***********************************************************************

            Return the root + folder combination.

    ***********************************************************************/

    abstract cstring path ();

    /***********************************************************************

            Return the name + suffix combination.

    ***********************************************************************/

    abstract cstring file ();

    /***********************************************************************

            Returns true if this FilePath is *not* relative to the
            current working directory.

    ***********************************************************************/

    abstract bool isAbsolute ();

    /***********************************************************************

            Returns true if this FilePath is empty.

    ***********************************************************************/

    abstract bool isEmpty ();

    /***********************************************************************

            Returns true if this FilePath has a parent.

    ***********************************************************************/

    abstract bool isChild ();

    /***********************************************************************

            Does this path currently exist?

    ***********************************************************************/

    abstract bool exists ();

    /***********************************************************************

            Returns the time of the last modification. Accurate
            to whatever the OS supports.

    ***********************************************************************/

    abstract Time modified ();

    /***********************************************************************

            Returns the time of the last access. Accurate to
            whatever the OS supports.

    ***********************************************************************/

    abstract Time accessed ();

    /***********************************************************************

            Returns the time of file creation. Accurate to
            whatever the OS supports.

    ***********************************************************************/

    abstract Time created ();

    /***********************************************************************

            Return the file length (in bytes).

    ***********************************************************************/

    abstract ulong fileSize ();

    /***********************************************************************

            Is this file writable?

    ***********************************************************************/

    abstract bool isWritable ();

    /***********************************************************************

            Is this file actually a folder/directory?

    ***********************************************************************/

    abstract bool isFolder ();

    /***********************************************************************

            Return timestamp information.

    ***********************************************************************/

    abstract Stamps timeStamps ();
}

unittest
{
    test (FilePath("/foo").append("bar").pop == "/foo");
    test (FilePath("/foo/").append("bar").pop == "/foo");

    auto fp = new FilePath(r"/home/foo/bar");
    fp ~= "john";
    test (fp == r"/home/foo/bar/john");
    fp.set (r"/");
    fp ~= "john";
    test (fp == r"/john");
    fp.set("foo.bar");
    fp ~= "john";
    test (fp == r"foo.bar/john");
    fp.set("");
    fp ~= "john";
    test (fp == r"john");

    fp.set(r"/home/foo/bar/john/foo.d");
    test (fp.pop == r"/home/foo/bar/john");
    test (fp.pop == r"/home/foo/bar");
    test (fp.pop == r"/home/foo");
    test (fp.pop == r"/home");
    test (fp.pop == r"/");
    test (fp.pop == r"");

    // special case for popping empty names
    fp.set (r"/home/foo/bar/john/");
    test (fp.parent == r"/home/foo/bar");

    fp = new FilePath;
    fp.set (r"/home/foo/bar/john/");
    test (fp.isAbsolute);
    test (fp.name == "");
    test (fp.folder == r"/home/foo/bar/john/");
    test (fp == r"/home/foo/bar/john/");
    test (fp.path == r"/home/foo/bar/john/");
    test (fp.file == "");
    test (fp.suffix == "");
    test (fp.root == "");
    test (fp.ext == "");
    test (fp.isChild);

    fp = new FilePath(r"/home/foo/bar/john");
    test (fp.isAbsolute);
    test (fp.name == "john");
    test (fp.folder == r"/home/foo/bar/");
    test (fp == r"/home/foo/bar/john");
    test (fp.path == r"/home/foo/bar/");
    test (fp.file == r"john");
    test (fp.suffix == "");
    test (fp.ext == "");
    test (fp.isChild);

    fp.pop;
    test (fp.isAbsolute);
    test (fp.name == "bar");
    test (fp.folder == r"/home/foo/");
    test (fp == r"/home/foo/bar");
    test (fp.path == r"/home/foo/");
    test (fp.file == r"bar");
    test (fp.suffix == r"");
    test (fp.ext == "");
    test (fp.isChild);

    fp.pop;
    test (fp.isAbsolute);
    test (fp.name == "foo");
    test (fp.folder == r"/home/");
    test (fp == r"/home/foo");
    test (fp.path == r"/home/");
    test (fp.file == r"foo");
    test (fp.suffix == r"");
    test (fp.ext == "");
    test (fp.isChild);

    fp.pop;
    test (fp.isAbsolute);
    test (fp.name == "home");
    test (fp.folder == r"/");
    test (fp == r"/home");
    test (fp.path == r"/");
    test (fp.file == r"home");
    test (fp.suffix == r"");
    test (fp.ext == "");
    test (fp.isChild);

    fp = new FilePath(r"foo/bar/john.doe");
    test (!fp.isAbsolute);
    test (fp.name == "john");
    test (fp.folder == r"foo/bar/");
    test (fp.suffix == r".doe");
    test (fp.file == r"john.doe");
    test (fp == r"foo/bar/john.doe");
    test (fp.ext == "doe");
    test (fp.isChild);

    fp = new FilePath(r"/doe");
    test (fp.isAbsolute);
    test (fp.suffix == r"");
    test (fp == r"/doe");
    test (fp.name == "doe");
    test (fp.folder == r"/");
    test (fp.file == r"doe");
    test (fp.ext == "");
    test (fp.isChild);

    fp = new FilePath(r"john.doe.foo");
    test (!fp.isAbsolute);
    test (fp.name == "john.doe");
    test (fp.folder == r"");
    test (fp.suffix == r".foo");
    test (fp == r"john.doe.foo");
    test (fp.file == r"john.doe.foo");
    test (fp.ext == "foo");
    test (!fp.isChild);

    fp = new FilePath(r".doe");
    test (!fp.isAbsolute);
    test (fp.suffix == r"");
    test (fp == r".doe");
    test (fp.name == ".doe");
    test (fp.folder == r"");
    test (fp.file == r".doe");
    test (fp.ext == "");
    test (!fp.isChild);

    fp = new FilePath(r"doe");
    test (!fp.isAbsolute);
    test (fp.suffix == r"");
    test (fp == r"doe");
    test (fp.name == "doe");
    test (fp.folder == r"");
    test (fp.file == r"doe");
    test (fp.ext == "");
    test (!fp.isChild);

    fp = new FilePath(r".");
    test (!fp.isAbsolute);
    test (fp.suffix == r"");
    test (fp == r".");
    test (fp.name == ".");
    test (fp.folder == r"");
    test (fp.file == r".");
    test (fp.ext == "");
    test (!fp.isChild);

    fp = new FilePath(r"..");
    test (!fp.isAbsolute);
    test (fp.suffix == r"");
    test (fp == r"..");
    test (fp.name == "..");
    test (fp.folder == r"");
    test (fp.file == r"..");
    test (fp.ext == "");
    test (!fp.isChild);

    fp = new FilePath(r"/a/b/c/d/e/foo.bar");
    test (fp.isAbsolute);
    fp.folder (r"/a/b/c/");
    test (fp.suffix == r".bar");
    test (fp == r"/a/b/c/foo.bar");
    test (fp.name == "foo");
    test (fp.folder == r"/a/b/c/");
    test (fp.file == r"foo.bar");
    test (fp.ext == "bar");
    test (fp.isChild);

    fp = new FilePath(r"/a/b/c/d/e/foo.bar");
    test (fp.isAbsolute);
    fp.folder (r"/a/b/c/d/e/f/g/");
    test (fp.suffix == r".bar");
    test (fp == r"/a/b/c/d/e/f/g/foo.bar");
    test (fp.name == "foo");
    test (fp.folder == r"/a/b/c/d/e/f/g/");
    test (fp.file == r"foo.bar");
    test (fp.ext == "bar");
    test (fp.isChild);

    fp = new FilePath(r"/foo/bar/test.bar");
    test (fp.path == "/foo/bar/");
    fp = new FilePath(r"\foo\bar\test.bar");
    test (fp.path == r"/foo/bar/");

    fp = new FilePath("");
    test (fp.isEmpty);
    test (!fp.isChild);
    test (!fp.isAbsolute);
    test (fp.suffix == r"");
    test (fp == r"");
    test (fp.name == "");
    test (fp.folder == r"");
    test (fp.file == r"");
    test (fp.ext == "");
}
