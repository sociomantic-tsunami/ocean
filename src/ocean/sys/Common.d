/*******************************************************************************

        Copyright:
            Copyright (c) 2004 Kris Bell.
            Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: November 2005

        Authors: Kris

*******************************************************************************/

module ocean.sys.Common;

import ocean.core.TypeConvert : assumeUnique;
import ocean.meta.types.Qualifiers;

public import ocean.sys.linux.linux;
alias ocean.sys.linux.linux posix;

/*******************************************************************************

        Stuff for sysErrorMsg(), kindly provided by Regan Heath.

*******************************************************************************/

import core.stdc.errno;
import core.stdc.string;


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

        static string lastMsg ()
        {
                return lookup (lastCode);
        }

        /***********************************************************************

        ***********************************************************************/

        static string lookup (uint errcode)
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
