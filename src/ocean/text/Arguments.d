/*******************************************************************************

    Module to manage command-line arguments.

    ____________________________________________________________________________

    Simple usage:

    ---

        int main ( istring[] cl_args )
        {
            // Create an object to parse command-line arguments
            auto args = new Arguments;

            // Setup what arguments are valid
            // (these can be configured in various ways as will be demonstrated
            // later in the documentation)
            args("alpha");
            args("bravo");

            // Parse the actual command-line arguments given to the application
            // (the first element is the application name, so that should not be
            // passed to the 'parse()' function)
            auto args_ok = args.parse(cl_args[1 .. $]);

            if ( args_ok )
            {
                // Proceed with rest of the application
                ...
            }
            else
            {
                // Discover what caused the error and handle appropriately
            }
        }

    ---

    ____________________________________________________________________________


    For the sake of brevity, the rest of this documentation will not show the
    'main()' function or the creation of the 'args' object. Also, setting up of
    arguments will be shown only where necessary. Moreover, the 'args.parse()'
    function will be called with a custom string representing the command-line
    arguments. This is as shown in the following example:

    ---

        args.parse("--alpha --bravo");

        if ( args("alpha").set )
        {
            // This will be reached as '--alpha' was given
        }

        if ( args("bravo").set )
        {
            // This will be reached as '--bravo' was given
        }

        if ( args("charlie").set )
        {
            // This will *not* be reached as '--charlie' was not given
        }

    ---

    ____________________________________________________________________________


    When arguments are being set up, normally all arguments that an application
    supports are explicitly declared and suitably configured. But sometimes, it
    may be desirable to use on-the-fly arguments that are not set up but
    discovered during parsing. Such arguments are called 'sloppy arguments'.
    Support for sloppy arguments is disabled by default, but can be enabled when
    calling the 'parse()' function, as shown below:

    ---

        args("alpha");

        args.parse("--alpha --bravo");
            // This will result in an error because only 'alpha' was declared,
            // but not 'bravo'.

        args.parse("--alpha --bravo", true);
            // This, on the other hand would work. Space for 'bravo' (and
            // potentially any of its parameters) would be allocated when
            // 'bravo' gets discovered during parsing.

    ---

    ____________________________________________________________________________


    Arguments can be configured to have aliases. This is a convenient way to
    represent arguments with long names. Aliases are always exactly one
    character long. An argument can have multiple aliases. Aliases are always
    given on the command-line using the short prefix.

    ---

        args("alpha").aliased('a');
        args("help").aliased('?').aliased('h'); // multiple aliases allowed

        args.parse("-a -?");

    ---

    ____________________________________________________________________________


    Arguments can be configured to be mandatorily present, by calling the
    'required()' function as follows:

    ---

        args("alpha").required();

        args.parse("--bravo");
            // This will fail because the required argument 'alpha' was not
            // given.

    ---

    ____________________________________________________________________________


    An argument can be configured to depend upon another, by calling the
    'requires()' function as follows:

    ---

        args("alpha");
        args("bravo").requires("alpha");

        args.parse("--bravo");
            // This will fail because 'bravo' needs 'alpha', but 'alpha' was not
            // given.

        args.parse("--alpha --bravo");
            // This, on the other hand, will succeed.

    ---

    ____________________________________________________________________________


    An argument can be configured to conflict with another, by calling the
    'conflicts()' function as follows:

    ---

        args("alpha");
        args("bravo").conflicts("alpha");

        args.parse("--alpha --bravo");
            // This will fail because 'bravo' conflicts with 'alpha', so both of
            // them can't be present together.

    ---

    ____________________________________________________________________________


    By default arguments don't have any associated parameters. When setting up
    arguments, they can be configured to have zero or more associated
    parameters. Parameters assigned to an argument can be accessed using that
    argument's 'assigned[]' array at consecutive indices. The number of
    parameters assigned to an argument must exactly match the number of
    parameters it has been set up to have, or else parsing will fail. Dealing
    with parameters is shown in the following example:

    ---

        args("alpha");
        args("bravo").params(0);
            // Doing `params(0)` is redundant
        args("charlie").params(1);
            // 'charlie' must have exactly one associated parameter

        args.parse("--alpha --bravo --charlie=chaplin");
            // the parameter assigned to 'charlie' (i.e. 'chaplin') can be
            // accessed using `args("charlie").assigned[0]`

    ---

    ____________________________________________________________________________


    Parameter assignment can be either explicit or implicit. Explicit assignment
    is done using an assignment symbol (defaults to '=', can be changed),
    whereas implicit assignment happens when a parameter is found after a
    whitespace.
    Implicit assignment always happens to the last known argument target, such
    that multiple parameters accumulate (until the configured parameters count
    for that argument is reached). Any extra parameters encountered after that
    are assigned to a special 'null' argument. The 'null' argument is always
    defined and acts as an accumulator for parameters left uncaptured by other
    arguments.

    Please note:
        * if sloppy arguments are supported, and if a sloppy argument happens to
          be the last known argument target, then implicit assignment of any
          extra parameters will happen to that sloppy argument.
          [example 2 below]

        * explicit assignment to an argument always associates the parameter
          with that argument even if that argument's parameters count has been
          reached. In this case, 'parse()' will fail.
          [example 3 below]

    ---

        args("alpha").params(3);

        // Example 1
        args.parse("--alpha=one --alpha=two three four");
            // In this case, 'alpha' would have 3 parameters assigned to it (so
            // its 'assigned' array would be `["one", "two", "three"]`), and the
            // null argument would have 1 parameter (with its 'assigned' array
            // being `["four"]`).
            // Here's why:
            // Two of these parameters ('one' & 'two') were assigned explicitly.
            // The next parameter ('three') was assigned implicitly since
            // 'alpha' was the last known argument target. At this point,
            // alpha's parameters count is reached, so no more implicit
            // assignment will happen to 'alpha'.
            // So the last parameter ('four') is assigned to the special 'null'
            // argument.

        // Example 2
        // (sloppy arguments supported by passing 'true' as the second parameter
        // to 'parse()')
        args.parse("--alpha one two three four --xray five six", true);
            // In this case, 'alpha' would get its 3 parameters ('one', 'two' &
            // 'three') by way of implicit assignment.
            // Parameter 'four' would be assigned to the 'null' argument (since
            // implicit assignment to the last known argument target 'alpha' is
            // not possible as alpha's parameter count has been reached).
            // The sloppy argument 'xray' now becomes the new last known
            // argument target and hence gets the last two parameters ('five' &
            // 'six').

        // Example 3
        args.parse("--alpha one two three --alpha=four");
            // As before, 'alpha' would get its 3 parameters ('one', 'two' &
            // 'three') by way of implicit assignment.
            // Since 'four' is being explicitly assigned to 'alpha', parsing
            // will fail here as 'alpha' has been configured to have at most 3
            // parameters.

    ---

    ____________________________________________________________________________


    An argument can be configured to have one or more default parameters. This
    means that if the argument was not given on the command-line, it would still
    contain the configured parameter(s).
    It is, of course, possible to have no default parameters configured. But if
    one or more default parameters have been configured, then their number must
    exactly match the number of parameters configured.

    Please note:
        * Irrespective of whether default parameters have been configured or not,
          if an argument was not given on the command-line, its 'set()' function
          would return 'false'.
          [example 1 below]

        * Irrespective of whether default parameters have been configured or not,
          if an argument is given on the command-line, it must honour its
          configured number of parameters.
          [example 2 below]

    ---

        args("alpha").params(1).defaults("one");

        // Example 1
        args.parse("--bravo");
            // 'alpha' was not given, so `args("alpha").set` would return false
            // but still `args("alpha").assigned[0]` would contain 'one'

        // Example 2
        args.parse("--alpha");
            // this will fail because 'alpha' expects a parameter and that was
            // not given. In this case, the configured default parameter will
            // *not* be picked up.

    ---

    ____________________________________________________________________________


    Parameters of an argument can be restricted to a pre-defined set of
    acceptable values. In this case, argument parsing will fail on an attempt to
    assign a value from outside the set:

    ---

        args("greeting").restrict(["hello", "namaste", "ahoj", "hola"]);
        args("enabled").restrict(["true", "false", "t", "f", "y", "n"]);

        args.parse("--greeting=bye");
            // This will fail since 'bye' is not among the acceptable values

    ---

    ____________________________________________________________________________


    The parser makes a distinction between long prefix arguments and short
    prefix arguments. Long prefix arguments start with two hyphens (--argument),
    while short prefix arguments start with a single hyphen (-a) [the prefixes
    themselves are configurable, as shown in later documentation]. Within a
    short prefix argument, each character represents an individual argument.
    Long prefix arguments must always be distinct, while short prefix arguments
    may be combined together.

    ---

        args.parse("--alpha -b");
            // The argument 'alpha' will be set.
            // The argument represented by 'b' will be set (note that 'b' here
            // could be an alias to another argument, or could be the argument
            // name itself)

    ---

    ____________________________________________________________________________


    When assigning parameters to an argument using the argument's short prefix
    version, it is possible to "smush" the parameter with the argument. Smushing
    refers to omitting the explicit assignment symbol ('=' by default) or
    whitespace (when relying on implicit assignment) that separates an argument
    from its parameter. The ability to smush an argument with its parameter in
    this manner has to be explicitly enabled using the 'smush()' function.

    Please note:
        * smushing cannot be done with the long prefix version of an argument
          [example 2 below]

        * smushing is irrelevant if an argument has no parameters
          [example 3 below]

        * if an argument has more than one parameter, and smushing is desired,
          then the short prefix version of the argument needs to be repeated as
          many times as the number of parameters to be assigned (this is because
          one smush can only assign one parameter at a time)
          [example 4 below]

        * smushing cannot be used if the parameter contains the explicit
          assignment symbol ('=' by default). In this case, either explicit or
          implicit assignment should be used. This limitation is due to how
          argv/argc values are stripped of original quotes.
          [example 5 below]

    ---

        // Example 1
        args("alpha").aliased('a').params(1).smush;
        args.parse("-aparam");
            // OK - this is equivalent to `args.parse("-a param");`

        // Example 2
        args("bravo").params(1).smush;
        args.parse("--bravoparam");
            // ERROR - 'param' cannot be smushed with 'bravo'

        // Example 3
        args("charlie").smush;
            // irrelevant smush as argument has no parameters

        // Example 4
        args('d').params(2).smush;
        args.parse("-dfile1 -dfile2");
            // smushing multiple parameters requires the short prefix version of
            // the argument to be repeated. This could have been done without
            // smushing as `args.parse("-d file1 file2);`

        // Example 5
        args("e").params(1).smush;
        args.parse("-e'foo=bar'");
            // The parameter 'foo=bar' cannot be smushed with the argument as
            // the parameter contains '=' within. Be especially careful of this
            // as the 'parse()' function will not fail in this case, but may
            // result in unexpected behaviour.
            // The proper way to assign a parameter containing the explicit
            // assignment symbol is to use one of the following:
            //     args.parse("-e='foo=bar'"); // explicit assignment
            //     args.parse("-e 'foo=bar'"); // implicit assignment

    ---

    ____________________________________________________________________________


    The prefixes used for the long prefix and the short prefix version of the
    arguments default to '--' & '-' respectively, but they are configurable. To
    change these, the desired prefix strings need to be passed to the
    constructor as shown below:

    ---

        // Change short prefix to '/' & long prefix to '%'
        auto args = new Arguments(null, null, null, null, "/", "%");

        args.parse("%alpha=param %bravo /abc");
            // arguments 'alpha' & 'bravo' set using the long prefix version
            // arguments represented by the characters 'a', 'b' & 'c' set using
            // the short prefix version

    ---

    Note that it is also possible to disable both prefixes by passing 'null' as
    the constructor parameters.

    ____________________________________________________________________________


    We noted in the documentation earlier that a parameter following a
    whitespace gets assigned to the last known target (implicit assignment). On
    the other hand, the symbol used for explicitly assigning a parameter to an
    argument defaults to '='. This symbol is also configurable, and can be
    changed by passing the desired symbol character to the constructor as
    shown below:

    ---

        // Change the parameter assignment symbol to ':'
        // (the short prefix and long prefix need to be passed as their default
        // values since we're not changing them)
        auto args = new Arguments(null, null, null, null, "-", "--", ':');

        args.parse("--alpha:param");
            // argument 'alpha' will be assigned parameter 'param' using
            // explicit assignment

    ---

    ____________________________________________________________________________


    All text following a "--" token are treated as parameters (even if they
    start with the long prefix or the short prefix). This notion is applied by
    unix systems to terminate argument processing in a similar manner.

    These parameters are always assigned to the special 'null' argument.

    ---

        args("alpha").params(1);

        args.parse("--alpha one -- -two --three");
            // 'alpha' gets one parameter ('one')
            // the null argument gets two parameters ('-two' & '--three')
            // note how 'two' & 'three' are prefixed by the short and long
            // prefixes respectively, but the prefixes don't play any part as
            // these are just parameters now

    ---

    ____________________________________________________________________________


    When configuring the command-line arguments, qualifiers can be chained
    together as shown in the following example:

    ---

        args("alpha")
            .required
            .params(1)
            .aliased('a')
            .requires("bravo")
            .conflicts("charlie")
            .defaults("one");

    ---

    ____________________________________________________________________________

    The full help message for the application (which includes the configured
    usage, long & short descriptions as well as the help text of each of the
    arguments) can be displayed using the 'displayHelp()' function as follows:

    ---

        auto args = new Arguments(
            "my_app",
            "{0} : this is a short description",
            "this is the usage string",
            "this is a long description on how to make '{0}' work");

        args("alpha")
            .aliased('a')
            .params(1,3)
            .help("help for alpha");
        args("bravo")
            .aliased('b')
            .params(1)
            .defaults("val")
            .help("help for bravo");

        args.displayHelp();

    ---

    Doing this, would produce the following help message:

        my_app : this is a short description

        Usage:  this is the usage string

        this is a long description on how to make 'my_app' work

        Program options:
          -a, --alpha  help for alpha (1-3 params)
          -b, --bravo  help for bravo (1 param, default: [val])

    ____________________________________________________________________________


    The 'parse()' function will return true only where all conditions are met.
    If an error occurs, the parser will set an error code and return false.

    The error codes (which indicate the nature of the error) are as follows:

        None     : ok (no error)
        ParamLo  : too few parameters were assigned to this argument
        ParamHi  : too many parameters were assigned to this argument
        Required : this is a required argument, but was not given
        Requires : this argument depends on another argument which was not given
        Conflict : this argument conflicts with another given argument
        Extra    : unexpected argument (will not trigger an error if sloppy
                   arguments are enabled)
        Option   : parameter assigned is not one of the acceptable options


    A simple way to handle errors is to invoke an internal format routine, which
    constructs error messages on your behalf. The messages are constructed using
    a layout handler and the messages themselves may be customized (for i18n
    purposes). See the two 'errors()' methods for more information on this. The
    following example shows this way of handling errors:

    ---

        if ( ! args.parse (...) )
        {
            stderr(args.errors(&stderr.layout.sprint));
        }

    ---


    Another way of handling argument parsing errors, is to traverse the set of
    arguments, to find out exactly which argument has the error, and what is the
    error code. This is as shown in the following example:

    ---

        if ( ! args.parse (...) )
        {
            foreach ( arg; args )
            {
                if ( arg.error )
                {
                    // 'arg.error' contains one of the above error-codes

                    ...
                }
            }
        }

    ---

    ____________________________________________________________________________


    The following two types of callbacks are supported:
        - a callback called when an argument is parsed
        - a callback called whenever a parameter gets assigned to an argument
    (see the 'bind()' methods for the signatures of these delegates).

    ____________________________________________________________________________

    Copyright:
        Copyright (c) 2009 Kris.
        Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

*******************************************************************************/

