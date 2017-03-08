/*******************************************************************************

        Simplified, pedestrian usage:
        ---
        import ocean.util.log.Config_tango;

        Log ("hello world");
        Log ("temperature is {} degrees", 75);
        ---

        Generic usage:

        Loggers are named entities, sometimes shared, sometimes specific to
        a particular portion of code. The names are generally hierarchical in
        nature, using dot notation (with '.') to separate each named section.
        For example, a typical name might be something like "mail.send.writer"
        ---
        import ocean.util.log.Log;

        auto log = Log.lookup ("mail.send.writer");

        log.info  ("an informational message");
        log.error ("an exception message: {}", exception);

        etc ...
        ---

        It is considered good form to pass a logger instance as a function or
        class-ctor argument, or to assign a new logger instance during static
        class construction. For example: if it were considered appropriate to
        have one logger instance per class, each might be constructed like so:
        ---
        private Logger log;

        static this()
        {
            log = Log.lookup (nameOfThisClassOrStructOrModule);
        }
        ---

        Messages passed to a Logger are assumed to be either self-contained
        or configured with "{}" notation a la Layout & Stdout:
        ---
        log.warn ("temperature is {} degrees!", 101);
        ---

        Note that an internal workspace is used to format the message, which
        is limited to 2000 bytes. Use "{.256}" truncation notation to limit
        the size of individual message components, or use explicit formatting:
        ---
        char[4096] buf = void;

        log.warn (log.format (buf, "a very long message: {}", someLongMessage));
        ---

        To avoid overhead when constructing arguments passed to formatted
        messages, you should check to see whether a logger is active or not:
        ---
        if (log.warn)
            log.warn ("temperature is {} degrees!", complexFunction());
        ---

        ocean.log closely follows both the API and the behaviour as documented
        at the official Log4J site, where you'll find a good tutorial. Those
        pages are hosted over
        <A HREF="http://logging.apache.org/log4j/docs/documentation.html">here</A>.

        Copyright:
            Copyright (c) 2004 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version:
            May 2004 : Initial release
            Oct 2004: Hierarchy moved due to circular dependencies
            Apr 2008: Lazy delegates removed due to awkward usage

        Authors: Kris

*******************************************************************************/

module ocean.util.log.Log;

import ocean.transition;

import ocean.sys.Common;

import ocean.time.Clock;

import ocean.core.Exception_tango;

import ocean.io.model.IConduit;

import ocean.text.convert.Format;

import ocean.util.log.model.ILogger;

import ocean.core.Vararg;

import AP = ocean.util.log.Appender;
import EV = ocean.util.log.Event;
import ocean.util.log.Hierarchy;

alias void* Arg;
alias va_list ArgList;

/*******************************************************************************

        These represent the standard LOG4J event levels. Note that
        Debug is called Trace here, because debug is a reserved word
        in D

*******************************************************************************/

alias ILogger.Level Level;


/*******************************************************************************

        Manager for routing Logger calls to the default hierarchy. Note
        that you may have multiple hierarchies per application, but must
        access the hierarchy directly for root() and lookup() methods within
        each additional instance.

*******************************************************************************/

public struct Log
{
        /***********************************************************************

            Structure for accumulating number of log events issued.

            Note:
                this takes the logging level in account, so calls that are not
                logged because of the minimum logging level are not counted.

        ***********************************************************************/

        public static struct Stats
        {
            mixin TypeofThis!();

            /// Number of trace log events issued
            public uint logged_trace;

            /// Number of info log events issued
            public uint logged_info;

            /// Number of warn log events issued
            public uint logged_warn;

            /// Number of error log events issued
            public uint logged_error;

            /// Number of fatal log events issue
            public uint logged_fatal;

            static assert(Level.max == This.tupleof.length,
                    "Number of members doesn't match Levels");

            /*******************************************************************

                Resets the counters.

            *******************************************************************/

            private void reset ()
            {
                foreach (ref field; this.tupleof)
                {
                    field = field.init;
                }
            }

            /*******************************************************************

                Accumulate the LogEvent into the stats.

                Params:
                    event_level = level of the event that has been logged.

            *******************************************************************/

