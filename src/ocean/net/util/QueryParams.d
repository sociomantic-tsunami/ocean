/******************************************************************************

    URI query parameter parser

    - QueryParams splits an URI query parameter list into key/value pairs.
    - QueryParamSet parses an URI query parameter list and memorizes the values
      corresponding to keys in a list provided at instantiation.

    TODO: The QueryParams class may be moved to ocean.text.

    Copyright:
        Copyright (c) 2009-2016 dunnhumby Germany GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.net.util.QueryParams;


import ocean.transition;

import ocean.core.Verify;

import ocean.net.util.ParamSet;

import ocean.text.util.SplitIterator: ChrSplitIterator;

import ocean.util.container.AppendBuffer: AppendBuffer, IAppendBufferReader;

version(UnitTest) import ocean.core.Test;

/******************************************************************************

    The QueryParams class is memory-friendly and therefore suitable for stack
    allocated 'scope' instances.

 ******************************************************************************/

class QueryParams
{
    /**************************************************************************

        Delimiter of elements, where each element is a key/value pair, and
        between key and value of an element.

        Treatment of special cases:

        - If an element does not contain a keyval_delim character, it is treated
          as a key without a value; a null value is then reported.
        - If an element contains more than one keyval_delim character, the first
          occurrence is used as delimiter so that the value contains
          keyval_delim characters but not the key.
        - If the last character of an element is a keyval_delim character and
          this is the only occurrence, the value is a non-null empty string.

        Must be specified in the constructor but may be modified at any time.

        Note that changing the delimiters during an iteration becomes effective
        when the next iteration is started.

     **************************************************************************/

    public char element_delim, keyval_delim;

    /**************************************************************************

        Option to trim whitespace from keys and values, enabled by default.

        Note that changing this option during an iteration becomes effective
        when the next iteration is started.

     **************************************************************************/

    public bool trim_whitespace = true;

    /**************************************************************************

        Current query string to parse and iterate over

     **************************************************************************/

    private cstring query;

    /**************************************************************************

        Debug flag to prevent calling any method during a 'foreach' iteration.

     **************************************************************************/

    private bool iterating = false;

    invariant ( )
    {
        assert (!this.iterating, typeof (this).stringof ~
                                 " method called during 'foreach' iteration");
    }

    /**************************************************************************

        Constructor

        Params:
            element_delim = delimiter between elements
            keyval_delim  = delimiter between key and value of an element

     **************************************************************************/

    public this ( char element_delim, char keyval_delim )
    {
        this.element_delim = element_delim;
        this.keyval_delim = keyval_delim;
    }

    /**************************************************************************

        Sets the URI query string to parse

        Params:
            query = query string to parse

        Returns:
            this instance

     **************************************************************************/

    public typeof (this) set ( cstring query )
    {
        this.query = query;

        return this;
    }

    /**************************************************************************

        'foreach' iteration over the URI query parameter list items, each one
        split into a key/value pair. key and value slice the string passed to
        query() so DO NOT MODIFY THEM. (You may, however, modify their content;
        this will modify the string passed to query() in-place.)

        Note that during iteration, no public method may be called nor may a
        nested iteration be started.

     **************************************************************************/

    public int opApply ( scope int delegate ( ref cstring key, ref cstring value ) ext_dg )
    {
        this.iterating = true;

        scope (exit) this.iterating = false;

        scope trim_dg = (ref cstring key, ref cstring value)
        {
            auto tkey = ChrSplitIterator.trim(key),
                 tval = ChrSplitIterator.trim(value);
            return ext_dg(tkey, tval);
        };

        scope dg = this.trim_whitespace ? trim_dg : ext_dg;

        scope split_paramlist = new ChrSplitIterator(this.element_delim),
              split_param     = new ChrSplitIterator(this.keyval_delim);

        split_paramlist.collapse = true;

        split_param.include_remaining = false;

        split_paramlist.reset(this.query);

        return split_paramlist.opApply((ref cstring param)
        {
            cstring value = null;

            foreach (key; split_param.reset(param))
            {
                value = split_param.remaining;

                return dg(key, value);
            }

            verify(!split_param.n);

            return dg(param, value);
        });
    }
}

/******************************************************************************/

class QueryParamSet: ParamSet
{
    /**************************************************************************

        Delimiter of elements, where each element is a key/value pair, and
        between key and value of an element.

        Treatment of special cases:

        - If an element does not contain a keyval_delim character, it is treated
          as a key without a value; a null value is then reported.
        - If an element contains more than one keyval_delim character, the first
          occurrence is used as delimiter so that the value contains
          keyval_delim characters but not the key.
        - If the last character of an element is a keyval_delim character and
          this is the only occurrence, the value is a non-null empty string.

        Must be specified in the constructor but may be modified at any time.

     **************************************************************************/

    public char element_delim, keyval_delim;

    /**************************************************************************

        Constructor

        Params:
            element_delim = delimiter between elements
            keyval_delim  = delimiter between key and value of an element
            keys          = parameter keys of interest (case-insensitive)

     **************************************************************************/

    public this ( char element_delim, char keyval_delim, in istring[] keys ... )
    {
        this.addKeys(keys);

        this.rehash();

        this.element_delim = element_delim;
        this.keyval_delim   = keyval_delim;
    }

    /**************************************************************************

        Parses query and memorizes the values corresponding to the keys provided
        to the constructor. query will be sliced.

        Params:
            query = query string to parse

     **************************************************************************/

    public void parse ( cstring query )
    {
        this.reset();

        scope query_params = new QueryParams(this.element_delim, this.keyval_delim);

        foreach (key, val; query_params.set(query))
        {
            this.set(key, val);
        }
    }
}

unittest
{
    scope qp = new QueryParams(';', '=');

    test (qp.trim_whitespace);

    {
        uint i = 0;

        foreach (key, val; qp.set(" Die Katze = tritt ;\n\tdie= Treppe;krumm.= "))
        {
            switch (i++)
            {
                case 0:
                    test (key == "Die Katze");
                    test (val == "tritt");
                    break;
                case 1:
                    test (key == "die");
                    test (val == "Treppe");
                    break;
                case 2:
                    test (key == "krumm.");
                    test (!val.length);
                    break;
                default:
                    test(0);
            }
        }
    }

    {
        qp.trim_whitespace = false;

        uint i = 0;

        foreach (key, val; qp.set(" Die Katze = tritt ;\n\tdie= Treppe;krumm.= "))
        {
            switch (i++)
            {
                case 0:
                    test (key == " Die Katze ");
                    test (val == " tritt ");
                    break;
                case 1:
                    test (key == "\n\tdie");
                    test (val == " Treppe");
                    break;
                case 2:
                    test (key == "krumm.");
                    test (val == " ");
                    break;
                default:
                    test(0);
            }
        }
    }
}
