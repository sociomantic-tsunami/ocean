/*******************************************************************************

        Provides case mapping Functions for Unicode Strings. As of now it is
        only 99 % complete, because it does not take into account Conditional
        case mappings. This means the Greek Letter Sigma will not be correctly
        case mapped at the end of a Word, and the Locales Lithuanian, Turkish
        and Azeri are not taken into account during Case Mappings. This means
        all in all around 12 Characters will not be mapped correctly under
        some circumstances.

        ICU4j also does not handle these cases at the moment.

        Unittests are written against output from ICU4j

        This Module tries to minimize Memory allocation and usage. You can
        always pass the output buffer that should be used to the case mapping
        function, which will be resized if necessary.

        Copyright:
            Copyright (c) 2007 Peter Triller.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: Sept 2007

        Authors: Peter

*******************************************************************************/

module ocean.text.Unicode;

import ocean.transition;
import ocean.text.UnicodeData;
import ocean.text.convert.Utf;



/**
 * Converts an Utf8 String to Upper case
 *
 * Params:
 *     input = String to be case mapped
 *     output = this output buffer will be used unless too small
 * Returns: the case mapped string
 */
char[] toUpper(Const!(char)[] input, char[] output = null) {

    dchar[1] buf;
    // assume most common case: String stays the same length
    if (output.length < input.length)
        output.length = input.length;

    auto produced = 0;
    size_t ate;
    foreach(dchar ch; input) {
        // TODO Conditional Case Mapping
        UnicodeData *d = getUnicodeData(ch);
        if(d !is null && (d.generalCategory & UnicodeData.GeneralCategory.SpecialMapping)) {
            SpecialCaseData *s = getSpecialCaseData(ch);
            debug {
                assert(s !is null);
            }
            if(s.upperCaseMapping !is null) {
                // To speed up, use worst case for memory prealocation
                // since the length of an UpperCaseMapping list is at most 4
                // Make sure no relocation is made in the toString Method
                // better allocation algorithm ?
                if(produced + s.upperCaseMapping.length * 4 >= output.length)
                        output.length = output.length + output.length / 2 +  s.upperCaseMapping.length * 4;
                auto res = toString(s.upperCaseMapping, output[produced..output.length], &ate);
                debug {
                    assert(ate == s.upperCaseMapping.length);
                    assert(res.ptr == output[produced..output.length].ptr);
                }
                produced += res.length;
                continue;
            }
        }
        // Make sure no relocation is made in the toString Method
        if(produced + 4 >= output.length)
            output.length = output.length + output.length / 2 + 4;
        buf[0] = d is null ? ch:d.simpleUpperCaseMapping;
        auto res = toString(buf, output[produced..output.length], &ate);
        debug {
            assert(ate == 1);
            assert(res.ptr == output[produced..output.length].ptr);
        }
        produced += res.length;
    }
    return output[0..produced];
}


/**
 * Converts an Utf16 String to Upper case
 *
 * Params:
 *     input = String to be case mapped
 *     output = this output buffer will be used unless too small
 * Returns: the case mapped string
 */
wchar[] toUpper(Const!(wchar)[] input, wchar[] output = null) {

    dchar[1] buf;
    // assume most common case: String stays the same length
    if (output.length < input.length)
        output.length = input.length;

    auto produced = 0;
    size_t ate;
    foreach(dchar ch; input) {
        // TODO Conditional Case Mapping
        UnicodeData *d = getUnicodeData(ch);
        if(d !is null && (d.generalCategory & UnicodeData.GeneralCategory.SpecialMapping)) {
            SpecialCaseData *s = getSpecialCaseData(ch);
            debug {
                assert(s !is null);
            }
            if(s.upperCaseMapping !is null) {
                // To speed up, use worst case for memory prealocation
                // Make sure no relocation is made in the toString16 Method
                // better allocation algorithm ?
                if(produced + s.upperCaseMapping.length * 2 >= output.length)
                    output.length = output.length + output.length / 2 +  s.upperCaseMapping.length * 3;
                auto res = toString16(s.upperCaseMapping, output[produced..output.length], &ate);
                debug {
                    assert(ate == s.upperCaseMapping.length);
                    assert(res.ptr == output[produced..output.length].ptr);
                }
                produced += res.length;
                continue;
            }
        }
        // Make sure no relocation is made in the toString16 Method
        if(produced + 4 >= output.length)
            output.length = output.length + output.length / 2 + 3;
        buf[0] = d is null ? ch:d.simpleUpperCaseMapping;
        auto res = toString16(buf, output[produced..output.length], &ate);
        debug {
            assert(ate == 1);
            assert(res.ptr == output[produced..output.length].ptr);
        }
        produced += res.length;
    }
    return output[0..produced];
}

