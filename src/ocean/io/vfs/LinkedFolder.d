/*******************************************************************************

        Copyright:
            Copyright (c) 2007 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Oct 2007: Initial version

        Authors: Kris

*******************************************************************************/

module ocean.io.vfs.LinkedFolder;

import ocean.transition;

import ocean.io.vfs.model.Vfs;

import ocean.core.Exception_tango;

import ocean.io.vfs.VirtualFolder;

/*******************************************************************************

        LinkedFolder is derived from VirtualFolder, and behaves exactly the
        same in all but one aspect: it treats mounted folders as an ordered
        list of alternatives to look for a file. This supports the notion of
        file 'overrides', whereby "customized" files can be inserted into a
        chain of alternatives.

        (Overridden folders are not currently supported.)

*******************************************************************************/


class LinkedFolder : VirtualFolder
{
        private Link* head;

        /***********************************************************************

                Linked-list of folders.

        ***********************************************************************/

        private struct Link
        {
                Link*     next;
                VfsFolder folder;

                static Link* opCall(VfsFolder folder)
                {
                        auto p = new Link;
                        p.folder = folder;
                        return p;
                }
        }

        /***********************************************************************

                All folder must have a name. No '.' or '/' chars are
                permitted.

        ***********************************************************************/

        this (istring name)
        {
                super (name);
        }

        /***********************************************************************

                Add a child folder. The child cannot 'overlap' with others
                in the tree of the same type. Circular references across a
                tree of virtual folders are detected and trapped.

                We add the new child at the end of an ordered list, which
                we subsequently traverse when looking up a file.

                The second argument represents an optional name that the
                mount should be known as, instead of the name exposed by
                the provided folder (it is not an alias).

        ***********************************************************************/

        final override VfsHost mount (VfsFolder folder, istring name=null)
        {
                // traverse to the end of the list
                auto link = &head;
                while (*link)
                        link = &(*link).next;

                // hook up the new folder
                *link = Link (folder);

                // and let superclass deal with it
                return super.mount (folder, name);
        }

        /***********************************************************************

                TODO: Unhook a child folder.

        ***********************************************************************/

        final override VfsHost dismount (VfsFolder folder)
        {
                assert (0, "LinkedFolder.dismount not implemented");
        }

        /***********************************************************************

                Return a file representation of the given path. If the
                path-head does not refer to an immediate child folder,
                and does not match a symbolic link, it is considered to
                be unknown.

                We scan the set of mounted folders, in the order mounted,
                looking for a match. Where one is found, we test to see
                that it really exists before returning the reference.

        ***********************************************************************/

        final override VfsFile file (istring path)
        {
                auto link = head;
                while (link)
                      {
                      //Stdout.formatln ("looking in {}", link.folder.toString);
                      try {
                          auto file = link.folder.file (path);
                          if (file.exists)
                              return file;
                          } catch (VfsException x) {}
                      link = link.next;
                      }
                super.error ("file '"~path~"' not found");
                return null;
        }
}


debug (LinkedFolder)
{
/*******************************************************************************

*******************************************************************************/

import ocean.io.Stdout_tango;
import ocean.io.vfs.FileFolder;

void main()
{
        auto root = new LinkedFolder ("root");
        auto sub  = new VirtualFolder ("sub");
        sub.mount (new FileFolder (r"d:/d/import/temp"));
        sub.map (sub.file(r"temp/subtree/test.txt"), "wumpus");

        root.mount (new FileFolder (r"d:/d/import/tango"))
            .mount (new FileFolder (r"c:/"), "windows");
        root.mount (sub);

        auto file = root.file (r"wumpus");
        Stdout.formatln ("file = {}", file);
}
}
