/*******************************************************************************

    Base interface for Loggers implementation

    Note:
        The formatting primitives (error, info, warn...) are not part of the
        interface anymore, as they can be templated functions.

    Copyright:
        Copyright (c) 2004 Kris Bell.
        Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

    Version: Initial release: May 2004

    Authors: Kris

*******************************************************************************/

deprecated("Import `ocean.util.log.ILogger` instead")
module ocean.util.log.model.ILogger;

public import ocean.util.log.ILogger;