module ocean.text.Arguments;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.io.Stdout_tango;
import ocean.math.Math;
import ocean.text.Util;
import ocean.text.convert.Integer_tango;
import ocean.util.container.SortedMap;
import ocean.util.container.more.Stack;



/*******************************************************************************

    The main arguments container class.

*******************************************************************************/

public class Arguments
{
    import ocean.core.Enforce : enforce;

    /***************************************************************************

        Convenience aliases to access a specific argument instance

    ***************************************************************************/

    public alias get opCall;  // args("name")
    public alias get opIndex; // args["name"]


    /***************************************************************************

        Convenience alias to get the value of a boolean argument

    ***************************************************************************/

    public alias getBool exists;


    /***************************************************************************

        Application's name to use in help messages.

    ***************************************************************************/

    public istring app_name;


    /***************************************************************************

        Application's short usage description (as a format string).

        This is used as a format string to print the usage. The first parameter
        to the format string is the application's name. This string should
        describe how to invoke the application.

        If the usage description spans multiple lines, then it's better to start
        each line with a tab character (\t).

        Examples:

        ---

            args.usage = "{0} [OPTIONS] SOMETHING FILE";
            args.usage = "{0} [OPTIONS] SOMETHING FILE\n"
                         "\t{0} --version";

        ---

    ***************************************************************************/

