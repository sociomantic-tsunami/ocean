/*******************************************************************************

  Copyright:
      Copyright (c) 2006 Juan Jose Comellas.
      Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
      All rights reserved.

  License:
      Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
      See LICENSE_TANGO.txt for details.

  Authors: Juan Jose Comellas <juanjo@comellas.com.ar>

*******************************************************************************/

module ocean.sys.Process;

import ocean.transition;

import ocean.core.Array : copy;
import ocean.io.model.IFile;
import ocean.io.Console;
import ocean.sys.Common;
import ocean.sys.Pipe;
import ocean.core.Exception_tango;
import ocean.text.Util;
import Integer = ocean.text.convert.Integer_tango;

import ocean.stdc.stdlib;
import ocean.stdc.string;
import ocean.stdc.stringz;

version (Posix)
{
    import ocean.stdc.errno;
    import ocean.stdc.posix.fcntl;
    import ocean.stdc.posix.unistd;
    import ocean.stdc.posix.sys.wait;

    version (darwin)
    {
        extern (C) char*** _NSGetEnviron();
        private char** environ;

        static this ()
        {
            environ = *_NSGetEnviron();
        }
    }

    else
    {
        private
        {
            mixin(global("extern (C) extern char** environ"));
        }
    }
}

debug (Process)
{
    import ocean.io.Stdout_tango;
}


/**
 * Redirect flags for processes.  Defined outside process class to cut down on
 * verbosity.
 */
enum Redirect
{
    /**
     * Redirect none of the standard handles
     */
    None = 0,

    /**
     * Redirect the stdout handle to a pipe.
     */
    Output = 1,

    /**
     * Redirect the stderr handle to a pipe.
     */
    Error = 2,

    /**
     * Redirect the stdin handle to a pipe.
     */
    Input = 4,

    /**
     * Redirect all three handles to pipes (default).
     */
    All = Output | Error | Input,

    /**
     * Send stderr to stdout's handle.  Note that the stderr PipeConduit will
     * be null.
     */
    ErrorToOutput = 0x10,

    /**
     * Send stdout to stderr's handle.  Note that the stdout PipeConduit will
     * be null.
     */
    OutputToError = 0x20,
}

/**
 * The Process class is used to start external programs and communicate with
 * them via their standard input, output and error streams.
 *
 * You can pass either the command line or an array of arguments to execute,
 * either in the constructor or to the args property. The environment
 * variables can be set in a similar way using the env property and you can
 * set the program's working directory via the workDir property.
 *
 * To actually start a process you need to use the execute() method. Once the
 * program is running you will be able to write to its standard input via the
 * stdin OutputStream and you will be able to read from its standard output and
 * error through the stdout and stderr InputStream respectively.
 *
 * You can check whether the process is running or not with the isRunning()
 * method and you can get its process ID via the pid property.
 *
 * After you are done with the process, or if you just want to wait for it to
 * end, you need to call the wait() method which will return once the process
 * is no longer running.
 *
 * To stop a running process you must use kill() method. If you do this you
 * cannot call the wait() method. Once the kill() method returns the process
 * will be already dead.
 *
 * After calling either wait() or kill(), and no more data is expected on the
 * pipes, you should call close() as this will clean the pipes. Not doing this
 * may lead to a depletion of the available file descriptors for the main
 * process if many processes are created.
 *
 * Examples:
 * ---
 * try
 * {
 *     auto p = new Process ("ls -al", null);
 *     p.execute;
 *
 *     Stdout.formatln ("Output from {}:", p.programName);
 *     Stdout.copy (p.stdout).flush;
 *     auto result = p.wait;
 *
 *     Stdout.formatln ("Process '{}' ({}) exited with reason {}, status {}",
 *                      p.programName, p.pid, cast(int) result.reason, result.status);
 * }
 * catch (ProcessException e)
 *        Stdout.formatln ("Process execution failed: {}", e);
 * ---
 *
 * ---
 *    // Example how to pipe two processes together:
 *    auto p1 = new Process("ls");
 *    auto p2 = new Process("head");
 *
 *    p1.execute();
 *    p2.execute();
 *
 *    p2.stdin.copy(p1.stdout);
 *
 *    p2.wait();
 *    Stdout.copy(p2.stdout);
 *
 * ---
 */
class Process
{
    /**
     * Result returned by wait().
     */
    public struct Result
    {
        /**
         * Reasons returned by wait() indicating why the process is no
         * longer running.
         */
        public enum
        {
            Exit,
            Signal,
            Stop,
            Continue,
            Error
        }

        public int reason;
        public int status;

        /**
         * Returns a string with a description of the process execution result.
         */
        public istring toString()
        {
            cstring str;

            switch (reason)
            {
                case Exit:
                    str = format("Process exited normally with return code ", status);
                    break;

                case Signal:
                    str = format("Process was killed with signal ", status);
                    break;

                case Stop:
                    str = format("Process was stopped with signal ", status);
                    break;

                case Continue:
                    str = format("Process was resumed with signal ", status);
                    break;

                case Error:
                    str = format("Process failed with error code ", reason) ~
                                 " : " ~ SysError.lookup(status);
                    break;

                default:
                    str = format("Unknown process result ", reason);
                    break;
            }

            return assumeUnique(str);
        }
    }