/**
 * Converts an Utf32 String to Upper case
 *
 * Params:
 *     input = String to be case mapped
 *     output = this output buffer will be used unless too small
 * Returns: the case mapped string
 */
dchar[] toUpper(Const!(dchar)[] input, dchar[] output = null) {

    // assume most common case: String stays the same length
    if (input.length > output.length)
        output.length = input.length;

    uint produced = 0;
    if (input.length)
        foreach(dchar orig; input) {
            // TODO Conditional Case Mapping
            UnicodeData *d = getUnicodeData(orig);
            if(d !is null && (d.generalCategory & UnicodeData.GeneralCategory.SpecialMapping)) {
                SpecialCaseData *s = getSpecialCaseData(orig);
                debug {
                    assert(s !is null);
                }
                if(s.upperCaseMapping !is null) {
                    // Better resize strategy ???
                    if(produced + s.upperCaseMapping.length  > output.length)
                        output.length = output.length + output.length / 2 + s.upperCaseMapping.length;
                    foreach(ch; s.upperCaseMapping) {
                        output[produced++] = ch;
                    }
                }
                continue;
            }
            if(produced >= output.length)
                output.length = output.length + output.length / 2;
            output[produced++] = d is null ? orig:d.simpleUpperCaseMapping;
        }
    return output[0..produced];
}


/**
 * Converts an Utf8 String to Lower case
 *
 * Params:
 *     input = String to be case mapped
 *     output = this output buffer will be used unless too small
 * Returns: the case mapped string
 */
char[] toLower(Const!(char)[] input, char[] output = null) {

    dchar[1] buf;
    // assume most common case: String stays the same length
    if (output.length < input.length)
        output.length = input.length;

    auto produced = 0;
    size_t ate;
    foreach(dchar ch; input) {
        // TODO Conditional Case Mapping
        UnicodeData *d = getUnicodeData(ch);
        if(d !is null && (d.generalCategory & UnicodeData.GeneralCategory.SpecialMapping)) {
            SpecialCaseData *s = getSpecialCaseData(ch);
            debug {
                assert(s !is null);
            }
            if(s.lowerCaseMapping !is null) {
                // To speed up, use worst case for memory prealocation
                // since the length of an LowerCaseMapping list is at most 4
                // Make sure no relocation is made in the toString Method
                // better allocation algorithm ?
                if(produced + s.lowerCaseMapping.length * 4 >= output.length)
                        output.length = output.length + output.length / 2 +  s.lowerCaseMapping.length * 4;
                auto res = toString(s.lowerCaseMapping, output[produced..output.length], &ate);
                debug {
                    assert(ate == s.lowerCaseMapping.length);
                    assert(res.ptr == output[produced..output.length].ptr);
                }
                produced += res.length;
                continue;
            }
        }
        // Make sure no relocation is made in the toString Method
        if(produced + 4 >= output.length)
            output.length = output.length + output.length / 2 + 4;
        buf[0] = d is null ? ch:d.simpleLowerCaseMapping;
        auto res = toString(buf, output[produced..output.length], &ate);
        debug {
            assert(ate == 1);
            assert(res.ptr == output[produced..output.length].ptr);
        }
        produced += res.length;
    }
    return output[0..produced];
}


/**
 * Converts an Utf16 String to Lower case
 *
 * Params:
 *     input = String to be case mapped
 *     output = this output buffer will be used unless too small
 * Returns: the case mapped string
 */
