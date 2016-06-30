/*******************************************************************************

    D Library Wrapper for PCRE regular expression engine.

    Requires linking with libpcre (-lpcre).

    Usage example:

    ---

        import ocean.text.regex.PCRE;

        auto pcre = new PCRE;

        // Simple, one-off use
        auto match = pcre.preg_match("Hello World!", "^Hello");

        // Compile then reuse
        auto regex = pcre.new CompiledRegex;
        regex.compile("^Hello");
        for ( int i; i < 100; i++ )
        {
            auto match = regex.match("Hello World!");
        }

    ---


    Related:
        http://regexkit.sourceforge.net/Documentation/pcre/pcreapi.html

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

        Bear in mind this module provides bindings to an external library that
        has its own license, which might be more restrictive. Please check the
        external library license to see which conditions apply for linking.

*******************************************************************************/

module ocean.text.regex.PCRE;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.core.Array : copy, concat;
import ocean.text.util.StringC;
import ocean.text.regex.c.pcre;
import ocean.core.TypeConvert;

import ocean.stdc.stdlib : free;
import ocean.text.convert.Format;



/*******************************************************************************

    PCRE

*******************************************************************************/

public class PCRE
{
    /***************************************************************************

        Represents a PCRE Exception.
        The class is re-usable exception where the error message can be
        reset and the same instance can be re-thrown.

    ***************************************************************************/

    public static class PcreException : Exception
    {
        /***********************************************************************

            Error code returned by pcre function

        ***********************************************************************/

        public int error;

        /***********************************************************************

            Constructor.
            Just calls the super Exception constructor with initial error
            message.

        ***********************************************************************/

        public this()
        {
            super("Error message not yet set");
        }

        /***********************************************************************

            Sets the error code and message.

            Params:
                code = error code to set
                msg = the new exception message to be used

        ***********************************************************************/

        private void set ( int code, istring msg )
        {
            this.error = code;
            this.msg = msg;
        }
    }

    /***************************************************************************

        Limits the complexity of regex searches. If a regex search passes the
        specified complexity limit without either finding a match or determining
        that no match exists, it bails out, throwing an exception (see
        CompiledRegex.match()).

        The default value of 0 uses libpcre's built-in default complexity
        limit (10 million, see below), which is set to be extremely permissive.
        Any value less than 10 million will have the effect of reducing the
        level of complexity tolerated, thus reducing the potential processing
        time spent searching.

        This field maps directly to the match_limit field in libpcre's
        pcre_extra struct.

        From http://regexkit.sourceforge.net/Documentation/pcre/pcreapi.html:

        The match_limit field provides a means of preventing PCRE from using up
        a vast amount of resources when running patterns that are not going to
        match, but which have a very large number of possibilities in their
        search trees. The classic example is the use of nested unlimited
        repeats.

        Internally, PCRE uses a function called match() which it calls
        repeatedly (sometimes recursively). The limit set by match_limit is
        imposed on the number of times this function is called during a match,
        which has the effect of limiting the amount of backtracking that can
        take place. For patterns that are not anchored, the count restarts from
        zero for each position in the subject string.

        The default value for the limit can be set when PCRE is built; the
        default default is 10 million, which handles all but the most extreme
        cases.

    ***************************************************************************/

    public const int DEFAULT_COMPLEXITY_LIMIT = 0;

    public int complexity_limit = DEFAULT_COMPLEXITY_LIMIT;

    /***************************************************************************

        String used internally for formatting.

    ***************************************************************************/

    private mstring buffer_char;

    /***************************************************************************

        A re-usable exception instance

    ***************************************************************************/

    private PcreException exception;

    /***************************************************************************

        Compiled regex class. Enables a regex pattern to be compiled once and
        used for multiple searches.

    ***************************************************************************/

    public class CompiledRegex
    {
        /***********************************************************************

            Pointer to C-allocated pcre regex object, created upon compilation
            of a regex (see compile()).

        ***********************************************************************/

        private pcre* pcre_object;

        /***********************************************************************

            Settings used by the call to pcre_exec() in the match() method.
            These are modified by the complexity_limit field of the outer class,
            and by the study() method.

        ***********************************************************************/

