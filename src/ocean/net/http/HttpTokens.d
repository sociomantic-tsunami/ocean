/*******************************************************************************

        Copyright:
            Copyright (c) 2004 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: April 2004

        Authors: Kris

*******************************************************************************/

module ocean.net.http.HttpTokens;

import ocean.transition;

import ocean.time.Time;

import ocean.io.device.Array;

import ocean.io.stream.Buffered;

import ocean.net.http.HttpStack,
       ocean.net.http.HttpConst;

import Text = ocean.text.Util;

import Integer = ocean.text.convert.Integer_tango;

import TimeStamp = ocean.text.convert.TimeStamp;

/******************************************************************************

        Struct used to expose freachable HttpToken instances.

******************************************************************************/

struct HttpToken
{
        cstring  name,
                 value;
}

/******************************************************************************

        Maintains a set of HTTP tokens. These tokens include headers, query-
        parameters, and anything else vaguely related. Both input and output
        are supported, though a subclass may choose to expose as read-only.

        All tokens are mapped directly onto a buffer, so there is no memory
        allocation or copying involved.

        Note that this class does not support deleting tokens, per se. Instead
        it marks tokens as being 'unused' by setting content to null, avoiding
        unwarranted reshaping of the token stack. The token stack is reused as
        time goes on, so there's only minor runtime overhead.

******************************************************************************/

class HttpTokens
{
        protected HttpStack     stack;
        private Array           input;
        private Array           output;
        private bool            parsed;
        private bool            inclusive;
        private char            separator;
        private char[1]         sepString;

        /**********************************************************************

                Construct a set of tokens based upon the given delimiter,
                and an indication of whether said delimiter should be
                considered part of the left side (effectively the name).

                The latter is useful with headers, since the seperating
                ':' character should really be considered part of the
                name for purposes of subsequent token matching.

        **********************************************************************/

        this (char separator, bool inclusive = false)
        {
                stack = new HttpStack;

                this.inclusive = inclusive;
                this.separator = separator;

                // convert separator into a string, for later use
                sepString[0] = separator;

                // pre-construct an empty buffer for wrapping char[] parsing
                input = new Array (0);

                // construct an array for containing stack tokens
                output = new Array (4096, 1024);
        }

        /**********************************************************************

                Clone a source set of HttpTokens

        **********************************************************************/

        this (HttpTokens source)
        {
                stack = source.stack.clone;
                input = null;
                output = source.output;
                parsed = true;
                inclusive = source.inclusive;
                separator = source.separator;
                sepString[0] = source.sepString[0];
        }

        /**********************************************************************

                Read all tokens. Everything is mapped rather than being
                allocated & copied

        **********************************************************************/

        abstract void parse (InputBuffer input);

        /**********************************************************************

                Parse an input string.

        **********************************************************************/

        void parse (char[] content)
        {
                input.assign (content);
                parse (input);
        }

        /**********************************************************************

                Reset this set of tokens.

        **********************************************************************/

        HttpTokens reset ()
        {
                stack.reset;
                parsed = false;

                // reset output buffer
                output.clear;
                return this;
        }

        /**********************************************************************

                Have tokens been parsed yet?

        **********************************************************************/

        bool isParsed ()
        {
                return parsed;
        }

        /**********************************************************************

                Indicate whether tokens have been parsed or not.

        **********************************************************************/

        void setParsed (bool parsed)
        {
                this.parsed = parsed;
        }

        /**********************************************************************

                Return the value of the provided header, or null if the
                header does not exist

        **********************************************************************/

        cstring get (cstring name, cstring ret = null)
        {
                Token token = stack.findToken (name);
                if (token)
                   {
                   HttpToken element;

                   if (split (token, element))
                       ret = trim (element.value);
                   }
                return ret;
        }

        /**********************************************************************

                Return the integer value of the provided header, or the
                provided default-vaule if the header does not exist

        **********************************************************************/

        int getInt (cstring name, int ret = -1)
        {
                auto value = get (name);

                if (value.length)
                    ret = cast(int) Integer.parse (value);

                return ret;
        }

        /**********************************************************************

                Return the date value of the provided header, or the
                provided default-value if the header does not exist

        **********************************************************************/

        Time getDate (cstring name, Time date = Time.epoch)
        {
                auto value = get (name);

                if (value.length)
                    date = TimeStamp.parse (value);

                return date;
        }

        /**********************************************************************

                Iterate over the set of tokens

        **********************************************************************/

        int opApply (int delegate(ref HttpToken) dg)
        {
                HttpToken element;
                int       result = 0;

                foreach (Token t; stack)
                         if (split (t, element))
                            {
                            result = dg (element);
                            if (result)
                                break;
                            }
                return result;
        }

        /**********************************************************************

                Output the token list to the provided consumer

        **********************************************************************/

        void produce (size_t delegate(Const!(void)[]) consume, cstring eol = null)
        {
                foreach (Token token; stack)
                        {
                        auto content = token.toString;
                        if (content.length)
                           {
                           consume (content);
                           if (eol.length)
                               consume (eol);
                           }
                        }
        }