wchar[] toLower(Const!(wchar)[] input, wchar[] output = null) {

    dchar[1] buf;
    // assume most common case: String stays the same length
    if (output.length < input.length)
        output.length = input.length;

    auto produced = 0;
    size_t ate;
    foreach(dchar ch; input) {
        // TODO Conditional Case Mapping
        UnicodeData *d = getUnicodeData(ch);
        if(d !is null && (d.generalCategory & UnicodeData.GeneralCategory.SpecialMapping)) {
            SpecialCaseData *s = getSpecialCaseData(ch);
            debug {
                assert(s !is null);
            }
            if(s.lowerCaseMapping !is null) {
                // To speed up, use worst case for memory prealocation
                // Make sure no relocation is made in the toString16 Method
                // better allocation algorithm ?
                if(produced + s.lowerCaseMapping.length * 2 >= output.length)
                    output.length = output.length + output.length / 2 +  s.lowerCaseMapping.length * 3;
                auto res = toString16(s.lowerCaseMapping, output[produced..output.length], &ate);
                debug {
                    assert(ate == s.lowerCaseMapping.length);
                    assert(res.ptr == output[produced..output.length].ptr);
                }
                produced += res.length;
                continue;
            }
        }
        // Make sure no relocation is made in the toString16 Method
        if(produced + 4 >= output.length)
            output.length = output.length + output.length / 2 + 3;
        buf[0] = d is null ? ch:d.simpleLowerCaseMapping;
        auto res = toString16(buf, output[produced..output.length], &ate);
        debug {
            assert(ate == 1);
            assert(res.ptr == output[produced..output.length].ptr);
        }
        produced += res.length;
    }
    return output[0..produced];
}


/**
 * Converts an Utf32 String to Lower case
 *
 * Params:
 *     input = String to be case mapped
 *     output = this output buffer will be used unless too small
 * Returns: the case mapped string
 */
dchar[] toLower(Const!(dchar)[] input, dchar[] output = null) {

    // assume most common case: String stays the same length
    if (input.length > output.length)
        output.length = input.length;

    auto produced = 0;
    if (input.length)
        foreach(dchar orig; input) {
            // TODO Conditional Case Mapping
            UnicodeData *d = getUnicodeData(orig);
            if(d !is null && (d.generalCategory & UnicodeData.GeneralCategory.SpecialMapping)) {
                SpecialCaseData *s = getSpecialCaseData(orig);
                debug {
                    assert(s !is null);
                }
                if(s.lowerCaseMapping !is null) {
                    // Better resize strategy ???
                    if(produced + s.lowerCaseMapping.length  > output.length)
                        output.length = output.length + output.length / 2 + s.lowerCaseMapping.length;
                    foreach(ch; s.lowerCaseMapping) {
                        output[produced++] = ch;
                    }
                }
                continue;
            }
            if(produced >= output.length)
                output.length = output.length + output.length / 2;
            output[produced++] = d is null ? orig:d.simpleLowerCaseMapping;
        }
    return output[0..produced];
}

/**
 * Converts an Utf8 String to Folding case
 * Folding case is used for case insensitive comparsions.
 *
 * Params:
 *     input = String to be case mapped
 *     output = this output buffer will be used unless too small
 * Returns: the case mapped string
 */
char[] toFold(Const!(char)[] input, char[] output = null) {

    dchar[1] buf;
    // assume most common case: String stays the same length
    if (output.length < input.length)
        output.length = input.length;

    auto produced = 0;
    size_t ate;
    foreach(dchar ch; input) {
        FoldingCaseData *s = getFoldingCaseData(ch);
        if(s !is null) {
            // To speed up, use worst case for memory prealocation
            // since the length of an UpperCaseMapping list is at most 4
            // Make sure no relocation is made in the toString Method
            // better allocation algorithm ?
            if(produced + s.mapping.length * 4 >= output.length)
                output.length = output.length + output.length / 2 +  s.mapping.length * 4;
            auto res = toString(s.mapping, output[produced..output.length], &ate);
            debug {
                assert(ate == s.mapping.length);
                assert(res.ptr == output[produced..output.length].ptr);
            }
            produced += res.length;
            continue;
        }
        // Make sure no relocation is made in the toString Method
        if(produced + 4 >= output.length)
            output.length = output.length + output.length / 2 + 4;
        buf[0] = ch;
        auto res = toString(buf, output[produced..output.length], &ate);
        debug {
            assert(ate == 1);
            assert(res.ptr == output[produced..output.length].ptr);
        }
        produced += res.length;
    }
    return output[0..produced];
}

