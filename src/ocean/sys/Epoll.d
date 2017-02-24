/*****************************************************************************

    Linux Epoll API binding and utility struct.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 *****************************************************************************/

module ocean.sys.Epoll;

/*****************************************************************************

    Imports

 *****************************************************************************/

import ocean.transition;
import core.sys.posix.unistd: close;

/*****************************************************************************

    Struct bundling the event to register a file descriptor for with an
    attachment.

 *****************************************************************************/

align (1) struct epoll_event_t
{
    /**************************************************************************

        Events supported by epoll, can be OR-combined.

     **************************************************************************/

    enum Event : uint
    {
        None            = 0,

        /**********************************************************************

            The associated file is available for read(2) operations.

         **********************************************************************/

        EPOLLIN         = 0x001,

        /**********************************************************************

            There is urgent data available for read(2) operations.

         **********************************************************************/

        EPOLLPRI        = 0x002,

        /**********************************************************************

            The associated file is available for write(2) operations.

         **********************************************************************/

        EPOLLOUT        = 0x004,

        EPOLLRDNORM     = 0x040,
        EPOLLRDBAND     = 0x080,
        EPOLLWRNORM     = 0x100,
        EPOLLWRBAND     = 0x200,
        EPOLLMSG        = 0x400,

        /**********************************************************************

            Error condition happened on the associated file descriptor.
            epoll_wait(2) will always wait for this event; it is not necessary
            to set it in events.

         **********************************************************************/

        EPOLLERR        = 0x008,

        /**********************************************************************

            Hang up happened on the associated file descriptor. epoll_wait(2)
            will always wait for this event; it is not necessary to set it in
            events.

         **********************************************************************/

        EPOLLHUP        = 0x010,

        /**********************************************************************

            (since Linux 2.6.17)
            Stream socket peer closed connection, or shut down writing half of
            connection. (This flag is especially useful for writing simple code
            to detect peer shutdown when using Edge Triggered monitoring.)

         **********************************************************************/

        EPOLLRDHUP      = 0x2000,

        /**********************************************************************

            (since Linux 2.6.2)
            Sets the one-shot behavior for the associated file descriptor. This
            means that after an event is pulled out with epoll_wait(2) the
            associated file descriptor is internally disabled and no other
            events will be reported by the epoll interface. The user must call
            epoll_ctl() with EPOLL_CTL_MOD to rearm the file descriptor with a
            new event mask.

         **********************************************************************/

        EPOLLONESHOT    = 1u << 30,

        /**********************************************************************

            Sets the Edge Triggered behavior for the associated file descriptor.
            The default behavior for epoll is Level Triggered. See epoll(7) for
            more detailed information about Edge and Level Triggered event
            distribution architectures.

         **********************************************************************/

        EPOLLET         = 1u << 31
    }

    /**************************************************************************

        Mapping from Event -> string, useful for printouts

     **************************************************************************/

    static istring[Event] event_to_name;

    static this ( )
    {
        with ( Event )
        {
            event_to_name[EPOLLIN]       = "Re";
            event_to_name[EPOLLPRI]      = "Pr";
            event_to_name[EPOLLOUT]      = "Wr";
            event_to_name[EPOLLRDNORM]   = "Rn";
            event_to_name[EPOLLRDBAND]   = "Rb";
            event_to_name[EPOLLWRNORM]   = "Wn";
            event_to_name[EPOLLWRBAND]   = "Wb";
            event_to_name[EPOLLMSG]      = "Ms";
            event_to_name[EPOLLERR]      = "Er";
            event_to_name[EPOLLHUP]      = "Hu";
            event_to_name[EPOLLRDHUP]    = "Rh";
            event_to_name[EPOLLONESHOT]  = "Os";
            event_to_name[EPOLLET]       = "Et";
        }
        event_to_name.rehash;
    }

    /**************************************************************************

        Convenience type alias

     **************************************************************************/

    alias .epoll_data_t Data;

    /**************************************************************************

        Epoll events

     **************************************************************************/

    Event events;

    /**************************************************************************

        User data variable

     **************************************************************************/

    Data  data;
}

/******************************************************************************

    Epoll user data union

 ******************************************************************************/

align (1) union epoll_data_t
{
    void*   ptr;
    int     fd;
    uint    u32;
    ulong   u64;

    /**************************************************************************

        Sets ptr to o.

        Params:
            o = object to set ptr to

        Returns:
            ptr cast back to Object

     **************************************************************************/

    Object obj ( Object o )
    {
        return cast (Object) (this.ptr = cast (void*) o);
    }

    /**************************************************************************

        Obtains the object to which ptr should previously have been set.

        Returns:
            ptr cast back to Object

     **************************************************************************/

    Object obj ( )
    {
        return cast (Object) this.ptr;
    }
}

