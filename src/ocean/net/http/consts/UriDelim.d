/*******************************************************************************

    Uri delimiters moved from the old ocean.net.http.HttpConstants module as
    the delimiters were the only constants used in the old module.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.net.http.consts.UriDelim;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;


/*******************************************************************************

    Uri Delimiter

********************************************************************************/

struct UriDelim
{
    enum istring QUERY      = `?`; // separates uri path & query parameter
    enum istring FRAGMENT   = `#`; // separates uri path & fragment
    enum istring QUERY_URL  = `/`; // separates url path elements
    enum istring PARAM      = `&`; // separates key/value pairs
    enum istring KEY_VALUE  = `=`; // separate key and value
}
