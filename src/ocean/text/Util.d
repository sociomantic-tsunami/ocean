/*******************************************************************************

        Placeholder for a variety of wee functions.

        Several of these functions return an index value, representing where
        some criteria was identified. When said criteria is not matched, the
        functions return a value representing the array length provided to
        them. That is, for those scenarios where C functions might typically
        return -1 these functions return length instead. This operate nicely
        with D slices:
        ---
        auto text = "happy:faces";

        assert (text[0 .. locate (text, ':')] == "happy");

        assert (text[0 .. locate (text, '!')] == "happy:faces");
        ---

        The contains() function is more convenient for trivial
        lookup cases:
        ---
        if (contains ("fubar", '!'))
            ...
        ---

        Note that where some functions expect a size_t as an argument, the
        D template-matching algorithm will fail where an int is provided
        instead. This is the typically the cause of "template not found"
        errors. Also note that name overloading is not supported cleanly
        by IFTI at this time, so is not applied here.


        Applying the D "import alias" mechanism to this module is highly
        recommended, in order to limit namespace pollution:
        ---
        import Util = ocean.text.Util;

        auto s = Util.trim ("  foo ");
        ---


        Function templates:
        ---
        trim (source)                               // trim whitespace
        triml (source)                              // trim whitespace
        trimr (source)                              // trim whitespace
        strip (source, match)                       // trim elements
        stripl (source, match)                      // trim elements
        stripr (source, match)                      // trim elements
        chopl (source, match)                       // trim pattern match
        chopr (source, match)                       // trim pattern match
        delimit (src, set)                          // split on delims
        split (source, pattern)                     // split on pattern
        splitLines (source);                        // split on lines
        head (source, pattern, tail)                // split to head & tail
        join (source, postfix, output)              // join text segments
        prefix (dst, prefix, content...)            // prefix text segments
        postfix (dst, postfix, content...)          // postfix text segments
        combine (dst, prefix, postfix, content...)  // combine lotsa stuff
        repeat (source, count, output)              // repeat source
        replace (source, match, replacement)        // replace chars
        substitute (source, match, replacement)     // replace/remove matches
        count (source, match)                       // count instances
        contains (source, match)                    // has char?
        containsPattern (source, match)             // has pattern?
        index (source, match, start)                // find match index
        locate (source, match, start)               // find char
        locatePrior (source, match, start)          // find prior char
        locatePattern (source, match, start);       // find pattern
        locatePatternPrior (source, match, start);  // find prior pattern
        indexOf (s*, match, length)                 // low-level lookup
        mismatch (s1*, s2*, length)                 // low-level compare
        matching (s1*, s2*, length)                 // low-level compare
        isSpace (match)                             // is whitespace?
        unescape(source, output)                    // convert '\' prefixes
        lines (str)                                 // foreach lines
        quotes (str, set)                           // foreach quotes
        delimiters (str, set)                       // foreach delimiters
        patterns (str, pattern)                     // foreach patterns
        ---

        Please note that any 'pattern' referred to within this module
        refers to a pattern of characters, and not some kind of regex
        descriptor. Use the Regex module for regex operation.

        Copyright:
            Copyright (c) 2004 Kris Bell.
            Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version:
            Apr 2004: Initial release
            Dec 2006: South Seas version

        Authors: Kris

*******************************************************************************/

module ocean.text.Util;

//import ocean.meta.types.Qualifiers : cstring, mstring;
import ocean.meta.types.Qualifiers;
import ocean.core.Verify;

version (unittest) import ocean.core.Test;


/******************************************************************************

        Trim the provided array by stripping whitespace from both
        ends. Returns a slice of the original content

******************************************************************************/

inout(char)[] trim (inout(char)[] source)
{
        inout(char)*   head = source.ptr,
                       tail = head + source.length;

        while (head < tail && isSpace(*head))
               ++head;

        while (tail > head && isSpace(*(tail-1)))
               --tail;

        return head [0 .. tail - head];
}

/******************************************************************************

        Trim the provided array by stripping whitespace from the left.
        Returns a slice of the original content

******************************************************************************/

inout(char)[] triml (inout(char)[] source)
{
        inout(char)*   head = source.ptr,
                       tail = head + source.length;

        while (head < tail && isSpace(*head))
               ++head;

        return head [0 .. tail - head];
}

/******************************************************************************

        Trim the provided array by stripping whitespace from the right.
        Returns a slice of the original content

******************************************************************************/

inout(char)[] trimr (inout(char)[] source)
{
        inout(char)*   head = source.ptr,
                       tail = head + source.length;

        while (tail > head && isSpace(*(tail-1)))
               --tail;

        return head [0 .. tail - head];
}

/******************************************************************************

        Trim the given array by stripping the provided match from
        both ends. Returns a slice of the original content

******************************************************************************/

inout(char)[] strip (inout(char)[] source, char match)
{
        inout(char)*   head = source.ptr,
                       tail = head + source.length;

        while (head < tail && *head is match)
               ++head;

        while (tail > head && *(tail-1) is match)
               --tail;

        return head [0 .. tail - head];
}

