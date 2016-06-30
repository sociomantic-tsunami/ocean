/******************************************************************************

    URI query parameter parser

    - QueryParams splits an URI query parameter list into key/value pairs.
    - QueryParamSet parses an URI query parameter list and memorizes the values
      corresponding to keys in a list provided at instantiation.
    - FullQueryParamSet extends QueryParamSet by adding the key/value pairs
      whose keys are not in the list of keys provided at instantiation.

    TODO: The QueryParams class may be moved to ocean.text.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.net.util.QueryParams;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.transition;

import ocean.net.util.ParamSet;

import ocean.text.util.SplitIterator: ChrSplitIterator;

import ocean.util.container.AppendBuffer: AppendBuffer, IAppendBufferReader;

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

    public int opApply ( int delegate ( ref cstring key, ref cstring value ) ext_dg )
    {
        this.iterating = true;

        scope (exit) this.iterating = false;

        auto dg = this.trim_whitespace?
                    (ref cstring key, ref cstring value)
                    {
                        auto tkey = ChrSplitIterator.trim(key),
                             tval = ChrSplitIterator.trim(value);
                        return ext_dg(tkey, tval);
                    } :
                    ext_dg;

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

            assert (!split_param.n);

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
        super.addKeys(keys);

        super.rehash();

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
        super.reset();

        scope query_params = new QueryParams(this.element_delim, this.keyval_delim);

        foreach (key, val; query_params.set(query))
        {
            super.set(key, val);
        }
    }
}

/******************************************************************************/

class FullQueryParamSet: QueryParamSet
{
    /**************************************************************************

        List of key/value pairs passed to set() where the key is not one of the
        parameter keys passed on instantiation or added by a subclass.

        Note the keys in this list are case-sensitive and may contain multiple
        elements with the same key.

     **************************************************************************/

    public IAppendBufferReader!(Element) remaining_elements ( )
    {
        return this._remaining_elements;
    }

    private IAppendBufferReader!(Element) _remaining_elements;

    private AppendBuffer!(Element) remaining;

    /**************************************************************************

        Constructor

        Params:
            element_delim = delimiter between elements
            keyval_delim  = delimiter between key and value of an element
            keys          = parameter keys of interest (case-insensitive)

     **************************************************************************/

    public this ( char element_delim, char keyval_delim, istring[] keys ... )
    {
        super(element_delim, keyval_delim, keys);

        this._remaining_elements = this.remaining = new AppendBuffer!(Element);
    }

    /**************************************************************************

        Sets the parameter value for key if key is one of the parameter keys
        passed on instantiation or added by a subclass.
        If key is not of these parameter keys, the key/val pair is added to the
        list of remaining elements.

        Params:
            key = parameter key (case insensitive)
            val = parameter value (will be sliced)

        Returns:
            true if key is one of parameter keys passed on instantiation or
            added by a subclass or false otherwise. In case of false the key/val
            pair has been added to the list of remaining elements.

     **************************************************************************/

    public override bool set ( cstring key, cstring val )
    {
        if (super.set(key, val))
        {
            return true;
        }
        else
        {
            this.remaining ~= Element(key, val);

            return false;
        }
    }

    /**************************************************************************

        'foreach' iteration over parameter key/value pairs

     **************************************************************************/

    public override int opApply ( int delegate ( ref cstring key, ref cstring val ) dg )
    {
        int result = super.opApply(dg);

        if (!result) foreach (ref remaining_element; this.remaining[])
        {
            this.iterate(remaining_element, dg, result);

            if (result) break;
        }

        return result;
    }

    /**************************************************************************

        Resets everything.

     **************************************************************************/

    public override void reset ( )
    {
        super.reset();

        this.remaining.clear();
    }


    version (D_Version2) {}
    else
    {
        /***********************************************************************

            Disposer

        ***********************************************************************/

        protected override void dispose ( )
        {
            super.dispose();

            delete this.remaining;
        }
    }
}

/******************************************************************************/

unittest
{
    scope qp = new QueryParams(';', '=');

    assert (qp.trim_whitespace);

    {
        uint i = 0;

        foreach (key, val; qp.set(" Die Katze = tritt ;\n\tdie= Treppe;krumm.= "))
        {
            switch (i++)
            {
                case 0:
                    assert (key == "Die Katze");
                    assert (val == "tritt");
                    break;
                case 1:
                    assert (key == "die");
                    assert (val == "Treppe");
                    break;
                case 2:
                    assert (key == "krumm.");
                    assert (!val.length);
                    break;
                default:
                    assert(0);
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
                    assert (key == " Die Katze ");
                    assert (val == " tritt ");
                    break;
                case 1:
                    assert (key == "\n\tdie");
                    assert (val == " Treppe");
                    break;
                case 2:
                    assert (key == "krumm.");
                    assert (val == " ");
                    break;
                default:
                    assert(0);
            }
        }
    }
}
