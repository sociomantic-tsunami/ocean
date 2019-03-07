/*******************************************************************************

        Copyright:
            Copyright (c) 2007 Kris Bell.
            Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Oct 2007: Initial version

        Authors: Kris

*******************************************************************************/

module ocean.io.vfs.FileFolder;

import ocean.transition;

import ocean.core.Verify;

import ocean.io.device.File;

import Path = ocean.io.Path;

import ocean.core.ExceptionDefinitions;

public import ocean.io.vfs.model.Vfs;

import ocean.io.model.IConduit;

import ocean.time.Time : Time;

/*******************************************************************************

        Represents a physical folder in a file system. Use one of these
        to address specific paths (sub-trees) within the file system.

*******************************************************************************/

class FileFolder : VfsFolder
{
        private istring         path;
        private VfsStats        stats;

        /***********************************************************************

                Create a file folder with the given path.

                Option 'create' will create the path when set true,
                or reference an existing path otherwise.

        ***********************************************************************/

        this (istring path, bool create=false)
        {
                auto mpath = Path.standard(path.dup);
                this.path = open (assumeUnique(mpath), create);
        }

        /***********************************************************************

                Create a FileFolder as a Group member.

        ***********************************************************************/

        private this (istring path, istring name)
        {
                auto mpath = Path.join (path, name);
                this.path = assumeUnique(mpath);
        }

        /***********************************************************************

                Explicitly create() or open() a named folder.

        ***********************************************************************/

        private this (FileFolder parent, istring name, bool create=false)
        {
                .verify(parent !is null);
                auto mpath = Path.join(parent.path, name);
                this.path = open (assumeUnique(mpath), create);
        }

        /***********************************************************************

                Return a short name.

        ***********************************************************************/

        final istring name ()
        {
                auto mname = Path.parse(path.dup).name;
                return assumeUnique(mname);
        }

        /***********************************************************************

                Return a long name.

        ***********************************************************************/

        final override istring toString ()
        {
                return idup(path);
        }

        /***********************************************************************

                A folder is being added or removed from the hierarchy. Use
                this to test for validity (or whatever) and throw exceptions
                as necessary

                Here we test for folder overlap, and bail-out when found.

        ***********************************************************************/

        final void verify (VfsFolder folder, bool mounting)
        {
                if (mounting && cast(FileFolder) folder)
                   {
                   auto src = Path.FS.padded (this.path);
                   auto dst = Path.FS.padded (folder.toString.dup);

                   auto len = src.length;
                   if (len > dst.length)
                       len = dst.length;

                   if (src[0..len] == dst[0..len])
                       error ("folders '"~dst~"' and '"~src~"' overlap");
                   }
        }

        /***********************************************************************

                Return a contained file representation.

        ***********************************************************************/

        final VfsFile file (istring name)
        {
            auto mpath = Path.join (path, name);
            return new FileHost (assumeUnique(mpath));
        }

        /***********************************************************************

                Return a contained folder representation.

        ***********************************************************************/

        final VfsFolderEntry folder (istring path)
        {
                return new FolderHost (this, path);
        }

        /***********************************************************************

                Remove the folder subtree. Use with care!

        ***********************************************************************/

        final VfsFolder clear ()
        {
                Path.remove (Path.collate(path, "*", true));
                return this;
        }

        /***********************************************************************

                Is folder writable?

        ***********************************************************************/

        final bool writable ()
        {
                return Path.isWritable (path);
        }

        /***********************************************************************

                Returns content information about this folder.

        ***********************************************************************/

        final VfsFolders self ()
        {
                return new FolderGroup (this, false);
        }

        /***********************************************************************

                Returns a subtree of folders matching the given name.

        ***********************************************************************/

        final VfsFolders tree ()
        {
                return new FolderGroup (this, true);
        }

        /***********************************************************************

                Iterate over the set of immediate child folders. This is
                useful for reflecting the hierarchy.

        ***********************************************************************/

        final int opApply (scope int delegate(ref VfsFolder) dg)
        {
                int result;

                foreach (folder; folders(true))
                        {
                        VfsFolder x = folder;
                        if ((result = dg(x)) != 0)
                             break;
                        }
                return result;
        }

        /***********************************************************************

                Close and/or synchronize changes made to this folder. Each
                driver should take advantage of this as appropriate, perhaps
                combining multiple files together, or possibly copying to a
                remote location.

        ***********************************************************************/

        VfsFolder close (bool commit = true)
        {
                return this;
        }

        /***********************************************************************

                Sweep owned folders.

        ***********************************************************************/

        private FileFolder[] folders (bool collect)
        {
                FileFolder[] folders;

                stats = stats.init;
                foreach (info; Path.children (path))
                         if (info.folder)
                            {
                            if (collect)
                                folders ~= new FileFolder (info.path, info.name);
                            ++stats.folders;
                            }
                         else
                            {
                            stats.bytes += info.bytes;
                           ++stats.files;
                            }

                return folders;
        }

        /***********************************************************************

                Sweep owned files.

        ***********************************************************************/