/******************************************************************************

    Flags accepted by epoll_create1(), can be OR-combined.

 ******************************************************************************/

enum EpollCreateFlags
{
    None            = 0,

    /**************************************************************************

        Set the close-on-exec (FD_CLOEXEC) flag on the new file descriptor.
        See the description of the O_CLOEXEC flag in open(2) for reasons why
        this may be useful.

     **************************************************************************/

    EPOLL_CLOEXEC   = 0x8_0000, // 02000000

    EPOLL_NONBLOCK  = 0x800     // 04000
}

/******************************************************************************

    epoll_ctl opcodes.

******************************************************************************/

enum EpollCtlOp : int
{
    /**************************************************************************

        Register the target file descriptor fd on the epoll instance referred to
        by the file descriptor epfd and associate the event event with the
        internal file linked to fd.

     **************************************************************************/

    EPOLL_CTL_ADD = 1,

    /**************************************************************************

        Remove (deregister) the target file descriptor fd from the epoll
        instance referred to by epfd. The event is ignored; it and can be null
        on Linux 2.6.9 or later.

     **************************************************************************/

    EPOLL_CTL_DEL = 2,

    /**************************************************************************

        Change the event event associated with the target file descriptor fd.

     **************************************************************************/

    EPOLL_CTL_MOD = 3
}


extern (C)
{
    /**************************************************************************

        Description

        epoll_create1() creates an epoll "instance", requesting the kernel to
        allocate an event backing store dimensioned for size descriptors.
        epoll_create1() returns a file descriptor referring to the new epoll
        instance. This file descriptor is used for all the subsequent calls to
        the epoll interface. When no longer required, the file descriptor
        returned by epoll_create1() should be closed by using close(2). When all
        file descriptors referring to an epoll instance have been closed, the
        kernel destroys the instance and releases the associated resources for
        reuse.

        The following value can be included in flags:

        EPOLL_CLOEXEC
            Set the close-on-exec (FD_CLOEXEC) flag on the new file descriptor.
            See the description of the O_CLOEXEC flag in open(2) for reasons why
            this may be useful.

        Return Value

        On success, these system calls return a nonnegative file descriptor.
        On error, -1 is returned, and errno is set to indicate the error.

        Errors

        EINVAL
            size is not positive.
        EINVAL
            Invalid value specified in flags.
        EMFILE
            The per-user limit on the number of epoll instances imposed by
            /proc/sys/fs/epoll/max_user_instances was encountered. See epoll(7)
            for further details.
        ENFILE
            The system limit on the total number of open files has been reached.
        ENOMEM
            There was insufficient memory to create the kernel object.

        Versions
            epoll_create1() was added to the kernel in version 2.6.27. Library
            support is provided in glibc starting with version 2.9.

     **************************************************************************/

    int epoll_create1(EpollCreateFlags flags = EpollCreateFlags.None);

    /**************************************************************************

        Description

        This system call performs control operations on the epoll instance
        referred to by the file descriptor epfd. It requests that the operation
        op be performed for the target file descriptor, fd.

        Valid values for the op argument are:

        EPOLL_CTL_ADD
            Register the target file descriptor fd on the epoll instance
            referred to by the file descriptor epfd and associate the event
            event with the internal file linked to fd.
        EPOLL_CTL_MOD
            Change the event event associated with the target file descriptor
            fd.
        EPOLL_CTL_DEL
            Remove (deregister) the target file descriptor fd from the epoll
            instance referred to by epfd. The event is ignored; it and can be null
            on Linux 2.6.9 or later.

        The event argument describes the object linked to the file descriptor
        fd. The events member is a bit set composed using the following
        available event types:

        EPOLLIN
            The associated file is available for read(2) operations.
        EPOLLOUT
            The associated file is available for write(2) operations.
        EPOLLRDHUP (since Linux 2.6.17)
            Stream socket peer closed connection, or shut down writing half of
            connection. (This flag is especially useful for writing simple code
            to detect peer shutdown when using Edge Triggered monitoring.)
        EPOLLPRI
            There is urgent data available for read(2) operations.
        EPOLLERR
            Error condition happened on the associated file descriptor.
            epoll_wait(2) will always wait for this event; it is not necessary
            to set it in events.
        EPOLLHUP
            Hang up happened on the associated file descriptor. epoll_wait(2)
            will always wait for this event; it is not necessary to set it in
            events.
        EPOLLET
            Sets the Edge Triggered behavior for the associated file descriptor.
            The default behavior for epoll is Level Triggered. See epoll(7) for
            more detailed information about Edge and Level Triggered event
            distribution architectures.
        EPOLLONESHOT (since Linux 2.6.2)
            Sets the one-shot behavior for the associated file descriptor. This
            means that after an event is pulled out with epoll_wait(2) the
            associated file descriptor is internally disabled and no other
            events will be reported by the epoll interface. The user must call
            epoll_ctl() with EPOLL_CTL_MOD to rearm the file descriptor with a
            new event mask.

        Return Value

        When successful, epoll_ctl() returns zero. When an error occurs,
        epoll_ctl() returns -1 and errno is set appropriately.

        Errors

        EBADF
            epfd or fd is not a valid file descriptor.
        EEXIST
            op was EPOLL_CTL_ADD, and the supplied file descriptor fd is already
            registered with this epoll instance.
        EINVAL
            epfd is not an epoll file descriptor, or fd is the same as epfd, or
            the requested operation op is not supported by this interface.
        ENOENT
            op was EPOLL_CTL_MOD or EPOLL_CTL_DEL, and fd is not registered with
            this epoll instance.
        ENOMEM
            There was insufficient memory to handle the requested op control
            operation.
        ENOSPC
            The limit imposed by /proc/sys/fs/epoll/max_user_watches was
            encountered while trying to register (EPOLL_CTL_ADD) a new file
            descriptor on an epoll instance. See epoll(7) for further details.
        EPERM
            The target file fd does not support epoll.

        Versions

        epoll_ctl() was added to the kernel in version 2.6.

     **************************************************************************/

    int epoll_ctl(int epfd, EpollCtlOp op, int fd, epoll_event_t* event);

    /**************************************************************************

        Description

        The epoll_wait() system call waits for events on the epoll instance
        referred to by the file descriptor epfd. The memory area pointed to by
        events will contain the events that will be available for the caller.
        Up to maxevents are returned by epoll_wait(). The maxevents argument
        must be greater than zero.

        The call waits for a maximum time of timeout milliseconds. Specifying a
        timeout of -1 makes epoll_wait() wait indefinitely, while specifying a
        timeout equal to zero makes epoll_wait() to return immediately even if
        no events are available (return code equal to zero).

        The data of each returned structure will contain the same data the user
        set with an epoll_ctl(2) (EPOLL_CTL_ADD,EPOLL_CTL_MOD) while the events
        member will contain the returned event bit field.

        Return Value

        When successful, epoll_wait() returns the number of file descriptors
        ready for the requested I/O, or zero if no file descriptor became ready
        during the requested timeout milliseconds. When an error occurs,
        epoll_wait() returns -1 and errno is set appropriately.

        Errors

        EBADF
            epfd is not a valid file descriptor.
        EFAULT
            The memory area pointed to by events is not accessible with write
            permissions.
        EINTR
            The call was interrupted by a signal handler before any of the
            requested events occurred or the timeout expired; see signal(7).
        EINVAL
            epfd is not an epoll file descriptor, or maxevents is less than or
            equal to zero.

        Versions

        epoll_wait() was added to the kernel in version 2.6. Library support is
        provided in glibc starting with version 2.3.2.

     **************************************************************************/

    int epoll_wait(int epfd, epoll_event_t* events, int maxevents, int timeout);
}

