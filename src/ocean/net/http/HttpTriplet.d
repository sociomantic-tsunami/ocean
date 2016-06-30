/*******************************************************************************

        Copyright:
            Copyright (c) 2004 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: December 2005

        Authors: Kris

*******************************************************************************/

module ocean.net.http.HttpTriplet;

import ocean.transition;

/******************************************************************************

        Class to represent an HTTP response- or request-line

******************************************************************************/

class HttpTriplet
{
        protected char[]        line;
        protected char[]        failed;
        protected char[][3]     tokens;

        /**********************************************************************

                test the validity of these tokens

        **********************************************************************/

        abstract bool test ();

        /**********************************************************************

                Parse the the given line into its constituent components.

        **********************************************************************/

        bool parse (char[] line)
        {
                int i;
                int mark;

                this.line = line;
                foreach (int index, char c; line)
                         if (c is ' ')
                         {
                             if (i < 2)
                             {
                                tokens[i] = line[mark .. index];
                                mark = index+1;
                                ++i;
                             }
                             else
                                break;
                         }

                tokens[2] = line [mark .. line.length];
                return test;
        }

        /**********************************************************************

                return a copy of the original string

        **********************************************************************/

        override istring toString ()
        {
                return idup(line);
        }

        /**********************************************************************

                return error string after a failed parse()

        **********************************************************************/

        final char[] error ()
        {
                return failed;
        }
}