/******************************************************************************

        Trim the given array by stripping the provided match from
        the left hand side. Returns a slice of the original content

******************************************************************************/

inout(char)[] stripl (inout(char)[] source, char match)
{
        inout(char)* head = source.ptr,
                     tail = head + source.length;

        while (head < tail && *head is match)
               ++head;

        return head [0 .. tail - head];
}

/******************************************************************************

        Trim the given array by stripping the provided match from
        the right hand side. Returns a slice of the original content

******************************************************************************/

inout(char)[] stripr (inout(char)[] source, char match)
{
        inout(char)* head = source.ptr,
                     tail = head + source.length;

        while (tail > head && *(tail-1) is match)
               --tail;

        return head [0 .. tail - head];
}

/******************************************************************************

        Chop the given source by stripping the provided match from
        the left hand side. Returns a slice of the original content

******************************************************************************/

inout(char)[] chopl (inout(char)[] source, cstring match)
{
        if (match.length <= source.length)
            if (source[0 .. match.length] == match)
                source = source [match.length .. $];

        return source;
}

/******************************************************************************

        Chop the given source by stripping the provided match from
        the right hand side. Returns a slice of the original content

******************************************************************************/

inout(char)[] chopr (inout(char)[] source, cstring match)
{
        if (match.length <= source.length)
            if (source[$-match.length .. $] == match)
                source = source [0 .. $-match.length];

        return source;
}

/******************************************************************************

        Replace all instances of one element with another (in place)

******************************************************************************/

mstring replace (mstring source, char match, char replacement)
{
        foreach (ref c; source)
                 if (c is match)
                     c = replacement;
        return source;
}

/******************************************************************************

        Substitute all instances of match from source. Set replacement
        to null in order to remove instead of replace

******************************************************************************/

mstring substitute (cstring source, cstring match, cstring replacement)
{
        mstring output;

        foreach (s; patterns (source, match, replacement))
        {
                    output ~= s;
        }
        return output;
}

/******************************************************************************

        Count all instances of match within source

******************************************************************************/

size_t count (cstring source, cstring match)
{
        size_t c;

        foreach (s; patterns (source, match))
                    ++c;
        verify(c > 0);
        return c - 1;
}

/******************************************************************************

        Returns whether or not the provided array contains an instance
        of the given match

******************************************************************************/

bool contains (cstring source, char match)
{
        return indexOf (source.ptr, match, source.length) != source.length;
}

/******************************************************************************

        Returns whether or not the provided array contains an instance
        of the given match

******************************************************************************/

bool containsPattern (cstring source, cstring match)
{
        return locatePattern (source, match) != source.length;
}

unittest
{
    mstring greeting = "Hello world".dup;
    string satan = "Hell";
    test(containsPattern(greeting, satan), "Pattern not found");
}


/******************************************************************************

        Return the index of the next instance of 'match' starting at
        position 'start', or source.length where there is no match.

        Parameter 'start' defaults to 0

******************************************************************************/

size_t index (cstring source, cstring match, size_t start=0)
{
        return (match.length is 1) ? locate (source, match[0], start)
                                   : locatePattern (source, match, start);
}

unittest
{
    char[] url;
    size_t start;
    cstring CSLASHSLASH = "://";
    start = index(url, CSLASHSLASH);
}

/******************************************************************************

        Return the index of the prior instance of 'match' starting
        just before 'start', or source.length where there is no match.

        Parameter 'start' defaults to source.length

******************************************************************************/

size_t rindex (cstring source, cstring match, size_t start=size_t.max)
{
        return (match.length is 1) ? locatePrior (source, match[0], start)
                                   : locatePatternPrior (source, match, start);
}

/******************************************************************************

        Return the index of the next instance of 'match' starting at
        position 'start', or source.length where there is no match.

        Parameter 'start' defaults to 0

******************************************************************************/

size_t locate (cstring source, char match, size_t start=0)
{
        if (start > source.length)
            start = source.length;

        return indexOf (source.ptr+start, match, source.length - start) + start;
}

unittest
{
    size_t start;
    char[] url;
    start = locate(url, '/', start);
}

/******************************************************************************

        Return the index of the prior instance of 'match' starting
        just before 'start', or source.length where there is no match.

        Parameter 'start' defaults to source.length

******************************************************************************/

size_t locatePrior (cstring source, char match, size_t start = size_t.max)
{
        if (start > source.length)
            start = source.length;

        while (start > 0)
               if (source[--start] is match)
                   return start;
        return source.length;
}

/******************************************************************************

        Return the index of the next instance of 'match' starting at
        position 'start', or source.length where there is no match.

        Parameter 'start' defaults to 0

******************************************************************************/

size_t locatePattern (cstring source, cstring match, size_t start=0)
{
        size_t idx;
        const(char)* p = source.ptr + start;
        size_t extent = source.length - start - match.length + 1;

        if (match.length && extent <= source.length)
        {
            while (extent)
                if ((idx = indexOf (p, match[0], extent)) is extent)
                    break;
                else
                {
                    if (matching (p+=idx, match.ptr, match.length))
                        return p - source.ptr;
                    else
                    {
                        extent -= (idx+1);
                        ++p;
                    }
                }
        }

        return source.length;
}