        private char[][] files (ref VfsStats stats, scope VfsFilter filter = null)
        {
                char[][] files;

                foreach (info; Path.children (path))
                         if (info.folder is false)
                             if (filter is null || filter(&info))
                                {
                                files ~= Path.join (info.path, info.name);
                                stats.bytes += info.bytes;
                                ++stats.files;
                                }

                return files;
        }

        /***********************************************************************

                Throw an exception.

        ***********************************************************************/

        private char[] error (cstring msg)
        {
                throw new VfsException (idup(msg));
        }

        /***********************************************************************

                Create or open the given path, and detect path errors.

        ***********************************************************************/

        private istring open (istring path, bool create)
        {
                if (Path.exists (path))
                   {
                   if (! Path.isFolder (path))
                       error ("FileFolder.open :: path exists but not as a folder: "~path);
                   }
                else
                   if (create)
                       Path.createPath (path);
                   else
                      error ("FileFolder.open :: path does not exist: "~path);
                return path;
        }
}


/*******************************************************************************

        Represents a group of files (need this declared here to avoid
        a bunch of bizarre compiler warnings.)

*******************************************************************************/

class FileGroup : VfsFiles
{
        private char[][]        group;          // set of filtered filenames
        private char[][]        hosts;          // set of containing folders
        private VfsStats        stats;          // stats for contained files

        /***********************************************************************

        ***********************************************************************/

        this (FolderGroup host, scope VfsFilter filter)
        {
                foreach (folder; host.members)
                        {
                        auto files = folder.files (stats, filter);
                        if (files.length)
                           {
                           group ~= files;
                           //hosts ~= folder.toString;
                           }
                        }
        }

        /***********************************************************************

                Iterate over the set of contained VfsFile instances.

        ***********************************************************************/

        final int opApply (scope int delegate(ref VfsFile) dg)
        {
                int  result;
                auto host = new FileHost;

                foreach (file; group)
                        {
                        VfsFile x = host;
                        host.path.parse (file);
                        if ((result = dg(x)) != 0)
                             break;
                        }
                return result;
        }

        /***********************************************************************

                Return the total number of entries.

        ***********************************************************************/

        final uint files ()
        {
                return cast(uint) group.length;
        }

        /***********************************************************************

                Return the total size of all files.

        ***********************************************************************/

        final ulong bytes ()
        {
                return stats.bytes;
        }
}


/*******************************************************************************

        A set of folders representing a selection. This is where file
        selection is made, and pattern-matched folder subsets can be
        extracted. You need one of these to expose statistics (such as
        file or folder count) of a selected folder group.

*******************************************************************************/

private class FolderGroup : VfsFolders
{
        private FileFolder[] members;           // folders in group

        /***********************************************************************

                Create a subset group.

        ***********************************************************************/

        private this () {}

        /***********************************************************************

                Create a folder group including the provided folder and
                (optionally) all child folders.

        ***********************************************************************/

        private this (FileFolder root, bool recurse)
        {
                members = root ~ scan (root, recurse);
        }

        /***********************************************************************

                Iterate over the set of contained VfsFolder instances.

        ***********************************************************************/

        final int opApply (scope int delegate(ref VfsFolder) dg)
        {
                int  result;

                foreach (folder; members)
                        {
                        VfsFolder x = folder;
                        if ((result = dg(x)) != 0)
                             break;
                        }
                return result;
        }

        /***********************************************************************

                Return the number of files in this group.

        ***********************************************************************/

        final uint files ()
        {
                uint files;
                foreach (folder; members)
                         files += folder.stats.files;
                return files;
        }

        /***********************************************************************

                Return the total size of all files in this group.

        ***********************************************************************/

        final ulong bytes ()
        {
                ulong bytes;

                foreach (folder; members)
                         bytes += folder.stats.bytes;
                return bytes;
        }

        /***********************************************************************

                Return the number of folders in this group.

        ***********************************************************************/

        final uint folders ()
        {
                if (members.length is 1)
                    return members[0].stats.folders;
                return cast(uint) members.length;
        }

        /***********************************************************************

                Return the total number of entries in this group.

        ***********************************************************************/

        final uint entries ()
        {
                return files + folders;
        }

        /***********************************************************************

                Return a subset of folders matching the given pattern.

        ***********************************************************************/

        final VfsFolders subset (istring pattern)
        {
                Path.PathParser parser;
                auto set = new FolderGroup;

                foreach (folder; members)
                         if (Path.patternMatch (parser.parse(folder.path.dup).name, pattern))
                             set.members ~= folder;
                return set;
        }

        /***********************************************************************

                Return a set of files matching the given pattern.

        ***********************************************************************/

        final FileGroup catalog (istring pattern)
        {
                bool foo (VfsInfo info)
                {
                        return Path.patternMatch (info.name, pattern);
                }

                return catalog (&foo);
        }

        /***********************************************************************

                Returns a set of files conforming to the given filter.

        ***********************************************************************/

        final FileGroup catalog (scope VfsFilter filter = null)
        {
                return new FileGroup (this, filter);
        }

        /***********************************************************************

                Internal routine to traverse the folder tree.

        ***********************************************************************/

