/*******************************************************************************

    Extension for the SignalExt Application extension. All objects which wish to
    be notified of the receipt of signals by the application must implement this
    interface and register themselves with the signal extension.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.ext.model.ISignalExtExtension;



/*******************************************************************************

    Imports

*******************************************************************************/

public import ocean.util.app.model.IApplication;

import ocean.util.app.model.IExtension;



/*******************************************************************************

    Interface for extensions for the SignalExt extension.

*******************************************************************************/

interface ISignalExtExtension : IExtension
{
    /***************************************************************************

        Called when the SignalExt is notified of a signal.

        Params:
            signum = number of signal which was received

    ***************************************************************************/

    void onSignal ( int signum );
}