/******************************************************************************

        Return the index of the prior instance of 'match' starting
        just before 'start', or source.length where there is no match.

        Parameter 'start' defaults to source.length

******************************************************************************/

size_t locatePatternPrior (cstring source, cstring match, size_t start=size_t.max)
{
        auto len = source.length;

        if (start > len)
            start = len;

        if (match.length && match.length <= len)
            while (start)
                  {
                  start = locatePrior (source, match[0], start);
                  if (start is len)
                      break;
                  else
                     if ((start + match.length) <= len)
                          if (matching (source.ptr+start, match.ptr, match.length))
                              return start;
                  }

        return len;
}

/******************************************************************************

        Split the provided array on the first pattern instance, and
        return the resultant head and tail. The pattern is excluded
        from the two segments.

        Where a segment is not found, tail will be null and the return
        value will be the original array.

******************************************************************************/

inout(char)[] head (inout(char)[] src, cstring pattern, out inout(char)[] tail)
{
        auto i = locatePattern (src, pattern);
        if (i != src.length)
           {
           tail = src [i + pattern.length .. $];
           src = src [0 .. i];
           }
        return src;
}

/******************************************************************************

        Split the provided array on the last pattern instance, and
        return the resultant head and tail. The pattern is excluded
        from the two segments.

        Where a segment is not found, head will be null and the return
        value will be the original array.

******************************************************************************/

inout(char)[] tail (inout(char)[] src, cstring pattern, out inout(char)[] head)
{
        auto i = locatePatternPrior (src, pattern);
        if (i != src.length)
           {
           head = src [0 .. i];
           src = src [i + pattern.length .. $];
           }
        return src;
}

/******************************************************************************

        Split the provided array wherever a delimiter-set instance is
        found, and return the resultant segments. The delimiters are
        excluded from each of the segments. Note that delimiters are
        matched as a set of alternates rather than as a pattern.

        Splitting on a single delimiter is considerably faster than
        splitting upon a set of alternatives.

        Note that the src content is not duplicated by this function,
        but is sliced instead.

******************************************************************************/

inout(char)[][] delimit (inout(char)[] src, cstring set)
{
        typeof(return) result;

        // Cast is needed to avoid instantiating `DelimFruct!(inout(char))`
        // which can't compile. We cast segment back to `inout` after so the end
        // result is still type-checked.

        foreach (segment; delimiters (cast(cstring) src, set))
                 result ~= cast(typeof(src)) segment;
        return result;
}

/******************************************************************************

        Split the provided array wherever a pattern instance is
        found, and return the resultant segments. The pattern is
        excluded from each of the segments.

        Note that the src content is not duplicated by this function,
        but is sliced instead.

******************************************************************************/

inout(char)[][] split (inout(char)[] src, cstring pattern)
{
        typeof(return) result;

        // Cast is needed to avoid instantiating `PatternFruct!(inout(char))`
        // which can't compile. We cast segment back to `inout` after so the end
        // result is still type-checked.

        foreach (segment; patterns (cast(cstring) src, pattern))
                 result ~= cast(typeof(src)) segment;
        return result;
}

/******************************************************************************

        Convert text into a set of lines, where each line is identified
        by a \n or \r\n combination. The line terminator is stripped from
        each resultant array

        Note that the src content is not duplicated by this function, but
        is sliced instead.

******************************************************************************/

inout(char)[][] toLines (inout(char)[] src)
{
        typeof(return) result;

        // Cast is needed to avoid instantiating `LineFruct!(inout(char))`
        // which can't compile. We cast line back to `inout` after so the end
        // result is still type-checked.

        foreach (line; lines (cast(cstring) src))
                 result ~= cast(typeof(src)) line;
        return result;
}

alias toLines splitLines;

/******************************************************************************

        Return the indexed line, where each line is identified by a \n
        or \r\n combination. The line terminator is stripped from the
        resultant line

        Note that src content is not duplicated by this function, but
        is sliced instead.

******************************************************************************/

inout(char)[] lineOf (inout(char)[] src, size_t index)
{
        int i = 0;

        // Cast is needed to avoid instantiating `LineFruct!(inout(char))`
        // which can't compile. We cast line back to `inout` after so the end
        // result is still type-checked.

        foreach (line; lines(cast(cstring) src))
                 if (i++ is index)
                     return cast(typeof(return)) line;
        return null;
}

/******************************************************************************

        Combine a series of text segments together, each appended with
        a postfix pattern. An optional output buffer can be provided to
        avoid heap activity - it should be large enough to contain the
        entire output, otherwise the heap will be used instead.

        Returns a valid slice of the output, containing the concatenated
        text.

******************************************************************************/

mstring join (const(char[])[] src, cstring postfix=null, mstring dst = null)
{
        return combine(dst, null, postfix, src);
}