        private final FileFolder[] scan (FileFolder root, bool recurse)
        {
                auto folders = root.folders (recurse);
                if (recurse)
                    foreach (child; folders)
                             folders ~= scan (child, recurse);
                return folders;
        }
}


/*******************************************************************************

        A host for folders, currently used to harbor create() and open()
        methods only.

*******************************************************************************/

private class FolderHost : VfsFolderEntry
{
        private istring         path;
        private FileFolder      parent;

        /***********************************************************************

        ***********************************************************************/

        private this (FileFolder parent, istring path)
        {
                this.path = idup(path);
                this.parent = parent;
        }

        /***********************************************************************

        ***********************************************************************/

        final VfsFolder create ()
        {
                return new FileFolder (parent, path, true);
        }

        /***********************************************************************

        ***********************************************************************/

        final VfsFolder open ()
        {
                return new FileFolder (parent, path, false);
        }

        /***********************************************************************

                Test to see if a folder exists.

        ***********************************************************************/

        bool exists ()
        {
                try {
                    open();
                    return true;
                    } catch (IOException x) {}
                return false;
        }
}


/*******************************************************************************

        Represents things you can do with a file.

*******************************************************************************/

private class FileHost : VfsFile
{
        // effectively immutable, mutated only in constructor
        private Path.PathParser path;

        /***********************************************************************

        ***********************************************************************/

        this (istring path = null)
        {
                this.path.parse (path.dup);
        }

        /***********************************************************************

                Return a short name.

        ***********************************************************************/

        final istring name()
        {
                return cast(istring) path.file;
        }

        /***********************************************************************

                Return a long name.

        ***********************************************************************/

        final override istring toString ()
        {
                return path.toString;
        }

        /***********************************************************************

                Does this file exist?

        ***********************************************************************/

        final bool exists()
        {
                return Path.exists (path.toString);
        }

        /***********************************************************************

                Return the file size.

        ***********************************************************************/

        final ulong size()
        {
                return Path.fileSize(path.toString);
        }

        /***********************************************************************

                Create a new file instance.

        ***********************************************************************/

        final VfsFile create ()
        {
                Path.createFile(path.toString);
                return this;
        }

        /***********************************************************************

                Create a new file instance and populate with stream.

        ***********************************************************************/

        final VfsFile create (InputStream input)
        {
                create.output.copy(input).close;
                return this;
        }

        /***********************************************************************

                Create and copy the given source.

        ***********************************************************************/

        VfsFile copy (VfsFile source)
        {
                auto input = source.input;
                scope (exit) input.close;
                return create (input);
        }

        /***********************************************************************

                Create and copy the given source, and remove the source.

        ***********************************************************************/

        final VfsFile move (VfsFile source)
        {
                copy (source);
                source.remove;
                return this;
        }

        /***********************************************************************

                Return the input stream. Don't forget to close it.

        ***********************************************************************/

        final InputStream input ()
        {
                return new File (path.toString);
        }

        /***********************************************************************

                Return the output stream. Don't forget to close it.

        ***********************************************************************/

        final OutputStream output ()
        {
                return new File (path.toString, File.WriteExisting);
        }

        /***********************************************************************

                Remove this file.

        ***********************************************************************/

        final VfsFile remove ()
        {
                Path.remove (path.toString);
                return this;
        }

        /***********************************************************************

                Duplicate this entry.

        ***********************************************************************/

        final VfsFile dup()
        {
                auto ret = new FileHost;
                ret.path = path.dup;
                return ret;
        }

        /***********************************************************************

                Modified time of the file.

        ***********************************************************************/

        final Time modified ()
        {
                return Path.timeStamps(path.toString).modified;
        }
}


debug (FileFolder)
{

/*******************************************************************************

*******************************************************************************/

import ocean.io.Stdout;
import ocean.io.device.Array;

void main()
{
        auto root = new FileFolder ("d:/d/import/temp", true);
        root.folder("test").create;
        root.file("test.txt").create(new Array("hello"));
        Stdout.formatln ("test.txt.length = {}", root.file("test.txt").size);

        root = new FileFolder ("c:/");
        auto set = root.self;

        Stdout.formatln ("self.files = {}", set.files);
        Stdout.formatln ("self.bytes = {}", set.bytes);
        Stdout.formatln ("self.folders = {}", set.folders);
        Stdout.formatln ("self.entries = {}", set.entries);
/+
        set = root.tree;
        Stdout.formatln ("tree.files = {}", set.files);
        Stdout.formatln ("tree.bytes = {}", set.bytes);
        Stdout.formatln ("tree.folders = {}", set.folders);
        Stdout.formatln ("tree.entries = {}", set.entries);

        //foreach (folder; set)
        //Stdout.formatln ("tree.folder '{}' has {} files", folder.name, folder.self.files);

        auto cat = set.catalog ("s*");
        Stdout.formatln ("cat.files = {}", cat.files);
        Stdout.formatln ("cat.bytes = {}", cat.bytes);
+/
        //foreach (file; cat)
        //         Stdout.formatln ("cat.name '{}' '{}'", file.name, file.toString);
}
}
