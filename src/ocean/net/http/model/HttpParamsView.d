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

module ocean.net.http.model.HttpParamsView;

import ocean.transition;

import ocean.time.Time;

/******************************************************************************

        Maintains a set of query parameters, parsed from an HTTP request.
        Use HttpParams instead for output parameters.

        Note that these input params may have been encoded by the user-
        agent. Unfortunately there has been little consensus on what that
        encoding should be (especially regarding GET query-params). With
        luck, that will change to a consistent usage of UTF-8 within the
        near future.

******************************************************************************/

interface HttpParamsView
{
        /**********************************************************************

                Return the number of headers

        **********************************************************************/

        uint size ();

        /**********************************************************************

                Return the value of the provided header, or null if the
                header does not exist

        **********************************************************************/

        cstring get (cstring name, cstring ret = null);

        /**********************************************************************

                Return the integer value of the provided header, or the
                provided default-value if the header does not exist

        **********************************************************************/

        int getInt (cstring name, int ret = -1);

        /**********************************************************************

                Return the date value of the provided header, or the
                provided default-value if the header does not exist

        **********************************************************************/

        Time getDate (cstring name, Time ret = Time.epoch);

        /**********************************************************************

                Output the param list to the provided consumer

        **********************************************************************/

        void produce (size_t delegate(Const!(void)[]) consume, cstring eol=null);
}
