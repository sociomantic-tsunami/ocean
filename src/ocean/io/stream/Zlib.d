/*******************************************************************************

    Zlib base stream

    Copyright:
        Copyright (C) 2007 Daniel Keep.
        Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

        Bear in mind this module provides bindings to an external library that
        has its own license, which might be more restrictive. Please check the
        external library license to see which conditions apply for linking.

    Version:
        Feb 08: Added support for different stream encodings, removed
                old "window bits" ctors.$(BR)
        Dec 07: Added support for "window bits", needed for Zip support.$(BR)
        Jul 07: Initial release.

    Authors: Daniel Keep

*******************************************************************************/

deprecated module ocean.io.stream.Zlib;

import ocean.transition;

import ocean.util.compress.c.zlib;

import ocean.stdc.stringz : fromStringz;

import ocean.core.Exception_tango : IOException;

import ocean.io.device.Conduit : InputFilter, OutputFilter;

import ocean.io.model.IConduit : InputStream, OutputStream, IConduit;

import ocean.text.convert.Integer_tango : toString;


deprecated("Removed from public access, use ZlibStream instead"):

public import ocean.io.stream.Zlib_internal;
