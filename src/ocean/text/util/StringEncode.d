/*******************************************************************************

    Character encoding conversion.

    Character encoding conversion using the C iconv library
    (ocean.text.util.c.Iconv).

    Usage:
        This module can be used by creating an instance of the StringEncode
        class with the template parameters of the desired character encoding
        conversion:

        ---

            auto string_enc = new StringEncode!("ISO-8859-1", "UTF-8");

        ---

        The conversion function is called as follows:

        ---

            char[] input = "A string to be converted";
            char[] output; // The buffer which is written into

            string_enc.convert(input, output);

        ---

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.text.util.StringEncode;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.text.util.c.iconv;

import ocean.stdc.errno;

/******************************************************************************

    IconvException

*******************************************************************************/

class IconvException : Exception
{
    const MSG = "Iconv: Error";

    this ( istring msg = MSG, istring file = __FILE__, int line = __LINE__ )
    {
        super(msg, file, line);
    }

    /**************************************************************************

        Invalid Multibyte Sequence

     **************************************************************************/

    static class InvalidMbSeq :  IconvException
    {
        const msg = "Iconv: Invalid Multibyte Sequence";

        this ( istring file = __FILE__, int line = __LINE__ )
        {
            super(this.msg, file, line);
        }
    }

    /**************************************************************************

        Incomplete Multibyte Sequence

     **************************************************************************/

    static class IncompleteMbSeq :  IconvException
    {
        const msg = "Iconv: Incomplete Multibyte Sequence";

        this ( istring file = __FILE__, int line = __LINE__ )
        {
            super(this.msg, file, line);
        }
    }
}

/*******************************************************************************

    Encoder interface.

*******************************************************************************/

interface StringEncoder
{
    /***************************************************************************

        Converts a string from one encoding to another.

        Params:
            input = string to convert
            output = converted string

    ***************************************************************************/

    public void convert ( cstring input, ref mstring output );
}



/*******************************************************************************

    StringEncode class
    The template parameters are the character encoding types for the input
    and output of the converter.

*******************************************************************************/

public class StringEncode ( istring fromcode, istring tocode ) : StringEncoder
{
    /***************************************************************************

        The conversion descriptor which iconv uses internally

    ***************************************************************************/

    private ConversionDescriptor cd;


    /***************************************************************************

        Exceptions which could be thrown by this class. (These are created as
        class members so that there is no risk of convert() being called over
        and over, and newing exceptions each time, leading to an accumulation of
        memory over time.)

    ***************************************************************************/

    private IconvException.InvalidMbSeq exception_InvalidMbSeq;

    private IconvException.IncompleteMbSeq exception_IncompleteMbSeq;

    private IconvException exception_Generic;


    /***************************************************************************

        Constructor.
        Initialises iconv with the desired character encoding conversion types,
        and sets default values for the public bool properties above.

    ***************************************************************************/

    public this ( )
    {
        this.cd = iconv_open(tocode.ptr, fromcode.ptr);

        this.exception_InvalidMbSeq = new IconvException.InvalidMbSeq;

        this.exception_IncompleteMbSeq = new IconvException.IncompleteMbSeq;

        this.exception_Generic = new IconvException;
    }


    /***************************************************************************

        Destructor.
        Simply closes down the C iconv library.

    ***************************************************************************/

    private ~this ( )
    {
        iconv_close(this.cd);
    }

    /***************************************************************************

        Converts a string in one encoding type to another (as specified by the
        class' template parameters).

        Makes a guess at the required size of output buffer, simply setting it
        to the same size as the input buffer. Then repeatedly tries converting
        the input and increasing the size of the output buffer until the
        conversion succeeds.

        To avoid repeated memory allocation, if you need to call this function
        many times, it's best to always pass the same output buffer.

        Params:
            input = the array of characters to be converted.
            output = array of characters which will be filled with the results
                     of the conversion. The output array is resized to fit the
                     results.

    ***************************************************************************/

