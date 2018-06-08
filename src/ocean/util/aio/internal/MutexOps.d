/*********************************************************************

    Implementation of common mutex operations

    copyright:
        Copyright (c) 2016-2018 dunnhumby Germany GmbH. All rights reserved

    License:
        Boost Software License Version 1.0. See LICENSE.txt for details.

*********************************************************************/

module ocean.util.aio.internal.MutexOps;

import core.sys.posix.pthread;
import core.sys.posix.unistd;
import core.stdc.errno;
import ocean.sys.ErrnoException;

/*********************************************************************

    Helper function to lock the mutex with the check for
    the return value and throwing in the case of the error
    This method must can be executed *ONLY* inside main thread.
    Otherwise, GC holding glibc's mutex can deadlock, because
    assert internally allocates memory from GC.

    Params:
        mutex = pointer to the mutex handle
        exception = ErrnoException instance to throw

*********************************************************************/

public void lock_mutex (pthread_mutex_t* mutex)
{
    int ret = pthread_mutex_lock(mutex);

    switch (ret)
    {
        case 0:
            break;
        default:
            throw (new ErrnoException).set(ret, "pthread_mutex_lock");
        case EINVAL:
            assert(false, "Mutex reference is invalid");
        case EDEADLK:
            assert(false, "The mutex is already locked by this thread");
    }
}

/*********************************************************************

    Helper function to unlock the mutex with the check for
    the return value and throwing in the case of the error
    This method must be executed *ONLY* inside main thread.
    Otherwise, GC holding glibc's mutex can deadlock, because
    assert internally allocates memory from GC.

    Params:
        mutex = pointer to the mutex handle

*********************************************************************/

public void unlock_mutex (pthread_mutex_t* mutex)
{
    int ret = pthread_mutex_unlock(mutex);

    switch (ret)
    {
        case 0:
            break;
        default:
            throw (new ErrnoException).set(ret, "pthread_mutex_unlock");
        case EINVAL:
            assert(false, "Mutex reference is invalid");
        case EPERM:
            assert(false, "The calling thread does not own the mutex");
    }
}