/******************************************************************************

    Epoll utility struct, memorises the file descriptor obtained by create().

 ******************************************************************************/

struct Epoll
{
    /**************************************************************************

        Convenience aliases

     **************************************************************************/

    public alias .EpollCreateFlags CreateFlags;
    public alias .EpollCtlOp CtlOp;
    public alias .epoll_event_t epoll_event_t;
    public alias .epoll_event_t.Event Event;

    /**************************************************************************

        Initial file descriptor value.

     **************************************************************************/

    public const int fd_init = -1;

    /**************************************************************************

        epoll file descriptor.

     **************************************************************************/

    public int fd = fd_init;

    /**************************************************************************

        Calls epoll_create1() and memorises the returned file descriptor, which
        is -1 in case of an error.

        Params:
            flags = epoll_create1() flags

        Returns:
            the obtained file descriptor on success or, -1 on error.
            On error errno is set appropriately and the returned -1 is memorised
            as file descriptor.

     **************************************************************************/

    public int create ( CreateFlags flags = CreateFlags.None )
    {
        return this.fd = epoll_create1(flags);
    }

    /**************************************************************************

        Calls epoll_ctl() using the current epoll file descriptor.

        The current epoll file descriptor should have been sucessfully obtained
        by create() or epoll_create1() and not already been closed, otherwise
        epoll_ctl() will fail so that this method returns -1.

        Params:
            op    = epoll_ctl opcode
            fd    = file descriptor to register for events
            event = epoll_event_t struct instance containing the events to
                    register fd for and optional user data

        Returns:
            0 on success or -1 on error. On error errno is set appropriately.

     **************************************************************************/

