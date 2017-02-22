/*******************************************************************************

    Test for the SignalExt behaviour.

    copyright: Copyright (c) 2015 sociomantic labs. All rights reserved

*******************************************************************************/

import ocean.transition;

import core.sys.posix.signal;
import ocean.core.Test;
import ocean.sys.ErrnoException;
import ocean.util.app.DaemonApp;
import ocean.io.select.client.TimerEvent;

/// Counters incremented from original and application's
/// signal handler
private int main_counter;
private int app_counter;

class MyApp : DaemonApp
{
    import ocean.io.select.EpollSelectDispatcher;

    private EpollSelectDispatcher epoll;

    this ( )
    {
        this.epoll = new EpollSelectDispatcher;

        istring name = "Application";
        istring desc = "Testing signal handling.";

        DaemonApp.OptionalSettings settings;
        settings.signals = [SIGRTMIN];

        super(name, desc, VersionInfo.init, settings);
    }

    // Called after arguments and config file parsing.
    override protected int run ( Arguments args, ConfigParser config )
    {
        this.startEventHandling(this.epoll);

        auto timer = new TimerEvent(
                {
                    // This should now trigger the new handler
                    raise(SIGRTMIN);
                    return false;
                });

        timer.set(0, 100, 0, 0);
        this.epoll.register(timer);

        this.epoll.eventLoop();
        return 0; // return code to OS
    }

    // Handle those signals we were interested in
    override public void onSignal ( int signal )
    {
        test!("==")(signal, SIGRTMIN);
        .app_counter++;
        this.epoll.shutdown();
    }
}

import ocean.io.device.File;
import Path = ocean.io.Path;
import ocean.text.util.StringC;
import core.sys.posix.unistd;
import ocean.stdc.posix.stdlib : mkdtemp;


void main(istring[] args)
{
    static extern(C) void sighandler (int sig)
    {
        main_counter++;
    }

    // Exception to throw on failure. Instantiated for ergonomics
    auto e = new ErrnoException;

    // Set the initial signal handler
    sigaction_t handler, old_handler;
    handler.sa_handler = &sighandler;

    auto sigaction_res =
        e.enforceRetCode!(sigaction).call(SIGRTMIN, &handler, &old_handler);

    scope (exit)
    {
        // Restore the old one on exit
        sigaction(SIGRTMIN, &old_handler, null);
    }

    // The main-function signal handler should be triggered here
    raise(SIGRTMIN);

    // Prepare environment
    char[4096] old_cwd;
    e.enforceRetPtr!(getcwd).call(old_cwd.ptr, old_cwd.length);

    auto tmp_path = e.enforceRetPtr!(mkdtemp)
        .call("/tmp/Dunittest-XXXXXX\0".dup.ptr);

    scope (exit)
    {
        auto d_tmp_path = StringC.toDString(tmp_path);
        // Remove all subdirectories and files in the tmp dir
        Path.remove(Path.collate(d_tmp_path, "*", true));
        // Remove the tmp dir itself
        Path.remove(d_tmp_path);
    }

    e.enforceRetCode!(chdir).call(tmp_path);

    scope (exit)
    {
        e.enforceRetCode!(chdir).call(old_cwd.ptr);
    }

    // Now start the application:

    // setup directory structure needed to run
    if (!Path.exists("etc"))
    {
        Path.createFolder("etc");
    }

    if (!Path.exists("log"))
    {
        Path.createFolder("log");
    }

    auto file = new File("etc/config.ini", File.ReadWriteCreate);

    file.write("[LOG.Root]\n" ~
               "console = false\n");

    file.close();

    auto app = new MyApp;
    auto ret = app.main(args);

    // The old handler should be triggered here
    raise(SIGRTMIN);

    test!("==")(main_counter, 2);
    test!("==")(app_counter, 1);
}