        private pcre_extra match_settings;

        /***********************************************************************

            Destructor. Frees the C-allocated pcre object.

        ***********************************************************************/

        ~this ( )
        {
            this.cleanup();
        }

        /***********************************************************************

            Compiles the specified regex for use in the match() method. Cleans
            up a previously compiled regex, if this instance has been used
            before.

            Params:
                pattern = pattern to search for, as a string
                case_sens = case sensitive matching

            Throws:
                if the compilation of the regex fails

            Out:
                following a call to this method, the compiled regex exists

        ***********************************************************************/

        public void compile ( cstring pattern, bool case_sens = true )
        out
        {
            assert(this.pcre_object);
        }
        body
        {
            this.cleanup();

            char* errmsg;
            int error_code;
            int error_offset;

            this.outer.buffer_char.concat(pattern, "\0"[]);
            this.pcre_object = pcre_compile2(this.outer.buffer_char.ptr,
                    (case_sens ? 0 : PCRE_CASELESS), &error_code, &errmsg,
                    &error_offset, null);
            if ( !this.pcre_object )
            {
                this.outer.exception.msg.length = 0;
                this.outer.exception.msg = Format(
                    "Error compiling regular expression: {} - on pattern: {} at position {}",
                    StringC.toDString(errmsg), pattern, error_offset
                );
                this.outer.exception.error = error_code;
                throw this.outer.exception;
            }
        }

        /***********************************************************************

            Perform a regular expression match.

            Params:
                subject = the compiled patter will be matched against this string

            Returns:
                true, if matches or false if no match

            Throws:
                if an error occurs when running the regex search

            In:
                the regex must have been compiled

        ***********************************************************************/

        public bool match ( cstring subject )
        {
            //"" matches against the pattern ""
            if ( this.outer.buffer_char == "\0" && subject == "" )
            {
                return true;
            }

            return this.findFirst(subject) != null;
        }

        /***********************************************************************

            Performs a regular expression match and return the first found match

            Params:
                subject  = input string

            Returns:
                slice to the first found match or null if no match

            Throws:
                if an error occurs when running the regex search

            In:
                the regex must have been compiled

        ***********************************************************************/

        public cstring findFirst ( cstring subject )
        in
        {
            assert(this.pcre_object);
        }
        body
        {
            // This method supports only one capture so size 3 is enough.
            // 2/3 for the positions and 1/3 for a internal buffer
            int[3] ovector;

            if ( this.outer.complexity_limit != DEFAULT_COMPLEXITY_LIMIT )
            {
                this.match_settings.flags |= PCRE_EXTRA_MATCH_LIMIT;
                this.match_settings.match_limit = this.outer.complexity_limit;
            }

            int error_code = pcre_exec(this.pcre_object, &this.match_settings,
                subject.ptr, castFrom!(size_t).to!(int)(subject.length), 0, 0,
                ovector.ptr, ovector.length);

            // A positive return value indicates that a single match was found
            // and its indices stored in ovector[0] and ovector[1].
            // A zero return value indicates that multiple matches were found,
            // the first stored in ovector[0] and ovector[1], and the rest
            // discarded.
            if ( error_code >= 0 )
            {
                // we got a match but ovector is 0 so the whole subject matched
                if ( ovector[0] == 0 && ovector[1] == 0 )
                {
                    return subject;
                }

                return subject[ovector[0] .. ovector[1]];
            }
            // Negative return values indicate failure or error. We ignore
            // match failures and throw on error.
            else if ( error_code != PCRE_ERROR_NOMATCH )
            {
                this.outer.exception.set(error_code,
                    "Error on executing regular expression!");
                throw this.outer.exception;
            }

            return null;
        }

        /***********************************************************************

            Performs a regular expression match and returns an array of slices
            of all matches

            Params:
                subject  = input string
                matches_buffer = found matches will be stored here

            Returns:
                Array with slices of all matches

            Throws:
                if an error occurs when running the regex search

            In:
                the regex must have been compiled

        ***********************************************************************/