        /**********************************************************************

                overridable method to handle the case where a token does
                not have a separator. Apparently, this can happen in HTTP
                usage

        **********************************************************************/

        protected bool handleMissingSeparator (cstring s, ref HttpToken element)
        {
                return false;
        }

        /**********************************************************************

                split basic token into an HttpToken

        **********************************************************************/

        final private bool split (Token t, ref HttpToken element)
        {
                auto s = t.get();

                if (s.length)
                   {
                   auto i = Text.locate (s, separator);

                   // we should always find the separator
                   if (i < s.length)
                      {
                      auto j = (inclusive) ? i+1 : i;
                      element.name = s[0 .. j];
                      element.value = (++i < s.length) ? s[i .. $] : null;
                      return true;
                      }
                   else
                      // allow override to specialize this case
                      return handleMissingSeparator (s, element);
                   }
                return false;
        }

        /**********************************************************************

                Create a filter for iterating over the tokens matching
                a particular name.

        **********************************************************************/

        FilteredTokens createFilter (char[] match)
        {
                return new FilteredTokens (this, match);
        }

        /**********************************************************************

                Implements a filter for iterating over tokens matching
                a particular name. We do it like this because there's no
                means of passing additional information to an opApply()
                method.

        **********************************************************************/

        protected static class FilteredTokens
        {
                private cstring         match;
                private HttpTokens      tokens;

                /**************************************************************

                        Construct this filter upon the given tokens, and
                        set the pattern to match against.

                **************************************************************/

                this (HttpTokens tokens, cstring match)
                {
                        this.match = match;
                        this.tokens = tokens;
                }

                /**************************************************************

                        Iterate over all tokens matching the given name

                **************************************************************/

                int opApply (int delegate(ref HttpToken) dg)
                {
                        HttpToken       element;
                        int             result = 0;

                        foreach (Token token; tokens.stack)
                                 if (tokens.stack.isMatch (token, match))
                                     if (tokens.split (token, element))
                                        {
                                        result = dg (element);
                                        if (result)
                                            break;
                                        }
                        return result;
                }

        }

        /**********************************************************************

                Is the argument a whitespace character?

        **********************************************************************/

        private bool isSpace (char c)
        {
                return cast(bool) (c is ' ' || c is '\t' || c is '\r' || c is '\n');
        }

        /**********************************************************************

                Trim the provided string by stripping whitespace from
                both ends. Returns a slice of the original content.

        **********************************************************************/

        private cstring trim (cstring source)
        {
                int  front,
                     back = cast(int) source.length;

                if (back)
                   {
                   while (front < back && isSpace(source[front]))
                          ++front;

                   while (back > front && isSpace(source[back-1]))
                          --back;
                   }
                return source [front .. back];
        }


        /**********************************************************************
        ****************** these should be exposed carefully ******************
        **********************************************************************/


        /**********************************************************************

                Return a char[] representing the output. An empty array
                is returned if output was not configured. This perhaps
                could just return our 'output' buffer content, but that
                would not reflect deletes, or seperators. Better to do
                it like this instead, for a small cost.

        **********************************************************************/

        char[] formatTokens (OutputBuffer dst, cstring delim)
        {
                bool first = true;

                foreach (Token token; stack)
                        {
                        cstring content = token.get();
                        if (content.length)
                           {
                           if (first)
                               first = false;
                           else
                              dst.write (delim);
                           dst.write (content);
                           }
                        }
                return cast(mstring) dst.slice;
        }

        /**********************************************************************

                Add a token with the given name. The content is provided
                via the specified delegate. We stuff this name & content
                into the output buffer, and map a new Token onto the
                appropriate buffer slice.

        **********************************************************************/

        protected void add (cstring name, void delegate(OutputBuffer) value)
        {
                // save the buffer write-position
                //int prior = output.limit;
                auto prior = output.slice.length;

                // add the name
                output.append (name);

                // don't append separator if it's already part of the name
                if (! inclusive)
                      output.append (sepString);

                // add the value
                value (output);

                // map new token onto buffer slice
                stack.push (cast(char[]) output.slice [prior .. $]);
        }

        /**********************************************************************

                Add a simple name/value pair to the output

        **********************************************************************/

        protected void add (cstring name, cstring value)
        {
                void addValue (OutputBuffer buffer)
                {
                        buffer.write (value);
                }

                add (name, &addValue);
        }

        /**********************************************************************

                Add a name/integer pair to the output

        **********************************************************************/

        protected void addInt (cstring name, int value)
        {
                char[16] tmp = void;

                add (name, Integer.format (tmp, cast(long) value));
        }

        /**********************************************************************

               Add a name/date(long) pair to the output

        **********************************************************************/

        protected void addDate (cstring name, Time value)
        {
                char[40] tmp = void;

                add (name, TimeStamp.format (tmp, value));
        }

        /**********************************************************************

               remove a token from our list. Returns false if the named
               token is not found.

        **********************************************************************/

        protected bool remove (cstring name)
        {
                return stack.removeToken (name);
        }
}