            private void accumulate (Level event_level)
            {
                with (Level) switch (event_level)
                {
                    case Trace:
                        this.logged_trace++;
                        break;
                    case Info:
                        this.logged_info++;
                        break;
                    case Warn:
                        this.logged_warn++;
                        break;
                    case Error:
                        this.logged_error++;
                        break;
                    case Fatal:
                        this.logged_fatal++;
                        break;
                    case None:
                        break;
                    default:
                        assert(false, "Non supported log level");
                }
            }
        }

        // support for old API
        public alias lookup getLogger;

        // trivial usage via opCall
        public alias formatln opCall;

        // internal use only
        private static Hierarchy base;
        package static Time beginTime;

        private struct  Pair {istring name; Level value;}

        private static  Level [istring] map;

        private static  Pair[] Pairs =
                        [
                        {"TRACE",  Level.Trace},
                        {"Trace",  Level.Trace},
                        {"trace",  Level.Trace},
                        {"INFO",   Level.Info},
                        {"Info",   Level.Info},
                        {"info",   Level.Info},
                        {"WARN",   Level.Warn},
                        {"Warn",   Level.Warn},
                        {"warn",   Level.Warn},
                        {"ERROR",  Level.Error},
                        {"Error",  Level.Error},
                        {"error",  Level.Error},
                        {"Fatal",  Level.Fatal},
                        {"FATAL",  Level.Fatal},
                        {"fatal",  Level.Fatal},
                        {"NONE",   Level.None},
                        {"None",   Level.None},
                        {"none",   Level.None},
                        ];

        // logging-level names
        package static istring[] LevelNames =
        [
                "Trace", "Info", "Warn", "Error", "Fatal", "None"
        ];

        /***********************************************************************

            Logger stats.

        ***********************************************************************/

        private static Stats logger_stats;

        /***********************************************************************

                Initialize the base hierarchy

        ***********************************************************************/

        static this ()
        {
                base = new Hierarchy ("ocean");

                foreach (p; Pairs)
                         map[p.name] = p.value;

                version (Posix)
                {
                        beginTime = Clock.now;
                }
        }

        /***********************************************************************

                Return the level of a given name

        ***********************************************************************/

        static Level convert (cstring name, Level def=Level.Trace)
        {
                auto p = name in map;
                if (p)
                    return *p;
                return def;
        }

        /***********************************************************************

                Return the current time

        ***********************************************************************/

        static Time time ()
        {
                version (Posix)
                {
                        return Clock.now;
                }
        }

        /***********************************************************************

                Return the root Logger instance. This is the ancestor of
                all loggers and, as such, can be used to manipulate the
                entire hierarchy. For instance, setting the root 'level'
                attribute will affect all other loggers in the tree.

        ***********************************************************************/

        static Logger root ()
        {
                return base.root;
        }

        /***********************************************************************

                Return an instance of the named logger. Names should be
                hierarchical in nature, using dot notation (with '.') to
                separate each name section. For example, a typical name
                might be something like "ocean.io.Stdout".

                If the logger does not currently exist, it is created and
                inserted into the hierarchy. A parent will be attached to
                it, which will be either the root logger or the closest
                ancestor in terms of the hierarchical name space.

        ***********************************************************************/

        static Logger lookup (cstring name)
        {
                return base.lookup (name);
        }

        /***********************************************************************

                Return text name for a log level

        ***********************************************************************/

        static istring convert (int level)
        {
                assert (level >= Level.Trace && level <= Level.None);
                return LevelNames[level];
        }

        /***********************************************************************

                Return the singleton hierarchy.

        ***********************************************************************/

        static Hierarchy hierarchy ()
        {
                return base;
        }

        /***********************************************************************

                Pedestrian usage support, as an alias for Log.root.info()

        ***********************************************************************/

        static void formatln (istring fmt, ...)
        {
            root.format (Level.Info, fmt, _arguments, _argptr);
        }

        /***********************************************************************

                Initialize the behaviour of a basic logging hierarchy.

                Adds a StreamAppender to the root node, and sets
                the activity level to be everything enabled.

        ***********************************************************************/

