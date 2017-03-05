/*******************************************************************************

        Copyright:
            Copyright (c) 2007 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: Oct 2007

        Authors: Kris

*******************************************************************************/

module ocean.io.stream.Digester;

import ocean.transition;

import ocean.io.device.Conduit;

import ocean.util.digest.Digest;

/*******************************************************************************

        Inject a digest filter into an input stream, updating the digest
        as information flows through it.

*******************************************************************************/

class DigestInput : InputFilter, InputFilter.Mutator
{
        private Digest filter;

        /***********************************************************************

                Accepts any input stream, and any digest derivation.

        ***********************************************************************/

        this (InputStream stream, Digest digest)
        {
                super (stream);
                filter = digest;
        }

        /***********************************************************************

                Read from conduit into a target array. The provided dst
                will be populated with content from the conduit.

                Returns the number of bytes read, which may be less than
                requested in dst (or IOStream.Eof for end-of-flow.)

        ***********************************************************************/

        final override size_t read (void[] dst)
        {
                auto len = source.read (dst);
                if (len != Eof)
                    filter.update (dst [0 .. len]);
                return len;
        }

        /***********************************************************************

                Slurp remaining stream content and return this.

        ***********************************************************************/

        final DigestInput slurp (void[] dst = null)
        {
                if (dst.length is 0)
                    dst.length = conduit.bufferSize;

                while (read(dst) != Eof) {}
                return this;
        }

        /********************************************************************

                Return the Digest instance we were created with. Use this
                to access the resultant binary or hex digest value.

        *********************************************************************/

        final Digest digest()
        {
                return filter;
        }
}


/*******************************************************************************

        Inject a digest filter into an output stream, updating the digest
        as information flows through it. Here's an example where we calculate
        an MD5 digest as a side-effect of copying a file:
        ---
        auto output = new DigestOutput(new FileOutput("output"), new Md5);
        output.copy (new FileInput("input"));

        Stdout.formatln ("hex digest: {}", output.digest.hexDigest);
        ---

*******************************************************************************/

class DigestOutput : OutputFilter, InputFilter.Mutator
{
        private Digest filter;

        /***********************************************************************

                Accepts any output stream, and any digest derivation.

        ***********************************************************************/

        this (OutputStream stream, Digest digest)
        {
                super (stream);
                filter = digest;
        }

        /***********************************************************************

                Write to conduit from a source array. The provided src
                content will be written to the conduit.

                Returns the number of bytes written from src, which may
                be less than the quantity provided.

        ***********************************************************************/

        final override size_t write (Const!(void)[] src)
        {
                auto len = sink.write (src);
                if (len != Eof)
                    filter.update (src[0 .. len]);
                return len;
        }

        /********************************************************************

                Return the Digest instance we were created with. Use this
                to access the resultant binary or hex digest value.

        *********************************************************************/

        final Digest digest()
        {
                return filter;
        }
}


/*******************************************************************************

*******************************************************************************/

debug (DigestStream)
{
        import ocean.io.Stdout;
        import ocean.io.device.Array;
        import ocean.util.digest.Md5;
        import ocean.io.stream.FileStream;

        void main()
        {
                auto output = new DigestOutput(new Array(1024, 1024), new Md5);
                output.copy (new FileInput("Digester.d"));

                Stdout.formatln ("hex digest:{}", output.digest.hexDigest);
        }
}
