/******************************************************************************

    Simple POSIX I/O device interfaces and base classes, significantly
    influenced by Tango's Conduit.

    An input device is merely an ISelectable (a file descriptor) with a read()
    method and an output an ISelectable device wih a write() method. read() and
    write() wrap the POSIX function with the same name.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.io.device.IODevice;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.transition;

import ocean.io.model.IConduit: ISelectable;

import core.sys.posix.unistd: read, write;
import ocean.stdc.posix.sys.types: ssize_t;

/******************************************************************************

    Input device interface

 ******************************************************************************/

interface IInputDevice : ISelectable
{
    /**************************************************************************

        Convenience type alias for subclasses/interfaces

     **************************************************************************/

    alias .ssize_t ssize_t;

    /**************************************************************************

        read()  attempts  to  read  up  to  dst.length  bytes  from  the  device
        associated with the file descriptor of this instance into dst.

        If dst.length is zero, read() returns zero and has no other results.  If
        count is greater than SSIZE_MAX, the result is unspecified.

        Params:
            dst = destination buffer

        Returns:
            On success, the number of bytes read is returned (zero indicates end
            of file), and the file position is advanced by this number.   It  is
            not  an  error  if  this  number is smaller than the number of bytes
            requested; this may happen for example because fewer bytes are actu‐
            ally  available  right  now  (maybe because we were close to end-of-
            file, or because we are reading from a pipe, or from a terminal), or
            because  read()  was  interrupted  by  a  signal.   On  error, -1 is
            returned, and errno is set appropriately.  In this case it  is  left
            unspecified whether the file position (if any) changes.

        Errors:

            EAGAIN The  file  descriptor fd refers to a file other than a socket
                   and has been marked nonblocking (O_NONBLOCK),  and  the  read
                   would block.

            EAGAIN or EWOULDBLOCK
                   The file descriptor fd refers to a socket and has been marked
                   nonblocking  (O_NONBLOCK),  and   the   read   would   block.
                   POSIX.1-2001  allows  either  error  to  be returned for this
                   case, and does not require these constants to have  the  same
                   value, so a portable application should check for both possi‐
                   bilities.

            EBADF  fd is not a valid file descriptor or is not open for reading.

            EFAULT dst is outside your accessible address space.

            EINTR  The call was interrupted by a  signal  before  any  data  was
                   read; see signal(7).

            EINVAL fd  is attached to an object which is unsuitable for reading;
                   or the file was opened with the O_DIRECT flag, and either the
                   address  specified  in  dst, the value specified in count, or
                   the current file offset is not suitably aligned.

            EINVAL fd was created via a call to timerfd_create(2) and the  wrong
                   size  buffer  was  given to read(); see timerfd_create(2) for
                   further information.

            EIO    I/O error.  This will happen for example when the process  is
                   in  a  background  process group, tries to read from its con‐
                   trolling tty, and either it is ignoring or  blocking  SIGTTIN
                   or  its  process  group  is orphaned.  It may also occur when
                   there is a low-level I/O error while reading from a  disk  or
                   tape.

            EISDIR fd refers to a directory.

            Other  errors  may  occur,  depending on the object connected to fd.
            POSIX allows a read() that is interrupted after reading some data to
            return -1 (with errno set to EINTR) or to return the number of bytes
            already read.

     **************************************************************************/

    ssize_t read ( void[] dst );
}

/******************************************************************************

    Output device interface

 ******************************************************************************/

interface IOutputDevice : ISelectable
{
    /**************************************************************************

        Convenience type alias for subclasses/interfaces

     **************************************************************************/

    alias .ssize_t ssize_t;

