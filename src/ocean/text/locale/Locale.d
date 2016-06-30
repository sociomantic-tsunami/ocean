/*******************************************************************************

        This is the Tango I18N gateway, which extends the basic Layout
        module with support for cuture- and region-specific formatting
        of numerics, date, time, and currency.

        Use as a standalone formatter in the same manner as Layout, or
        combine with other entities such as Stdout. To enable a French
        Stdout, do the following:
        ---
        Stdout.layout = new Locale (Culture.getCulture ("fr-FR"));
        ---

        Note that Stdout is a shared entity, so every usage of it will
        be affected by the above example. For applications supporting
        multiple regions create multiple Locale instances instead, and
        cache them in an appropriate manner.

        In addition to region-specific currency, date and time, Locale
        adds more sophisticated formatting option than Layout provides:
        numeric digit placement using '#' formatting, for example, is
        supported by Locale - along with placement of '$', '-', and '.'
        regional-specifics.

        Locale is currently utf8 only. Support for both Utf16 and utf32
        may be enabled at a later time

        Copyright:
            Copyright (c) 2007 Kris.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Feb 2007: Initial release

        Authors: Kris

******************************************************************************/

module ocean.text.locale.Locale;

public import ocean.text.locale.Core : Culture;

import ocean.transition;

import ocean.text.locale.Core,
       ocean.text.locale.Convert;

import ocean.time.Time;

import ocean.text.convert.Layout_tango;

/*******************************************************************************

        Locale-enabled wrapper around ocean.text.convert.Layout

*******************************************************************************/

public class Locale : Layout!(char)
{
        private DateTimeFormat  dateFormat;
        private NumberFormat    numberFormat;

        /**********************************************************************

        **********************************************************************/

        this (IFormatService formatService = null)
        {
                numberFormat = NumberFormat.getInstance (formatService);
                dateFormat = DateTimeFormat.getInstance (formatService);
        }

        /***********************************************************************

        ***********************************************************************/

        protected override cstring unknown (char[] output, cstring format, TypeInfo type, Arg p)
        {
                if (cast(TypeInfo_Struct) type)
                {
                    if (type is typeid(Time))
                        return formatDateTime (output, *cast(Time*) p, format, dateFormat);
                    
                    return type.toString;
                }

                return "{unhandled argument type: " ~ type.toString ~ '}';
        }

        /**********************************************************************

        **********************************************************************/

        protected override cstring integer (char[] output, long v, cstring alt, ulong mask=ulong.max, cstring format=null)
        {
                return formatInteger (output, v, alt, numberFormat);
        }

        /**********************************************************************

        **********************************************************************/

        protected override cstring floater (char[] output, real v, cstring format)
        {
                return formatDouble (output, v, format, numberFormat);
        }
}


/*******************************************************************************

*******************************************************************************/

debug (Locale)
{
        import ocean.io.Console;
        import ocean.time.WallClock;

        void main ()
        {
                auto layout = new Locale (Culture.getCulture ("fr-FR"));

                Cout (layout ("{:D}", WallClock.now)) ();
        }
}
