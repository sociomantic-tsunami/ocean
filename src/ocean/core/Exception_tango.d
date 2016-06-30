/**
 * The exception module defines all system-level exceptions and provides a
 * mechanism to alter system-level error handling.
 *
 * Copyright:
 *     Copyright (C) 2005-2006 Sean Kelly, Kris Bell.
 *     Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
 *     All rights reserved.
 *
 * License:
 *     Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
 *     See LICENSE_TANGO.txt for details.
 *
 * Authors: Sean Kelly, Kris Bell
 *
 */
module ocean.core.Exception_tango;

import ocean.transition;

version = SocketSpecifics;              // TODO: remove this before v1.0


private
{
    alias void  function( istring file, size_t line, istring msg = null ) assertHandlerType;

    version(D_Version2)
    {
        mixin("__gshared assertHandlerType assertHandler   = null;");
    }
    else
    {
        assertHandlerType assertHandler   = null;
    }
}


////////////////////////////////////////////////////////////////////////////////
/*
- Exception
  - OutOfMemoryException
  - SwitchException
  - AssertException
  - ArrayBoundsException
  - FinalizeException

  - PlatformException
    - ProcessException
    - ThreadException
      - FiberException
    - ThreadPoolException
    - SyncException
    - IOException
      - SocketException
      - VfsException
      - ClusterException

  - NoSuchElementException
    - CorruptedIteratorException

  - IllegalArgumentException
    - IllegalElementException

  - TextException
    - XmlException
    - RegexException
    - LocaleException
    - UnicodeException

  - PayloadException
*/
////////////////////////////////////////////////////////////////////////////////


public import core.exception;

import core.thread;
alias core.thread.ThreadException ThreadException;

// Tango backwards compatibility aliases
public alias AssertError AssertException;
public alias OutOfMemoryError OutOfMemoryException;
public alias FinalizeError FinalizeException;
public alias RangeError ArrayBoundsException;
public alias SwitchError SwitchException;

/**
 * Base class for operating system or library exceptions.
 */
class PlatformException : Exception
{
    this( istring msg )
    {
        super( msg );
    }
}


/**
 * Base class for ThreadPoolException
 */
class ThreadPoolException : Exception
{
    this( istring msg )
    {
        super( msg );
    }
}


/**
 * Base class for synchronization exceptions.
 */
class SyncException : PlatformException
{
    this( istring msg )
    {
        super( msg );
    }
}



/**
 * The basic exception thrown by the ocean.io package. One should try to ensure
 * that all Tango exceptions related to IO are derived from this one.
 */
class IOException : PlatformException
{
    this( istring msg )
    {
        super( msg );
    }
}

/**
 * The basic exception thrown by the ocean.io.vfs package.
 */
class VfsException : IOException
{
    this( istring msg )
    {
        super( msg );
    }
}

/**
 * The basic exception thrown by the ocean.io.cluster package.
 */
class ClusterException : IOException
{
    this( istring msg )
    {
        super( msg );
    }
}

/**
 * Base class for socket exceptions.
 */
class SocketException : IOException
{
    this( istring msg )
    {
        super( msg );
    }
}


/**
 * Base class for exception thrown by an InternetHost.
 */
class HostException : IOException
{
    this( istring msg )
    {
        super( msg );
    }
}


/**
 * Base class for exceptiond thrown by an Address.
 */
class AddressException : IOException
{
    this( istring msg )
    {
        super( msg );
    }
}


/**
 * Thrown when a socket failed to accept an incoming connection.
 */
class SocketAcceptException : SocketException
{
    this( istring msg )
    {
        super( msg );
    }
}

/**
 * Thrown on a process error.
 */
class ProcessException : PlatformException
{
    this( istring msg )
    {
        super( msg );
    }
}


/**
 * Represents a text processing error.
 */
class TextException : Exception
{
    this( istring msg )
    {
        super( msg );
    }
}


/**
 * Base class for regluar expression exceptions.
 */
class RegexException : TextException
{
    this( istring msg )
    {
        super( msg );
    }
}


/**
 * Base class for locale exceptions.
 */
class LocaleException : TextException
{
    this( istring msg )
    {
        super( msg );
    }
}


/**
 * Base class for XML exceptions.
 */
class XmlException : TextException
{
    this( istring msg )
    {
        super( msg );
    }
}


/**
 * RegistryException is thrown when the NetworkRegistry encounters a
 * problem during proxy registration, or when it sees an unregistered
 * guid.
 */
class RegistryException : Exception
{
    this( istring msg )
    {
        super( msg );
    }
}


/**
 * Thrown when an illegal argument is encountered.
 */
class IllegalArgumentException : Exception
{
    this( istring msg )
    {
        super( msg );
    }
}


/**
 *
 * IllegalElementException is thrown by Collection methods
 * that add (or replace) elements (and/or keys) when their
 * arguments are null or do not pass screeners.
 *
 */
class IllegalElementException : IllegalArgumentException
{
    this( istring msg )
    {
        super( msg );
    }
}


/**
 * Thrown on past-the-end errors by iterators and containers.
 */
class NoSuchElementException : Exception
{
    this( istring msg )
    {
        super( msg );
    }
}


/**
 * Thrown when a corrupt iterator is detected.
 */
class CorruptedIteratorException : NoSuchElementException
{
    this( istring msg )
    {
        super( msg );
    }
}