    const uint DefaultStdinBufferSize    = 512;
    const uint DefaultStdoutBufferSize   = 8192;
    const uint DefaultStderrBufferSize   = 512;
    const Redirect DefaultRedirectFlags  = Redirect.All;

    private cstring[]        _args;
    private istring[istring] _env;
    private cstring          _workDir;
    private PipeConduit      _stdin;
    private PipeConduit      _stdout;
    private PipeConduit      _stderr;
    private bool             _running = false;
    private bool             _copyEnv = false;
    private Redirect         _redirect = DefaultRedirectFlags;

    private pid_t _pid = cast(pid_t) -1;

    /**
     * Constructor (variadic version).  Note that by default, the environment
     * will not be copied.
     *
     * Params:
     * args     = array of strings with the process' arguments.  If there is
     *            exactly one argument, it is considered to contain the entire
     *            command line including parameters.  If you pass only one
     *            argument, spaces that are not intended to separate
     *            parameters should be embedded in quotes.  The arguments can
     *            also be empty.
     *            Note: The class will use only slices, .dup when necessary.
     *
     */
    public this(Const!(mstring)[] args ...)
    {
        if(args.length == 1)
            _args = splitArgs(args[0]);
        else
            _args.copy(args);
    }

    ///
    unittest
    {
        void example ( )
        {
            auto p1 = new Process("myprogram", "first argument", "second", "third");
            auto p2 = new Process("myprogram \"first argument\" second third");
        }
    }

    /**
     * Constructor (variadic version, with environment copy).
     *
     * Params:
     * copyEnv  = if true, the environment is copied from the current process.
     * args     = array of strings with the process' arguments.  If there is
     *            exactly one argument, it is considered to contain the entire
     *            command line including parameters.  If you pass only one
     *            argument, spaces that are not intended to separate
     *            parameters should be embedded in quotes.  The arguments can
     *            also be empty.
     *            Note: The class will use only slices, .dup when necessary.
     */
    public this(bool copyEnv, Const!(mstring)[] args ...)
    {
        _copyEnv = copyEnv;
        this(args);
    }

    ///
    unittest
    {
        void example ( )
        {
            auto p1 = new Process(true, "myprogram", "first argument", "second", "third");
            auto p2 = new Process(true, "myprogram \"first argument\" second third");
        }
    }

    /**
     * Constructor.
     *
     * Params:
     * command  = string with the process' command line; arguments that have
     *            embedded whitespace must be enclosed in inside double-quotes (").
     *            Note: The class will use only slices, .dup when necessary.
     * env      = associative array of strings with the process' environment
     *            variables; the variable name must be the key of each entry.
     */
    public this(cstring command, istring[istring] env)
    in
    {
        assert(command.length > 0);
    }
    body
    {
        _args = splitArgs(command);
        _env = env;
    }

    ///
    unittest
    {
        void example ( )
        {
            cstring command = "myprogram \"first argument\" second third";
            istring[istring] env;

            // Environment variables
            env["MYVAR1"] = "first";
            env["MYVAR2"] = "second";

            auto p = new Process(command, env);
        }
    }

    /**
     * Constructor.
     *
     * Params:
     * args     = array of strings with the process' arguments; the first
     *            argument must be the process' name; the arguments can be
     *            empty.
     *            Note: The class will use only slices, .dup when necessary.
     * env      = associative array of strings with the process' environment
     *            variables; the variable name must be the key of each entry.
     */
    public this(Const!(mstring)[] args, istring[istring] env)
    in
    {
        assert(args.length > 0);
        assert(args[0].length > 0);
    }
    body
    {
        _args.copy(args);
        _env = env;
    }

    ///
    unittest
    {
        void example ( )
        {
             istring[] args;
             istring[istring] env;

             // Process name
             args ~= "myprogram";
             // Process arguments
             args ~= "first argument";
             args ~= "second";
             args ~= "third";

             // Environment variables
             env["MYVAR1"] = "first";
             env["MYVAR2"] = "second";

             auto p = new Process(args, env);
        }
    }

    /**
     * Indicate whether the process is running or not.
     */
    public bool isRunning()
    {
        return _running;
    }

    /**
     * Return the running process' ID.
     *
     * Returns: an int with the process ID if the process is running;
     *          -1 if not.
     */
    public int pid()
    {
        return cast(int) _pid;
    }

    /**
     * Return the process' executable filename.
     */
    public cstring programName()
    {
        return (_args !is null ? _args[0] : null);
    }

    /**
     * Set the process' executable filename.
     */
    public cstring programName(cstring name)
    {
        if (_args.length == 0)
        {
            _args.length = 1;
        }
        return _args[0] = name;
    }

    /**
     * Set the process' executable filename, return 'this' for chaining
     */
    public Process setProgramName(cstring name)
    {
        programName = name;
        return this;
    }

    /**
     * Return an array with the process' arguments.
     */
    public cstring[] args()
    {
        return _args;
    }