/**
 * Converts an Utf16 String to Folding case
 * Folding case is used for case insensitive comparsions.
 *
 * Params:
 *     input = String to be case mapped
 *     output = this output buffer will be used unless too small
 * Returns: the case mapped string
 */
wchar[] toFold(Const!(wchar)[] input, wchar[] output = null) {

    dchar[1] buf;
    // assume most common case: String stays the same length
    if (output.length < input.length)
        output.length = input.length;

    auto produced = 0;
    size_t ate;
    foreach(dchar ch; input) {
        FoldingCaseData *s = getFoldingCaseData(ch);
        if(s !is null) {
            // To speed up, use worst case for memory prealocation
            // Make sure no relocation is made in the toString16 Method
            // better allocation algorithm ?
            if(produced + s.mapping.length * 2 >= output.length)
                output.length = output.length + output.length / 2 +  s.mapping.length * 3;
            auto res = toString16(s.mapping, output[produced..output.length], &ate);
            debug {
                assert(ate == s.mapping.length);
                assert(res.ptr == output[produced..output.length].ptr);
            }
            produced += res.length;
            continue;
        }
        // Make sure no relocation is made in the toString16 Method
        if(produced + 4 >= output.length)
            output.length = output.length + output.length / 2 + 3;
        buf[0] = ch;
        auto res = toString16(buf, output[produced..output.length], &ate);
        debug {
            assert(ate == 1);
            assert(res.ptr == output[produced..output.length].ptr);
        }
        produced += res.length;
    }
    return output[0..produced];
}

/**
 * Converts an Utf32 String to Folding case
 * Folding case is used for case insensitive comparsions.
 *
 * Params:
 *     input = String to be case mapped
 *     output = this output buffer will be used unless too small
 * Returns: the case mapped string
 */
dchar[] toFold(Const!(dchar)[] input, dchar[] output = null) {

    // assume most common case: String stays the same length
    if (input.length > output.length)
        output.length = input.length;

    uint produced = 0;
    if (input.length)
        foreach(dchar orig; input) {
            FoldingCaseData *d = getFoldingCaseData(orig);
            if(d !is null ) {
                // Better resize strategy ???
                if(produced + d.mapping.length  > output.length)
                    output.length = output.length + output.length / 2 + d.mapping.length;
                foreach(ch; d.mapping) {
                    output[produced++] = ch;
                }
                continue;
            }
            if(produced >= output.length)
                output.length = output.length + output.length / 2;
            output[produced++] = orig;
        }
    return output[0..produced];
}


/**
 * Determines if a character is a digit. It returns true for decimal
 * digits only.
 *
 * Params:
 *     ch = the character to be inspected
 */
bool isDigit(dchar ch) {
    UnicodeData *d = getUnicodeData(ch);
    return (d !is null) && (d.generalCategory & UnicodeData.GeneralCategory.Nd);
}


/**
 * Determines if a character is a letter.
 *
 * Params:
 *     ch = the character to be inspected
 */
bool isLetter(int ch) {
    UnicodeData *d = getUnicodeData(ch);
    return (d !is null) && (d.generalCategory &
        ( UnicodeData.GeneralCategory.Lu
        | UnicodeData.GeneralCategory.Ll
        | UnicodeData.GeneralCategory.Lt
        | UnicodeData.GeneralCategory.Lm
        | UnicodeData.GeneralCategory.Lo));
}

/**
 * Determines if a character is a letter or a
 * decimal digit.
 *
 * Params:
 *     ch = the character to be inspected
 */