        public cstring[] findAll ( cstring subject, ref cstring[] matches_buffer )
        in
        {
            assert(this.pcre_object);
        }
        body
        {
            ptrdiff_t pos;

            while ( pos < subject.length )
            {
                if ( auto match = this.findFirst(subject[pos .. $]) )
                {
                    matches_buffer ~= match;
                    //set pos to end of the match
                    pos = match.ptr - subject.ptr + match.length;
                }
                else
                {
                    break;
                }
            }

            return matches_buffer;
        }

        /***********************************************************************

            Study a compiled regex in order to increase processing efficiency
            when calling match(). This is usually only worth doing for a regex
            which will be used many times, and does not always yield an
            improvement in efficiency.

            Throws:
                if an error occurs when studying the regex

            In:
                the regex must have been compiled

        ***********************************************************************/

        public void study ( )
        in
        {
            assert(this.pcre_object);
        }
        body
        {
            char* errmsg;
            auto res = pcre_study(this.pcre_object, 0, &errmsg);
            if ( errmsg )
            {
                auto derrmsg = StringC.toDString(errmsg);
                this.outer.exception.set(0, assumeUnique(derrmsg));
                throw this.outer.exception;
            }
            if ( res )
            {
                this.match_settings.study_data = res.study_data;
            }
        }

        /***********************************************************************

            Cleans up the compiled regex object and the study data.

        ***********************************************************************/

        private void cleanup ( )
        {
            free(this.pcre_object);
            this.match_settings = this.match_settings.init;
        }
    }

    /***************************************************************************

        Constructor. Initializes the re-usable exception.

    ***************************************************************************/

    public this ( )
    {
        this.exception = new PcreException();
    }

    /***************************************************************************

        Perform a regular expression match. Note that this method internally
        allocates and then frees a C pcre object each time it is called. If you
        want to run the same regex search multiple times on different input, you
        are probably better off using the compile() method, above.

        Usage:
            auto regex = new PCRE;
            bool match = regex.preg_match("Hello World!", "^Hello");

        Params:
            subject = the compiled patter will be matched against this string
            pattern = pattern to search for, as a string
            case_sens = case sensitive matching

        Returns:
            true, if matches or false if no match

        Throws:
            if the compilation or running of the regex fails

    ***************************************************************************/

    public bool preg_match ( cstring subject, cstring pattern, bool case_sens = true )
    {
        scope regex = new CompiledRegex;
        regex.compile(pattern, case_sens);
        return regex.match(subject);
    }
}

version ( UnitTest )
{
    import ocean.core.Test;

    class CounterNamedTest : NamedTest
    {
        static uint test_num;

        this ( )
        {
            super(Format("PCRE test #{}", ++test_num));
        }
    }
}


/*******************************************************************************

    Test for invalid pattern

*******************************************************************************/

unittest
{
    auto pcre = new PCRE;
    testThrown!(PCRE.PcreException)(pcre.preg_match("", "("));
}

/*******************************************************************************

    Tests for simple boolean matching via the preg_match() method. (This
    unittest tests only the interface of this method. It does not test the full
    range of PCRE features as that is beyond its scope.)

*******************************************************************************/

unittest
{
    void test ( bool delegate ( ) dg, bool match )
    {
        auto t = new CounterNamedTest;
        t.test!("==")(match, dg());
    }

    auto pcre = new PCRE;

    // Empty pattern (matches any string)
    test({ return pcre.preg_match("Hello World", ""); }, true);

    // Empty string and empty pattern (match)
    test({ return pcre.preg_match("", ""); }, true);

    // Empty string (no match)
    test({ return pcre.preg_match("", "a"); }, false);

    // Simple string match
    test({ return pcre.preg_match("Hello World", "Hello"); }, true);

    // Simple string match (fail)
    test({ return pcre.preg_match("Hello World", "Hallo"); }, false);

    // Case-sensitive match (fail)
    test({ return pcre.preg_match("Hello World", "hello"); }, false);

    // Case-insensitive match
    test({ return pcre.preg_match("Hello World", "hello", false); }, true);
}

