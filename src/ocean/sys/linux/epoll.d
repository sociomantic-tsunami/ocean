/*******************************************************************************

    Copyright:
        Copyright (c) 2004-2009 Tango contributors.
        Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

*******************************************************************************/

module ocean.sys.linux.epoll;

version (linux):

extern (C):

// From <sys/epoll.h>: support for the Linux epoll_*() system calls

enum: uint
{
    EPOLLIN         = 0x001,
    EPOLLPRI        = 0x002,
    EPOLLOUT        = 0x004,
    EPOLLRDNORM     = 0x040,
    EPOLLRDBAND     = 0x080,
    EPOLLWRNORM     = 0x100,
    EPOLLWRBAND     = 0x200,
    EPOLLMSG        = 0x400,
    EPOLLERR        = 0x008,
    EPOLLHUP        = 0x010,
    EPOLLONESHOT    = (1 << 30),
    EPOLLET         = (1 << 31)
}

enum: uint
{
    EPOLL_CLOEXEC   = 0x8_0000, // 02000000
    EPOLL_NONBLOCK  = 0x800,    // 04000
}

// Valid opcodes ( "op" parameter ) to issue to epoll_ctl().
enum: uint
{
    EPOLL_CTL_ADD = 1, // Add a file descriptor to the interface.
    EPOLL_CTL_DEL = 2, // Remove a file descriptor from the interface.
    EPOLL_CTL_MOD = 3, // Change file descriptor epoll_event structure.
}

align(1) union epoll_data
{
    align(1):
    void* ptr;
    int fd;
    uint u32;
    ulong u64;
}

alias epoll_data epoll_data_t;

align(1) struct epoll_event
{
    align(1):
    uint events;       // Epoll events
    epoll_data_t data; // User data variable
}

int epoll_create(int size);
int epoll_create1(int flags);
int epoll_ctl(int epfd, int op, int fd, epoll_event* event);
int epoll_wait(int epfd, epoll_event* events, int maxevents, int timeout);

