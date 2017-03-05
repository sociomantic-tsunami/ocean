/*******************************************************************************

        Copyright:
            Copyright (c) 2007 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: Nov 2007

        Authors: Kris

*******************************************************************************/

module ocean.io.stream.DataFile;

import ocean.io.device.File;

import ocean.io.stream.Data;

/*******************************************************************************

        Composes a seekable file with buffered binary input. A seek causes
        the input buffer to be cleared.

*******************************************************************************/

class DataFileInput : DataInput
{
        private File conduit;

        /***********************************************************************

                Compose a FileStream.

        ***********************************************************************/

        this (char[] path, File.Style style = File.ReadExisting)
        {
                this (new File (path, style));
        }

        /***********************************************************************

                Wrap a File instance.

        ***********************************************************************/

        this (File file)
        {
                super (conduit = file);
        }

        /***********************************************************************

                Return the underlying conduit.

        ***********************************************************************/

        final File file ()
        {
                return conduit;
        }
}


/*******************************************************************************

        Composes a seekable file with buffered binary output. A seek causes
        the output buffer to be flushed first.

*******************************************************************************/

class DataFileOutput : DataOutput
{
        private File conduit;

        /***********************************************************************

                Compose a FileStream.

        ***********************************************************************/

        this (char[] path, File.Style style = File.WriteCreate)
        {
                this (new File (path, style));
        }

        /***********************************************************************

                Wrap a FileConduit instance.

        ***********************************************************************/

        this (File file)
        {
                super (conduit = file);
        }

        /***********************************************************************

                Return the underlying conduit.

        ***********************************************************************/

        final File file ()
        {
                return conduit;
        }
}

debug (DataFile)
{
        import ocean.io.Stdout;

        void main()
        {
                auto myFile = new DataFileOutput("Hello.txt");
                myFile.write("some text");
                myFile.flush;
                Stdout.formatln ("{}:{}", myFile.file.position, myFile.seek(myFile.Anchor.Current));
        }
}