        static void config (OutputStream stream, bool flush = true)
        {
                root.add (new AP.AppendStream (stream, flush));
        }

        /***********************************************************************

            Gets the stats of the logger system between two calls to this
            method.

            Returns:
                number of log events issued after last call to stats, aggregated
                per logger level

        ***********************************************************************/

        public static Stats stats ()
        {
            // Make a copy to return
            Stats s = logger_stats;
            logger_stats.reset();

            return s;
        }
}


/*******************************************************************************

        Loggers are named entities, sometimes shared, sometimes specific to
        a particular portion of code. The names are generally hierarchical in
        nature, using dot notation (with '.') to separate each named section.
        For example, a typical name might be something like "mail.send.writer"
        ---
        import ocean.util.log.Log;format

        auto log = Log.lookup ("mail.send.writer");

        log.info  ("an informational message");
        log.error ("an exception message: {}", exception.toString);

        etc ...
        ---

        It is considered good form to pass a logger instance as a function or
        class-ctor argument, or to assign a new logger instance during static
        class construction. For example: if it were considered appropriate to
        have one logger instance per class, each might be constructed like so:
        ---
        private Logger log;

        static this()
        {
            log = Log.lookup (nameOfThisClassOrStructOrModule);
        }
        ---

        Messages passed to a Logger are assumed to be either self-contained
        or configured with "{}" notation a la Layout & Stdout:
        ---
        log.warn ("temperature is {} degrees!", 101);
        ---

        Note that an internal workspace is used to format the message, which
        is limited to 2048 bytes. Use "{.256}" truncation notation to limit
        the size of individual message components. You can also use your own
        formatting buffer:
        ---
        log.buffer (new char[](4096));

        log.warn ("a very long warning: {}", someLongWarning);
        ---

        Or you can use explicit formatting:
        ---
        char[4096] buf = void;

        log.warn (log.format (buf, "a very long warning: {}", someLongWarning));
        ---

        To avoid overhead when constructing argument passed to formatted
        messages, you should check to see whether a logger is active or not:
        ---
        if (log.enabled (log.Warn))
            log.warn ("temperature is {} degrees!", complexFunction());
        ---

        The above will be handled implicitly by the logging system when
        macros are added to the language (used to be handled implicitly
        via lazy delegates, but usage of those turned out to be awkward).

        ocean.log closely follows both the API and the behaviour as documented
        at the official Log4J site, where you'll find a good tutorial. Those
        pages are hosted over
        <A HREF="http://logging.apache.org/log4j/docs/documentation.html">here</A>.

*******************************************************************************/

public class Logger : ILogger
{

        alias Level.Trace Trace;        // shortcut to Level values
        alias Level.Info  Info;         // ...
        alias Level.Warn  Warn;         // ...
        alias Level.Error Error;        // ...
        alias Level.Fatal Fatal;        // ...

        alias append      opCall;       // shortcut to append

        /***********************************************************************

        ***********************************************************************/

        package Logger          next,
                                parent;

        private HierarchyT!(Logger) host_;
        private istring         name_;
        package Level           level_;
        private bool            additive_;
        private AP.Appender     appender_;
        private mstring         buffer_;
        private size_t          buffer_size_;

        /***********************************************************************

            Indicator if the log emits should be counted towards global
            stats.

        ***********************************************************************/

        package bool            collect_stats;

        /***********************************************************************

                Construct a LoggerInstance with the specified name for the
                given hierarchy. By default, logger instances are additive
                and are set to emit all events.

                Params:
                    host = Hierarchy instance that is hosting this logger
                    name = name of this Logger

        ***********************************************************************/

        package this (HierarchyT!(Logger) host, istring name)
        {
                this.host_ = host;
                this.level_ = Level.Trace;
                this.additive_ = true;
                this.collect_stats = true;
                this.name_ = name;
        }

        /***********************************************************************

                Is this logger enabled for the specified Level?

        ***********************************************************************/

        final bool enabled (Level level = Level.Fatal)
        {
                return host_.context.enabled (level_, level);
        }

        /***********************************************************************

                Append a trace message

        ***********************************************************************/

