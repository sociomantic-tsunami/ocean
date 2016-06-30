/******************************************************************************

    Bindings to GLIB unicode manipulation functions.

    Documentation:

        http://www.gtk.org/api/2.6/glib/glib-Unicode-Manipulation.html

    Note: Requires linking against -lglib-2.0

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

 /*****************************************************************************/

module ocean.text.utf.c.glib_unicode;

import ocean.transition;

enum GUnicodeType
{
    G_UNICODE_CONTROL,
    G_UNICODE_FORMAT,
    G_UNICODE_UNASSIGNED,
    G_UNICODE_PRIVATE_USE,
    G_UNICODE_SURROGATE,
    G_UNICODE_LOWERCASE_LETTER,
    G_UNICODE_MODIFIER_LETTER,
    G_UNICODE_OTHER_LETTER,
    G_UNICODE_TITLECASE_LETTER,
    G_UNICODE_UPPERCASE_LETTER,
    G_UNICODE_COMBINING_MARK,
    G_UNICODE_ENCLOSING_MARK,
    G_UNICODE_NON_SPACING_MARK,
    G_UNICODE_DECIMAL_NUMBER,
    G_UNICODE_LETTER_NUMBER,
    G_UNICODE_OTHER_NUMBER,
    G_UNICODE_CONNECT_PUNCTUATION,
    G_UNICODE_DASH_PUNCTUATION,
    G_UNICODE_CLOSE_PUNCTUATION,
    G_UNICODE_FINAL_PUNCTUATION,
    G_UNICODE_INITIAL_PUNCTUATION,
    G_UNICODE_OTHER_PUNCTUATION,
    G_UNICODE_OPEN_PUNCTUATION,
    G_UNICODE_CURRENCY_SYMBOL,
    G_UNICODE_MODIFIER_SYMBOL,
    G_UNICODE_MATH_SYMBOL,
    G_UNICODE_OTHER_SYMBOL,
    G_UNICODE_LINE_SEPARATOR,
    G_UNICODE_PARAGRAPH_SEPARATOR,
    G_UNICODE_SPACE_SEPARATOR
}

enum GUnicodeBreakType
{
    G_UNICODE_BREAK_MANDATORY,
    G_UNICODE_BREAK_CARRIAGE_RETURN,
    G_UNICODE_BREAK_LINE_FEED,
    G_UNICODE_BREAK_COMBINING_MARK,
    G_UNICODE_BREAK_SURROGATE,
    G_UNICODE_BREAK_ZERO_WIDTH_SPACE,
    G_UNICODE_BREAK_INSEPARABLE,
    G_UNICODE_BREAK_NON_BREAKING_GLUE,
    G_UNICODE_BREAK_CONTINGENT,
    G_UNICODE_BREAK_SPACE,
    G_UNICODE_BREAK_AFTER,
    G_UNICODE_BREAK_BEFORE,
    G_UNICODE_BREAK_BEFORE_AND_AFTER,
    G_UNICODE_BREAK_HYPHEN,
    G_UNICODE_BREAK_NON_STARTER,
    G_UNICODE_BREAK_OPEN_PUNCTUATION,
    G_UNICODE_BREAK_CLOSE_PUNCTUATION,
    G_UNICODE_BREAK_QUOTATION,
    G_UNICODE_BREAK_EXCLAMATION,
    G_UNICODE_BREAK_IDEOGRAPHIC,
    G_UNICODE_BREAK_NUMERIC,
    G_UNICODE_BREAK_INFIX_SEPARATOR,
    G_UNICODE_BREAK_SYMBOL,
    G_UNICODE_BREAK_ALPHABETIC,
    G_UNICODE_BREAK_PREFIX,
    G_UNICODE_BREAK_POSTFIX,
    G_UNICODE_BREAK_COMPLEX_CONTEXT,
    G_UNICODE_BREAK_AMBIGUOUS,
    G_UNICODE_BREAK_UNKNOWN,
    G_UNICODE_BREAK_NEXT_LINE,
    G_UNICODE_BREAK_WORD_JOINER
};

enum GNormalizeMode
{
    G_NORMALIZE_DEFAULT,
    G_NORMALIZE_NFD             = G_NORMALIZE_DEFAULT,
    G_NORMALIZE_DEFAULT_COMPOSE,
    G_NORMALIZE_NFC             = G_NORMALIZE_DEFAULT_COMPOSE,
    G_NORMALIZE_ALL,
    G_NORMALIZE_NFKD            = G_NORMALIZE_ALL,
    G_NORMALIZE_ALL_COMPOSE,
    G_NORMALIZE_NFKC            = G_NORMALIZE_ALL_COMPOSE
}

