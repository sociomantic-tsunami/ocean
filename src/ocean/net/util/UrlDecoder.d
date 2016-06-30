/******************************************************************************

    UTF-8 URL decoder

    Uses the glib 2.0, use

        -Lglib-2.0

    as linking parameter.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.net.util.UrlDecoder;

/******************************************************************************

    Imports and library function declarations

 ******************************************************************************/

import ocean.transition;

import ocean.text.util.SplitIterator: ChrSplitIterator;

import ocean.stdc.string: memmove;

extern (C) private
{
    /**************************************************************************

        Determines the numeric value of a character as a hexidecimal digit.

        @see http://developer.gnome.org/glib/stable/glib-String-Utility-Functions.html#g-ascii-xdigit-value

        Params:
            c = an ASCII character.

        Returns:
            If c is a hex digit its numeric value. Otherwise, -1.

     **************************************************************************/

    int   g_ascii_xdigit_value(int c);

    /**************************************************************************

        Converts a single character to UTF-8.

        @see http://developer.gnome.org/glib/stable/glib-Unicode-Manipulation.html#g-unichar-to-utf8

        Params:
            c      = a Unicode character code
            outbuf = output buffer, must have at least 6 bytes of space.
                     If NULL, the length will be computed and returned and
                     nothing will be written to outbuf.

        Returns:
            number of bytes written

     **************************************************************************/

    int g_unichar_to_utf8(dchar c, char* outbuf);
}

/******************************************************************************

    UrlDecoder class

    Memory friendly, suitable for stack-allocated 'scope' instances.

 ******************************************************************************/

class UrlDecoder
{
    /**************************************************************************

        Source string, may be changed at any time except during decoding
        'foreach' iteration.

     **************************************************************************/

    public cstring source;

    /**************************************************************************

        Constructor

        Params:
            source_in = source string

     **************************************************************************/

    public this ( cstring source_in = null )
    {
        this.source = source_in;
    }

    /***************************************************************************

        Decodes this.source in an 'foreach' iteration over decoded chunks.

        Checks whether the passed source string contains any characters encoded
        according to the RFC 2396 escape format. (A '%' character followed by
        two hexadecimal digits.)

        The non-standard 4-digit unicode encoding scheme is also supported ("%u"
        followed by four hex digits). Such characters are converted to UTF-8.

    **************************************************************************/

    public int opApply ( int delegate ( ref cstring chunk ) dg )
    {
        int callDg ( cstring str )
        {
            return dg(str);
        }

        scope iterate_markers = new ChrSplitIterator('%');

        iterate_markers.include_remaining = false;

        size_t first_marker = iterate_markers.reset(this.source).locateDelim();

        if (first_marker < this.source.length)
        {
            int result = callDg(this.source[0 .. first_marker]);

            if (!result) foreach (ref pos, between; iterate_markers.reset(this.source[first_marker .. $]))
            {
                result = dg(between);

                if (result) break;

                auto remaining = iterate_markers.remaining;

                char[6] decoded_buf;
                size_t read_pos = 0;

                auto decoded = decodeCharacter(decoded_buf, remaining, read_pos);

                if (decoded.length)
                {
                    assert (read_pos);

                    auto original = this.source[0 .. read_pos];

                    result = callDg(this.copyDecoded(decoded, original)?
                                        decoded : original);

                    pos += read_pos;
                }
                else                                           // decoding error
                {
                    assert (!read_pos);

                    result = callDg("%");
                }

                if (result) break;
            }

            return result? result : callDg(iterate_markers.remaining);
        }
        else
        {
            return dg(this.source);
        }
    }

    /***************************************************************************

        Extracts a single character from the specified position in the passed
        string, which is expected to be the index of a character preceeded by a
        '%'.
        source[pos .. $] is scanned to see if they represent an encoded
        character in either the RFC 2396 escape format (%XX) or the non-standard
        escape format (%uXXXX) or if they should represent a '%' (%%).

        (See: http://en.wikipedia.org/wiki/Percent-encoding)

        On success the extracted character is written as utf8 into the provided
        output buffer and pos is increased to the index right after the last
        consumed character in source. On failure pos remains unchanged.

        Params:
            dst    = string buffer to receive decoded characters
            source = character string to decode a character from; may be
                     empty or null which will result in failure
            pos    = position in source

        Returns:
            a slice to the UTF-8 representation of the decoded character in dst
            on success or an empty string on failure. The returned string is
            guaranteed to slice dst from dst[0].

    ***************************************************************************/