        final void trace (cstring fmt, ...)
        {
            format (Level.Trace, fmt, _arguments, _argptr);
        }

        /***********************************************************************

                Append an info message

        ***********************************************************************/

        final void info (cstring fmt, ...)
        {
            format (Level.Info, fmt, _arguments, _argptr);
        }

        /***********************************************************************

                Append a warning message

        ***********************************************************************/

        final void warn (cstring fmt, ...)
        {
            format (Level.Warn, fmt, _arguments, _argptr);
        }

        /***********************************************************************

                Append an error message

        ***********************************************************************/

        final void error (cstring fmt, ...)
        {
            format (Level.Error, fmt, _arguments, _argptr);
        }

        /***********************************************************************

                Append a fatal message

        ***********************************************************************/

        final void fatal (cstring fmt, ...)
        {
            format (Level.Fatal, fmt, _arguments, _argptr);
        }

        /***********************************************************************

                Return the name of this Logger (sans the appended dot).

        ***********************************************************************/

        final cstring name ()
        {
                auto i = name_.length;
                if (i > 0)
                    --i;
                return name_[0 .. i];
        }

        /***********************************************************************

                Return the Level this logger is set to

        ***********************************************************************/

        final Level level ()
        {
                return level_;
        }

        /***********************************************************************

                Set the current level for this logger (and only this logger).

        ***********************************************************************/

        final Logger level (Level l)
        {
                return level (l, false);
        }

        /***********************************************************************

                Set the current level for this logger, and (optionally) all
                of its descendants.

        ***********************************************************************/

        final Logger level (Level level, bool propagate)
        {
                level_ = level;

                if (propagate)
                {
                    this.host_.propagateValue!("level_")(this.name_, level);
                }

                return this;
        }

        /***********************************************************************

                Is this logger additive? That is, should we walk ancestors
                looking for more appenders?

        ***********************************************************************/

        final bool additive ()
        {
                return additive_;
        }

        /***********************************************************************

                Set the additive status of this logger. See bool additive().

        ***********************************************************************/

        final Logger additive (bool enabled)
        {
                additive_ = enabled;
                return this;
        }

        /***********************************************************************

                Add (another) appender to this logger. Appenders are each
                invoked for log events as they are produced. At most, one
                instance of each appender will be invoked.

        ***********************************************************************/

        final Logger add (AP.Appender another)
        {
                assert (another);
                another.next = appender_;
                appender_ = another;
                return this;
        }

        /***********************************************************************

                Remove all appenders from this Logger

        ***********************************************************************/

        final Logger clear ()
        {
                appender_ = null;
                return this;
        }

        /***********************************************************************

                Get the current formatting buffer (null if none).

        ***********************************************************************/

        final mstring buffer ()
        {
                return buffer_;
        }

        /***********************************************************************

                Set the current formatting buffer.

                Set to null to use the default internal buffer.

        ***********************************************************************/

        final Logger buffer (mstring buf)
        {
                buffer_ = buf;
                buffer_size_ = buf.length;
                return this;
        }

        /***********************************************************************

            Toggles the stats collecting for this logger and optionally
            for all its descendants.

            Params:
                value = indicator if the stats collection for this logger
                    should happen
                propagate = should we propagate this change to all children
                    loggers

        ***********************************************************************/

        void collectStats (bool value, bool propagate)
        {
            this.collect_stats = value;

            if (propagate)
            {
                this.host_.propagateValue!("collect_stats")(this.name_, value);
            }
        }

        /***********************************************************************

                Get time since this application started

        ***********************************************************************/

        final TimeSpan runtime ()
        {
                return Clock.now - Log.beginTime;
        }

        /***********************************************************************

                Send a message to this logger via its appender list.

        ***********************************************************************/

        final Logger append (Level level, lazy cstring exp)
        {
                if (host_.context.enabled (level_, level))
                   {
                   EV.LogEvent event;

                   // set the event attributes and append it
                   event.set (host_, level, exp, name.length ? name_[0..$-1] : "root");
                   append (event);
                   }
                return this;
        }

        /***********************************************************************

                Send a message to this logger via its appender list.

        ***********************************************************************/

