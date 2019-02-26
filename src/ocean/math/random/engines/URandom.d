/*******************************************************************************

        Copyright:
            Copyright (c) 2008. Fawzi Mohamed
            Some parts copyright (c) 2009-2016 dunnhumby Germany GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: July 2008

        Authors: Fawzi Mohamed

*******************************************************************************/
module ocean.math.random.engines.URandom;

import ocean.transition;
import Integer = ocean.text.convert.Integer_tango;
import ocean.io.device.File; // use stdc read/write?
import ocean.core.Verify;

/// basic source that takes data from system random device
/// This is an engine, do not use directly, use RandomG!(Urandom)
/// should use stdc rad/write?
struct URandom{
    static File.Style readStyle;
    static this(){
        readStyle.access=File.Access.Read;
        readStyle.open  =File.Open.Exists;
        readStyle.share =File.Share.Read;
        readStyle.cache =File.Cache.None;

    }
    enum int canCheckpoint=false;
    enum int canSeed=false;

    void skip(uint n){ }
    ubyte nextB(){
        union ToVoidA{
            ubyte i;
            void[1] a;
        }
        ToVoidA el;
        auto fn = new File("/dev/urandom", readStyle);
        if(fn.read(el.a)!=el.a.length){
            throw new Exception("could not write the requested bytes from urandom");
        }
        fn.close();
        return el.i;
    }
    uint next(){
        union ToVoidA{
            uint i;
            void[4] a;
        }
        ToVoidA el;
        auto fn = new File("/dev/urandom", readStyle);
        if(fn.read(el.a)!=el.a.length){
            throw new Exception("could not write the requested bytes from urandom");
        }
        fn.close();
        return el.i;
    }
    ulong nextL(){
        union ToVoidA{
            ulong l;
            void[8] a;
        }
        ToVoidA el;
        auto fn = new File("/dev/urandom", readStyle);
        if(fn.read(el.a)!=el.a.length){
            throw new Exception("could not write the requested bytes from urandom");
        }
        fn.close();
        return el.l;
    }
    /// does nothing
    void seed(scope uint delegate() r) { }
    /// writes the current status in a string
    istring toString(){
        return "URandom";
    }
    /// reads the current status from a string (that should have been trimmed)
    /// returns the number of chars read
    size_t fromString(cstring s){
        auto r="URandom";
        verify(s[0.. r.length]==r,"unxepected string instad of URandom:"~idup(s));
        return r.length;
    }
}