    public override void convert ( cstring input, ref mstring output )
    {
        enableStomping(output);
        output.length = input.length;
        enableStomping(output);

        // Do the conversion. Keep trying until there is no E2BIG error.
        size_t inbytesleft  = input.length;
        size_t outbytesleft = output.length;
        Const!(char)* inptr  = input.ptr;
        char* outptr = output.ptr;

        ptrdiff_t result;

        bool too_big = false;

        do
        {
            // Attempt the conversion
            result = iconv(this.cd, &inptr, &inbytesleft, &outptr, &outbytesleft);

            // If it wasn't E2BIG, we're finished
            too_big = (result < 0 && errno() == E2BIG);

            if (too_big)
            {
                // Conversion failed because the output buffer was too small.
                // Resize the output buffer and try again.
                // To improve performance, we pass the number of bytes already
                // processed to iconv. But, because extending the buffer may
                // result in a memory allocation, outptr may become invalid.

                // Convert 'outptr' to an index
                size_t out_so_far = outptr - output.ptr;

                output.length = output.length + input.length;
                outbytesleft += input.length;

                // Readjust outptr to the same position relative to output.ptr,
                // in case memory allocation just occured
                outptr = output.ptr + out_so_far;
            }
        }
        while ( too_big );

        output.length = output.length - outbytesleft;
        enableStomping(output);

        // Check for any errors from iconv and throw them as exceptions
        if (result < 0)
        {
            switch (errno())
            {
                case EILSEQ:
                    throw this.exception_InvalidMbSeq;

                case EINVAL:
                    throw this.exception_IncompleteMbSeq;

                default:
                    throw this.exception_Generic;
            }
        }
    }
}



/*******************************************************************************

    String encoder sequence. Runs a sequence of encoders over a string until one
    achieves a successful encoding.

    Template_Params:
        Encoders = tuple of types of encoders

*******************************************************************************/

public class StringEncoderSequence ( Encoders... )
{
    /***************************************************************************

        Static constructor - ensures that all template types implement the
        Encoder interface.

    ***************************************************************************/

    static this ( )
    {
        foreach ( E; Encoders )
        {
            static assert(is(E : StringEncoder));
        }
    }


    /***************************************************************************

        Array of encoders.

    ***************************************************************************/

    private StringEncoder[] encoders;


    /***************************************************************************

        Constructor. News an instance of each of the template types.

    ***************************************************************************/

    public this ( )
    {
        foreach ( E; Encoders )
        {
            this.encoders ~= new E;
        }
    }


    version (D_Version2) {}
    else
    {
        /***********************************************************************

            Disposer. Deletes encoders.

        ***********************************************************************/

        override void dispose ( )
        {
            foreach ( e; this.encoders )
            {
                delete e;
            }
        }
    }


    /***************************************************************************

        Runs the encoders in sequence until one succeeds.

        This method is aliased with opCall.

        Params:
            input = text to convert
            output = converted text

        Returns:
            converted text, or "" if all encoders failed.

    ***************************************************************************/

    public mstring convert ( cstring input, ref mstring output )
    {
        output.length = 0;
        enableStomping(output);

        foreach ( e; this.encoders )
        {
            try
            {
                if ( convert(e, input, output) )
                {
                    return output;
                }
            }
            // Exceptions thrown by an encoder are ignored.
            catch ( IconvException.InvalidMbSeq e )
            {
            }
            catch ( IconvException.IncompleteMbSeq e )
            {
            }
            catch ( IconvException e )
            {
            }
        }

        output.length = 0;
        enableStomping(output);
        return output;
    }

    public alias convert opCall;


    /***************************************************************************

        Attempts to convert the given text with the given encoder.

        Params:
            encoder = encoder to use
            input = text to convert
            output = converted text

        Returns:
            true if the text was converted successfully

    ***************************************************************************/

    private bool convert ( StringEncoder encoder, cstring input, ref mstring output )
    {
        try
        {
            encoder.convert(input, output);
            return true;
        }
        catch ( IconvException.InvalidMbSeq )
        {
            return false;
        }
    }
}

///
unittest
{
    alias StringEncode!("UTF-8", "UTF-8//TRANSLIT") Utf8Converter;
    alias StringEncode!("ISO-8859-1", "UTF-8//TRANSLIT") Iso_8859_1_Converter;
    alias StringEncoderSequence!(Utf8Converter, Iso_8859_1_Converter) Utf8Encoder;

    Utf8Encoder utf8_encoder = new Utf8Encoder();
    mstring buff;
    utf8_encoder.convert("Soon\u2122", buff);
    assert(buff == "Soon™", buff);
}
