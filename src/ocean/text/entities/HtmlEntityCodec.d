/*******************************************************************************

    Html entity en/decoder.

    Example usage:

    ---

        import ocean.text.entities.HtmlEntityCodec;

        scope entity_codec = new HtmlEntityCodec;

        char[] test = "hello & world © &szlig;&nbsp;&amp;#x230;'";

        if ( entity_codec.containsUnencoded(test) )
        {
            char[] encoded;
            entity_codec.encode(test, encoded);
        }

    ---

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.text.entities.HtmlEntityCodec;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.text.entities.model.MarkupEntityCodec;

import ocean.text.entities.HtmlEntitySet;

/*******************************************************************************

    Class to en/decode html entities.

*******************************************************************************/

public alias MarkupEntityCodec!(HtmlEntitySet) HtmlEntityCodec;