    public istring usage = "{0} [OPTIONS] [ARGS]";


    /***************************************************************************

        One line description of what the application does (as a format string).

        This is used as a format string to print a short description of what the
        application does. The first argument is the name of the application (but
        the name shouldn't normally be used in the description).

    ***************************************************************************/

    public istring short_desc;


    /***************************************************************************

        Long description about the application and how to use it (as a format
        string).

        This is used as a format string to print a long description of what the
        application does and how to use it. The first argument is the name of
        the application.

    ***************************************************************************/

    public istring long_desc;


    /***************************************************************************

        Stack used to help in assigning implicitly assigned parameters to
        arguments during parsing.

        This stack contains argument instances of only those arguments that can
        have one or more associated parameters. Implicit parameters always get
        assigned to the topmost argument in the stack. Once the number of
        parameters of the topmost argument in the stack reaches its maximum
        configured value, that argument gets popped off the stack. Future
        implicit assignments will then happen to the new topmost argument in the
        stack.

        The null argument is always the first one that gets pushed onto the
        stack. This ensures that it is able to "catch" all unclaimed parameters
        at the end.

    ***************************************************************************/

    private Stack!(Argument) stack;


    /***************************************************************************

        All argument instances. A sorted map (indexed by the argument name) is
        used to store these so that the arguments appear in a sorted manner in
        the help text output

    ***************************************************************************/

    private SortedMap!(cstring, Argument) args;


    /***************************************************************************

        Argument instances that have aliases. A sorted map (indexed by the
        argument aliases) is used to store these so that the arguments appear in
        a sorted manner in the help text output

    ***************************************************************************/

    private SortedMap!(cstring, Argument) aliases;


    /***************************************************************************

        Character to be used as the explicit assignment symbol

    ***************************************************************************/

    private char eq;


    /***************************************************************************

        The short prefix string

    ***************************************************************************/

    private istring sp;


    /***************************************************************************

        The long prefix string

    ***************************************************************************/

    private istring lp;


    /***************************************************************************

        Error messages

    ***************************************************************************/

    private Const!(istring)[] msgs;


    /***************************************************************************

        Format strings of all default errors

    ***************************************************************************/

    private const istring[] errmsg = [
        "argument '{0}' expects {2} parameter(s) but has {1}\n",
        "argument '{0}' expects {3} parameter(s) but has {1}\n",
        "argument '{0}' is missing\n",
        "argument '{0}' requires '{4}'\n",
        "argument '{0}' conflicts with '{4}'\n",
        "unexpected argument '{0}'\n",
        "argument '{0}' expects one of {5}\n",
        "invalid parameter for argument '{0}': {4}\n",
    ];


    /***************************************************************************

        Internal string used for spacing of the full help message

    ***************************************************************************/

    private mstring spaces;


    /***************************************************************************

        Maximum width of the column showing argument aliases in the full help
        message

    ***************************************************************************/

    private size_t aliases_width;


    /***************************************************************************

        Maximum width of the column showing argument names in the full help
        message

    ***************************************************************************/

    private size_t long_name_width;


