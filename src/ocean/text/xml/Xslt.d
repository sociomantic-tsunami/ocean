/*******************************************************************************

    Xslt (Extensible Stylesheet Language Transformations) - enables
    transformation of xml documents into other formats (including differently
    structured xml documents) using a stylsheet language.

    See http://en.wikipedia.org/wiki/XSLT

    This module uses the C library libxslt internally, which requires
    linking with:

        -Llxml2
        -Llxslt

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

module ocean.text.xml.Xslt;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.core.Array;

import ocean.text.xml.c.LibXml2,
       ocean.text.xml.c.LibXslt;

import ocean.stdc.stdio,
       ocean.stdc.stdlib;

import ocean.stdc.stdarg;

import ocean.core.Exception_tango;




/*******************************************************************************

    Checks the libxml error status and throws an exception if an error occurred.

    Params:
        exception = exception instance to throw

    Throws:
        throws passed exception if an error occurred in libxml

*******************************************************************************/

private void throwXmlErrors ( Exception exception )
{
    auto err = xmlGetLastError();
    if ( err )
    {
        mstring err_msg;
        formatXmlErrorString(err, err_msg);
        exception.msg = assumeUnique(err_msg);

        // Ensure that we don't see this error again

        xmlResetLastError();

        throw exception;
    }
}



/*******************************************************************************

    Xslt stylesheet class. Can be initialised once and used for multiple xslt
    transformations.

*******************************************************************************/

class XsltStylesheet
{
    /***************************************************************************

        Reusable xml exception

    ***************************************************************************/

    private XmlException exception;


    /***************************************************************************

        Xml structure of stylesheet text.

    ***************************************************************************/

    private xmlDocPtr stylesheet_xml;


    /***************************************************************************

        Transformation stylesheet.

    ***************************************************************************/

    private xsltStylesheetPtr stylesheet;


    /***************************************************************************

        Constructor.

    ***************************************************************************/

    public this ( )
    {
        this.exception = new XmlException("");
    }


    /***************************************************************************

        Destructor -- deallocates any C-allocated data.

    ***************************************************************************/

    ~this ( )
    {
        this.cleanup();
    }


    /***************************************************************************

        Sets the xslt text.

        Params:
            xslt = text of xslt

    ***************************************************************************/

    public void set ( ref mstring xslt )
    {
        this.cleanup();

        xslt.append("\0"[]);
        scope ( exit ) xslt.length = xslt.length - 1;

        this.stylesheet_xml = xmlParseDoc(xslt.ptr);
        throwXmlErrors(this.exception);

        this.stylesheet = xsltParseStylesheetDoc(this.stylesheet_xml);
        throwXmlErrors(this.exception);
    }


    /***************************************************************************

        Frees the C-allocated buffers associated with this stylesheet. The
        stylesheet xml is automatically freed as well.

    ***************************************************************************/

    private void cleanup ( )
    {
        if ( this.stylesheet !is null )
        {
            xsltFreeStylesheet(this.stylesheet);
            this.stylesheet = null;
        }
    }
}



/*******************************************************************************

    Xslt result class. Stores the result of an xslt transformation.

    The result is a C-allocated string, which this class wraps with a D string
    (a slice of the C string) and manages, ensuring that it is freed when
    appropriate.

*******************************************************************************/

public class XsltResult
{
    /***************************************************************************

        Slice of the C-allocated result string.

    ***************************************************************************/

    private mstring str;


    /***************************************************************************

        Destructor. Makes sure the C string is freed.

    ***************************************************************************/

    ~this ( )
    {
        this.cleanup();
    }


    /***************************************************************************

        Gets the slice to the C-allocated string.

    ***************************************************************************/

    public cstring opCall ( )
    {
        return this.str;
    }


    /***************************************************************************

        Sets the result string. (Called by XsltProcessor.transform().)

        Params:
            xml = pointer to an xml document
            stylesheet = xslt stylesheet

    ***************************************************************************/

    package void set ( xmlDocPtr xml, XsltStylesheet stylesheet )
    {
        this.cleanup();

        // XSLT BUG: xsltSaveResultToString() segfaults if xml is null
        if ( xml )
        {
            char* c_allocated_string;
            int length;

            xsltSaveResultToString(&c_allocated_string, &length, xml, stylesheet.stylesheet);

            this.str = c_allocated_string[0..length];
        }
        else
        {
            this.str = null;
        }
    }


    /***************************************************************************

        Frees the C-allocated string if one has been set.

    ***************************************************************************/

    private void cleanup ( )
    {
        if ( this.str.ptr !is null )
        {
            free(this.str.ptr);
            this.str = typeof(this.str).init;
        }
    }
}

/*******************************************************************************

    Xslt parameter class

    Stores parameters to be passed to an XsltStylesheet object.
    Parameters must be null-terminated.

*******************************************************************************/

public class XsltParameters
{
    /***************************************************************************

        Null-terminated parameters, in C-format.
        Consists of key, value, key, value, null.

    ***************************************************************************/

    private Const!(char)*[] c_params;

    /***************************************************************************

        Accepts a list of strings in the form
        ----
            key, value, key, value, ...
        ----
        Each string must be null-terminated since it will be passed to C.

    ***************************************************************************/

