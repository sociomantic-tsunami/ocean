/*******************************************************************************

    CLI args support for overriding config values.

    Copyright:
        Copyright (c) 2018 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.application.components.ConfigOverrides;

import ocean.transition;
import ocean.core.Verify;
import ocean.text.Arguments;
import ocean.text.Util : join, locate, locatePrior, trim;
import ocean.util.config.ConfigParser;

/*******************************************************************************

    Setup args for overriding config options

    Params:
        args = parsed command line arguments

*******************************************************************************/

public void setupArgs ( Arguments args )
{
    args("override-config").aliased('O').params(1,int.max).smush()
        .help("override a configuration value "
            ~ "(example: -O 'category.key = value', need a space between "
            ~ "-O and the option now because of a Tango bug)");
}

/*******************************************************************************

    Do a simple validation over override-config arguments

    Params:
        args = parsed command line arguments

    Returns:
        error text if any

*******************************************************************************/

public cstring validateArgs ( Arguments args )
{
    istring[] errors;
    foreach (opt; args("override-config").assigned)
    {
        istring cat, key, val;

        auto error = parseArg(opt, cat, key, val);

        if (!error.length)
            continue;

        errors ~= error;
    }

    auto ret = join(errors, ", ");
    return assumeUnique(ret);
}

/*******************************************************************************

    Process overridden config options

    Params:
        args = parsed command line arguments

*******************************************************************************/

public void handleArgs ( Arguments args, ConfigParser config )
{
    istring category, key, value;

    foreach (opt; args("override-config").assigned)
    {
        auto error = parseArg(opt, category, key, value);
        verify (error is null,
                "Unexpected error while processing overrides, errors " ~
                "should have been caught by the validateArgs() method");

        if ( !value.length )
        {
            config.remove(category, key);
        }
        else
        {
            config.set(category, key, value);
        }
    }
}

/*******************************************************************************

    Parses an overridden config.

    Category, key and value are filled with slices to the original opt
    string, so if you need to store them you probably want to dup() them.
    No allocations are performed for those variables, although some
    allocations are performed in case of errors (but only on errors).

    Since keys can't have a dot ("."), cate.gory.key=value will be
    interpreted as category="cate.gory", key="key" and value="value".

    Params:
        opt = the overridden config as specified on the command-line
        category = buffer to be filled with the parsed category
        key = buffer to be filled with the parsed key
        value = buffer to be filled with the parsed value

    Returns:
        null if parsing was successful, an error message if there was an
        error.

*******************************************************************************/

private istring parseArg ( istring opt, out istring category,
    out istring key, out istring value )
{
    opt = trim(opt);

    if (opt.length == 0)
        return "Option can't be empty";

    auto key_end = locate(opt, '=');
    if (key_end == opt.length)
        return "No value separator ('=') found for config option " ~
                "override: " ~ opt;

    value = trim(opt[key_end + 1 .. $]);

    auto cat_key = opt[0 .. key_end];
    auto category_end = locatePrior(cat_key, '.');
    if (category_end == cat_key.length)
        return "No category separator ('.') found before the value " ~
                "separator ('=') for config option override: " ~ opt;

    category = trim(cat_key[0 .. category_end]);
    if (category.length == 0)
        return "Empty category for config option override: " ~ opt;

    key = trim(cat_key[category_end + 1 .. $]);
    if (key.length == 0)
        return "Empty key for config option override: " ~ opt;

    return null;
}

version (UnitTest)
{
    import ocean.core.Test : NamedTest;
    import ocean.core.Array : startsWith;
}

unittest
{
    // Errors are compared only with startsWith(), not the whole error
    void testParser ( istring opt, istring exp_cat, istring exp_key,
        istring exp_val, istring expected_error = null )
    {
        istring cat, key, val;

        auto t = new NamedTest(opt);

        auto error = parseArg(opt, cat, key, val);

        if (expected_error is null)
        {
            t.test(error is null, "Error message mismatch, expected no " ~
                                  "error, got '" ~ error ~ "'");
        }
        else
        {
            t.test(error.startsWith(expected_error), "Error message " ~
                    "mismatch, expected an error starting with '" ~
                    expected_error ~ "', got '" ~ error ~ "'");
        }

        if (exp_cat is null && exp_key is null && exp_val is null)
            return;

        t.test!("==")(cat, exp_cat);
        t.test!("==")(key, exp_key);
        t.test!("==")(val, exp_val);
    }

    // Shortcut to test expected errors
    void testParserError ( istring opt, istring expected_error )
    {
        testParser(opt, null, null, null, expected_error);
    }

    // New format
    testParser("cat.key=value", "cat", "key", "value");
    testParser("cat.key = value", "cat", "key", "value");
    testParser("cat.key= value", "cat", "key", "value");
    testParser("cat.key =value", "cat", "key", "value");
    testParser("cat.key = value  ", "cat", "key", "value");
    testParser("  cat.key = value  ", "cat", "key", "value");
    testParser("  cat . key = value \t ", "cat", "key", "value");
    testParser("  empty . val = \t ", "empty", "val", "");

    // New format errors
    testParserError("cat.key value", "No value separator ");
    testParserError("key = value", "No category separator ");
    testParserError("cat key value", "No value separator ");
    testParserError(" . empty = cat\t ", "Empty category ");
    testParserError("  empty .  = key\t ", "Empty key ");
    testParserError("  empty . val = \t ", null);
    testParserError("  .   = \t ", "Empty ");
}
