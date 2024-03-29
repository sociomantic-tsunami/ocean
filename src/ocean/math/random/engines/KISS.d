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
module ocean.math.random.engines.KISS;
import ocean.meta.types.Qualifiers;
import ocean.core.TypeConvert: assumeUnique;
import Integer = ocean.text.convert.Integer_tango;
import ocean.core.Verify;

/+ Kiss99 random number generator, by Marisaglia
+ a simple RNG that passes all statistical tests
+ This is the engine, *never* use it directly, always use it though a RandomG class
+/
struct Kiss99{
    private uint kiss_x = 123456789;
    private uint kiss_y = 362436000;
    private uint kiss_z = 521288629;
    private uint kiss_c = 7654321;
    private uint nBytes = 0;
    private uint restB  = 0;

    enum int canCheckpoint=true;
    enum int canSeed=true;

    void skip(uint n){
        for (int i=n;i!=n;--i){
            next;
        }
    }
    ubyte nextB(){
        if (nBytes>0) {
            ubyte res=cast(ubyte)(restB & 0xFF);
            restB >>= 8;
            --nBytes;
            return res;
        } else {
            restB=next;
            ubyte res=cast(ubyte)(restB & 0xFF);
            restB >>= 8;
            nBytes=3;
            return res;
        }
    }
    uint next(){
        enum ulong a = 698769069UL;
        ulong t;
        kiss_x = 69069*kiss_x+12345;
        kiss_y ^= (kiss_y<<13); kiss_y ^= (kiss_y>>17); kiss_y ^= (kiss_y<<5);
        t = a*kiss_z+kiss_c; kiss_c = cast(uint)(t>>32);
        kiss_z=cast(uint)t;
        return kiss_x+kiss_y+kiss_z;
    }
    ulong nextL(){
        return ((cast(ulong)next)<<32)+cast(ulong)next;
    }

    void seed(scope uint delegate() r){
        kiss_x = r();
        for (int i=0;i<100;++i){
            kiss_y=r();
            if (kiss_y!=0) break;
        }
        if (kiss_y==0) kiss_y=362436000;
        kiss_z=r();
        /* Don’t really need to seed c as well (is reset after a next),
           but doing it allows to completely restore a given internal state */
        kiss_c = r() % 698769069; /* Should be less than 698769069 */
        nBytes = 0;
        restB=0;
    }
    /// writes the current status in a string
    string toString(){
        char[] res=new char[6+6*9];
        int i=0;
        res[i..i+6]="KISS99";
        i+=6;
        foreach (val;[kiss_x,kiss_y,kiss_z,kiss_c,nBytes,restB]){
            res[i]='_';
            ++i;
            Integer.format(res[i..i+8],val,"x8");
            i+=8;
        }
        verify(i==res.length,"unexpected size");
        return assumeUnique(res);
    }
    /// reads the current status from a string (that should have been trimmed)
    /// returns the number of chars read
    size_t fromString(cstring s){
        size_t i=0;
        verify(s[i..i+4]=="KISS","unexpected kind, expected KISS");
        verify(s[i+4..i+7]=="99_","unexpected version, expected 99");
        i+=6;
        foreach (val;[&kiss_x,&kiss_y,&kiss_z,&kiss_c,&nBytes,&restB]){
            verify(s[i]=='_',"no separator _ found");
            ++i;
            uint ate;
            *val=cast(uint)Integer.convert(s[i..i+8],16,&ate);
            verify(ate==8,"unexpected read size");
            i+=8;
        }
        return i;
    }
}
