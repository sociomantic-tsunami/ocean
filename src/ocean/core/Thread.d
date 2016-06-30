/**
 * The thread module provides support for thread creation and management.
 *
 * If AtomicSuspendCount is used for speed reasons all signals are sent together.
 * When debugging gdb funnels all signals through one single handler, and if
 * the signals arrive quickly enough they will be coalesced in a single signal,
 * (discarding the second) thus it is possible to loose signals, which blocks
 * the program. Thus when debugging it is better to use the slower SuspendOneAtTime
 * version.
 *
 * Copyright:
 *     Copyright (C) 2005-2006 Sean Kelly, Fawzi.
 *     Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
 *     All rights reserved.
 *
 * License:
 *     Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
 *     See LICENSE_TANGO.txt for details.
 *
 * Authors: Sean Kelly, Fawzi Mohamed
 *
 */
module ocean.core.Thread;

public import core.thread;

