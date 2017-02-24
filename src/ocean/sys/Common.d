/*******************************************************************************

        Copyright:
            Copyright (c) 2004 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: November 2005

        Authors: Kris

*******************************************************************************/

module ocean.sys.Common;

import ocean.transition;

version (linux)
        {
        public import ocean.sys.linux.linux;
        alias ocean.sys.linux.linux posix;
        }

version (darwin)
        {
        public import ocean.sys.darwin.darwin;
        alias ocean.sys.darwin.darwin posix;
        }
version (freebsd)
        {
        public import ocean.sys.freebsd.freebsd;
        alias ocean.sys.freebsd.freebsd posix;
        }
version (solaris)
        {
        public import ocean.sys.solaris.solaris;
        alias ocean.sys.solaris.solaris posix;
        }

/*******************************************************************************

        Stuff for sysErrorMsg(), kindly provided by Regan Heath.

*******************************************************************************/

version (Posix)
        {
        import core.stdc.errno;
        import core.stdc.string;
        }
else
   {
   pragma (msg, "Unsupported environment; neither Win32 or Posix is declared");
   static assert(0);
   }


/*******************************************************************************

*******************************************************************************/

struct SysError
{
        /***********************************************************************

        ***********************************************************************/

        static uint lastCode ()
        {
             return errno;
        }

        /***********************************************************************

        ***********************************************************************/

        static istring lastMsg ()
        {
                return lookup (lastCode);
        }

        /***********************************************************************

        ***********************************************************************/

        static istring lookup (uint errcode)
        {
                char[] text;

                size_t  r;
                char* pemsg;

                pemsg = strerror(errcode);
                r = strlen(pemsg);

                /* Remove \r\n from error string */
                if (pemsg[r-1] == '\n') r--;
                if (pemsg[r-1] == '\r') r--;
                text = pemsg[0..r].dup;

                return assumeUnique(text);
        }
}