/*******************************************************************************

    Tests for single substring matching via the CompiledRegex.findFirst()
    method.

*******************************************************************************/

unittest
{
    auto pcre = new PCRE;
    auto regex = pcre.new CompiledRegex;

    void testFind ( cstring needle, cstring pre, cstring match, cstring post )
    {
        regex.compile(needle);

        auto haystack = pre ~ match ~ post;
        auto res = regex.findFirst(haystack);

        auto t = new CounterNamedTest;
        t.test!("==")(res, haystack[pre.length .. pre.length + match.length]);
    }

    // Simple match
    testFind(
        "a",
        "bbb",
        "a",
        "ccc"
    );

    // Match with a more complicated regex
    testFind(
       "(firstparam=[^l]*liza.*(secondparam=mary|secondparam=lena|secondparam=john))|((secondparam=mary|secondparam=lena|secondparam=john).*firstparam=liza)",
        "http://example.org?",
        "firstparam=elizabeth&rand=84527497861&secondparam=mary",
        "&some=other&params=are&here=%20%21%22%12222"
    );

    // Single match returned when multiple matches are possible
    testFind(
        "a",
        "bbb",
        "a",
        "cacac"
    );
}

/*******************************************************************************

    Tests for multiple substring matching via the CompiledRegex.findAll()
    method.

*******************************************************************************/

unittest
{
    auto pcre = new PCRE;
    auto regex = pcre.new CompiledRegex;
    cstring[] matches_buffer;

    auto t = new NamedTest("PCRE findAll");

    {
        istring str = "apa bepa cepa depa epa fepa gepa hepa";
        regex.compile("a[ ]", false);

        matches_buffer.length = 0;
        enableStomping(matches_buffer);

        foreach ( match; regex.findAll(str, matches_buffer) )
        {
            t.test!("==")(match, "a "[]);
        }

        t.test!("==")(matches_buffer.length, 7);
    }

    {
        istring[3] exp = ["ast", "at", "ast"];
        istring str = "en hast at en annan hast";
        regex.compile("a[s]*t", false);

        matches_buffer = null;


        foreach (i, match; regex.findAll(str, matches_buffer) )
        {
            t.test!("==")(match, exp[i]);
        }
        t.test!("==")(matches_buffer.length, 3);
    }

    {
        istring[3] exp = ["ta", "tb", "td"];
        istring str = "tatb t c Tf td";
        regex.compile("t[\\w]", true);
        regex.study();

        matches_buffer = null;

        foreach (i, match; regex.findAll(str, matches_buffer) )
        {
            t.test!("==")(match, exp[i]);
        }

        t.test!("==")(matches_buffer.length, 3);
    }

    {
        istring str = "en text";
        regex.compile("zzz", false);
        matches_buffer = null;
        auto matches = regex.findAll(str, matches_buffer);

        t.test!("==")(matches_buffer.length, 0);
    }

    {
        istring str = "en text";
        regex.compile("zzz", false);
        matches_buffer = null;
        auto matches = regex.findAll(str, matches_buffer);

        t.test!("==")(matches_buffer.length, 0);
    }

    {
        istring str ="aaaaaaaaaaaaaaaaaaaaaaAaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                   "aaaaaaaaaaaaaaaaaaaaaaaaAaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                   "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaAaaaaaaaaaaaaaaaaaaaaaaaaa"
                   "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaAaaaaaaaaaaaaaaaaaaaaaaaa"
                   "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaAaaaaaaaaaaaaaaaaaa"
                   "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaAaaaaaaaaaaaaaaaaaaa"
                   "aaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbAbbbbbbbbbbbb"
                   "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbAbbbbbbb"
                   "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbaaaaaaaaaaaaaaaaaAaaaaa"
                   "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaAaaaaa"
                   "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaAaa"
                   "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                   "aaaaaAaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                   "aacaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                   "aaaacaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

        regex.compile("a", true);
        matches_buffer.length = 0;

        foreach (i, match; regex.findAll(str, matches_buffer) )
        {
            t.test!("==")(match, "a"[]);
        }

        t.test!("==")(matches_buffer.length, 695);
    }
}