bool isLetterOrDigit(int ch) {
    UnicodeData *d = getUnicodeData(ch);
    return (d !is null) && (d.generalCategory &
        ( UnicodeData.GeneralCategory.Lu
        | UnicodeData.GeneralCategory.Ll
        | UnicodeData.GeneralCategory.Lt
        | UnicodeData.GeneralCategory.Lm
        | UnicodeData.GeneralCategory.Lo
        | UnicodeData.GeneralCategory.Nd));
}

/**
 * Determines if a character is a lower case letter.
 * Params:
 *     ch = the character to be inspected
 */
bool isLower(dchar ch) {
    UnicodeData *d = getUnicodeData(ch);
    return (d !is null) && (d.generalCategory & UnicodeData.GeneralCategory.Ll);
}

/**
 * Determines if a character is a title case letter.
 * In case of combined letters, only the first is upper and the second is lower.
 * Some of these special characters can be found in the croatian and greek language.
 * See_Also: http://en.wikipedia.org/wiki/Capitalization
 * Params:
 *     ch = the character to be inspected
 */
bool isTitle(dchar ch) {
    UnicodeData *d = getUnicodeData(ch);
    return (d !is null) && (d.generalCategory & UnicodeData.GeneralCategory.Lt);
}

/**
 * Determines if a character is a upper case letter.
 * Params:
 *     ch = the character to be inspected
 */
bool isUpper(dchar ch) {
    UnicodeData *d = getUnicodeData(ch);
    return (d !is null) && (d.generalCategory & UnicodeData.GeneralCategory.Lu);
}

/**
 * Determines if a character is a Whitespace character.
 * Whitespace characters are characters in the
 * General Catetories Zs, Zl, Zp without the No Break
 * spaces plus the control characters out of the ASCII
 * range, that are used as spaces:
 * TAB VT LF FF CR FS GS RS US NL
 *
 * WARNING: look at isSpace, maybe that function does
 *          more what you expect.
 *
 * Params:
 *     ch = the character to be inspected
 */
bool isWhitespace(dchar ch) {
    if((ch >= 0x0009 && ch <= 0x000D) || (ch >= 0x001C && ch <= 0x001F))
        return true;
    UnicodeData *d = getUnicodeData(ch);
    return (d !is null) && (d.generalCategory &
            ( UnicodeData.GeneralCategory.Zs
            | UnicodeData.GeneralCategory.Zl
            | UnicodeData.GeneralCategory.Zp))
            && ch != 0x00A0 // NBSP
            && ch != 0x202F // NARROW NBSP
            && ch != 0xFEFF; // ZERO WIDTH NBSP
}

/**
 * Detemines if a character is a Space character as
 * specified in the Unicode Standard.
 *
 * WARNING: look at isWhitespace, maybe that function does
 *          more what you expect.
 *
 * Params:
 *     ch = the character to be inspected
 */
bool isSpace(dchar ch) {
    UnicodeData *d = getUnicodeData(ch);
    return (d !is null) && (d.generalCategory &
            ( UnicodeData.GeneralCategory.Zs
            | UnicodeData.GeneralCategory.Zl
            | UnicodeData.GeneralCategory.Zp));
}


/**
 * Detemines if a character is a printable character as
 * specified in the Unicode Standard.
 *
 * Params:
 *     ch = the character to be inspected
 */
bool isPrintable(dchar ch) {
    UnicodeData *d = getUnicodeData(ch);
    return (d !is null) && !(d.generalCategory &
            ( UnicodeData.GeneralCategory.Cn
            | UnicodeData.GeneralCategory.Cc
            | UnicodeData.GeneralCategory.Cf
            | UnicodeData.GeneralCategory.Co
            | UnicodeData.GeneralCategory.Cs));
}