    public static mstring decodeCharacter ( mstring dst, cstring source, ref size_t pos )
    in
    {
        assert(pos <= source.length, typeof (this).stringof ~ ".decodeCharacter (in): offset out of array bounds");
    }
    out (slice)
    {
        assert (slice.ptr is dst.ptr, typeof (this).stringof ~ ".decodeCharacter: bad returned slice");
        assert(pos <= source.length, typeof (this).stringof ~ ".decodeCharacter (out): offset out of array bounds");
    }
    body
    {
        auto src = source[pos .. $];

        size_t read    = 0,
               written = 0;

        if (src.length) switch (src[0])
        {
            default:
                if (src.length >= 2)
                {
                    written = hex2(src[0], src[1], dst[0]);

                    if (written)
                    {
                        read = 2;
                    }
                }
                break;

            case 'u':
                if (src.length >= 5)
                {
                    written = hex4(src[1 .. 5], dst).length;

                    if (written)
                    {
                        read = 5;
                    }
                }
                break;

            case '%':
                read  = 1;
                written = 1;
                dst[0] = src[0];
        }

        pos += read;

        return dst[0 .. written];
    }

    /***************************************************************************

        Decodes '%' encoded characters in str, replacing them in-place.

        Checks whether the passed source string contains any characters encoded
        according to the RFC 2396 escape format. (A '%' character followed by
        two hexadecimal digits.)

        The non-standard 4-digit unicode encoding scheme is also supported ("%u"
        followed by four hex digits). Such characters are converted to UTF-8.

        Note that the original content in str is overwritten with the decoded
        content. The resulting content is at most as long as the original. The
        returned string slices the valid content in str. str itself may contain
        tailing junk.

        Params:
            str = string to decode

        Returns:
            the decoded str content (slices str from the beginning)

        Out:
            The returned array slices str from the beginning.

    ***************************************************************************/

    public static mstring decode ( mstring str )
    out (str_out)
    {
        assert (str_out.ptr is str.ptr);
    }
    body
    {
        size_t pos = 0;

        if (str.length)
        {
            scope iterator = new ChrSplitIterator('%');

            // Skip the beginning of str before the first '%'.

            foreach (chunk; iterator.reset(str))
            {
                pos = chunk.length;
                break;
            }

            bool had_percent = false;

            foreach (chunk; iterator)
            {
                size_t read, written = 0;

                if (chunk.length)
                {
                    if (chunk[0] == 'u')
                    {
                        // Have a 'u': Assume four hex digits follow which denote
                        // the character value; decode that character and copy the
                        // UTF-8 sequence into str, starting from pos. Note that
                        // since g_unichar_to_utf8() produces UTF-8 sequence of 6
                        // bytes maximum, the UTF-8 sequence won't be longer than
                        // the original "%u####" sequence.

                        read = 5;
                        if (chunk.length >= read)
                        {
                            written = hex4(chunk[1 .. read], str[pos .. pos + 6]).length;
                        }
                    }
                    else
                    {
                        // Assume two hex digits follow which denote the character
                        // value; replace str[pos] with the corresponding character.

                        read = 2;
                        if (chunk.length >= read)
                        {
                            written = hex2(chunk[0], chunk[1], str[pos]);
                        }
                    }
                }
                else
                {
                    if (had_percent)
                    {
                        had_percent = false;
                    }
                    else
                    {
                        str[pos++] = '%';
                        had_percent = true;
                    }

                    continue;
                }

                assert (written <= read);

                // written = 0 => error: Pass through the erroneous sequence,
                // prepending the '%' that was skipped by the iterator.

                if (!written)
                {
                    if (had_percent)
                    {
                        had_percent = false;
                    }
                    else
                    {
                        str[pos] = '%';
                        written = 1;
                        had_percent = true;
                    }

                    read = 0;
                }

                pos += written;

                // Move the rest of chunk to the front.

                if (chunk.length > read)
                {
                    cstring between = chunk[read .. $];

                    memmove(&str[pos], &between[0], between.length);

                    pos += between.length;
                }

                had_percent = false;
            }
        }

        return str[0 .. pos];
    }