    /**
     * Set the process' arguments from the arguments received by the method.
     *
     * Remarks:
     * The first element of the array must be the name of the process'
     * executable.
     *
     * Returns: the arguments that were set.
     */
    public cstring[] args(cstring progname, Const!(mstring)[] args ...)
    {
        return _args.copy(progname ~ args);
    }

    ///
    unittest
    {
        void example ( )
        {
            auto p = new Process;
            p.args("myprogram", "first", "second argument", "third");
        }
    }

    /**
     * Set the process' command and arguments from an array.
     *
     * Remarks:
     * The first element of the array must be the name of the process'
     * executable.
     *
     * Returns: the arguments that were set.
     *
     */

    public void argsWithCommand(Const!(mstring)[] args)
    {
        _args.copy(args);
    }

    ///
    unittest
    {
        void example ( )
        {
            auto p = new Process;
            p.argsWithCommand(["myprogram", "first", "second argument", "third"]);
        }
    }

    /**
     * Set the process' arguments from the arguments received by the method.
     *
     * Remarks:
     * The first element of the array must be the name of the process'
     * executable.
     *
     * Returns: a reference to this for chaining
     *
     */
    public Process setArgs(cstring progname, Const!(mstring)[] args ...)
    {
        this.args(progname, args);
        return this;
    }

    ///
    unittest
    {
        void example ( )
        {
            auto p = new Process;
            p.setArgs("myprogram", "first", "second argument", "third").execute();
        }
    }

    /**
     * If true, the environment from the current process will be copied to the
     * child process.
     */
    public bool copyEnv()
    {
        return _copyEnv;
    }

    /**
     * Set the copyEnv flag.  If set to true, then the environment will be
     * copied from the current process.  If set to false, then the environment
     * is set from the env field.
     */
    public bool copyEnv(bool b)
    {
        return _copyEnv = b;
    }

    /**
     * Set the copyEnv flag.  If set to true, then the environment will be
     * copied from the current process.  If set to false, then the environment
     * is set from the env field.
     *
     * Returns:
     *   A reference to this for chaining
     */
    public Process setCopyEnv(bool b)
    {
        _copyEnv = b;
        return this;
    }

    /**
     * Return an associative array with the process' environment variables.
     *
     * Note that if copyEnv is set to true, this value is ignored.
     */
    public istring[istring] env()
    {
        return _env;
    }

    /**
     * Set the process' environment variables from the associative array
     * received by the method.
     *
     * This also clears the copyEnv flag.
     *
     * Params:
     * env  = associative array of strings containing the environment
     *        variables for the process. The variable name should be the key
     *        used for each entry.
     *
     * Returns: the env set.
     * Examples:
     * ---
     * istring[istring] env;
     *
     * env["MYVAR1"] = "first";
     * env["MYVAR2"] = "second";
     *
     * p.env = env;
     * ---
     */
    public istring[istring] env(istring[istring] env)
    {
        _copyEnv = false;
        return _env = env;
    }

    /**
     * Set the process' environment variables from the associative array
     * received by the method.  Returns a 'this' reference for chaining.
     *
     * This also clears the copyEnv flag.
     *
     * Params:
     * env  = associative array of strings containing the environment
     *        variables for the process. The variable name should be the key
     *        used for each entry.
     *
     * Returns: A reference to this process object
     */
    public Process setEnv(istring[istring] env)
    {
        _copyEnv = false;
        _env = env;
        return this;
    }

    ///
    unittest
    {
        void example ( )
        {
            auto p = new Process;
            istring[istring] env;
            env["MYVAR1"] = "first";
            env["MYVAR2"] = "second";
            p.setEnv(env).execute();
        }
    }

    /**
     * Return an UTF-8 string with the process' command line.
     */
    public override istring toString()
    {
        istring command;

        for (uint i = 0; i < _args.length; ++i)
        {
            if (i > 0)
            {
                command ~= ' ';
            }
            if (contains(_args[i], ' ') || _args[i].length == 0)
            {
                command ~= '"';
                command ~= _args[i].substitute("\\", "\\\\").substitute(`"`, `\"`);
                command ~= '"';
            }
            else
            {
                command ~= _args[i].substitute("\\", "\\\\").substitute(`"`, `\"`);
            }
        }
        return command;
    }

    /**
     * Return the working directory for the process.
     *
     * Returns: a string with the working directory; null if the working
     *          directory is the current directory.
     */
    public cstring workDir()
    {
        return _workDir;
    }

    /**
     * Set the working directory for the process.
     *
     * Params:
     * dir  = a string with the working directory; null if the working
     *         directory is the current directory.
     *
     * Returns: the directory set.
     */
    public cstring workDir(cstring dir)
    {
        return _workDir = dir;
    }

    /**
     * Set the working directory for the process.  Returns a 'this' reference
     * for chaining
     *
     * Params:
     * dir  = a string with the working directory; null if the working
     *         directory is the current directory.
     *
     * Returns: a reference to this process.
     */
    public Process setWorkDir(cstring dir)
    {
        _workDir = dir;
        return this;
    }