unittest
{
    test (join([ "aaa", "bbb", "ccc" ], ",") == "aaa,bbb,ccc");

    // ensure `join` works with differently qualified arguments
    const(char[][]) mut = [ "xxx".dup, "yyy".dup, "zzz" ];
    char[20] buf;
    auto ret = join(mut, " ", buf);
    test (ret == "xxx yyy zzz");
    test (ret.ptr is buf.ptr);
}

/******************************************************************************

        Combine a series of text segments together, each prepended with
        a prefix pattern. An optional output buffer can be provided to
        avoid heap activity - it should be large enough to contain the
        entire output, otherwise the heap will be used instead.

        Note that, unlike join(), the output buffer is specified first
        such that a set of trailing strings can be provided.

        Returns a valid slice of the output, containing the concatenated
        text.

******************************************************************************/

mstring prefix (mstring dst, cstring prefix, const(char[])[] src...)
{
        return combine(dst, prefix, null, src);
}

/******************************************************************************

        Combine a series of text segments together, each appended with an
        optional postfix pattern. An optional output buffer can be provided
        to avoid heap activity - it should be large enough to contain the
        entire output, otherwise the heap will be used instead.

        Note that, unlike join(), the output buffer is specified first
        such that a set of trailing strings can be provided.

        Returns a valid slice of the output, containing the concatenated
        text.

******************************************************************************/

mstring postfix (mstring dst, cstring postfix, cstring[] src...)
{
        return combine(dst, null, postfix, src);
}

/******************************************************************************

        Combine a series of text segments together, each prefixed and/or
        postfixed with optional strings. An optional output buffer can be
        provided to avoid heap activity - which should be large enough to
        contain the entire output, otherwise the heap will be used instead.

        Note that, unlike join(), the output buffer is specified first
        such that a set of trailing strings can be provided.

        Returns a valid slice of the output, containing the concatenated
        text.

******************************************************************************/

mstring combine (mstring dst, cstring prefix, cstring postfix, const(char[])[] src ...)
{
        size_t len = src.length * prefix.length +
                   src.length * postfix.length;

        foreach (segment; src)
                 len += segment.length;

        if (dst.length < len)
            dst.length = len;

        auto p = dst.ptr;
        foreach (segment; src)
                {
                p[0 .. prefix.length] = prefix;
                p += prefix.length;
                p[0 .. segment.length] = segment;
                p += segment.length;
                p[0 .. postfix.length] = postfix;
                p += postfix.length;
                }

        // remove trailing seperator
        if (len)
            len -= postfix.length;
        return dst [0 .. len];
}

/******************************************************************************

        Repeat an array for a specific number of times. An optional output
        buffer can be provided to avoid heap activity - it should be large
        enough to contain the entire output, otherwise the heap will be used
        instead.

        Returns a valid slice of the output, containing the concatenated
        text.

******************************************************************************/

mstring repeat (cstring src, size_t count, mstring dst=null)
{
        size_t len = src.length * count;
        if (len is 0)
            return null;

        if (dst.length < len)
            dst.length = len;

        for (auto p = dst.ptr; count--; p += src.length)
             p[0 .. src.length] = src;

        return dst [0 .. len];
}

/******************************************************************************

        Is the argument a whitespace character?

******************************************************************************/

bool isSpace (char c)
{
        return (c <= 32 && (c is ' ' || c is '\t' || c is '\r' || c is '\n' || c is '\f' || c is '\v'));
}

/******************************************************************************

        Return whether or not the two arrays have matching content

******************************************************************************/

bool matching (const(char)* s1, const(char)* s2, size_t length)
{
        return mismatch(s1, s2, length) is length;
}

/******************************************************************************

        Returns the index of the first match in str, failing once
        length is reached. Note that we return 'length' for failure
        and a 0-based index on success

******************************************************************************/

size_t indexOf (const(char)* str, char match, size_t length)
{
        enum m1 = cast(size_t) 0x0101010101010101;
        enum m2 = cast(size_t) 0x8080808080808080;

        if (length)
        {
           size_t m = match;
           m += m << 8;
           m += (m << (8 * 2));
           m += (m << (8 * 4));

           auto p = str;
           auto e = p + length - size_t.sizeof;
           while (p < e)
           {
                 // clear matching T segments
                 auto v = (*cast(size_t*) p) ^ m;
                 // test for zero, courtesy of Alan Mycroft
                 if ((v - m1) & ~v & m2)
                      break;
                 p += size_t.sizeof;
           }

           e += size_t.sizeof;
           while (p < e)
                  if (*p++ is match)
                      return cast(size_t) (p - str - 1);
        }
        return length;
}

/******************************************************************************

        Returns the index of a mismatch between s1 & s2, failing when
        length is reached. Note that we return 'length' upon failure
        (array content matches) and a 0-based index upon success.

        Use this as a faster opEquals. Also provides the basis for a
        faster opCmp, since the index of the first mismatched character
        can be used to determine the return value

******************************************************************************/

