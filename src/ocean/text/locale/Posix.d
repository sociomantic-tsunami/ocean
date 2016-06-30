/*******************************************************************************

    Copyright:
        Copyright (c) 2005 John Chapman.
        Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.

    Version: Initial release: 2005

    Authors: John Chapman

 ******************************************************************************/

module ocean.text.locale.Posix;

import ocean.transition;

version (Posix)
{
    alias ocean.text.locale.Posix nativeMethods;

    import ocean.core.Exception_tango;
    import ocean.text.locale.Data;
    import ocean.stdc.ctype;
    import ocean.stdc.posix.stdlib;
    import ocean.stdc.string;
    import ocean.stdc.stringz;
    import ocean.stdc.locale;

    /*private extern(C) char* setlocale(int type, char* locale);
      private extern(C) void putenv(char*);

      private enum {LC_CTYPE, LC_NUMERIC, LC_TIME, LC_COLLATE, LC_MONETARY, LC_MESSAGES, LC_ALL, LC_PAPER, LC_NAME, LC_ADDRESS, LC_TELEPHONE, LC_MEASUREMENT, LC_IDENTIFICATION};*/

    int getUserCulture()
    {
        char* env = getenv("LC_ALL".ptr);
        if (!env || *env == '\0')
        {
            env = getenv("LANG".ptr);
        }

        // getenv returns a string of the form <language>_<region>.
        // Therefore we need to replace underscores with hyphens.
        cstring s;
        if (env)
        {
            auto s_mut = fromStringz(env).dup;
            foreach (ref char c; s_mut)
            {
                if (c == '.')
                    break;
                else
                    if (c == '_')
                        c = '-';
            }
            s = s_mut;
        }
        else
        {
            s="en-US";
        }
        foreach (entry; CultureData.cultureDataTable)
        {
            // todo: there is also a local compareString defined. Is it correct that here
            // we use ocean.text.locale.Data, which matches the signature?
            if (ocean.text.locale.Data.compareString(entry.name, s) == 0)
                return entry.lcid;
        }

        foreach (entry; CultureData.cultureDataTable)
        {
            // todo: there is also a local compareString defined. Is it correct that here
            // we use ocean.text.locale.Data, which matches the signature?
            if (ocean.text.locale.Data.compareString(entry.name, "en-US") == 0)
                return entry.lcid;
        }
        return 0;
    }

    void setUserCulture(int lcid)
    {
        char[] name;
        try
        {
            name = CultureData.getDataFromCultureID(lcid).name.dup ~ ".utf-8";
        }
        catch(Exception e)
        {
            return;
        }

        for(int i = 0; i < name.length; i++)
        {
            if(name[i] == '.') break;
            if(name[i] == '-') name[i] = '_';
        }

        putenv(("LANG=" ~ name).ptr);
        setlocale(LC_CTYPE, name.ptr);
        setlocale(LC_NUMERIC, name.ptr);
        setlocale(LC_TIME, name.ptr);
        setlocale(LC_COLLATE, name.ptr);
        setlocale(LC_MONETARY, name.ptr);

        setlocale(LC_PAPER, name.ptr);
        setlocale(LC_NAME, name.ptr);
        setlocale(LC_ADDRESS, name.ptr);
        setlocale(LC_TELEPHONE, name.ptr);
        setlocale(LC_MEASUREMENT, name.ptr);
        setlocale(LC_IDENTIFICATION, name.ptr);
    }

    int compareString(int lcid, cstring stringA, size_t offsetA, size_t lengthA,
            cstring stringB, size_t offsetB, size_t lengthB, bool ignoreCase)
    {

        void strToLower(char[] string)
        {
            for(size_t i = 0; i < string.length; i++)
            {
                string[i] = cast(char)(tolower(cast(int)string[i]));
            }
        }

        char* tempCol = setlocale(LC_COLLATE, null), tempCType = setlocale(LC_CTYPE, null);
        char[] locale;
        try
        {
            locale = CultureData.getDataFromCultureID(lcid).name.dup ~ ".utf-8";
        }
        catch(Exception e)
        {
            return 0;
        }

        setlocale(LC_COLLATE, locale.ptr);
        setlocale(LC_CTYPE, locale.ptr);

        char[] s1 = stringA[offsetA..offsetA+lengthA] ~ "\0",
            s2 = stringB[offsetB..offsetB+lengthB] ~ "\0";
        if (ignoreCase)
        {
            strToLower(s1);
            strToLower(s2);
        }

        int ret = strcoll(s1.ptr, s2.ptr);

        setlocale(LC_COLLATE, tempCol);
        setlocale(LC_CTYPE, tempCType);

        return ret;
    }

    unittest
    {
        int c = getUserCulture();
        assert(compareString(c, "Alphabet", 0, 8, "Alphabet", 0, 8, false) == 0);
        assert(compareString(c, "Alphabet", 0, 8, "alphabet", 0, 8, true) == 0);
        assert(compareString(c, "Alphabet", 0, 8, "alphabet", 0, 8, false) != 0);
        assert(compareString(c, "lphabet", 0, 7, "alphabet", 0, 8, true) != 0);
        assert(compareString(c, "Alphabet", 0, 8, "lphabet", 0, 7, true) != 0);
        assert(compareString(c, "Alphabet", 0, 7, "ZAlphabet", 1, 7, false) == 0);
    }
}
