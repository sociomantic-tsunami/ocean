/**
 * A lightweight alternative to core.time that avoids all templates
 *
 * Copied from Tango-D2 project
 *
 * Copyright:
 *     Copyright (C) 2012 Pavel Sountsov.
 *     Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
 *     All rights reserved.
 *
 * License:
 *     Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
 *     See LICENSE_TANGO.txt for details.
 *
 * Authors: Pavel Sountsov
 *
 */
module ocean.core.Time;

static import core.time;

/**
 * Returns a Duration struct that represents secs seconds.
 */
core.time.Duration seconds(double secs)
{
        // TODO: check if this can be replaced with plain
        // usage of core.time.Duration

        struct DurationClone
        {
                long hnsecs;
        }

        return cast(core.time.Duration)(DurationClone(cast(long)(secs * 10_000_000)));
}