size_t mismatch (const(char)* s1, const(char)* s2, size_t length)
{
        verify(s1 && s2);

        if (length)
        {
           auto start = s1;
           auto e = start + length - size_t.sizeof;

           while (s1 < e)
                 {
                 if (*cast(size_t*) s1 != *cast(size_t*) s2)
                     break;
                 s1 += size_t.sizeof;
                 s2 += size_t.sizeof;
                 }

           e += size_t.sizeof;
           while (s1 < e)
                  if (*s1++ != *s2++)
                      return s1 - start - 1;
        }

        return length;
}

/******************************************************************************

        Iterator to isolate lines.

        Converts text into a set of lines, where each line is identified
        by a \n or \r\n combination. The line terminator is stripped from
        each resultant array.

        ---
        foreach (line; lines ("one\ntwo\nthree"))
                 ...
        ---

******************************************************************************/

LineFruct!(T) lines(T) (T[] src)
{
        LineFruct!(T) lines;
        lines.src = src;
        return lines;
}

/******************************************************************************

        Iterator to isolate text elements.

        Splits the provided array wherever a delimiter-set instance is
        found, and return the resultant segments. The delimiters are
        excluded from each of the segments. Note that delimiters are
        matched as a set of alternates rather than as a pattern.

        Splitting on a single delimiter is considerably faster than
        splitting upon a set of alternatives.

        ---
        foreach (segment; delimiters ("one,two;three", ",;"))
                 ...
        ---

        Has to be templated to propagate mutable/const input qualifier to
        return struct.

******************************************************************************/

DelimFruct!T delimiters (T) (T[] src, cstring set)
{
        DelimFruct!T elements;
        elements.set = set;
        elements.src = src;
        return elements;
}

/******************************************************************************

        Iterator to isolate text elements.

        Split the provided array wherever a pattern instance is found,
        and return the resultant segments. Pattern are excluded from
        each of the segments, and an optional sub argument enables
        replacement.

        ---
        foreach (segment; patterns ("one, two, three", ", "))
                 ...
        ---

******************************************************************************/

PatternFruct!T patterns(T) (T[] src, cstring pattern, T[] sub = null)
{
        PatternFruct!T elements;
        elements.pattern = pattern;
        elements.sub = sub;
        elements.src = src;
        return elements;
}

unittest
{
    cstring[] arr;
    foreach (match; patterns("aaa..bbb..ccc", ".."))
        arr ~= match;
    test (arr == [ "aaa", "bbb", "ccc" ]);

    arr = [ ];
    foreach (match; patterns("aaa..bbb..ccc", "..", "X"))
        arr ~= match;
    test (arr == [ "aaa", "X", "bbb", "X", "ccc" ]);
}

/******************************************************************************

        Iterator to isolate optionally quoted text elements.

        As per elements(), but with the extension of being quote-aware;
        the set of delimiters is ignored inside a pair of quotes. Note
        that an unterminated quote will consume remaining content.

        ---
        foreach (quote; quotes ("one two 'three four' five", " "))
                 ...
        ---

******************************************************************************/

QuoteFruct!T quotes(T) (T[] src, cstring set)
{
        QuoteFruct!T quotes;
        quotes.set = set;
        quotes.src = src;
        return quotes;
}

/******************************************************************************

        Convert 'escaped' chars to normal ones: \t => ^t for example.
        Supports \" \' \\ \a \b \f \n \r \t \v

******************************************************************************/

cstring unescape (cstring src, mstring dst = null)
{
        ptrdiff_t delta;
        auto s = src.ptr;
        auto len = src.length;

        // take a peek first to see if there's anything
        if ((delta = indexOf (s, '\\', len)) < len)
           {
           // make some room if not enough provided
           if (dst.length < src.length)
               dst.length = src.length;
           auto d = dst.ptr;

           // copy segments over, a chunk at a time
           do {
              d [0 .. delta] = s [0 .. delta];
              len -= delta;
              s += delta;
              d += delta;

              // bogus trailing '\'
              if (len < 2)
                 {
                 *d++ = '\\';
                 len = 0;
                 break;
                 }

              // translate \char
              char c = s[1];
              switch (c)
                     {
                      case '\\':
                           break;
                      case '\'':
                           c = '\'';
                           break;
                      case '"':
                           c = '"';
                           break;
                      case 'a':
                           c = '\a';
                           break;
                      case 'b':
                           c = '\b';
                           break;
                      case 'f':
                           c = '\f';
                           break;
                      case 'n':
                           c = '\n';
                           break;
                      case 'r':
                           c = '\r';
                           break;
                      case 't':
                           c = '\t';
                           break;
                      case 'v':
                           c = '\v';
                           break;
                      default:
                           *d++ = '\\';
                     }
              *d++ = c;
              len -= 2;
              s += 2;
              } while ((delta = indexOf (s, '\\', len)) < len);

           // copy tail too
           d [0 .. len] = s [0 .. len];
           return dst [0 .. (d + len) - dst.ptr];
           }
        return src;
}