    /**
     * Get the redirect flags for the process.
     *
     * The redirect flags are used to determine whether stdout, stderr, or
     * stdin are redirected.  The flags are an or'd combination of which
     * standard handles to redirect.  A redirected handle creates a pipe,
     * whereas a non-redirected handle simply points to the same handle this
     * process is pointing to.
     *
     * You can also redirect stdout or stderr to each other.  The flags to
     * redirect a handle to a pipe and to redirect it to another handle are
     * mutually exclusive.  In the case both are specified, the redirect to
     * the other handle takes precedent.  It is illegal to specify both
     * redirection from stdout to stderr and from stderr to stdout.  If both
     * of these are specified, an exception is thrown.
     *
     * If redirected to a pipe, once the process is executed successfully, its
     * input and output can be manipulated through the stdin, stdout and
     * stderr member PipeConduit's.  Note that if you redirect for example
     * stderr to stdout, and you redirect stdout to a pipe, only stdout will
     * be non-null.
     */
    public Redirect redirect()
    {
        return _redirect;
    }

    /**
     * Set the redirect flags for the process.
     */
    public Redirect redirect(Redirect flags)
    {
        return _redirect = flags;
    }

    /**
     * Set the redirect flags for the process.  Return a reference to this
     * process for chaining.
     */
    public Process setRedirect(Redirect flags)
    {
        _redirect = flags;
        return this;
    }

    /**
     * Get the GUI flag.
     *
     * This flag indicates on Windows systems that the CREATE_NO_WINDOW flag
     * should be set on CreateProcess.  Although this is a specific windows
     * flag, it is present on posix systems as a noop for compatibility.
     *
     * Without this flag, a console window will be allocated if it doesn't
     * already exist.
     */
    public bool gui()
    {
        return false;
    }

    /**
     * Set the GUI flag.
     *
     * This flag indicates on Windows systems that the CREATE_NO_WINDOW flag
     * should be set on CreateProcess.  Although this is a specific windows
     * flag, it is present on posix systems as a noop for compatibility.
     *
     * Without this flag, a console window will be allocated if it doesn't
     * already exist.
     */
    public bool gui(bool value)
    {
        return false;
    }

    /**
     * Set the GUI flag.  Returns a reference to this process for chaining.
     *
     * This flag indicates on Windows systems that the CREATE_NO_WINDOW flag
     * should be set on CreateProcess.  Although this is a specific windows
     * flag, it is present on posix systems as a noop for compatibility.
     *
     * Without this flag, a console window will be allocated if it doesn't
     * already exist.
     */
    public Process setGui(bool value)
    {
        return this;
    }

    /**
     * Return the running process' standard input pipe.
     *
     * Returns: a write-only PipeConduit connected to the child
     *          process' stdin.
     *
     * Remarks:
     * The stream will be null if no child process has been executed, or the
     * standard input stream was not redirected.
     */
    public PipeConduit stdin()
    {
        return _stdin;
    }

    /**
     * Return the running process' standard output pipe.
     *
     * Returns: a read-only PipeConduit connected to the child
     *          process' stdout.
     *
     * Remarks:
     * The stream will be null if no child process has been executed, or the
     * standard output stream was not redirected.
     */
    public PipeConduit stdout()
    {
        return _stdout;
    }

    /**
     * Return the running process' standard error pipe.
     *
     * Returns: a read-only PipeConduit connected to the child
     *          process' stderr.
     *
     * Remarks:
     * The stream will be null if no child process has been executed, or the
     * standard error stream was not redirected.
     */
    public PipeConduit stderr()
    {
        return _stderr;
    }

    /**
     * Pipes used during execute(). They are member variables so that they
     * can be reused by later calls to execute().
     * Note that any file handles created during execute() will remain open
     * and stored in these pipes, unless they are explicitly closed.
     */
    Pipe pin, pout, perr, pexec;

