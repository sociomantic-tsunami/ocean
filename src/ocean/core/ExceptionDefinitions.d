/**
 * The exception module defines all system-level exceptions and provides a
 * mechanism to alter system-level error handling.
 *
 * Copyright:
 *     Copyright (C) 2005-2006 Sean Kelly, Kris Bell.
 *     Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
 *     All rights reserved.
 *
 * License:
 *     Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
 *     See LICENSE_TANGO.txt for details.
 *
 * Authors: Sean Kelly, Kris Bell
 *
 */
module ocean.core.ExceptionDefinitions;

import ocean.meta.types.Qualifiers;

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

/**
 * Base class for operating system or library exceptions.
 */
class PlatformException : Exception
{
    this( string msg, string file = __FILE__, long line = __LINE__ )
    {
        super(msg, file, line);
    }
}


/**
 * Base class for ThreadPoolException
 */
class ThreadPoolException : Exception
{
    this( string msg, string file = __FILE__, long line = __LINE__ )
    {
        super(msg, file, line);
    }
}


/**
 * Base class for synchronization exceptions.
 */
class SyncException : PlatformException
{
    this( string msg, string file = __FILE__, long line = __LINE__ )
    {
        super(msg, file, line);
    }
}



/**
 * The basic exception thrown by the ocean.io package. One should try to ensure
 * that all Tango exceptions related to IO are derived from this one.
 */
class IOException : PlatformException
{
    /*******************************************************************

        Constructor

        Params:
            msg = message description of the error (uses stderr if empty)
            file = file where exception is thrown
            line = line where exception is thrown

    *******************************************************************/

    this( string msg, string file = __FILE__, long line = __LINE__ )
    {
        super(msg, file, line);
    }

    /*******************************************************************

        Constructor

        Params:
            msg = message description of the error (uses stderr if empty)
            error_num = error code
            func_name = name of the method that failed
            file = file where exception is thrown
            line = line where exception is thrown

    *******************************************************************/

    public this ( string msg, int error_num, string func_name,
        string file = __FILE__, long line = __LINE__ )
    {
        super(msg, file, line);

        this.error_num = error_num;
        this.func_name = func_name;
        this.line = line;
        this.file = file;
    }

    /*******************************************************************

        Error code

    *******************************************************************/

    protected int error_num;

    /*******************************************************************

        Last failed function name.

    *******************************************************************/

    protected string func_name;

    /*******************************************************************

        Returns:
            error code of the exception

    *******************************************************************/

    public int errorNumber ()
    {
        return this.error_num;
    }

    /*******************************************************************

        Returns:
            function name where the exception is thrown

    *******************************************************************/

    public string failedFunctionName ()
    {
        return this.func_name;
    }
}

/**
 * The basic exception thrown by the ocean.io.vfs package.
 */
class VfsException : IOException
{
    this( string msg, string file = __FILE__, long line = __LINE__ )
    {
        super(msg, file, line);
    }
}

/**
 * The basic exception thrown by the ocean.io.cluster package.
 */
class ClusterException : IOException
{
    this( string msg, string file = __FILE__, long line = __LINE__ )
    {
        super(msg, file, line);
    }
}

/**
 * Base class for socket exceptions.
 */
class SocketException : IOException
{
    this( string msg, string file = __FILE__, long line = __LINE__ )
    {
        super(msg, file, line);
    }
}


/**
 * Base class for exception thrown by an InternetHost.
 */
class HostException : IOException
{
    this( string msg, string file = __FILE__, long line = __LINE__ )
    {
        super(msg, file, line);
    }
}


/**
 * Base class for exceptiond thrown by an Address.
 */
class AddressException : IOException
{
    this( string msg, string file = __FILE__, long line = __LINE__ )
    {
        super(msg, file, line);
    }
}


/**
 * Thrown when a socket failed to accept an incoming connection.
 */
class SocketAcceptException : SocketException
{
    this( string msg, string file = __FILE__, long line = __LINE__ )
    {
        super(msg, file, line);
    }
}

/**
 * Thrown on a process error.
 */
class ProcessException : PlatformException
{
    this( string msg, string file = __FILE__, long line = __LINE__ )
    {
        super(msg, file, line);
    }
}


/**
 * Represents a text processing error.
 */
class TextException : Exception
{
    this( string msg, string file = __FILE__, long line = __LINE__ )
    {
        super(msg, file, line);
    }
}


/**
 * Base class for regluar expression exceptions.
 */
class RegexException : TextException
{
    this( string msg, string file = __FILE__, long line = __LINE__ )
    {
        super(msg, file, line);
    }
}


/**
 * Base class for locale exceptions.
 */
class LocaleException : TextException
{
    this( string msg, string file = __FILE__, long line = __LINE__ )
    {
        super(msg, file, line);
    }
}


/**
 * Base class for XML exceptions.
 */
class XmlException : TextException
{
    this( string msg, string file = __FILE__, long line = __LINE__ )
    {
        super(msg, file, line);
    }
}


/**
 * RegistryException is thrown when the NetworkRegistry encounters a
 * problem during proxy registration, or when it sees an unregistered
 * guid.
 */
class RegistryException : Exception
{
    this( string msg, string file = __FILE__, long line = __LINE__ )
    {
        super(msg, file, line);
    }
}


/**
 * Thrown when an illegal argument is encountered.
 */
class IllegalArgumentException : Exception
{
    this( string msg, string file = __FILE__, long line = __LINE__ )
    {
        super(msg, file, line);
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
    this( string msg, string file = __FILE__, long line = __LINE__ )
    {
        super(msg, file, line);
    }
}


/**
 * Thrown on past-the-end errors by iterators and containers.
 */
class NoSuchElementException : Exception
{
    this( string msg, string file = __FILE__, long line = __LINE__ )
    {
        super(msg, file, line);
    }
}


/**
 * Thrown when a corrupt iterator is detected.
 */
class CorruptedIteratorException : NoSuchElementException
{
    this( string msg, string file = __FILE__, long line = __LINE__ )
    {
        super(msg, file, line);
    }
}