        private void append (EV.LogEvent event)
        {
                // indicator if the event was at least once emitted to the
                // appender (to use for global stats)
                bool event_emitted;

                // combine appenders from all ancestors
                auto links = this;
                AP.Appender.Mask masks = 0;
                do {
                   auto appender = links.appender_;

                   // this level have an appender?
                   while (appender)
                         {
                         auto mask = appender.mask;

                         // have we visited this appender already?
                         if ((masks & mask) is 0)
                              // is appender enabled for this level?
                              if (appender.level <= event.level)
                                 {
                                 // append message and update mask
                                 appender.append (event);
                                 masks |= mask;
                                 event_emitted = true;
                                 }
                         // process all appenders for this node
                         appender = appender.next;
                         }
                     // process all ancestors
                   } while (links.additive_ && ((links = links.parent) !is null));

                // If the event was emitted to at least one appender, and the
                // collecting stats for this log is enabled, increment the
                // stats counters
                if (this.collect_stats && event_emitted)
                {
                    Log.logger_stats.accumulate(event.level);
                }
        }

        /***********************************************************************

                Return a formatted string from the given arguments

        ***********************************************************************/

        final mstring format (mstring buffer, cstring formatStr, ...)
        {
            return Format.vprint (buffer, formatStr, _arguments, _argptr);

        }

        /***********************************************************************

                Format and emit text from the given arguments

        ***********************************************************************/

        final void format (Level level, cstring fmt, ...)
        {
            format (level, fmt, _arguments, _argptr);
        }

        /***********************************************************************

                Format and emit text from the given arguments

        ***********************************************************************/

        final Logger format (Level level, cstring fmt, TypeInfo[] types, ArgList args)
        {
                if (types.length)
                {
                    if (buffer_ is null)
                        formatWithDefaultBuffer(level, fmt, types, args);
                    else
                        formatWithProvidedBuffer(level, fmt, types, args);
                }
                else
                   append (level, fmt);
                return this;
        }

        private void formatWithDefaultBuffer(Level level, cstring fmt, TypeInfo[] types, ArgList args)
        {
            char[2048] tmp = void;
            formatWithBuffer(level, fmt, types, args, tmp);
        }

        private void formatWithProvidedBuffer(Level level, cstring fmt, TypeInfo[] types, ArgList args)
        {
            formatWithBuffer(level, fmt, types, args, buffer_);
            buffer_.length = buffer_size_;
        }

        private void formatWithBuffer(Level level, cstring fmt, TypeInfo[] types, ArgList args, mstring buf)
        {
            append (level, Format.vprint (buf, fmt, types, args));
        }

        /***********************************************************************

                See if the provided Logger name is a parent of this one. Note
                that each Logger name has a '.' appended to the end, such that
                name segments will not partially match.

        ***********************************************************************/

        package final bool isChildOf (istring candidate)
        {
                auto len = candidate.length;

                // possible parent if length is shorter
                if (len < name_.length)
                {
                    // does the prefix match? Note we append a "." to each
                    // (the root is a parent of everything)
                    return (len is 0 || candidate == name_[0 .. len]);
                }
                return false;
        }

        /***********************************************************************

                See if the provided Logger is a better match as a parent of
                this one. This is used to restructure the hierarchy when a
                new logger instance is introduced

        ***********************************************************************/

        package final bool isCloserAncestor (Logger other)
        {
                auto name = other.name_;
                if (isChildOf (name))
                    // is this a better (longer) match than prior parent?
                    if ((parent is null) || (name.length >= parent.name_.length))
                         return true;
                return false;
        }
}

/*******************************************************************************

        The Logger hierarchy implementation. We keep a reference to each
        logger in a hash-table for convenient lookup purposes, plus keep
        each logger linked to the others in an ordered group. Ordering
        places shortest names at the head and longest ones at the tail,
        making the job of identifying ancestors easier in an orderly
        fashion. For example, when propagating levels across descendants
        it would be a mistake to propagate to a child before all of its
        ancestors were taken care of.

*******************************************************************************/

public alias HierarchyT!(Logger) Hierarchy;