    /***************************************************************************

        Constructor.

        Params:
            app_name = name of the application (to show in the help message)
            short_desc = short description of what the application does (should
                be one line only, preferably less than 80 characters long)
            usage = how the application is supposed to be invoked
            long_desc = long description of what the application does and how to
                use it
            sp = string to use as the short prefix (defaults to '-')
            lp = string to use as the long prefix (defaults to '--')
            eq = character to use as the explicit assignment symbol
                 (defaults to '=')

    ***************************************************************************/

    public this ( istring app_name = null, istring short_desc = null,
        istring usage = null, istring long_desc = null, istring sp = "-",
        istring lp = "--", char eq = '=' )
    {
        this.msgs = this.errmsg;

        this.app_name = app_name;
        this.short_desc = short_desc;
        this.long_desc = long_desc;
        this.sp = sp;
        this.lp = lp;
        this.eq = eq;

        this.args = new typeof(this.args)();
        this.aliases = new typeof(this.aliases)();

        if ( usage.length > 0 )
        {
            this.usage = usage;
        }

        this.get(null).params; // set null argument to consume params
    }


    /***************************************************************************

        Parses the command-line arguments into a set of Argument instances. The
        command-line arguments are expected to be passed in a string.

        Params:
            input = string to be parsed (contains command-line arguments)
            sloppy = true if any unexpected arguments found during parsing
                should be accepted on-the-fly, false if unexpected arguments
                should be treated as error

        Returns:
            true if parsing was successful, false otherwise

    ***************************************************************************/

    public bool parse ( istring input, bool sloppy = false )
    {
        istring[] tmp;

        foreach ( s; quotes(input, " ") )
        {
            tmp ~= s;
        }

        return parse(tmp, sloppy);
    }


    /***************************************************************************

        Parses the command-line arguments into a set of Argument instances. The
        command-line arguments are expected to be passed in an array of strings.

        Params:
            input = array of strings to be parsed (contains command-line
                arguments)
            sloppy = true if any unexpected arguments found during parsing
                should be accepted on-the-fly, false if unexpected arguments
                should be treated as error

        Returns:
            true if parsing was successful, false otherwise

    ***************************************************************************/

    public bool parse ( Const!(istring)[] input, bool sloppy = false )
    {
        bool done;
        int error;

        stack.push(this.get(null));

        foreach ( s; input )
        {
            if ( done is false )
            {
                if ( s == "--" )
                {
                    done = true;

                    stack.clear.push(this.get(null));

                    continue;
                }
                else
                {
                    if ( argument(s, lp, sloppy, false) ||
                         argument(s, sp, sloppy, true) )
                    {
                        continue;
                    }
                }
            }

            stack.top.append (s);
        }

        foreach ( arg; args )
        {
            error |= arg.valid;
        }

        return error is 0;
    }


    /***************************************************************************

        Unsets all configured arguments (as if they weren't given at all on the
        command-line), clears all parameters that may have been assigned to
        arguments and also clears any parsing errors that may have been
        associated with any argument(s).

        Note that configured arguments are *not* removed.

        Returns:
            this object for method chaining

    ***************************************************************************/

    public Arguments clear ( )
    {
        stack.clear;

        foreach ( arg; args )
        {
            arg.set = false;
            arg.values = null;
            arg.error = arg.None;
        }

        return this;
    }


    /***************************************************************************

        Gets a reference to an argument, creating a new instance if necessary.

        Params:
            name = character representing the argument to be retrieved (this is
                usually an alias to the argument, but could also be the argument
                name if the argument name is exactly one character long)

        Returns:
            a reference to the argument

    ***************************************************************************/

    public Argument get ( char name )
    {
        return get(cast(cstring)(&name)[0 .. 1]);
    }


    /***************************************************************************

        Gets a reference to an argument, creating a new instance if necessary.

        Params:
            name = string containing the argument name (pass null to access the
                special 'null' argument)

        Returns:
            a reference to the argument

    ***************************************************************************/

    public Argument get ( cstring name )
    {
        auto a = name in args;

        if ( a is null )
        {
            auto _name = idup(name);

            auto arg = new Argument(_name);

            args[_name] = arg;

            return arg;
        }

        return *a;
    }


    /***************************************************************************

        Enables 'foreach' iteration over the set of configured arguments.

        Params:
            dg = delegate called for each argument

    ***************************************************************************/

    public int opApply ( int delegate(ref Argument) dg )
    {
        int result;

        foreach ( arg; args )
        {
            if ( (result = dg(arg)) != 0 )
            {
                break;
            }
        }

        return result;
    }


    /***************************************************************************

        Constructs a string of error messages, using the given delegate to
        format the output.
        The system formatter can be used by passing `&stderr.layout.sprint` as
        the delegate.

        Params:
            dg = delegate that will be called for formatting the error messages

        Returns:
            formatted error message string

    ***************************************************************************/

    public istring errors ( mstring delegate(mstring buf, cstring fmt, ...) dg )
    {
        char[256] tmp;
        istring result;

        foreach ( arg; args )
        {
            if ( arg.error )
            {
                result ~= dg(tmp, msgs[arg.error-1], arg.name,
                    arg.values.length, arg.min, arg.max, arg.bogus,
                    arg.options);
            }
        }

        return result;
    }


    /***************************************************************************

        Replaces the default error messages with the given string.
        Note that arguments are passed to the formatter in the following order,
        and these should be indexed appropriately by each of the error messages
        (see the 'errmsg' variable for the format string):

            index 0: the argument name
            index 1: number of parameters
            index 2: configured minimum parameters
            index 3: configured maximum parameters
            index 4: conflicting/dependent argument (or invalid param)
            index 5: array of configured parameter options

        Params:
            errors = string to replace the default error messages with

        Returns:
            this object for method chaining

    ***************************************************************************/

    public Arguments errors ( Const!(istring)[] errors )
    {
        if ( errors.length is errmsg.length )
        {
            msgs = errors;
        }
        else
        {
            assert (false);
        }

        return this;
    }


    /***************************************************************************

        Exposes the configured help text for each of the configured arguments,
        via the given delegate. Note that the delegate will be called only for
        those arguments for which a help text has been configured.

        Params:
            dg = delegate that will be called for each argument having a help
                text (the argument name and the help text itself will be sent as
                parameters to the delegate)

        Returns:
            this object for method chaining

    ***************************************************************************/

    public Arguments help ( void delegate ( istring arg, istring help ) dg )
    {
        foreach ( arg; args )
        {
            if ( arg.text.ptr )
            {
                dg(arg.name, arg.text);
            }
        }

        return this;
    }


    /***************************************************************************

        Displays the full help message for the application.

        Params:
            output = stream where to print the errors (Stderr by default)

    ***************************************************************************/