    /**
     * Execute a process using the arguments that were supplied to the
     * constructor or to the args property.
     *
     * Once the process is executed successfully, its input and output can be
     * manipulated through the stdin, stdout and
     * stderr member PipeConduit's.
     *
     * Returns:
     * A reference to this process object for chaining.
     *
     * Throws:
     * ProcessCreateException if the process could not be created
     * successfully; ProcessForkException if the call to the fork()
     * system call failed (on POSIX-compatible platforms).
     *
     * Remarks:
     * The process must not be running and the list of arguments must
     * not be empty before calling this method.
     */
    public Process execute()
    in
    {
        assert(!_running);
        assert(_args.length > 0 && _args[0] !is null);
    }
    body
    {
        version (Posix)
        {
            // We close the pipes that could have been left open from a previous
            // execution.
            cleanPipes();

            // validate the redirection flags
            if((_redirect & (Redirect.OutputToError | Redirect.ErrorToOutput)) == (Redirect.OutputToError | Redirect.ErrorToOutput))
                throw new ProcessCreateException(_args[0], "Illegal redirection flags", __FILE__, __LINE__);

            // Are we redirecting stdout and stderr?
            bool redirected_output = (_redirect & (Redirect.Output | Redirect.OutputToError)) == Redirect.Output;
            bool redirected_error  = (_redirect & (Redirect.Error | Redirect.ErrorToOutput)) == Redirect.Error;

            if(_redirect & Redirect.Input)
            {
                if ( ! pin )
                {
                    pin = new Pipe(DefaultStdinBufferSize);
                }
                else
                {
                    pin.recreate(DefaultStdinBufferSize);
                }
            }

            if( redirected_output )
            {
                if ( ! pout )
                {
                    pout = new Pipe(DefaultStdoutBufferSize);
                }
                else
                {
                    pout.recreate(DefaultStdoutBufferSize);
                }
            }

            if( redirected_error )
            {
                if ( ! perr)
                {
                    perr = new Pipe(DefaultStderrBufferSize);
                }
                else
                {
                    perr.recreate(DefaultStderrBufferSize);
                }
            }

            // This pipe is used to propagate the result of the call to
            // execv*() from the child process to the parent process.
            if (! pexec)
            {
                pexec = new Pipe(8);
            }
            else
            {
                pexec.recreate(8);
            }

            int status = 0;

            _pid = fork();
            if (_pid >= 0)
            {
                if (_pid != 0)
                {
                    // Parent process
                    if(_redirect & Redirect.Input)
                    {
                        _stdin = pin.sink;
                        pin.source.close();
                    }

                    if( redirected_output )
                    {
                        _stdout = pout.source;
                        pout.sink.close();
                    }

                    if(redirected_error)
                    {
                        _stderr = perr.source;
                        perr.sink.close();
                    }

                    pexec.sink.close();

                    try
                    {
                        pexec.source.input.read((cast(byte*) &status)[0 .. status.sizeof]);
                    }
                    catch (Exception e)
                    {
                        // Everything's OK, the pipe was closed after the call to execv*()
                    }

                    pexec.source.close();

                    if (status == 0)
                    {
                        _running = true;
                    }
                    else
                    {
                        // We set errno to the value that was sent through
                        // the pipe from the child process
                        errno = status;
                        _running = false;

                        throw new ProcessCreateException(_args[0], __FILE__, __LINE__);
                    }
                }
                else
                {
                    // Child process
                    int rc;
                    char*[] argptr;
                    char*[] envptr;

                    // Note that for all the pipes, we can close both ends
                    // because dup2 opens a duplicate file descriptor to the
                    // same resource.

                    // Replace stdin with the "read" pipe
                    if(_redirect & Redirect.Input)
                    {
                        if (dup2(pin.source.fileHandle(), STDIN_FILENO) < 0)
                            throw new Exception("dup2 < 0");
                        pin.sink.close();
                        pin.source.close();
                    }

                    // Replace stdout with the "write" pipe
                    if( redirected_output )
                    {
                        if (dup2(pout.sink.fileHandle(), STDOUT_FILENO) < 0)
                            throw new Exception("dup2 < 0");
                        pout.source.close();
                        pout.sink.close();
                    }

                    // Replace stderr with the "write" pipe
                    if( redirected_error )
                    {
                        if (dup2(perr.sink.fileHandle(), STDERR_FILENO) < 0)
                            throw new Exception("dup2 < 0");
                        perr.source.close();
                        perr.sink.close();
                    }

                    // Check for redirection from stdout to stderr or vice
                    // versa
                    if(_redirect & Redirect.OutputToError)
                    {
                        if(dup2(STDERR_FILENO, STDOUT_FILENO) < 0)
                            throw new Exception("dup2 < 0");
                    }

                    if(_redirect & Redirect.ErrorToOutput)
                    {
                        if(dup2(STDOUT_FILENO, STDERR_FILENO) < 0)
                            throw new Exception("dup2 < 0");
                    }

                    // We close the unneeded part of the execv*() notification pipe
                    pexec.source.close();

                    // Set the "write" pipe so that it closes upon a successful
                    // call to execv*()
                    if (fcntl(cast(int) pexec.sink.fileHandle(), F_SETFD, FD_CLOEXEC) == 0)
                    {
                        // Convert the arguments and the environment variables to
                        // the format expected by the execv() family of functions.
                        argptr = toNullEndedArray(_args);
                        envptr = (_copyEnv ? null : toNullEndedArray(_env));

                        // Switch to the working directory if it has been set.
                        if (_workDir.length > 0)
                        {
                            chdir(toStringz(_workDir));
                        }

                        // Replace the child fork with a new process. We always use the
                        // system PATH to look for executables that don't specify
                        // directories in their names.
                        rc = execvpe(_args[0], argptr, envptr);
                        if (rc == -1)
                        {
                            Cerr("Failed to exec ")(_args[0])(": ")(SysError.lastMsg).newline;

                            try
                            {
                                status = errno;

                                // Propagate the child process' errno value to
                                // the parent process.
                                pexec.sink.output.write((cast(byte*) &status)[0 .. status.sizeof]);
                            }
                            catch (Exception e)
                            {
                            }
                            exit(errno);
                        }
                        exit(errno);
                    }
                    else
                    {
                        Cerr("Failed to set notification pipe to close-on-exec for ")
                            (_args[0])(": ")(SysError.lastMsg).newline;
                        exit(errno);
                    }
                }
            }
            else
            {
                throw new ProcessForkException(_pid, __FILE__, __LINE__);
            }
        }
        else
        {
            assert(false, "ocean.sys.Process: Unsupported platform");
        }
        return this;
    }