unittest {
    // 1) No Buffer passed, no resize, no SpecialCase

    Immut!(char)[] testString1utf8 = "\u00E4\u00F6\u00FC";
    Immut!(wchar)[] testString1utf16 = "\u00E4\u00F6\u00FC";
    Immut!(dchar)[] testString1utf32 = "\u00E4\u00F6\u00FC";
    Immut!(char)[] refString1utf8 = "\u00C4\u00D6\u00DC";
    Immut!(wchar)[] refString1utf16 = "\u00C4\u00D6\u00DC";
    Immut!(dchar)[] refString1utf32 = "\u00C4\u00D6\u00DC";
    char[] resultString1utf8 = toUpper(testString1utf8);
    assert(resultString1utf8 == refString1utf8);
    wchar[] resultString1utf16 = toUpper(testString1utf16);
    assert(resultString1utf16 == refString1utf16);
    dchar[] resultString1utf32 = toUpper(testString1utf32);
    assert(resultString1utf32 == refString1utf32);

    // 2) Buffer passed, no resize, no SpecialCase
    char[60] buffer1utf8;
    wchar[30] buffer1utf16;
    dchar[30] buffer1utf32;
    resultString1utf8 = toUpper(testString1utf8,buffer1utf8);
    assert(resultString1utf8.ptr == buffer1utf8.ptr);
    assert(resultString1utf8 == refString1utf8);
    resultString1utf16 = toUpper(testString1utf16,buffer1utf16);
    assert(resultString1utf16.ptr == buffer1utf16.ptr);
    assert(resultString1utf16 == refString1utf16);
    resultString1utf32 = toUpper(testString1utf32,buffer1utf32);
    assert(resultString1utf32.ptr == buffer1utf32.ptr);
    assert(resultString1utf32 == refString1utf32);

    // 3/ Buffer passed, resize necessary, no Special case

    char[5] buffer2utf8;
    wchar[2] buffer2utf16;
    dchar[2] buffer2utf32;
    resultString1utf8 = toUpper(testString1utf8,buffer2utf8);
    assert(resultString1utf8.ptr != buffer2utf8.ptr);
    assert(resultString1utf8 == refString1utf8);
    resultString1utf16 = toUpper(testString1utf16,buffer2utf16);
    assert(resultString1utf16.ptr != buffer2utf16.ptr);
    assert(resultString1utf16 == refString1utf16);
    resultString1utf32 = toUpper(testString1utf32,buffer2utf32);
    assert(resultString1utf32.ptr != buffer2utf32.ptr);
    assert(resultString1utf32 == refString1utf32);

    // 4) Buffer passed, resize necessary, extensive SpecialCase


    Immut!(char)[] testString2utf8 = "\uFB03\uFB04\uFB05";
    Immut!(wchar)[] testString2utf16 = "\uFB03\uFB04\uFB05";
    Immut!(dchar)[] testString2utf32 = "\uFB03\uFB04\uFB05";
    Immut!(char)[] refString2utf8 = "\u0046\u0046\u0049\u0046\u0046\u004C\u0053\u0054";
    Immut!(wchar)[] refString2utf16 = "\u0046\u0046\u0049\u0046\u0046\u004C\u0053\u0054";
    Immut!(dchar)[] refString2utf32 = "\u0046\u0046\u0049\u0046\u0046\u004C\u0053\u0054";
    resultString1utf8 = toUpper(testString2utf8,buffer2utf8);
    assert(resultString1utf8.ptr != buffer2utf8.ptr);
    assert(resultString1utf8 == refString2utf8);
    resultString1utf16 = toUpper(testString2utf16,buffer2utf16);
    assert(resultString1utf16.ptr != buffer2utf16.ptr);
    assert(resultString1utf16 == refString2utf16);
    resultString1utf32 = toUpper(testString2utf32,buffer2utf32);
    assert(resultString1utf32.ptr != buffer2utf32.ptr);
    assert(resultString1utf32 == refString2utf32);

}


