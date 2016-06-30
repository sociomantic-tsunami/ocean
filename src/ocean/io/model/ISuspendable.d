/*******************************************************************************

    Interface for a process which can be suspended and resumed.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.io.model.ISuspendable;


/*******************************************************************************

    Interface to a process which can be suspended and resumed.

*******************************************************************************/

public interface ISuspendable
{
    /***************************************************************************

        Requests that further processing be temporarily suspended, until
        resume() is called.

    ***************************************************************************/

    public void suspend ( );


    /***************************************************************************

        Requests that processing be resumed.

    ***************************************************************************/

    public void resume ( );


    /***************************************************************************

        Returns:
            true if the process is suspended

    ***************************************************************************/

    public bool suspended ( );
}