/******************************************************************************

        jhash() -- hash a variable-length key into a 32-bit value

          k     : the key (the unaligned variable-length array of bytes)
          len   : the length of the key, counting by bytes
          level : can be any 4-byte value

        Returns a 32-bit value.  Every bit of the key affects every bit of
        the return value.  Every 1-bit and 2-bit delta achieves avalanche.

        About 4.3*len + 80 X86 instructions, with excellent pipelining

        The best hash table sizes are powers of 2.  There is no need to do
        mod a prime (mod is sooo slow!).  If you need less than 32 bits,
        use a bitmask.  For example, if you need only 10 bits, do

                    h = (h & hashmask(10));

        In which case, the hash table should have hashsize(10) elements.
        If you are hashing n strings (ub1 **)k, do it like this:

                    for (i=0, h=0; i<n; ++i) h = hash( k[i], len[i], h);

        By Bob Jenkins, 1996.  bob_jenkins@burtleburtle.net.  You may use
        this code any way you wish, private, educational, or commercial.
        It's free.

        See http://burtleburtle.net/bob/hash/evahash.html
        Use for hash table lookup, or anything where one collision in 2^32
        is acceptable. Do NOT use for cryptographic purposes.

******************************************************************************/

size_t jhash (ubyte* k, size_t len, size_t c = 0)
{
        size_t a = 0x9e3779b9,
             b = 0x9e3779b9,
             i = len;

        // handle most of the key
        while (i >= 12)
              {
              a += *cast(uint *)(k+0);
              b += *cast(uint *)(k+4);
              c += *cast(uint *)(k+8);

              a -= b; a -= c; a ^= (c>>13);
              b -= c; b -= a; b ^= (a<<8);
              c -= a; c -= b; c ^= (b>>13);
              a -= b; a -= c; a ^= (c>>12);
              b -= c; b -= a; b ^= (a<<16);
              c -= a; c -= b; c ^= (b>>5);
              a -= b; a -= c; a ^= (c>>3);
              b -= c; b -= a; b ^= (a<<10);
              c -= a; c -= b; c ^= (b>>15);
              k += 12; i -= 12;
              }

        // handle the last 11 bytes
        c += len;
        switch (i)
               {
               case 11: c+=(cast(uint)k[10]<<24); goto case;
               case 10: c+=(cast(uint)k[9]<<16); goto case;
               case 9 : c+=(cast(uint)k[8]<<8); goto case;
               case 8 : b+=(cast(uint)k[7]<<24); goto case;
               case 7 : b+=(cast(uint)k[6]<<16); goto case;
               case 6 : b+=(cast(uint)k[5]<<8); goto case;
               case 5 : b+=(cast(uint)k[4]); goto case;
               case 4 : a+=(cast(uint)k[3]<<24); goto case;
               case 3 : a+=(cast(uint)k[2]<<16); goto case;
               case 2 : a+=(cast(uint)k[1]<<8); goto case;
               case 1 : a+=(cast(uint)k[0]); goto default;
               default:
               }

        a -= b; a -= c; a ^= (c>>13);
        b -= c; b -= a; b ^= (a<<8);
        c -= a; c -= b; c ^= (b>>13);
        a -= b; a -= c; a ^= (c>>12);
        b -= c; b -= a; b ^= (a<<16);
        c -= a; c -= b; c ^= (b>>5);
        a -= b; a -= c; a ^= (c>>3);
        b -= c; b -= a; b ^= (a<<10);
        c -= a; c -= b; c ^= (b>>15);

        return c;
}

/// ditto
size_t jhash (void[] x, size_t c = 0)
{
        return jhash (cast(ubyte*) x.ptr, x.length, c);
}


/******************************************************************************

        Helper fruct for iterator lines(). A fruct is a low
        impact mechanism for capturing context relating to an
        opApply (conjunction of the names struct and foreach)

******************************************************************************/

private struct LineFruct(T)
{
        private T[] src;

        int opApply (scope int delegate (ref T[] line) dg)
        {
                int     ret;
                size_t  pos,
                        mark;
                T[]     line;

                enum T nl = '\n';
                enum T cr = '\r';

                while ((pos = locate (src, nl, mark)) < src.length)
                      {
                      auto end = pos;
                      if (end && src[end-1] is cr)
                          --end;

                      line = src [mark .. end];
                      if ((ret = dg (line)) != 0)
                           return ret;
                      mark = pos + 1;
                      }

                line = src [mark .. $];
                if (mark <= src.length)
                    ret = dg (line);

                return ret;
        }
}

/******************************************************************************

        Helper fruct for iterator delims(). A fruct is a low
        impact mechanism for capturing context relating to an
        opApply (conjunction of the names struct and foreach)

******************************************************************************/

private struct DelimFruct (T)
{
        private T[]     src;
        private cstring set;

        int opApply (scope int delegate (ref T[] token) dg)
        {
                int     ret;
                size_t  pos,
                        mark;
                T[]     token;

                // optimize for single delimiter case
                if (set.length is 1)
                    while ((pos = locate (src, set[0], mark)) < src.length)
                          {
                          token = src [mark .. pos];
                          if ((ret = dg (token)) != 0)
                               return ret;
                          mark = pos + 1;
                          }
                else
                   if (set.length > 1)
                       foreach (i, elem; src)
                                if (contains (set, elem))
                                   {
                                   token = src [mark .. i];
                                   if ((ret = dg (token)) != 0)
                                        return ret;
                                   mark = i + 1;
                                   }

                token = src [mark .. $];
                if (mark <= src.length)
                    ret = dg (token);

                return ret;
        }
}