    /**
     * Unconditionally wait for a process to end and return the reason and
     * status code why the process ended.
     *
     * Returns:
     * The return value is a Result struct, which has two members:
     * reason and status. The reason can take the
     * following values:
     *
     * Process.Result.Exit: the child process exited normally;
     *                      status has the process' return
     *                      code.
     *
     * Process.Result.Signal: the child process was killed by a signal;
     *                        status has the signal number
     *                        that killed the process.
     *
     * Process.Result.Stop: the process was stopped; status
     *                      has the signal number that was used to stop
     *                      the process.
     *
     * Process.Result.Continue: the process had been previously stopped
     *                          and has now been restarted;
     *                          status has the signal number
     *                          that was used to continue the process.
     *
     * Process.Result.Error: We could not properly wait on the child
     *                       process; status has the
     *                       errno value if the process was
     *                       running and -1 if not.
     *
     * Remarks:
     * You can only call wait() on a running process once. The Signal, Stop
     * and Continue reasons will only be returned on POSIX-compatible
     * platforms.
     * Calling wait() will not clean the pipes as the parent process may still
     * want the remaining output. It is however recommended to call close()
     * when no more content is expected, as this will close the pipes.
     */
    public Result wait()
    {
        version (Posix)
        {
            Result result;

            if (_running)
            {
                int rc;

                // We clean up the process related data and set the _running
                // flag to false once we're done waiting for the process to
                // finish.
                //
                // IMPORTANT: we don't delete the open pipes so that the parent
                //            process can get whatever the child process left on
                //            these pipes before dying.
                scope(exit)
                {
                    _running = false;
                }

                // Wait for child process to end.
                if (waitpid(_pid, &rc, 0) != -1)
                {
                    if (WIFEXITED(rc))
                    {
                        result.reason = Result.Exit;
                        result.status = WEXITSTATUS(rc);
                        if (result.status != 0)
                        {
                            debug (Process)
                                Stdout.formatln("Child process '{0}' ({1}) returned with code {2}\n",
                                                _args[0], _pid, result.status);
                        }
                    }
                    else
                    {
                        if (WIFSIGNALED(rc))
                        {
                            result.reason = Result.Signal;
                            result.status = WTERMSIG(rc);

                            debug (Process)
                                Stdout.formatln("Child process '{0}' ({1}) was killed prematurely "
                                                "with signal {2}",
                                                _args[0], _pid, result.status);
                        }
                        else if (WIFSTOPPED(rc))
                        {
                            result.reason = Result.Stop;
                            result.status = WSTOPSIG(rc);

                            debug (Process)
                                Stdout.formatln("Child process '{0}' ({1}) was stopped "
                                                "with signal {2}",
                                                _args[0], _pid, result.status);
                        }
                        else if (WIFCONTINUED(rc))
                        {
                            result.reason = Result.Stop;
                            result.status = WSTOPSIG(rc);

                            debug (Process)
                                Stdout.formatln("Child process '{0}' ({1}) was continued "
                                                "with signal {2}",
                                                _args[0], _pid, result.status);
                        }
                        else
                        {
                            result.reason = Result.Error;
                            result.status = rc;

                            debug (Process)
                                Stdout.formatln("Child process '{0}' ({1}) failed "
                                                "with unknown exit status {2}\n",
                                                _args[0], _pid, result.status);
                        }
                    }
                }
                else
                {
                    result.reason = Result.Error;
                    result.status = errno;

                    debug (Process)
                        Stdout.formatln("Could not wait on child process '{0}' ({1}): ({2}) {3}",
                                        _args[0], _pid, result.status, SysError.lastMsg);
                }
            }
            else
            {
                result.reason = Result.Error;
                result.status = -1;

                debug (Process)
                    Stdout.formatln("Child process '{0}' is not running", _args[0]);
            }
            return result;
        }
        else
        {
            assert(false, "ocean.sys.Process: Unsupported platform");
        }
    }

    /**
     * Kill a running process. This method will not return until the process
     * has been killed.
     *
     * Throws:
     * ProcessKillException if the process could not be killed;
     * ProcessWaitException if we could not wait on the process after
     * killing it.
     *
     * Remarks:
     * After calling this method you will not be able to call wait() on the
     * process.
     * Killing the process does not clean the attached pipes as the parent
     * process may still want/need the remaining content. However, it is
     * recommended to call close() on the process when it is no longer needed
     * as this will clean the pipes.
     */
    public void kill()
    {
        version (Posix)
        {
            if (_running)
            {
                int rc;

                assert(_pid > 0);

                if (.kill(_pid, SIGTERM) != -1)
                {
                    // We clean up the process related data and set the _running
                    // flag to false once we're done waiting for the process to
                    // finish.
                    //
                    // IMPORTANT: we don't delete the open pipes so that the parent
                    //            process can get whatever the child process left on
                    //            these pipes before dying.
                    scope(exit)
                    {
                        _running = false;
                    }

                    // FIXME: is this loop really needed?
                    for (uint i = 0; i < 100; i++)
                    {
                        rc = waitpid(pid, null, WNOHANG | WUNTRACED);
                        if (rc == _pid)
                        {
                            break;
                        }
                        else if (rc == -1)
                        {
                            throw new ProcessWaitException(cast(int) _pid, __FILE__, __LINE__);
                        }
                        usleep(50000);
                    }
                }
                else
                {
                    throw new ProcessKillException(_pid, __FILE__, __LINE__);
                }
            }
            else
            {
                debug (Process)
                    Stdout.print("Tried to kill an invalid process");
            }
        }
        else
        {
            assert(false, "ocean.sys.Process: Unsupported platform");
        }
    }

