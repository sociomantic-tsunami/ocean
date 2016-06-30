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

module ocean.io.stream.TextFile;

import ocean.transition;

public  import ocean.io.device.File;

import ocean.io.stream.Text;

/*******************************************************************************

        Composes a file with line-oriented input. The input is buffered.

*******************************************************************************/

class TextFileInput : TextInput
{
        /***********************************************************************

                Compose a FileStream.

        ***********************************************************************/

        this (cstring path, File.Style style = File.ReadExisting)
        {
                this (new File (path, style));
        }

        /***********************************************************************

                Wrap a FileConduit instance.

        ***********************************************************************/

        this (File file)
        {
                super (file);
        }
}


/*******************************************************************************

        Composes a file with formatted text output. Output is buffered.

*******************************************************************************/

class TextFileOutput : TextOutput
{
        /***********************************************************************

                Compose a FileStream.

        ***********************************************************************/

        this (cstring path, File.Style style = File.WriteCreate)
        {
                this (new File (path, style));
        }

        /***********************************************************************

                Wrap a File instance.

        ***********************************************************************/

        this (File file)
        {
                super (file);
        }
 }


/*******************************************************************************

*******************************************************************************/

debug (TextFile)
{
        import ocean.io.Console;

        void main()
        {
                auto t = new TextFileInput ("TextFile.d");
                foreach (line; t)
                         Cout(line).newline;
        }
}