/******************************************************************************

        Helper fruct for iterator patterns(). A fruct is a low
        impact mechanism for capturing context relating to an
        opApply (conjunction of the names struct and foreach)

******************************************************************************/

public struct PatternFruct (T)
{
        private T[] src, sub;
        private cstring pattern;

        int opApply (scope int delegate (ref T[] token) dg)
        {
                int     ret;
                size_t  pos,
                        mark;
                T[]     token;

                while ((pos = index (src, pattern, mark)) < src.length)
                      {
                      token = src [mark .. pos];
                      if ((ret = dg(token)) != 0)
                           return ret;
                      if (sub.ptr && (ret = dg(sub)) != 0)
                          return ret;
                      mark = pos + pattern.length;
                      }

                token = src [mark .. $];
                if (mark <= src.length)
                    ret = dg (token);

                return ret;
        }
}

/******************************************************************************

        Helper fruct for iterator quotes(). A fruct is a low
        impact mechanism for capturing context relating to an
        opApply (conjunction of the names struct and foreach)

******************************************************************************/

private struct QuoteFruct (T)
{
        private T[]     src;
        private cstring set;

        int opApply (scope int delegate (ref T[] token) dg)
        {
                int     ret;
                size_t  mark;
                T[]     token;

                if (set.length)
                    for (size_t i=0; i < src.length; ++i)
                        {
                        T c = src[i];
                        if (c is '"' || c is '\'')
                            i = locate (src, c, i+1);
                        else
                           if (contains (set, c))
                              {
                              token = src [mark .. i];
                              if ((ret = dg (token)) != 0)
                                   return ret;
                              mark = i + 1;
                              }
                        }

                token = src [mark .. $];
                if (mark <= src.length)
                    ret = dg (token);

                return ret;
        }
}


/******************************************************************************

******************************************************************************/