enum GUtf8Validation: dchar
{
    Invalid    = cast (dchar) -1,
    Incomplete = cast (dchar) -2
}

extern (C) static:

struct GError
{
    uint   domain;
    int    code;
    char*  message;
}


bool                g_unichar_validate      (dchar c);
bool                g_unichar_isalnum       (dchar c);
bool                g_unichar_isalpha       (dchar c);
bool                g_unichar_iscntrl       (dchar c);
bool                g_unichar_isdigit       (dchar c);
bool                g_unichar_isgraph       (dchar c);
bool                g_unichar_islower       (dchar c);
bool                g_unichar_isprint       (dchar c);
bool                g_unichar_ispunct       (dchar c);
bool                g_unichar_isspace       (dchar c);
bool                g_unichar_isupper       (dchar c);
bool                g_unichar_isxdigit      (dchar c);
bool                g_unichar_istitle       (dchar c);
bool                g_unichar_isdefined     (dchar c);
bool                g_unichar_iswide        (dchar c);
dchar               g_unichar_toupper       (dchar c);
dchar               g_unichar_tolower       (dchar c);
dchar               g_unichar_totitle       (dchar c);
int                 g_unichar_digit_value   (dchar c);
int                 g_unichar_xdigit_value  (dchar c);
GUnicodeType        g_unichar_type          (dchar c);
GUnicodeBreakType   g_unichar_break_type    (dchar c);

void        g_unicode_canonical_ordering        (dchar* str, size_t len);
dchar*      g_unicode_canonical_decomposition   (dchar c, size_t* result_len);
bool        g_unichar_get_mirror_char           (dchar c, dchar* mirrored_ch);
//alias       p                                   g_utf8_next_char;
dchar       g_utf8_get_char             (char* p);
dchar       g_utf8_get_char_validated   (char* p,   ptrdiff_t max_len);

char*       g_utf8_offset_to_pointer    (char* str, long offset);
long        g_utf8_pointer_to_offset    (char* str, char* pos);
char*       g_utf8_prev_char            (char* p);
char*       g_utf8_find_next_char       (char* p,   char* end);
char*       g_utf8_find_prev_char       (char* str, char* p);
long        g_utf8_strlen               (Const!(char)* p,   ptrdiff_t max);
char*       g_utf8_strncpy              (char* dest, char* src, size_t n);
char*       g_utf8_strchr               (char* p,   ptrdiff_t len, dchar c);
char*       g_utf8_strrchr              (char* p,   ptrdiff_t len, dchar c);
char*       g_utf8_strreverse           (char* str, ptrdiff_t len);
bool        g_utf8_validate             (Const!(char)* str, ptrdiff_t max_len, char** end);

char*       g_utf8_strup        (char* str, ptrdiff_t len);
char*       g_utf8_strdown      (char* str, ptrdiff_t len);
char*       g_utf8_casefold     (char* str, ptrdiff_t len);
char*       g_utf8_normalize    (char* str, ptrdiff_t len, GNormalizeMode mode);

char*       g_utf8_collate_key  (char* str, ptrdiff_t len);
int         g_utf8_collate      (char* str1, char* str2);

wchar*      g_utf8_to_utf16     (char* str,  long len, long* items_read, long* items_written, GError** error);
dchar*      g_utf8_to_ucs4      (char* str,  long len, long* items_read, long* items_written, GError** error);
dchar*      g_utf8_to_ucs4_fast (char* str,  long len, long* items_written);
dchar*      g_utf16_to_ucs4     (wchar* str, long len, long* items_read, long* items_written, GError** error);
char*       g_utf16_to_utf8     (wchar* str, long len, long* items_read, long* items_written, GError** error);
wchar*      g_ucs4_to_utf16     (dchar* str, long len, long* items_read, long* items_written, GError** error);
char*       g_ucs4_to_utf8      (dchar* str, long len, long* items_read, long* items_written, GError** error);

int         g_unichar_to_utf8   (dchar c, char *outbuf);



alias       g_ucs4_to_utf8   g_to_utf8;
alias       g_utf16_to_utf8  g_to_utf8;

alias       g_ucs4_to_utf16  g_to_utf16;
alias       g_utf8_to_utf16  g_to_utf16;

alias       g_utf8_to_ucs4   g_to_ucs4;
alias       g_utf16_to_ucs4  g_to_ucs4;
