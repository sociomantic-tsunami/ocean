/*******************************************************************************

    Global configuration variable to define whether the close-on-exec option
    should be set on system calls that create a file descriptor in ocean
    modules.

    On a POSIX system, if a program calls `exec(2)` (or an equivalent function
    from the `exec` family) to execute another program, then the devices
    referred to by the file descriptors held by the original program stay open,
    and the executed program inherits all of them.
    This has the consequence that, if the executed program is unaware of the
    original program's file descriptors so it doesn't close those it doesn't
    need, then all devices will stay open until the process exits.

    Most of the time an `exec` call is preceded by a `fork` call to execute a
    program in a new process. As with `exec` the child process created by `fork`
    inherits all file descriptors from its parent process that called `fork`.
    However, each device referred to by one of these file descriptors stays open
    until _both_ the parent and child process close them or exit. This means
    that the parent process has no way of closing its devices any more unless
    the child process cooperates and does so as well, which is in practice very
    unlikely.

    This can cause the following situation:
     - A program opens a device (file, socket, timer or event fd).
     - The program registers the device with `epoll`.
     - The program uses a third-party library which starts a task in a separate
       process using `fork` + `exec`.
     - The original program (parent process) closes the device.
     - The executed program (child process) is, as libraries are, unaware of
       its parent's business so it doesn't close any of the inherited file
       descriptors; it doesn't even know which it inherited. So the device stays
       opened.
     - Because the device is opened it stays registered with `epoll`. The parent
       process cannot unregister it any more because it has closed the file
       descriptor.
     - Until the child process exits `epoll_wait(2)` keeps reporting events for
       the device in the parent process.

    This is a problem because it can cause sporadic erratic behaviour in a
    program. The error may be hard to reproduce and track down.

    To prevent this from happening POSIX provides a close-on-exec option for
    each file descriptor. By default it is disabled. If enabled, `exec` will
    close the file descriptor so that the executed program won't inherit it. But
    it works only if the parent process explicitly enables this option for every
    single file descriptor it obtains from the system.

    The global `open_with_close_on_exec` variable in this module is read by all
    functions and class constructors in ocean that obtain a file descriptor from
    the system. If it is `true` then they set the close-on-exec option.

    This does not affect `stdin`, `stdout` and `stderr`, which are opened before
    the start of the program.

    Currently the flag is `false` to keep the system's default behaviour. In
    general it is recommended to set it to `true` to avoid the aforementioned
    problem unless file descriptor inheriting is needed. Since there appears to
    be no use case for it for us the default value of `open_with_close_on_exec`
    will change to `true` in the next major ocean release.

    IF YOU HAVE A USE CASE FOR INHERITING FILE DESCRIPTORS, PLEASE CONTACT THE
    OCEAN MAINTAINERS.

    The following ocean functions obtain a file descriptor and use this flag:

    - `ocean.sys.Epoll`: `Epoll.create`
    - `ocean.sys.EventFD`: `EventFD` constructor
    - `ocean.sys.Inotify`: `Inotify` constructor
    - `ocean.sys.SignalFD`: `SignalFD.register`
    - `ocean.sys.TimerFD`: `TimerFD` constructor
    - `ocean.sys.socket`: The `socket` and `accept` methods in all `*Socket`
        classes
    - `ocean.io.device.File`: `File.open`

    Copyright:
        Copyright (c) 2017 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.sys.CloseOnExec;

import ocean.transition;

/*******************************************************************************

    If true then all ocean functions obtaining a file descriptor from the system
    set the close-on-exec option; if false they don't. Changing the value of
    this variable does not change the state of previously obtained file
    descriptors.

*******************************************************************************/

mixin(global("bool open_with_close_on_exec = false"));

/*******************************************************************************

    Helper function to set the close-on-exec bit in a bit mask which specifies
    option flags for a system call that obtains a new file descriptor, such as
    `open(2)`. On recent Linux all such system/library functions support
    enabling the close-on-exec option; this is a Linux extension to POSIX. Some
    of these flag accepting functions were added more recently with a name
    extension, for example `accept4(2)` or `inotify_init1(2)`.

    Params:
        flags = the flags where the close-on-exec bit should be set if
                `open_with_close_on_exec` is `true`
        close_on_exec_flag = a bitmask with only the close-on-exec bit set

    Returns:
        `flags | close_on_exec_flag` if `open_with_close_on_exec` is `true`,
        otherwise `flags`.

*******************************************************************************/

T setCloExec ( T, U ) ( T flags, U close_on_exec_flag )
{
    return open_with_close_on_exec? (flags | close_on_exec_flag) : flags;
}