unittest {
    // 1) No Buffer passed, no resize, no SpecialCase

    Immut!(char)[] testString1utf8 = "\u00C4\u00D6\u00DC";
    Immut!(wchar)[] testString1utf16 = "\u00C4\u00D6\u00DC";
    Immut!(dchar)[] testString1utf32 = "\u00C4\u00D6\u00DC";
    Immut!(char)[] refString1utf8 = "\u00E4\u00F6\u00FC";
    Immut!(wchar)[] refString1utf16 = "\u00E4\u00F6\u00FC";
    Immut!(dchar)[] refString1utf32 = "\u00E4\u00F6\u00FC";
    char[] resultString1utf8 = toLower(testString1utf8);
    assert(resultString1utf8 == refString1utf8);
    wchar[] resultString1utf16 = toLower(testString1utf16);
    assert(resultString1utf16 == refString1utf16);
    dchar[] resultString1utf32 = toLower(testString1utf32);
    assert(resultString1utf32 == refString1utf32);

    // 2) Buffer passed, no resize, no SpecialCase
    char[60] buffer1utf8;
    wchar[30] buffer1utf16;
    dchar[30] buffer1utf32;
    resultString1utf8 = toLower(testString1utf8,buffer1utf8);
    assert(resultString1utf8.ptr == buffer1utf8.ptr);
    assert(resultString1utf8 == refString1utf8);
    resultString1utf16 = toLower(testString1utf16,buffer1utf16);
    assert(resultString1utf16.ptr == buffer1utf16.ptr);
    assert(resultString1utf16 == refString1utf16);
    resultString1utf32 = toLower(testString1utf32,buffer1utf32);
    assert(resultString1utf32.ptr == buffer1utf32.ptr);
    assert(resultString1utf32 == refString1utf32);

    // 3/ Buffer passed, resize necessary, no Special case

    char[5] buffer2utf8;
    wchar[2] buffer2utf16;
    dchar[2] buffer2utf32;
    resultString1utf8 = toLower(testString1utf8,buffer2utf8);
    assert(resultString1utf8.ptr != buffer2utf8.ptr);
    assert(resultString1utf8 == refString1utf8);
    resultString1utf16 = toLower(testString1utf16,buffer2utf16);
    assert(resultString1utf16.ptr != buffer2utf16.ptr);
    assert(resultString1utf16 == refString1utf16);
    resultString1utf32 = toLower(testString1utf32,buffer2utf32);
    assert(resultString1utf32.ptr != buffer2utf32.ptr);
    assert(resultString1utf32 == refString1utf32);

    // 4) Buffer passed, resize necessary, extensive SpecialCase

    Immut!(char)[] testString2utf8 = "\u0130\u0130\u0130";
    Immut!(wchar)[] testString2utf16 = "\u0130\u0130\u0130";
    Immut!(dchar)[] testString2utf32 = "\u0130\u0130\u0130";
    Immut!(char)[] refString2utf8 = "\u0069\u0307\u0069\u0307\u0069\u0307";
    Immut!(wchar)[] refString2utf16 = "\u0069\u0307\u0069\u0307\u0069\u0307";
    Immut!(dchar)[] refString2utf32 = "\u0069\u0307\u0069\u0307\u0069\u0307";
    resultString1utf8 = toLower(testString2utf8,buffer2utf8);
    assert(resultString1utf8.ptr != buffer2utf8.ptr);
    assert(resultString1utf8 == refString2utf8);
    resultString1utf16 = toLower(testString2utf16,buffer2utf16);
    assert(resultString1utf16.ptr != buffer2utf16.ptr);
    assert(resultString1utf16 == refString2utf16);
    resultString1utf32 = toLower(testString2utf32,buffer2utf32);
    assert(resultString1utf32.ptr != buffer2utf32.ptr);
    assert(resultString1utf32 == refString2utf32);
}

unittest {
    Immut!(char)[] testString1utf8 = "?!Mädchen \u0390\u0390,;";
    Immut!(char)[] testString2utf8 = "?!MÄDCHEN \u03B9\u0308\u0301\u03B9\u0308\u0301,;";
    assert(toFold(testString1utf8) == toFold(testString2utf8));
    Immut!(wchar)[] testString1utf16 = "?!Mädchen \u0390\u0390,;";
    Immut!(wchar)[] testString2utf16 = "?!MÄDCHEN \u03B9\u0308\u0301\u03B9\u0308\u0301,;";
    assert(toFold(testString1utf16) == toFold(testString2utf16));
    Immut!(wchar)[] testString1utf32 = "?!Mädchen \u0390\u0390,;";
    Immut!(wchar)[] testString2utf32 = "?!MÄDCHEN \u03B9\u0308\u0301\u03B9\u0308\u0301,;";
    assert(toFold(testString1utf32) == toFold(testString2utf32));
}
