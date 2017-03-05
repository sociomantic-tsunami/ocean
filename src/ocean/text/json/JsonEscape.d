/*******************************************************************************

        Copyright:
            Copyright (C) 2008 Kris Bell,
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: July 2008: Initial release

        Authors: Kris

*******************************************************************************/

module ocean.text.json.JsonEscape;

import ocean.transition;

import ocean.text.json.JsonParser;

import Util = ocean.text.Util;

import Utf = ocean.text.convert.Utf;

/******************************************************************************

        Convert 'escaped' chars to normal ones. For example: \\ => \

        The provided output buffer should be at least as long as the
        input string, or it will be allocated from the heap instead.

        Returns a slice of dst where the content required conversion,
        or the provided src otherwise

******************************************************************************/

TC[] unescape(T, TC = Unqual!(T)) (T[] src, TC[] dst = null)
{
        size_t content;

        void append (Const!(Unqual!(T))[] s)
        {
                if (content + s.length > dst.length)
                    dst.length = dst.length + s.length + 1024;
                dst[content .. content+s.length] = s;
                content += s.length;
        }

        unescape (src, &append);
        return dst [0 .. content];
}

unittest
{
    auto s = unescape("aaa\\\\b");
    assert (s == "aaa\\b");
}


/******************************************************************************

        Convert reserved chars to escaped ones. For example: \ => \\

        Either a slice of the provided output buffer is returned, or the
        original content, depending on whether there were reserved chars
        present or not. The output buffer will be expanded as necessary

******************************************************************************/

TC[] escape(T, TC = Unqual!(T)) (T[] src, TC[] dst = null)
{
        size_t content;

        void append (Const!(Unqual!(T))[] s)
        {
                if (content + s.length > dst.length)
                    dst.length = dst.length + s.length + 1024;
                dst[content .. content+s.length] = s;
                content += s.length;
        }

        escape (src, &append);
        return dst [0..content];
}

unittest
{
    auto s = escape("aaa\\");
    assert (s == "aaa\\\\");
}


/******************************************************************************

        Convert 'escaped' chars to normal ones. For example: \\ => \

        This variant does not require an interim workspace, and instead
        emits directly via the provided delegate

******************************************************************************/

void unescape(T, TC) (T[] src, void delegate(TC[]) emit)
{
        static assert (is(Unqual!(T) == Unqual!(TC)));

        ptrdiff_t delta;
        auto s = src.ptr;
        auto len = src.length;
        enum : T { slash = '\\' }

        // take a peek first to see if there's anything
        if ((delta = Util.indexOf (s, slash, len)) < len)
           {
           // copy segments over, a chunk at a time
           do {
              emit (s[0 .. delta]);
              len -= delta;
              s += delta;

              // bogus trailing '\'
              if (len < 2)
                 {
                 emit ("\\");
                 len = 0;
                 break;
                 }

              // translate \c
              switch (s[1])
                     {
                      case '\\':
                           emit ("\\");
                           break;

                      case '/':
                           emit ("/");
                           break;

                      case '"':
                           emit (`"`);
                           break;

                      case 'b':
                           emit ("\b");
                           break;

                      case 'f':
                           emit ("\f");
                           break;

                      case 'n':
                           emit ("\n");
                           break;

                      case 'r':
                           emit ("\r");
                           break;

                      case 't':
                           emit ("\t");
                           break;

                      case 'u':
                           if (len < 6)
                               goto default;
                           else
                              {
                              dchar v = 0;
                              Unqual!(T)[6]  t = void;

                              for (auto i=2; i < 6; ++i)
                                  {
                                  Unqual!(T) c = s[i];
                                  if (c >= '0' && c <= '9')
                                     {}
                                  else
                                     if (c >= 'a' && c <= 'f')
                                         c -= 39;
                                     else
                                        if (c >= 'A' && c <= 'F')
                                            c -= 7;
                                        else
                                           goto default;
                                  v = (v << 4) + c - '0';
                                  }

                              emit (Utf.fromString32 ((&v)[0..1], t));
                              len -= 4;
                              s += 4;
                              }
                           break;

                      default:
                           throw new Exception ("invalid escape");
                     }

              s += 2;
              len -= 2;
              } while ((delta = Util.indexOf (s, slash, len)) < len);

           // copy tail too
           emit (s [0 .. len]);
           }
        else
           emit (src);
}


/******************************************************************************

        Convert reserved chars to escaped ones. For example: \ => \\

        This variant does not require an interim workspace, and instead
        emits directly via the provided delegate

******************************************************************************/

void escape(T, TC) (T[] src, void delegate(TC[]) emit)
{
        static assert (is(Unqual!(TC) == Unqual!(T)));

        Unqual!(T)[2] patch = '\\';
        auto s = src.ptr;
        auto t = s;
        auto e = s + src.length;

        while (s < e)
              {
              switch (*s)
                     {
                     case '"':
                     case '/':
                     case '\\':
                          patch[1] = *s;
                          break;
                     case '\r':
                          patch[1] = 'r';
                          break;
                     case '\n':
                          patch[1] = 'n';
                          break;
                     case '\t':
                          patch[1] = 't';
                          break;
                     case '\b':
                          patch[1] = 'b';
                          break;
                     case '\f':
                          patch[1] = 'f';
                          break;
                     default:
                          ++s;
                          continue;
                     }
              emit (t [0 .. s - t]);
              emit (patch[]);
              t = ++s;
              }

        // did we change anything? Copy tail also
        if (t is src.ptr)
            emit (src);
        else
           emit (t [0 .. e - t]);
}


/******************************************************************************

******************************************************************************/

debug (JsonEscape)
{
        import ocean.io.Stdout;

        void main()
        {
                escape ("abc");
                assert (escape ("abc") == "abc");
                assert (escape ("/abc") == `\/abc`, escape ("/abc"));
                assert (escape ("ab\\c") == `ab\\c`, escape ("ab\\c"));
                assert (escape ("abc\"") == `abc\"`);
                assert (escape ("abc/") == `abc\/`);
                assert (escape ("\n\t\r\b\f") == `\n\t\r\b\f`);

                unescape ("abc");
                unescape ("abc\\u0020x", (char[] p){Stdout(p);});
                assert (unescape ("abc") == "abc");
                assert (unescape ("abc\\") == "abc\\");
                assert (unescape ("abc\\t") == "abc\t");
                assert (unescape ("abc\\tc") == "abc\tc");
                assert (unescape ("\\t") == "\t");
                assert (unescape ("\\tx") == "\tx");
                assert (unescape ("\\r\\rx") == "\r\rx");
                assert (unescape ("abc\\t\\n\\bc") == "abc\t\n\bc");

                assert (unescape ("abc\"\\n\\bc") == "abc\"\n\bc");
                assert (unescape ("abc\\u002bx") == "abc+x");
        }

}
