/**
 * D bindings to the Perl-Compatible Regular Expressions library (libpcre)
 *
 * http://www.pcre.org/
 *
 * Needs linking using -lpcre
 *
 * Copyright:
 *     Copyright (c) 2009-2016 Sociomantic Labs GmbH.
 *     All rights reserved.
 *
 * License:
 *     Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
 *     Alternatively, this file may be distributed under the terms of the Tango
 *     3-Clause BSD License (see LICENSE_BSD.txt for details).
 *
 *     Bear in mind this module provides bindings to an external library that
 *     has its own license, which might be more restrictive. Please check the
 *     external library license to see which conditions apply for linking.
 */

module ocean.text.regex.c.pcre;

import ocean.transition;

extern (C):

char* PCRE_SPTR;

struct real_pcre;
alias real_pcre pcre;


// ulong might be also uint...needs to be checked...
struct pcre_extra {
  ulong flags;
  void* study_data;
  ulong match_limit;
  void* callout_data;
  ubyte* tables;
  ulong* match_limit_recursion;
};


static immutable int PCRE_CASELESS = 0x00000001;
static immutable int PCRE_MULTILINE = 0x00000002;
static immutable int PCRE_DOTALL = 0x00000004;
static immutable int PCRE_EXTENDED = 0x00000008;
static immutable int PCRE_ANCHORED = 0x00000010;
static immutable int PCRE_DOLLAR_ENDONLY = 0x00000020;
static immutable int PCRE_EXTRA = 0x00000040;
static immutable int PCRE_NOTBOL = 0x00000080;
static immutable int PCRE_NOTEOL = 0x00000100;
static immutable int PCRE_UNGREEDY = 0x00000200;
static immutable int PCRE_NOTEMPTY = 0x00000400;
static immutable int PCRE_UTF8 = 0x00000800;
static immutable int PCRE_NO_AUTO_CAPTURE = 0x00001000;
static immutable int PCRE_NO_UTF8_CHECK = 0x00002000;
static immutable int PCRE_AUTO_CALLOUT = 0x00004000;
static immutable int PCRE_PARTIAL = 0x00008000;
static immutable int PCRE_DFA_SHORTEST = 0x00010000;
static immutable int PCRE_DFA_RESTART = 0x00020000;
static immutable int PCRE_FIRSTLINE = 0x00040000;
static immutable int PCRE_DUPNAMES = 0x00080000;
static immutable int PCRE_NEWLINE_CR = 0x00100000;
static immutable int PCRE_NEWLINE_LF = 0x00200000;
static immutable int PCRE_NEWLINE_CRLF = 0x00300000;
static immutable int PCRE_NEWLINE_ANY = 0x00400000;
static immutable int PCRE_NEWLINE_ANYCRLF = 0x00500000;
static immutable int PCRE_BSR_ANYCRLF = 0x00800000;
static immutable int PCRE_BSR_UNICODE = 0x01000000;
static immutable int PCRE_JAVASCRIPT_COMPAT = 0x02000000;


static immutable int PCRE_ERROR_NOMATCH = (-1);
static immutable int PCRE_ERROR_NULL = (-2);
static immutable int PCRE_ERROR_BADOPTION = (-3);
static immutable int PCRE_ERROR_BADMAGIC = (-4);
static immutable int PCRE_ERROR_UNKNOWN_OPCODE = (-5);
static immutable int PCRE_ERROR_UNKNOWN_NODE = (-5);
static immutable int PCRE_ERROR_NOMEMORY = (-6);
static immutable int PCRE_ERROR_NOSUBSTRING = (-7);
static immutable int PCRE_ERROR_MATCHLIMIT = (-8);
static immutable int PCRE_ERROR_CALLOUT = (-9);
static immutable int PCRE_ERROR_BADUTF8 = (-10);
static immutable int PCRE_ERROR_BADUTF8_OFFSET = (-11);
static immutable int PCRE_ERROR_PARTIAL = (-12);
static immutable int PCRE_ERROR_BADPARTIAL = (-13);
static immutable int PCRE_ERROR_INTERNAL = (-14);
static immutable int PCRE_ERROR_BADCOUNT = (-15);
static immutable int PCRE_ERROR_DFA_UITEM = (-16);
static immutable int PCRE_ERROR_DFA_UCOND = (-17);
static immutable int PCRE_ERROR_DFA_UMLIMIT = (-18);
static immutable int PCRE_ERROR_DFA_WSSIZE = (-19);
static immutable int PCRE_ERROR_DFA_RECURSE = (-20);
static immutable int PCRE_ERROR_RECURSIONLIMIT = (-21);
static immutable int PCRE_ERROR_NULLWSLIMIT = (-22);
static immutable int PCRE_ERROR_BADNEWLINE = (-23);