    public void displayHelp ( typeof(Stderr) output = Stderr )
    {
        if ( this.short_desc.length > 0 )
        {
            output.formatln(this.short_desc, this.app_name);
            output.newline;
        }

        output.formatln("Usage:\t" ~ this.usage, this.app_name);
        output.newline;

        if ( this.long_desc.length > 0 )
        {
            output.formatln(this.long_desc, this.app_name);
            output.newline;
        }

        foreach ( arg; this.args )
        {
            this.calculateSpacing(arg);
        }

        output.formatln("Program options:");

        foreach ( arg; this.args )
        {
            // Skip the null argument
            if ( arg.name.length == 0 )
            {
                continue;
            }

            this.displayArgumentHelp(arg, output);
        }

        output.newline;
    }


    /***************************************************************************

        Displays any errors that occurred.

        Params:
            output = stream where to print the errors (Stderr by default)

    ***************************************************************************/

    public void displayErrors ( typeof(Stderr) output = Stderr )
    {
        output(this.errors(&output.layout.sprint));
    }


    /***************************************************************************

        Convenience method to check whether an argument is set or not (i.e.
        whether it was found during parsing of the command-line arguments).

        Params:
            name = name of the argument

        Returns:
            true if the argument is set, false otherwise

    ***************************************************************************/

    public bool getBool ( cstring name )
    {
        auto arg = this.get(name);

        if ( arg )
        {
            return arg.set;
        }
        else
        {
            return false;
        }
    }


    /***************************************************************************

        Convenience method to get the integer value of the parameter assigned to
        an argument. This is valid only if the argument has been assigned
        exactly one parameter.

        Template_Params:
            T = type of integer to return

        Params:
            name = name of the argument

        Returns:
            integer value of the parameter assigned to the argument

    ***************************************************************************/

    public T getInt ( T ) ( cstring name )
    {
        auto arg = this.get(name);

        cstring value;

        if ( arg && arg.assigned.length == 1 )
        {
            value = arg.assigned[0];
        }

        auto num = toLong(value);

        enforce(num <= T.max && num >= T.min);

        return cast(T)num;
    }


    /***************************************************************************

        Convenience method to get the string parameter assigned to an argument.
        This is valid only if the argument has been assigned exactly one
        parameter.

        Params:
            name = name of the argument

        Returns:
            parameter assigned to the argument

    ***************************************************************************/

    public istring getString ( cstring name )
    {
        auto arg = this.get(name);

        istring value;

        if ( arg && arg.assigned.length == 1 )
        {
            value = arg.assigned[0];
        }

        return value;
    }


    /***************************************************************************

        Tests for the presence of a switch (long/short prefix) and enables the
        associated argument if found. Also looks for and handles explicit
        parameter assignment.

        Params:
            s = An individual string from the command-line arguments (includes
                the long/short prefix if it is an argument string)
            p = the prefix string (whether this is the long prefix or the short
                prefix is indicated by the 'flag' parameter)
            sloppy = true if any unexpected arguments found during parsing
                should be accepted on-the-fly, false if unexpected arguments
                should be treated as error
            flag = true if the prefix string given is the short prefix, false if
                it is the long prefix

        Returns:
            true if the given string was an argument, false if it was a
            parameter

    ***************************************************************************/

    private bool argument ( istring s, istring p, bool sloppy, bool flag )
    {
        if ( s.length >= p.length && s[0 .. p.length] == p )
        {
            s = s[p.length .. $];

            auto i = locate(s, eq);

            if ( i < s.length )
            {
                enable(s[0 .. i], sloppy, flag).append(s[i + 1 .. $], true);
            }
            else
            {
                // trap empty arguments; attach as param to null-arg
                if ( s.length )
                {
                    enable(s, sloppy, flag);
                }
                else
                {
                    this.get(null).append(p, true);
                }
            }

            return true;
        }

        return false;
    }


    /***************************************************************************

        Indicates the existence of an argument, and handles sloppy arguments
        along with multiple-flags and smushed parameters. Note that sloppy
        arguments are configured with parameters enabled.

        Params:
            elem = an argument name found during parsing (does not contain the
                long/short prefix)
            sloppy = true if any unexpected arguments found during parsing
                should be accepted on-the-fly, false if unexpected arguments
                should be treated as error
            flag = true if the argument name was preceded by the short prefix,
                false if it was preceded by the long prefix

        Returns:
            the configured argument instance

    ***************************************************************************/

    private Argument enable ( istring elem, bool sloppy, bool flag = false )
    {
        if ( flag && elem.length > 1 )
        {
            // locate arg for first char
            auto arg = enable(elem[0 .. 1], sloppy);

            elem = elem[1 .. $];

            // drop further processing of this flag where in error
            if ( arg.error is arg.None )
            {
                // smush remaining text or treat as additional args
                if ( arg.cat )
                {
                    arg.append(elem, true);
                }
                else
                {
                    arg = enable(elem, sloppy, true);
                }
            }

            return arg;
        }

        // if not in args, or in aliases, then create new arg
        auto a = elem in args;

        if ( a is null )
        {
            if ( (a = elem in aliases) is null )
            {
                return this.get(elem).params.enable(!sloppy);
            }
        }

        return a.enable;
    }


    /***************************************************************************

        Calculates the width required to display all the aliases based on the
        given number of aliases (in the aliases string, each character is an
        individual argument alias).

        Params:
            aliases = number of argument aliases

        Returns:
            width required to display all the aliases

    ***************************************************************************/

    private size_t aliasesWidth ( size_t aliases )
    {
        auto width = aliases * 2; // *2 for a '-' before each alias

        if ( aliases > 1 )
        {
            width += (aliases - 1) * 2; // ', ' after each alias except the last
        }

        return width;
    }


    /***************************************************************************

        Calculates the maximum width required to display the given argument name
        and its aliases.

        Params:
            arg = the argument instance

    ***************************************************************************/

    private void calculateSpacing ( Argument arg )
    {
        this.long_name_width = max(this.long_name_width, arg.name.length);

        this.aliases_width = max(this.aliases_width,
            this.aliasesWidth(arg.aliases.length));
    }


    /***************************************************************************

        Displays help text for a single argument.

        Params:
            arg = argument instance for which the help text is to be printed
            output = stream where to print the help text (Stderr by default)

    ***************************************************************************/

    private void displayArgumentHelp ( Argument arg,
        typeof(Stderr) output = Stderr )
    {
        output.format("  ");

        foreach ( i, al; arg.aliases )
        {
            output.format("-{}", al);

            if ( i != arg.aliases.length - 1 || arg.name.length )
            {
                output.format(", ");
            }
        }

        // there is no trailing ", " in this case, so add two spaces instead.
        if ( arg.aliases.length == 0 )
        {
            output.format("  ");
        }

        output.format("{}",
            this.space(this.aliases_width -
                       this.aliasesWidth(arg.aliases.length)));

        output.format("--{}{}  ",
            arg.name, this.space(this.long_name_width - arg.name.length));

        output.format("{}", arg.text);

        uint extras;

        bool params = arg.min > 0 || arg.max > 0;

        if ( params )              extras++;
        if ( arg.options.length )  extras++;
        if ( arg.deefalts.length ) extras++;

        if ( extras )
        {
            // comma separate sections if more info to come
            void next ( )
            {
                extras--;

                if ( extras )
                {
                    output.format(", ");
                }
            }

            output.format(" (");

            if ( params )
            {
                if ( arg.min == arg.max )
                {
                    output.format("{} param{}", arg.min,
                        arg.min == 1 ? "" : "s");
                }
                else
                {
                    output.format("{}-{} params", arg.min, arg.max);
                }

                next();
            }

            if ( arg.options.length )
            {
                output.format("{}", arg.options);

                next();
            }

            if ( arg.deefalts.length )
            {
                output.format("default: {}", arg.deefalts);

                next();
            }

            output.format(")");
        }

        output.newline.flush;
    }


