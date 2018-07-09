/**
 * The vararg module is intended to facilitate vararg manipulation in D.
 * It should be interface compatible with the C module "stdarg," and the
 * two modules may share a common implementation if possible (as is done
 * here).
 *
 * Copyright:
 *     Public Domain
 *     Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
 *     All rights reserved.
 *
 * License:
 *     Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
 *     See LICENSE_TANGO.txt for details.
 *
 * Authors: Hauke Duden, Walter Bright
 *
 */
deprecated module ocean.core.Vararg;

pragma(msg, "Import core.stdc.stdarg instead of ocean.core.Vararg");

public import core.stdc.stdarg;