static immutable int PCRE_INFO_OPTIONS = 0;
static immutable int PCRE_INFO_SIZE = 1;
static immutable int PCRE_INFO_CAPTURECOUNT = 2;
static immutable int PCRE_INFO_BACKREFMAX = 3;
static immutable int PCRE_INFO_FIRSTBYTE = 4;
static immutable int PCRE_INFO_FIRSTCHAR = 4;
static immutable int PCRE_INFO_FIRSTTABLE = 5;
static immutable int PCRE_INFO_LASTLITERAL = 6;
static immutable int PCRE_INFO_NAMEENTRYSIZE = 7;
static immutable int PCRE_INFO_NAMECOUNT = 8;
static immutable int PCRE_INFO_NAMETABLE = 9;
static immutable int PCRE_INFO_STUDYSIZE = 10;
static immutable int PCRE_INFO_DEFAULT_TABLES = 11;
static immutable int PCRE_INFO_OKPARTIAL = 12;
static immutable int PCRE_INFO_JCHANGED = 13;
static immutable int PCRE_INFO_HASCRORLF = 14;


static immutable int PCRE_CONFIG_UTF8 = 0;
static immutable int PCRE_CONFIG_NEWLINE = 1;
static immutable int PCRE_CONFIG_LINK_SIZE = 2;
static immutable int PCRE_CONFIG_POSIX_MALLOC_THRESHOLD = 3;
static immutable int PCRE_CONFIG_MATCH_LIMIT = 4;
static immutable int PCRE_CONFIG_STACKRECURSE = 5;
static immutable int PCRE_CONFIG_UNICODE_PROPERTIES = 6;
static immutable int PCRE_CONFIG_MATCH_LIMIT_RECURSION = 7;
static immutable int PCRE_CONFIG_BSR = 8;


static immutable int PCRE_EXTRA_STUDY_DATA = 0x0001;
static immutable int PCRE_EXTRA_MATCH_LIMIT = 0x0002;
static immutable int PCRE_EXTRA_CALLOUT_DATA = 0x0004;
static immutable int PCRE_EXTRA_TABLES = 0x0008;
static immutable int PCRE_EXTRA_MATCH_LIMIT_RECURSION = 0x0010;


pcre*  pcre_compile(char* pattern, int options, char** errptr, int* erroffset, ubyte* tableptr);
pcre*  pcre_compile2(char* pattern, int options, int* errorcodeptr, char** errptr, int* erroffset, ubyte* tableptr);
int    pcre_config(int what, void* where);
int    pcre_copy_named_substring(pcre* code, char* subject, int* ovector, int stringcount, char* stringname, char* buffer, int buffersize);
int    pcre_copy_substring(char* subject, int* ovector, int stringcount, int stringnumber, char* buffer, int buffersize);
int    pcre_dfa_exec(pcre* code, pcre_extra* extra, char* subject, int length, int startoffset, int options, int* ovector, int ovecsize, int* workspace, int wscount);
int    pcre_exec(pcre* code, pcre_extra* extra, Const!(char)* subject, int length, int startoffset, int options, int* ovector, int ovecsize);
void   pcre_free_substring(char* stringptr);
void   pcre_free_substring_list(char** stringptr);
int    pcre_fullinfo(pcre* code, pcre_extra* extra, int what, void* where);
int    pcre_get_named_substring(pcre* code, char* subject, int* ovector, int stringcount, char* stringname, char** stringptr);
int    pcre_get_stringnumber(pcre* code, char* name);
int    pcre_get_stringtable_entries(pcre* code, char* name, char** first, char** last);
int    pcre_get_substring(char* subject, int* ovector, int stringcount, int stringnumber, char** stringptr);
int    pcre_get_substring_list(char* subject, int* ovector, int stringcount, char*** listptr);
int    pcre_info(pcre* code, int* optptr, int* firstcharptr);
ubyte* pcre_maketables();
int    pcre_refcount(pcre* code, int adjust);
pcre_extra* pcre_study(pcre* code, int options, char ** errptr);