    /***************************************************************************

        Creates a string with the specified number of spaces.

        Params:
            width = desired number of spaces

        Returns:
            string with desired number of spaces.

    ***************************************************************************/

    private mstring space ( size_t width )
    {
        this.spaces.length = width;
        enableStomping(this.spaces);

        if ( width > 0 )
        {
            this.spaces[0 .. $] = ' ';
        }

        return this.spaces;
    }


    /***************************************************************************

        Class that declares a specific argument instance.
        One of these is instantiated using one of the outer class' `get()`
        methods. All existing argument instances can be iterated over using the
        outer class' `opApply()` method.

    ***************************************************************************/

    private class Argument
    {
        /***********************************************************************

            Enumeration of all error identifiers

        ***********************************************************************/

        public enum
        {
            None,     // ok (no error)

            ParamLo,  // too few parameters were assigned to this argument

            ParamHi,  // too many parameters were assigned to this argument

            Required, // this is a required argument, but was not given

            Requires, // this argument depends on another argument which was not
                      // given

            Conflict, // this argument conflicts with another given argument

            Extra,    // unexpected argument (will not trigger an error if
                      // sloppy arguments are enabled)

            Option,   // parameter assigned is not one of the acceptable options

            Invalid   // invalid error
        }


        /***********************************************************************

            Convenience aliases

        ***********************************************************************/

        public alias void    delegate ( )               Invoker;
        public alias istring delegate ( istring value ) Inspector;


        /***********************************************************************

            Minimum number of parameters for this argument

        ***********************************************************************/

        public int min;


        /***********************************************************************

            Maximum number of parameters for this argument

        ***********************************************************************/

        public int max;


        /***********************************************************************

            The error code for this argument (0 => no error)

        ***********************************************************************/

        public int error;


        /***********************************************************************

            Flag to indicate whether this argument is present or not

        ***********************************************************************/

        public bool set;


        /***********************************************************************

            String in which each character is an alias for this argument

        ***********************************************************************/

        public istring aliases;


        /***********************************************************************

            The name of the argument

        ***********************************************************************/

        public istring name;


        /***********************************************************************

            The help text of the argument

        ***********************************************************************/

        public istring text;


        /***********************************************************************

            Allowed parameters for this argument (there is no restriction on the
            acceptable parameters if this array is empty)

        ***********************************************************************/

        public Const!(istring)[] options;


        /***********************************************************************

            Default parameters for this argument

        ***********************************************************************/

        public Const!(istring)[] deefalts;


        /***********************************************************************

            Flag to indicate whether this argument is required or not

        ***********************************************************************/

        private bool req;


        /***********************************************************************

            Flag to indicate whether this argument is smushable or not

        ***********************************************************************/

        private bool cat;


        /***********************************************************************

            Flag to indicate whether this argument can accept implicit
            parameters or not

        ***********************************************************************/

        private bool exp;


        /***********************************************************************

            Flag to indicate whether this argument has failed parsing or not

        ***********************************************************************/

        private bool fail;


        /***********************************************************************

            The name of the argument that conflicts with this argument

        ***********************************************************************/

        private istring bogus;


        /***********************************************************************

            Parameters assigned to this argument

        ***********************************************************************/

        private istring[] values;


        /***********************************************************************

            Invocation callback

        ***********************************************************************/

        private Invoker invoker;


        /***********************************************************************

            Inspection callback

        ***********************************************************************/

        private Inspector inspector;


        /***********************************************************************

            Argument instances that are required by this argument

        ***********************************************************************/

        private Argument[] dependees;


        /***********************************************************************

            Argument instances that this argument conflicts with

        ***********************************************************************/

        private Argument[] conflictees;


        /***********************************************************************

            Constructor.

            Params:
                name = name of the argument

        ***********************************************************************/

        public this ( istring name )
        {
            this.name = name;
        }


        /***********************************************************************

            Returns:
                the name of this argument

        ***********************************************************************/

        public override istring toString ( )
        {
            return name;
        }


        /***********************************************************************

            Returns:
                parameters assigned to this argument, or the default parameters
                if this argument was not present on the command-line

        ***********************************************************************/

        public Const!(istring)[] assigned ( )
        {
            return values.length ? values : deefalts;
        }


        /***********************************************************************

            Sets an alias for this argument.

            Params:
                name = character to be used as an alias for this argument

            Returns:
                this object for method chaining

        ***********************************************************************/

        public Argument aliased ( char name )
        {
            if ( auto arg = cast(cstring)((&name)[0..1]) in this.outer.aliases )
            {
                assert(
                    false,
                    "Argument '" ~ this.name ~ "' cannot " ~
                        "be assigned alias '" ~ name ~ "' as it has " ~
                        "already been assigned to argument '"
                        ~ arg.name ~ "'."
                );
            }

            this.outer.aliases[idup((&name)[0 .. 1])] = this;

            this.aliases ~= name;

            return this;
        }


        /***********************************************************************

            Makes this a mandatory argument.

            Returns:
                this object for method chaining

        ***********************************************************************/

        public Argument required ( )
        {
            this.req = true;

            return this;
        }


        /***********************************************************************

            Sets this argument to depend upon another argument.

            Params:
                arg = argument instance which is to be set as a dependency

            Returns:
                this object for method chaining

        ***********************************************************************/

        public Argument requires ( Argument arg )
        {
            dependees ~= arg;

            return this;
        }


        /***********************************************************************

            Sets this argument to depend upon another argument.

            Params:
                other = name of the argument which is to be set as a dependency

            Returns:
                this object for method chaining

        ***********************************************************************/

        public Argument requires ( istring other )
        {
            return requires(this.outer.get(other));
        }


        /***********************************************************************

            Sets this argument to depend upon another argument.

            Params:
                other = alias of the argument which is to be set as a dependency

            Returns:
                this object for method chaining

        ***********************************************************************/

        public Argument requires ( char other )
        {
            return requires(cast(istring)(&other)[0 .. 1]);
        }


        /***********************************************************************

            Sets this argument to conflict with another argument.

            Params:
                arg = argument instance with which this argument should conflict

            Returns:
                this object for method chaining

        ***********************************************************************/