    void setParams(cstring[] keyvaluelist...)
    {
        // Check that it is even
        assert(!(keyvaluelist.length & 1), "XSLT parameters must have equal number of keys and values");

        this.c_params = new char *[keyvaluelist.length + 1];

        foreach (int i, p; keyvaluelist)
        {
            assert(p[$-1]=='\0', "XSLT parameters must be null terminated");
            this.c_params[ i ] = p.ptr;
        }

        this.c_params[$-1] = null;
    }
}

/***************************************************************************

    Handler for Xml errors, which does nothing

    The default libxml2 error hander prints the error messages to stderr,
    which is normally undesirable.

    This alternative handler simply returns without generating output.

    Note that the default handler is completely redundant. The error message
    which would be written to stderr is present in the exceptions thrown by
    this library. (Effectively, the default handler calls xmlGetLastError()
    and writes the result to stderr).

    Params:
        ctx = context supplied by libxml2. Ignored.
        msg = message supplied by libxml2. Ignored.

***************************************************************************/

extern ( C )
{
    private void  silentXmlErrorHandler ( void * ctx, char * msg, ... )
    {

    }
}


/***************************************************************************

    Prevent XSLT errors from being displayed to the console

    The default libxml2 error hander prints the error messages to stderr,
    which is normally undesirable.

    This function simply suppresses the error output.

***************************************************************************/

public void suppressXsltStderrOutput ( )
{
    xmlSetGenericErrorFunc(null, &silentXmlErrorHandler);
}


/*******************************************************************************

    Xslt processor class -- takes an XsltStylesheet object defining a set of
    transformation rules, and an xml string. Runs the transformation over the
    xml string and fills in an XsltResult object.

*******************************************************************************/

public class XsltProcessor
{
    /***************************************************************************

        Xml structure of original text.

    ***************************************************************************/

    private xmlDocPtr original_xml;


    /***************************************************************************

        Xml structure of transformed text.

    ***************************************************************************/

    private xmlDocPtr transformed_xml;


    /***************************************************************************

        Flag set to true when the xml parser has been initialised.

    ***************************************************************************/

    private bool xml_parser_initialised;


    /***************************************************************************

        Reusable xml exception

    ***************************************************************************/

    private XmlException exception;


    /***************************************************************************

        Constructor.

    ***************************************************************************/

    public this ( )
    {
        this.exception = new XmlException("");
    }


    /***************************************************************************

        Destructor. Frees objects allocated by the C libraries.

    ***************************************************************************/

    ~this ( )
    {
        this.cleanupParser();
    }


    /***************************************************************************

        Transforms a source xml text via the xslt transformation rules given in
        stylesheet_text, and writes the transformed xml as text into a
        destination string.

        This method is aliased with opCall.

        Params:
            source = xml to transform
            result = result instance to receive transformed xml
            stylesheet = xslt transformation stylesheet instance
            params  = xslt parameters to pass to the stylesheet

    ***************************************************************************/

    public void transform ( ref mstring source, XsltResult result, XsltStylesheet stylesheet, XsltParameters params = null )
    in
    {
        assert(stylesheet.stylesheet !is null, typeof(this).stringof ~ ".transform: xslt stylesheet not initialised");
    }
    body
    {
        scope ( failure )
        {
            // clean everything to ensure it's fresh next time this method is called
            this.cleanupParser();
        }

        this.initParser();

        source.append("\0"[]);
        scope ( exit ) source.length = source.length - 1;

        this.original_xml = xmlParseDoc(source.ptr);

        throwXmlErrors(this.exception);

        if ( ! this.original_xml)
        {
            // Don't know if this can happen, but I don't trust libxslt
            this.exception.msg = "libxslt bug: XSLT parse error";
            throw this.exception;
        }

        this.transformed_xml = xsltApplyStylesheet(stylesheet.stylesheet, this.original_xml, params ? params.c_params.ptr : null);
        throwXmlErrors(this.exception);

        if ( ! this.transformed_xml )
        {
            // XSLT bug #1: this can happen without setting an XML error.
            // XSLT bug #2: if it happens, xsltSaveResultToString will segfault!
            this.exception.msg = "libxslt bug: XSLT transform error";
            throw this.exception;
        }

        result.set(this.transformed_xml, stylesheet);

        // cleanup used resources
        cleanupXmlDoc(this.original_xml);
        cleanupXmlDoc(this.transformed_xml);
    }

    public alias transform opCall;


    /***************************************************************************

        Initialises the xml parser with the settings required for xslt.

    ***************************************************************************/

    private void initParser ( )
    {
        if ( !this.xml_parser_initialised )
        {
            xmlInitParser();
            xmlSubstituteEntitiesDefault(1);
            xmlLoadExtDtdDefaultValue = 1;

            this.xml_parser_initialised = true;
        }
    }

    /***************************************************************************

        Cleans up all resources used by the xml parser & xlst.

    ***************************************************************************/

    private void cleanupParser ( )
    {
        if ( this.xml_parser_initialised )
        {
            cleanupXmlDoc(this.original_xml);
            cleanupXmlDoc(this.transformed_xml);

            xsltCleanupGlobals();
            xmlCleanupParser();

            this.xml_parser_initialised = false;
        }
    }


    /***************************************************************************

        Cleans up any resources used by the given xml document. It is set to
        null.

        Params:
            xml_doc = xml document to clean

    ***************************************************************************/

    private void cleanupXmlDoc ( ref xmlDocPtr xml_doc )
    {
        if ( !(xml_doc is null) )
        {
            xmlFreeDoc(xml_doc);
            xml_doc = null;
        }
    }
}

