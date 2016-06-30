/*******************************************************************************

    Base extension class for the Application framework. It just provides
    ordering to extensions.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.model.IExtension;


/*******************************************************************************

    Base extension class for the Application framework.

*******************************************************************************/

interface IExtension
{

    /***************************************************************************

        Returns a number to provide ordering to extensions.

        Smaller numbers are executed first (can be negative).

        By convention, the default order, if ordering is not important, should
        be zero.

    ***************************************************************************/

    int order ( );

}