        public Argument conflicts ( Argument arg )
        {
            conflictees ~= arg;

            return this;
        }


        /***********************************************************************

            Sets this argument to conflict with another argument.

            Params:
                other = name of the argument with which this argument should
                    conflict

            Returns:
                this object for method chaining

        ***********************************************************************/

        public Argument conflicts ( istring other )
        {
            return conflicts(this.outer.get(other));
        }


        /***********************************************************************

            Sets this argument to conflict with another argument.

            Params:
                other = alias of the argument with which this argument should
                    conflict

            Returns:
                this object for method chaining

        ***********************************************************************/

        public Argument conflicts ( char other )
        {
            return conflicts(cast(istring)(&other)[0 .. 1]);
        }


        /***********************************************************************

            Enables parameter assignment for this argument. The minimum and
            maximum number of parameters are set to 0 and 42 respectively.

            Returns:
                this object for method chaining

        ***********************************************************************/

        public Argument params ( )
        {
            return params(0, 42);
        }


        /***********************************************************************

            Enables parameter assignment for this argument and sets an exact
            count for the number of parameters required.

            Params:
                count = the number of parameters to be set

            Returns:
                this object for method chaining

        ***********************************************************************/

        public Argument params ( int count )
        {
            return params(count, count);
        }


        /***********************************************************************

            Enables parameter assignment for this argument and sets the counts
            of both the minimum and maximum parameters required.

            Params:
                min = minimum number of parameters required
                max = maximum number of parameters required

            Returns:
                this object for method chaining

        ***********************************************************************/

        public Argument params ( int min, int max )
        {
            this.min = min;

            this.max = max;

            return this;
        }


        /***********************************************************************

            Adds a default parameter for this argument.

            Params:
                values = default parameter to be added

            Returns:
                this object for method chaining

        ***********************************************************************/

        public Argument defaults ( istring values )
        {
            this.deefalts ~= values;

            return this;
        }


        /***********************************************************************

            Sets an inspector for this argument. The inspector delegate gets
            fired when a parameter is appended to this argument.
            The appended parameter gets sent to the delegate as the input
            parameter. If the appended parameter is ok, the delegate should
            return null. Otherwise, it should return a text string describing
            the issue. A non-null return value from the delegate will trigger an
            error.

            Params:
                inspector = delegate to be called when a parameter is appended
                    to this argument

            Returns:
                this object for method chaining

        ***********************************************************************/

        public Argument bind ( Inspector inspector )
        {
            this.inspector = inspector;

            return this;
        }


        /***********************************************************************

            Sets an invoker for this argument. The invoker delegate gets
            fired when this argument is found during parsing.

            Params:
                invoker = delegate to be called when this argument's declaration
                    is seen

            Returns:
                this object for method chaining

        ***********************************************************************/

        public Argument bind ( Invoker invoker )
        {
            this.invoker = invoker;

            return this;
        }


        /***********************************************************************

            Enables/disables smushing for this argument.

            Smushing refers to omitting the explicit assignment symbol ('=' by
            default) or whitespace (when relying on implicit assignment) that
            separates an argument from its parameter. Note that smushing is
            possible only when assigning parameters to an argument using the
            argument's short prefix version.

            Params:
                yes = true to enable smushing, false to disable

            Returns:
                this object for method chaining

        ***********************************************************************/

        public Argument smush ( bool yes = true )
        {
            cat = yes;

            return this;
        }


        /***********************************************************************

            Disables implicit parameter assignment to this argument.

            Returns:
                this object for method chaining

        ***********************************************************************/

        public Argument explicit ( )
        {
            exp = true;

            return this;
        }


        /***********************************************************************

            Changes the name of this argument (can be useful for naming the
            default argument).

            Params:
                name = new name of this argument

            Returns:
                this object for method chaining

        ***********************************************************************/

        public Argument title ( istring name )
        {
            this.name = name;

            return this;
        }


        /***********************************************************************

            Sets the help text for this argument.

            Params:
                text = the help text to set

            Returns:
                this object for method chaining

        ***********************************************************************/

        public Argument help ( istring text )
        {
            this.text = text;

            return this;
        }


        /***********************************************************************

            Fails the parsing immediately upon encountering this argument. This
            can be used for managing help text.

            Returns:
                this object for method chaining

        ***********************************************************************/

        public Argument halt ( )
        {
            this.fail = true;

            return this;
        }


        /***********************************************************************

            Restricts parameters of this argument to be in the given set.

            Params:
                options = array containing the set of acceptable parameters

            Returns:
                this object for method chaining

        ***********************************************************************/

        public Argument restrict ( Const!(istring)[] options ... )
        {
            this.options = options;

            return this;
        }


        /***********************************************************************

            Sets the flag that indicates that this argument was found during
            parsing. Also calls the invoker delegate, if configured. If the
            argument is unexpected (i.e. was not pre-configured), then an
            appropriate error condition gets set.

            Params:
                unexpected = true if this is an unexpected argument, false
                    otherwise

            Returns:
                this object for method chaining

        ***********************************************************************/

        private Argument enable ( bool unexpected = false )
        {
            this.set = true;

            if ( max > 0 )
            {
                this.outer.stack.push(this);
            }

            if ( invoker )
            {
                invoker();
            }

            if ( unexpected )
            {
                error = Extra;
            }

            return this;
        }


        /***********************************************************************

            Appends the given parameter to this argument. Also calls the
            inspector delegate, if configured.

            Params:
                value = parameter to be appended
                explicit = true if the parameter was explicitly assigned to this
                    argument, false otherwise (defaults to false)

        ***********************************************************************/

        private void append ( istring value, bool explicit = false )
        {
            // pop to an argument that can accept implicit parameters?
            if ( explicit is false )
            {
                auto s = &(this.outer.stack);

                while ( s.top.exp && s.size > 1 )
                {
                    s.pop;
                }
            }

            this.set = true; // needed for default assignments

            values ~= value; // append new value

            if ( error is None )
            {
                if ( inspector )
                {
                    if ( (bogus = inspector(value)).length )
                    {
                        error = Invalid;
                    }
                }

                if ( options.length )
                {
                    error = Option;

                    foreach ( option; options )
                    {
                        if ( option == value )
                        {
                            error = None;
                        }
                    }
                }
            }

            // pop to an argument that can accept parameters
            auto s = &(this.outer.stack);

            while ( s.top.values.length >= max && s.size > 1 )
            {
                s.pop;
            }
        }


        /***********************************************************************

            Tests whether an error condition occurred for this argument during
            parsing, and if so the appropriate error code is set.

            Returns:
                the error code for this argument (0 => no error)

        ***********************************************************************/

