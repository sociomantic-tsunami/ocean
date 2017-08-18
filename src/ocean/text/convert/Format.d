/*******************************************************************************

    Copyright:
        Copyright (c) 2007 Kris Bell.
        Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

    Version:
        Sep 2007: Initial release
        Nov 2007: Added stream wrappers

    Authors: Kris

 *******************************************************************************/

module ocean.text.convert.Format;

deprecated import ocean.text.convert.Layout_tango;

/******************************************************************************

  Constructs a global utf8 instance of Layout

 ******************************************************************************/

deprecated("Use ocean.text.convert.Formatter : [s[n]]format instead")
public Layout!(char) Format;

deprecated static this()
{
    Format = Layout!(char).instance;
}