    public int ctl ( CtlOp op, int fd, epoll_event_t event )
    {
        return epoll_ctl(this.fd, op, fd, &event);
    }

    template ctlT ( size_t i = 0 )
    {
        static if (i < epoll_event_t.data.tupleof.length)
        {


            /**************************************************************************

                Calls epoll_ctl() using the current epoll file descriptor to modify the
                registration of fd for events with data as user data.

                Creates the epoll_event_t instance passed to epoll_ctl() from events and
                data where the type of data must match one of the epoll_data_t members.

                The current epoll file descriptor should have been sucessfully obtained
                by create() or epoll_create1() and not already been closed, otherwise
                epoll_ctl() will fail so that this method returns -1.

                Params:
                    op     = epoll_ctl opcode
                    fd     = file descriptor to register for events
                    events = events to register fd for
                    data   = user data; the member of the data field of the created
                             epoll_data_t instance that matches the type is set to it

                Returns:
                    0 on success or -1 on error. On error errno is set appropriately.

            **************************************************************************/

            int ctl ( CtlOp op, int fd, Event events, typeof (epoll_event_t.data.tupleof[i]) data )
            {
                epoll_event_t event;

                event.events          = events;
                event.data.tupleof[i] = data;

                return epoll_ctl(this.fd, op, fd, &event);
            }

            mixin ctlT!(i + 1);
        }
    }

    mixin ctlT!();

    /**************************************************************************

        Calls epoll_ctl() using the current epoll file descriptor to modify the
        registration of fd for events with fd as user data.

        Creates the epoll_event_t instance passed to epoll_ctl() from events and
        fd where data.fd is set to fd.

        The current epoll file descriptor should have been sucessfully obtained
        by create() or epoll_create1() and not already been closed, otherwise
        epoll_ctl() will fail so that this method returns -1.

        Params:
            op     = epoll_ctl opcode
            fd     = file descriptor to register for events and to set data.fd
                     of the created epoll_data_t instance to
            events = events to register fd for

        Returns:
            0 on success or -1 on error. On error errno is set appropriately.

     **************************************************************************/

    public int ctl ( CtlOp op, int fd, Event events )
    {
        // FIXME: Apparently the mixin ctlT!() doesn't overload properly :(

//        return this.ctl(op, fd, events, fd);
        return ctlT!(1).ctl(op, fd, events, fd);
    }

    /**************************************************************************

        Calls epoll_ctl() using the current epoll file descriptor to modify the
        registration of fd for events with obj as user data.

        Creates the epoll_event_t instance passed to epoll_ctl() from events and
        obj where data.obj is set to obj.

        The current epoll file descriptor should have been sucessfully obtained
        by create() or epoll_create1() and not already been closed, otherwise
        epoll_ctl() will fail so that this method returns -1.

        Params:
            op     = epoll_ctl opcode
            fd     = file descriptor to register for events
            events = events to register fd for
            obj    = user object to set data.obj of the created epoll_data_t
                     instance to

        Returns:
            0 on success or -1 on error. On error errno is set appropriately.

     **************************************************************************/

    public int ctl ( CtlOp op, int fd, Event events, Object obj )
    {
        epoll_event_t event;

        event.events   = events;
        event.data.obj = obj;

        return epoll_ctl(this.fd, op, fd, &event);
    }

    /**************************************************************************

        Calls epoll_wait() using the current epoll file descriptor.

        events.length specifies the maximum number of file descriptors for which
        events can be reported with this epoll_wait() call.

        The current epoll file descriptor should have been sucessfully obtained
        by create() or epoll_create1() and not already been closed, otherwise
        epoll_ctl() will fail so that this method returns -1.

        Params:
            events     = destination array for the reported events
            timeout_ms = timeout in ms or -1 to disable timing out

        Returns:
            on success the number of file descriptors for which at least one
            event was reported. 0 indicates that this call timed out before an
            event on any file descriptor occurred.
            On error -1 is returned and errno set appropriately.

     **************************************************************************/

    public int wait ( epoll_event_t[] events, int timeout_ms = -1 )
    in
    {
        assert (events.length <= int.max);
    }
    out (n)
    {
        assert (n <= cast (int) events.length);
    }
    body
    {
        return epoll_wait(this.fd, events.ptr, cast (int) events.length, timeout_ms);
    }

    /**************************************************************************

        Calls close() to close the current epoll file descriptor.

        Returns:
            0 on success or -1 on error. On error errno is set appropriately.

     **************************************************************************/

    public int close ( )
    {
        return .close(this.fd);
    }
}
