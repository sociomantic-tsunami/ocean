/*******************************************************************************

    D binding for C functions & structures in libxslt.

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

module ocean.text.xml.c.LibXslt;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.text.xml.c.LibXml2;

import ocean.stdc.stdio;



extern ( C )
{
    /***************************************************************************

        Xslt stylesheet struct & pointer type.

    ***************************************************************************/

    struct xsltStylesheet;

    public alias xsltStylesheet* xsltStylesheetPtr;


    /***************************************************************************

        Read a stylesheet from a parsed xml document (see
        ocean.text.xml.c.LibXml2.xmlParseDoc).

    ***************************************************************************/

    xsltStylesheetPtr xsltParseStylesheetDoc ( xmlDocPtr doc );


    /***************************************************************************

        Read a stylesheet from a file.

    ***************************************************************************/

    xsltStylesheetPtr xsltParseStylesheetFile ( xmlChar* filename );


    /***************************************************************************

        Applies a stylesheet to a parsed xml doc.

    ***************************************************************************/

    xmlDocPtr xsltApplyStylesheet ( xsltStylesheetPtr style, xmlDocPtr doc,
        Const!(char)** params = null );


    /***************************************************************************

        Saves a processed xml doc to a file. TODO (if we need it).

    ***************************************************************************/

//    int xsltSaveResultToFile ( FILE* file, xmlDocPtr result, xsltStylesheetPtr style );


    /***************************************************************************

        Saves a processed xml doc to a string. A new string is malloced and the
        provided pointer is set to point to the resulting chunk of memory.

    ***************************************************************************/

    int xsltSaveResultToString ( xmlChar** doc_txt_ptr, int* doc_txt_len, xmlDocPtr result, xsltStylesheetPtr style );


    /***************************************************************************

        Frees any resources allocated for a stylesheet.

    ***************************************************************************/

    void xsltFreeStylesheet ( xsltStylesheetPtr style );


    /***************************************************************************

        Cleans up any global xslt allocations.

    ***************************************************************************/

    void xsltCleanupGlobals ( );
}


/*******************************************************************************

    LibXSLT global variable that sets the maximum XSLT recursion depth

    There is no API interface for reading and writing this value.

    When the max depth is reached, LibXSLT calls xsltGenericError with an
    inappropriate and useless error message, then prints some kind of stack
    trace directly onto the console. It does not set any
    error codes.

    Printing the error messages requires a considerable amount of stack space.

*******************************************************************************/

extern (C) extern private mixin(global("int xsltMaxDepth"));


/*******************************************************************************

    Set the maximum Xslt recursion depth

    The default maximum depth of 3000 can detect infinite recursion in XSLT
    templates, but requires megabytes of stack space. If a large stack is
    unavailable, the maximum recursion depth must be reduced dramatically.

    Params:
        max_depth = the maximum allowable recursive calls in an XSLT.

*******************************************************************************/

public void xsltSetMaxDepth ( int max_depth )
{
    xsltMaxDepth = max_depth;
}


/*******************************************************************************

    Return the maximum LibXslt recursion depth

    Returns:
        the maximum allowable depth of recursive calls in an XSLT.

*******************************************************************************/

public int xsltGetMaxDepth ( )
{
    return xsltMaxDepth;
}


/*******************************************************************************

    Provide a conservative estimate of the stack space which is required for
    XSLT processing.

    The stack space used by libxslt is very large, and depends on the level of
    recursion that is used by the stylesheet being processed. To prevent stack
    overflow, a maximum recursion depth must be imposed. This function provides
    a conservative estimate of the required stack size.

    Params:
        recursion_depth = the maximum allowable depth of recursive XSLT calls

    Returns:
        The minimum size in bytes which the stack should be, in order to avoid
        stack overflow during XSLT processing.

*******************************************************************************/

public int xsltRequiredStackSpace ( int recursion_depth )
{
    // The stack requirements of libxslt are not documented. The values below
    // were determined by extensive experimentation.

    // Typically each recursive call in an XSLT template involves 8 calls inside
    // libxslt, consuming about 700-900 bytes of stack space. When the recursion
    // limit is reached, more than 12KB of additional stack space is required by
    // the error message printing in the default handler for xsltGenericError.

    // Each recursion uses 700-900 bytes, so 1K gives some safety margin.

    return 1024 * (recursion_depth + 12);
}