        private int valid ( )
        {
            if ( error is None )
            {
                if ( req && !set )
                {
                    error = Required;
                }
                else
                {
                    if ( set )
                    {
                        // short circuit?
                        if ( fail )
                        {
                            return -1;
                        }

                        if ( values.length < min )
                        {
                            error = ParamLo;
                        }
                        else
                        {
                            if ( values.length > max )
                            {
                                error = ParamHi;
                            }
                            else
                            {
                                foreach ( arg; dependees )
                                {
                                    if ( ! arg.set )
                                    {
                                        error = Requires;
                                        bogus = arg.name;
                                    }
                                }

                                foreach ( arg; conflictees )
                                {
                                    if ( arg.set )
                                    {
                                        error = Conflict;
                                        bogus = arg.name;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            return error;
        }
    }
}



/*******************************************************************************

    Unit tests

*******************************************************************************/

unittest
{
    auto args = new Arguments;

    // basic
    auto x = args['x'];
    assert(args.parse(""));
    x.required;
    assert(args.parse("") is false);
    assert(args.clear.parse("-x"));
    assert(x.set);

    // alias
    x.aliased('X');
    assert(args.clear.parse("-X"));
    assert(x.set);

    // unexpected arg (with sloppy)
    assert(args.clear.parse("-y") is false);
    assert(args.clear.parse("-y") is false);
    assert(args.clear.parse("-y", true) is false);
    assert(args['y'].set);
    assert(args.clear.parse("-x -y", true));

    // parameters
    x.params(0);
    assert(args.clear.parse("-x param"));
    assert(x.assigned.length is 0);
    assert(args(null).assigned.length is 1);
    x.params(1);
    assert(args.clear.parse("-x=param"));
    assert(x.assigned.length is 1);
    assert(x.assigned[0] == "param");
    assert(args.clear.parse("-x param"));
    assert(x.assigned.length is 1);
    assert(x.assigned[0] == "param");

    // too many args
    x.params(1);
    assert(args.clear.parse("-x param1 param2"));
    assert(x.assigned.length is 1);
    assert(x.assigned[0] == "param1");
    assert(args(null).assigned.length is 1);
    assert(args(null).assigned[0] == "param2");

    // now with default params
    assert(args.clear.parse("param1 param2 -x=blah"));
    assert(args[null].assigned.length is 2);
    assert(args(null).assigned.length is 2);
    assert(x.assigned.length is 1);
    x.params(0);
    assert(!args.clear.parse("-x=blah"));

    // args as parameter
    assert(args.clear.parse("- -x"));
    assert(args[null].assigned.length is 1);
    assert(args[null].assigned[0] == "-");

    // multiple flags, with alias and sloppy
    assert(args.clear.parse("-xy"));
    assert(args.clear.parse("-xyX"));
    assert(x.set);
    assert(args['y'].set);
    assert(args.clear.parse("-xyz") is false);
    assert(args.clear.parse("-xyz", true));
    auto z = args['z'];
    assert(z.set);

    // multiple flags with trailing arg
    assert(args.clear.parse("-xyz=10"));
    assert(z.assigned.length is 1);

    // again, but without sloppy param declaration
    z.params(0);
    assert(!args.clear.parse("-xyz=10"));
    assert(args.clear.parse("-xzy=10"));
    assert(args('y').assigned.length is 1);
    assert(args('x').assigned.length is 0);
    assert(args('z').assigned.length is 0);

    // x requires y
    x.requires('y');
    assert(args.clear.parse("-xy"));
    assert(args.clear.parse("-xz") is false);

    // defaults
    z.defaults("foo");
    assert(args.clear.parse("-xy"));
    assert(z.assigned.length is 1);

    // long names, with params
    assert(args.clear.parse("-xy --foobar") is false);
    assert(args.clear.parse("-xy --foobar", true));
    assert(args["y"].set && x.set);
    assert(args["foobar"].set);
    assert(args.clear.parse("-xy --foobar=10"));
    assert(args["foobar"].assigned.length is 1);
    assert(args["foobar"].assigned[0] == "10");

    // smush argument z, but not others
    z.params;
    assert(args.clear.parse("-xy -zsmush") is false);
    assert(x.set);
    z.smush;
    assert(args.clear.parse("-xy -zsmush"));
    assert(z.assigned.length is 1);
    assert(z.assigned[0] == "smush");
    assert(x.assigned.length is 0);
    z.params(0);

    // conflict x with z
    x.conflicts(z);
    assert(args.clear.parse("-xyz") is false);

    // word mode, with prefix elimination
    args = new Arguments(null, null, null, null, null, null);
    assert(args.clear.parse("foo bar wumpus") is false);
    assert(args.clear.parse("foo bar wumpus wombat", true));
    assert(args("foo").set);
    assert(args("bar").set);
    assert(args("wumpus").set);
    assert(args("wombat").set);

    // use '/' instead of '-'
    args = new Arguments(null, null, null, null, "/", "/");
    assert(args.clear.parse("/foo /bar /wumpus") is false);
    assert(args.clear.parse("/foo /bar /wumpus /wombat", true));
    assert(args("foo").set);
    assert(args("bar").set);
    assert(args("wumpus").set);
    assert(args("wombat").set);

    // use '/' for short and '-' for long
    args = new Arguments(null, null, null, null, "/", "-");
    assert(args.clear.parse("-foo -bar -wumpus -wombat /abc", true));
    assert(args("foo").set);
    assert(args("bar").set);
    assert(args("wumpus").set);
    assert(args("wombat").set);
    assert(args("a").set);
    assert(args("b").set);
    assert(args("c").set);

    // "--" makes all subsequent be implicit parameters
    args = new Arguments;
    args('f').params(0);
    assert(args.parse("-f -- -bar -wumpus -wombat --abc"));
    assert(args('f').assigned.length is 0);
    assert(args(null).assigned.length is 4);

    // Confirm arguments are stored in a sorted manner
    args = new Arguments;
    assert(args.clear.parse("--beta --alpha --delta --echo --charlie", true));
    size_t index;
    foreach (arg; args)
    {
        switch ( index++ )
        {
            case 0: continue;
            case 1: assert("alpha"   == arg.name); continue;
            case 2: assert("beta"    == arg.name); continue;
            case 3: assert("charlie" == arg.name); continue;
            case 4: assert("delta"   == arg.name); continue;
            case 5: assert("echo"    == arg.name); continue;
            default: assert(0);
        }
    }

    // Test that getInt() works as expected
    args = new Arguments;
    args("num").params(1);
    assert(args.parse("--num 100"));
    assert(args.getInt!(uint)("num") == 100);
}

// Test for D2 'static immutable'
unittest
{
    const istring name_ = "encode";
    const istring conflicts_ = "decode";
    const istring[] restrict_ = [ "json", "yaml" ];
    const istring requires_ = "input";
    const istring help_ = "Convert from native format to JSON/Yaml";

    auto args = new Arguments;
    args(name_)
        .params(1)
        .conflicts(conflicts_)
        .restrict(restrict_)
        .requires(requires_)
        .help(help_);

}