unittest
{
    char[64] tmp;

    test (isSpace (' ') && !isSpace ('d'));

    test (indexOf ("abc".ptr, 'a', 3) is 0);
    test (indexOf ("abc".ptr, 'b', 3) is 1);
    test (indexOf ("abc".ptr, 'c', 3) is 2);
    test (indexOf ("abc".ptr, 'd', 3) is 3);
    test (indexOf ("abcabcabc".ptr, 'd', 9) is 9);

    test (mismatch ("abc".ptr, "abc".ptr, 3) is 3);
    test (mismatch ("abc".ptr, "abd".ptr, 3) is 2);
    test (mismatch ("abc".ptr, "acc".ptr, 3) is 1);
    test (mismatch ("abc".ptr, "ccc".ptr, 3) is 0);

    test (matching ("abc".ptr, "abc".ptr, 3));
    test (matching ("abc".ptr, "abb".ptr, 3) is false);

    test (contains ("abc", 'a'));
    test (contains ("abc", 'b'));
    test (contains ("abc", 'c'));
    test (contains ("abc", 'd') is false);

    test (containsPattern ("abc", "ab"));
    test (containsPattern ("abc", "bc"));
    test (containsPattern ("abc", "abc"));
    test (containsPattern ("abc", "zabc") is false);
    test (containsPattern ("abc", "abcd") is false);
    test (containsPattern ("abc", "za") is false);
    test (containsPattern ("abc", "cd") is false);

    test (trim ("") == "");
    test (trim (" abc  ") == "abc");
    test (trim ("   ") == "");

    test (strip ("", '%') == "");
    test (strip ("%abc%%%", '%') == "abc");
    test (strip ("#####", '#') == "");
    test (stripl ("#####", '#') == "");
    test (stripl (" ###", ' ') == "###");
    test (stripl ("#####", 's') == "#####");
    test (stripr ("#####", '#') == "");
    test (stripr ("### ", ' ') == "###");
    test (stripr ("#####", 's') == "#####");

    test (replace ("abc".dup, 'b', ':') == "a:c");
    test (substitute ("abc", "bc", "x") == "ax");

    test (locate ("abc".dup, 'c', 1) is 2);

    test (locate ("abc", 'c') is 2);
    test (locate ("abc", 'a') is 0);
    test (locate ("abc", 'd') is 3);
    test (locate ("", 'c') is 0);

    test (locatePrior ("abce".dup, 'c') is 2);
    test (locatePrior ("abce", 'a') is 0);
    test (locatePrior ("abce", 'd') is 4);
    test (locatePrior ("abce", 'c', 3) is 2);
    test (locatePrior ("abce", 'c', 2) is 4);
    test (locatePrior ("", 'c') is 0);

    auto x = delimit ("::b", ":");
    test (x.length is 3 && x[0] == "" && x[1] == "" && x[2] == "b");
    x = delimit ("a:bc:d", ":");
    test (x.length is 3 && x[0] == "a" && x[1] == "bc" && x[2] == "d");
    x = delimit ("abcd", ":");
    test (x.length is 1 && x[0] == "abcd");
    x = delimit ("abcd:", ":");
    test (x.length is 2 && x[0] == "abcd" && x[1] == "");
    x = delimit ("a;b$c#d:e@f", ";:$#@");
    test (x.length is 6 && x[0]=="a" && x[1]=="b" && x[2]=="c" &&
            x[3]=="d" && x[4]=="e" && x[5]=="f");

    test (locatePattern ("abcdefg".dup, "") is 7);
    test (locatePattern ("abcdefg", "g") is 6);
    test (locatePattern ("abcdefg", "abcdefg") is 0);
    test (locatePattern ("abcdefg", "abcdefgx") is 7);
    test (locatePattern ("abcdefg", "cce") is 7);
    test (locatePattern ("abcdefg", "cde") is 2);
    test (locatePattern ("abcdefgcde", "cde", 3) is 7);

    test (locatePatternPrior ("abcdefg".dup, "") is 7);
    test (locatePatternPrior ("abcdefg", "cce") is 7);
    test (locatePatternPrior ("abcdefg", "cde") is 2);
    test (locatePatternPrior ("abcdefgcde", "cde", 6) is 2);
    test (locatePatternPrior ("abcdefgcde", "cde", 4) is 2);
    test (locatePatternPrior ("abcdefg", "abcdefgx") is 7);

    x = splitLines ("a\nb\n");
    test (x.length is 3 && x[0] == "a" && x[1] == "b" && x[2] == "");
    x = splitLines ("a\r\n");
    test (x.length is 2 && x[0] == "a" && x[1] == "");

    x = splitLines ("a");
    test (x.length is 1 && x[0] == "a");
    x = splitLines ("");
    test (x.length is 1);

    cstring[] q;
    foreach (element; quotes ("1 'avcc   cc ' 3", " "))
        q ~= element;
    test (q.length is 3 && q[0] == "1" && q[1] == "'avcc   cc '" && q[2] == "3");

    x = split ("one, two, three", ",");
    test (x.length is 3 && x[0] == "one" && x[1] == " two" && x[2] == " three");
    x = split ("one, two, three", ", ");
    test (x.length is 3 && x[0] == "one" && x[1] == "two" && x[2] == "three");
    x = split ("one, two, three", ",,");
    test (x.length is 1 && x[0] == "one, two, three");
    x = split ("one,,", ",");
    test (x.length is 3 && x[0] == "one" && x[1] == "" && x[2] == "");

    string t, h;
    h =  head ("one:two:three", ":", t);
    test (h == "one" && t == "two:three");
    h = head ("one:::two:three", ":::", t);
    test (h == "one" && t == "two:three");
    h = head ("one:two:three", "*", t);
    test (h == "one:two:three" && t is null);

    t =  tail ("one:two:three", ":", h);
    test (h == "one:two" && t == "three");
    t = tail ("one:::two:three", ":::", h);
    test (h == "one" && t == "two:three");
    t = tail ("one:two:three", "*", h);
    test (t == "one:two:three" && h is null);

    test (chopl("hello world", "hello ") == "world");
    test (chopl("hello", "hello") == "");
    test (chopl("hello world", " ") == "hello world");
    test (chopl("hello world", "") == "hello world");

    test (chopr("hello world", " world") == "hello");
    test (chopr("hello", "hello") == "");
    test (chopr("hello world", " ") == "hello world");
    test (chopr("hello world", "") == "hello world");

    string[] foo = ["one", "two", "three"];
    auto j = join (foo);
    test (j == "onetwothree");
    j = join (foo, ", ");
    test (j == "one, two, three");
    j = join (foo, " ", tmp);
    test (j == "one two three");
    test (j.ptr is tmp.ptr);

    test (repeat ("abc", 0) == "");
    test (repeat ("abc", 1) == "abc");
    test (repeat ("abc", 2) == "abcabc");
    test (repeat ("abc", 4) == "abcabcabcabc");
    test (repeat ("", 4) == "");
    char[10] rep;
    test (repeat ("abc", 0, rep) == "");
    test (repeat ("abc", 1, rep) == "abc");
    test (repeat ("abc", 2, rep) == "abcabc");
    test (repeat ("", 4, rep) == "");

    test (unescape ("abc") == "abc");
    test (unescape ("abc\\") == "abc\\");
    test (unescape ("abc\\t") == "abc\t");
    test (unescape ("abc\\tc") == "abc\tc");
    test (unescape ("\\t") == "\t");
    test (unescape ("\\tx") == "\tx");
    test (unescape ("\\v\\vx") == "\v\vx");
    test (unescape ("abc\\t\\a\\bc") == "abc\t\a\bc");
}

debug (Util)
{
        auto x = import("Util.d");

        void main()
        {
                mismatch ("".ptr, x.ptr, 0);
                indexOf ("".ptr, '@', 0);
                char[] s;
                split (s, " ");
                //indexOf (s.ptr, '@', 0);

        }
}