    /**************************************************************************

        write() writes up to count bytes from the buffer pointed buf to the file
        referred to by the file descriptor fd.

        The number of bytes written may be less  than  count  if,  for  example,
        there  is  insufficient  space on the underlying physical medium, or the
        RLIMIT_FSIZE resource limit is encountered (see  setrlimit(2)),  or  the
        call  was interrupted by a signal handler after having written less than
        count bytes.  (See also pipe(7).)

        For a seekable file (i.e., one to which lseek(2)  may  be  applied,  for
        example, a regular file) writing takes place at the current file offset,
        and the file offset is incremented by the number of bytes actually writ‐
        ten.   If the file was open(2)ed with O_APPEND, the file offset is first
        set to the end of the file before writing.  The adjustment of  the  file
        offset and the write operation are performed as an atomic step.

        POSIX  requires  that  a  read(2)  which  can be proved to occur after a
        write() has returned returns the new data.  Note that not all file  sys‐
        tems are POSIX conforming.

        Returns:
            On success, the number of bytes written is returned (zero  indicates
            nothing  was  written).   On error, -1 is returned, and errno is set
            appropriately.

            If count is zero and fd refers to a regular file, then  write()  may
            return  a failure status if one of the errors below is detected.  If
            no errors are detected, 0 will be returned without causing any other
            effect.  If count is zero and fd refers to a file other than a regu‐
            lar file, the results are not specified.


            write()  writes up to count bytes from the buffer pointed buf to the
            file referred to by the file descriptor fd.

            The number of bytes written may be less than count if, for  example,
            there  is  insufficient  space on the underlying physical medium, or
            the RLIMIT_FSIZE resource limit is encountered  (see  setrlimit(2)),
            or the call was interrupted by a signal handler after having written
            less than count bytes.  (See also pipe(7).)

            For a seekable file (i.e., one to which lseek(2) may be applied, for
            example,  a  regular  file)  writing takes place at the current file
            offset, and the file offset is incremented by the  number  of  bytes
            actually written.  If the file was open(2)ed with O_APPEND, the file
            offset is first set to the end of  the  file  before  writing.   The
            adjustment  of the file offset and the write operation are performed
            as an atomic step.

            POSIX requires that a read(2) which can be proved to occur  after  a
            write()  has  returned returns the new data.  Note that not all file
            systems are POSIX conforming.

        Errors:
            EAGAIN The file descriptor fd refers to a file other than  a  socket
                   and  has  been marked nonblocking (O_NONBLOCK), and the write
                   would block.

            EAGAIN or EWOULDBLOCK
                   The file descriptor fd refers to a socket and has been marked
                   nonblocking   (O_NONBLOCK),   and   the  write  would  block.
                   POSIX.1-2001 allows either error  to  be  returned  for  this
                   case,  and  does not require these constants to have the same
                   value, so a portable application should check for both possi‐
                   bilities.

            EBADF  fd is not a valid file descriptor or is not open for writing.

            EDESTADDRREQ
                   fd  refers  to a datagram socket for which a peer address has
                   not been set using connect(2).

            EFAULT buf is outside your accessible address space.

            EFBIG  An attempt was made to write a file that exceeds  the  imple‐
                   mentation-defined  maximum  file  size  or the process's file
                   size limit, or to  write  at  a  position  past  the  maximum
                   allowed offset.

            EINTR  The  call  was  interrupted  by  a signal before any data was
                   written; see signal(7).

            EINVAL fd is attached to an object which is unsuitable for  writing;
                   or the file was opened with the O_DIRECT flag, and either the
                   address specified in buf, the value specified  in  count,  or
                   the current file offset is not suitably aligned.

            EIO    A low-level I/O error occurred while modifying the inode.

            ENOSPC The  device containing the file referred to by fd has no room
                   for the data.

            EPIPE  fd is connected to a pipe or  socket  whose  reading  end  is
                   closed.   When  this  happens  the  writing process will also
                   receive a SIGPIPE signal.  (Thus, the write return  value  is
                   seen only if the program catches, blocks or ignores this sig‐
                   nal.)

            Other errors may occur, depending on the object connected to fd.

     **************************************************************************/

    ssize_t write ( Const!(void)[] dst );
}

/******************************************************************************

    Input device base class, may be used to conveniently implement an
    IInputDevice.

 ******************************************************************************/

abstract class InputDevice : IInputDevice
{
    /**************************************************************************

        Attempts to read dst.length bytes, see IInputDevice.read()
        documentation.

        Params:
            dst = destination data buffer

        Returns
            the number of bytes read and stored in dst on success, 0 on end-of-
            file condition or -1 on error. On error errno is set appropriately.

     **************************************************************************/

    public ssize_t read ( void[] dst )
    {
        return .read(this.fileHandle(), dst.ptr, dst.length);
    }
}

/******************************************************************************

    IODevice device base class, may be used to conveniently implement an I/O
    class that is both an IInputDevice and IOutputDevice.

 ******************************************************************************/

abstract class IODevice : InputDevice, IOutputDevice
{
    /**************************************************************************

        Attempts to write src.length bytes, see IOutputDevice.write()
        documentation.

        Params:
            src = source data buffer

        Returns
            the number of bytes written on success or -1 on error. On error
            errno is set appropriately.

     **************************************************************************/

    abstract public ssize_t write ( Const!(void)[] src );
}

/******************************************************************************

    Output device base class, may be used to conveniently implement an
    IOutputDevice.

 ******************************************************************************/

deprecated ("use IOutputDevice or IODevice instead")
abstract class OutputDevice : IOutputDevice
{
    /**************************************************************************

        Attempts to write src.length bytes, see IOutputDevice.write()
        documentation.

        Params:
            src = source data buffer

        Returns
            the number of bytes written on success or -1 on error. On error
            errno is set appropriately.

     **************************************************************************/

    public ssize_t write ( Const!(void)[] src )
    {
        return .write(this.fileHandle(), src.ptr, src.length);
    }
}