    /**
     * Split a string containing the command line used to invoke a program
     * and return and array with the parsed arguments. The double-quotes (")
     * character can be used to specify arguments with embedded spaces.
     * e.g. first "second param" third
     */
    protected static cstring[] splitArgs(cstring command, cstring delims = " \t\r\n")
    in
    {
        assert(!contains(delims, '"'),
               "The argument delimiter string cannot contain a double quotes ('\"') character");
    }
    body
    {
        enum State
        {
            Start,
            FindDelimiter,
            InsideQuotes
        }

        cstring[]   args = null;
        cstring[]   chunks = null;
        int         start = -1;
        char        c;
        int         i;
        State       state = State.Start;

        // Append an argument to the 'args' array using the 'chunks' array
        // and the current position in the 'command' string as the source.
        void appendChunksAsArg()
        {
            size_t argPos;

            if (chunks.length > 0)
            {
                // Create the array element corresponding to the argument by
                // appending the first chunk.
                args   ~= chunks[0];
                argPos  = args.length - 1;

                for (uint chunkPos = 1; chunkPos < chunks.length; ++chunkPos)
                {
                    args[argPos] ~= chunks[chunkPos];
                }

                if (start != -1)
                {
                    args[argPos] ~= command[start .. i];
                }
                chunks.length = 0;
            }
            else
            {
                if (start != -1)
                {
                    args ~= command[start .. i];
                }
            }
            start = -1;
        }

        for (i = 0; i < command.length; i++)
        {
            c = command[i];

            switch (state)
            {
                // Start looking for an argument.
                case State.Start:
                    if (c == '"')
                    {
                        state = State.InsideQuotes;
                    }
                    else if (!contains(delims, c))
                    {
                        start = i;
                        state = State.FindDelimiter;
                    }
                    else
                    {
                        appendChunksAsArg();
                    }
                    break;

                // Find the ending delimiter for an argument.
                case State.FindDelimiter:
                    if (c == '"')
                    {
                        // If we find a quotes character this means that we've
                        // found a quoted section of an argument. (e.g.
                        // abc"def"ghi). The quoted section will be appended
                        // to the preceding part of the argument. This is also
                        // what Unix shells do (i.e. a"b"c becomes abc).
                        if (start != -1)
                        {
                            chunks ~= command[start .. i];
                            start = -1;
                        }
                        state = State.InsideQuotes;
                    }
                    else if (contains(delims, c))
                    {
                        appendChunksAsArg();
                        state = State.Start;
                    }
                    break;

                // Inside a quoted argument or section of an argument.
                case State.InsideQuotes:
                    if (start == -1)
                    {
                        start = i;
                    }

                    if (c == '"')
                    {
                        chunks ~= command[start .. i];
                        start = -1;
                        state = State.Start;
                    }
                    break;

                default:
                    assert(false, "Invalid state in Process.splitArgs");
            }
        }

        // Add the last argument (if there is one)
        appendChunksAsArg();

        return args;
    }

    /**
     * Close and delete any pipe that may have been left open in a previous
     * execution of a child process.
     */
    protected void cleanPipes()
    {
        version ( Posix )
        {
            // Posix version re-uses Pipe objects, so simply close them, if they
            // have been used before
            if ( pin !is null )   pin.close();
            if ( pout !is null )  pout.close();
            if ( perr !is null )  perr.close();
            if ( pexec !is null ) pexec.close();
        }
        else
        {
            delete _stdin;
            delete _stdout;
            delete _stderr;
        }
    }

    /**
     * Explicitly close any resources held by this process object. It is recommended
     * to always call this when you are done with the process.
     */
    public void close()
    {
        this.cleanPipes;
    }