    /***************************************************************************

        Creates a character c with the value specified by the 2-digit ASCII
        hexadecimal number whose digits are hi and lo. For example, if
        hi = 'E' or 'e' and lo = '9', c will be 0xE9.

        Params:
            hi = most significant hexadecimal digit (ASCII)
            lo = least significant hexadecimal digit (ASCII)
            c  = output character

        Returns:
            true on success or false if hi or lo or both are not a hexadecimal
            digit.

     ***************************************************************************/

    static bool hex2 ( char hi, char lo, out char c )
    {
        int xhi = g_ascii_xdigit_value(hi),
            xlo = g_ascii_xdigit_value(lo);

        if (xhi >= 0 && xlo >= 0)
        {
            c = cast(char) ((xhi << 4) | xlo);

            return true;
        }
        else
        {
            return false;
        }
    }

    /***************************************************************************

        Converts hex, which is expected to contain a 4-digit ASCII hexadecimal
        number, into its corresponding UTF-8 character sequence.

        Params:
            hex      = character code in hexadeximal representation (ASCII)
            utf8_buf = destination buffer for the UTF-8 sequence of the
                       character; the length must be at least 6; may contain
                       tailing junk if the sequence is actually shorter

        Returns:
            the UTF-8 sequence (slices the valid data in utf8_buf) on success or
            an empty string on failure.

        In:
            - hex.length must be 4,
            - utf8_buf.length must at least be 6.

        Out:
            The returned string slices utf8_buf from the beginning.

    ***************************************************************************/

    static mstring hex4 ( cstring hex, mstring utf8_buf )
    in
    {
        assert (hex.length == 4);
        assert (utf8_buf.length >= 6);
    }
    out (utf8)
    {
        assert (utf8_buf.ptr is utf8.ptr);
    }
    body
    {
        int hihi = g_ascii_xdigit_value(hex[0]),
            hilo = g_ascii_xdigit_value(hex[1]),
            lohi = g_ascii_xdigit_value(hex[2]),
            lolo = g_ascii_xdigit_value(hex[3]);

        size_t n = 0;

        if (hihi >= 0 && hilo >= 0 && lohi >= 0 && lolo >= 0)
        {
            dchar c = ((cast (dchar) hihi) << 0xC) |
                      ((cast (dchar) hilo) << 0x8) |
                      ((cast (dchar) lohi) << 0x4) |
                      ((cast (dchar) lolo));

            n = cast (size_t) g_unichar_to_utf8(c, utf8_buf.ptr);
        }

        return utf8_buf[0 .. n];
    }

    /**************************************************************************

        To be overridden as an option, called by opApply().

        Determines whether each decoded character should be passed as 'foreach'
        iteration variable string in its decoded or its original (encoded) form.
        This can be used in cases where the decoding of only certain characters
        is desired.

        By default always the decoded form is selected.

        Params:
            decoded  = decoded form of the character
            original = original (encoded) form

        Returns:
            true to use the decoded or false to use the original (encoded) form.

     **************************************************************************/

    protected bool copyDecoded ( cstring decoded, cstring original )
    {
        return true;
    }
}


unittest
{
    scope decoder = new UrlDecoder("%Die %uKatze %u221E%u221E tritt die Treppe %% krumm. %u2207%"),
          decoded = new char[0];

    foreach (chunk; decoder)
    {
        decoded ~= chunk;
    }

    assert (decoded == "%Die %uKatze ∞∞ tritt die Treppe % krumm. ∇%");

    assert (UrlDecoder.decode("%Die %uKatze %u221E%u221E tritt die Treppe %% krumm. %u2207".dup) ==
                   "%Die %uKatze ∞∞ tritt die Treppe % krumm. ∇");
}