    version (Posix)
    {
        /**
         * Convert an array of strings to an array of pointers to char with
         * a terminating null character (C strings). The resulting array
         * has a null pointer at the end. This is the format expected by
         * the execv*() family of POSIX functions.
         */
        protected static char*[] toNullEndedArray(cstring[] src)
        {
            if (src !is null)
            {
                char*[] dest = new char*[src.length + 1];
                auto i = src.length;

                // Add terminating null pointer to the array
                dest[i] = null;

                while (i > 0)
                {
                    --i;
                    // Add a terminating null character to each string
                    auto cstr = toStringz(src[i]);
                    if (cstr is src[i].ptr) // no new array was allocated
                        dest[i] = src[i].dup.ptr;
                    else
                        dest[i] = cast(char*) cstr;
                }
                return dest;
            }
            else
            {
                return null;
            }
        }

        /**
         * Convert an associative array of strings to an array of pointers to
         * char with a terminating null character (C strings). The resulting
         * array has a null pointer at the end. This is the format expected by
         * the execv*() family of POSIX functions for environment variables.
         */
        protected static char*[] toNullEndedArray(istring[istring] src)
        {
            char*[] dest;

            foreach (key, value; src)
            {
                dest ~= (key.dup ~ '=' ~ value ~ '\0').ptr;
            }

            dest ~= null;
            return dest;
        }

        /**
         * Execute a process by looking up a file in the system path, passing
         * the array of arguments and the the environment variables. This
         * method is a combination of the execve() and execvp() POSIX system
         * calls.
         */
        protected static int execvpe(cstring filename, char*[] argv, char*[] envp)
        in
        {
            assert(filename.length > 0);
        }
        body
        {
            int rc = -1;
            char* str;

            if (!contains(filename, FileConst.PathSeparatorChar) &&
                (str = getenv("PATH".ptr)) !is null)
            {
                auto pathList = delimit(str[0 .. strlen(str)], ":");

                mstring path_buf;

                foreach (path; pathList)
                {
                    if (path[$-1] != FileConst.PathSeparatorChar)
                    {
                        path_buf.length = path.length + 1 + filename.length + 1;
                        enableStomping(path_buf);

                        path_buf[] = path ~ FileConst.PathSeparatorChar ~ filename ~ '\0';
                    }
                    else
                    {
                        path_buf.length = path.length +filename.length + 1;
                        enableStomping(path_buf);

                        path_buf[] = path ~ filename ~ '\0';
                    }

                    rc = execve(path_buf.ptr, argv.ptr, (envp.length == 0 ? environ : envp.ptr));

                    // If the process execution failed because of an error
                    // other than ENOENT (No such file or directory) we
                    // abort the loop.
                    if (rc == -1 && SysError.lastCode !is ENOENT)
                    {
                        break;
                    }
                }
            }
            else
            {
                debug (Process)
                    Stdout.formatln("Calling execve('{0}', argv[{1}], {2})",
                                    (argv[0])[0 .. strlen(argv[0])],
                                    argv.length, (envp.length > 0 ? "envp" : "null"));

                rc = execve(argv[0], argv.ptr, (envp.length == 0 ? environ : envp.ptr));
            }
            return rc;
        }
    }
}


/**
 * Exception thrown when the process cannot be created.
 */
class ProcessCreateException: ProcessException
{
    public this(cstring command, istring file, uint line)
    {
        this(command, SysError.lastMsg, file, line);
    }

    public this(cstring command, istring message, istring file, uint line)
    {
        super("Could not create process for " ~ idup(command) ~ " : " ~ message);
    }
}

/**
 * Exception thrown when the parent process cannot be forked.
 *
 * This exception will only be thrown on POSIX-compatible platforms.
 */
class ProcessForkException: ProcessException
{
    public this(int pid, istring file, uint line)
    {
        auto msg = format("Could not fork process ", pid);
        super(assumeUnique(msg) ~ " : " ~ SysError.lastMsg);
    }
}

/**
 * Exception thrown when the process cannot be killed.
 */
class ProcessKillException: ProcessException
{
    public this(int pid, istring file, uint line)
    {
        auto msg = format("Could not kill process ", pid);
        super(assumeUnique(msg) ~ " : " ~ SysError.lastMsg);
    }
}

/**
 * Exception thrown when the parent process tries to wait on the child
 * process and fails.
 */
class ProcessWaitException: ProcessException
{
    public this(int pid, istring file, uint line)
    {
        auto msg = format("Could not wait on process ", pid);
        super(assumeUnique(msg) ~ " : " ~ SysError.lastMsg);
    }
}




/**
 *  append an int argument to a message
*/
private mstring format (cstring msg, int value)
{
    char[10] tmp;

    return cast(mstring) msg ~ Integer.format (tmp, value);
}

extern (C) uint sleep (uint s);

unittest
{
    istring message = "hello world";
    istring command = "echo " ~ message;

    try
    {
        auto p = new Process(command, null);
        p.execute();
        char[255] buffer;

        auto nread = p.stdout.read(buffer);
        assert(nread != p.stdout.Eof);
        assert(buffer[0..nread] == message ~ "\n");

        nread = p.stdout.read(buffer);
        assert(nread == p.stdout.Eof);

        auto result = p.wait();

        assert(result.reason == Process.Result.Exit && result.status == 0);
    }
    catch (ProcessException e)
    {
        assert(false, getMsg(e));
    }
}

// check differently qualified argument calls
unittest
{
    auto p = new Process("aaa", "bbb", "ccc");
    mstring s = "xxxx".dup;
    p.argsWithCommand([ s, "aaa", "bbb"]);
    p.programName("huh");
}

// check non-literals arguments
unittest
{
    istring[] args = [ "aaa", "bbb" ];
    auto p = new Process(args);
    p.argsWithCommand(args);
}
