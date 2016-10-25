/**
 * Elementary Mathematical Functions
 *
 * Copyright:
 *     Portions Copyright (C) 2001-2005 Digital Mars.
 *     Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
 *     All rights reserved.
 *
 * License:
 *     Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
 *     See LICENSE_TANGO.txt for details.
 *
 * Authors: Walter Bright, Don Clugston, Sean Kelly
 *
 */

/**
 * Macros:
 *  NAN = $(RED NAN)
 *  TEXTNAN = $(RED NAN:$1 )
 *  SUP = <span style="vertical-align:super;font-size:smaller">$0</span>
 *  GAMMA =  &#915;
 *  INTEGRAL = &#8747;
 *  INTEGRATE = $(BIG &#8747;<sub>$(SMALL $1)</sub><sup>$2</sup>)
 *  POWER = $1<sup>$2</sup>
 *  BIGSUM = $(BIG &Sigma; <sup>$2</sup><sub>$(SMALL $1)</sub>)
 *  CHOOSE = $(BIG &#40;) <sup>$(SMALL $1)</sup><sub>$(SMALL $2)</sub> $(BIG &#41;)
 *  PLUSMN = &plusmn;
 *  INFIN = &infin;
 *  PLUSMNINF = &plusmn;&infin;
 *  PI = &pi;
 *  LT = &lt;
 *  GT = &gt;
 *  SQRT = &radix;
 *  HALF = &frac12;
 *  TABLE_SV = <table border=1 cellpadding=4 cellspacing=0>
 *      <caption>Special Values</caption>
 *      $0</table>
 *  SVH = $(TR $(TH $1) $(TH $2))
 *  SV  = $(TR $(TD $1) $(TD $2))
 *  TABLE_DOMRG = <table border=1 cellpadding=4 cellspacing=0>$0</table>
 *  DOMAIN = $(TR $(TD Domain) $(TD $0))
 *  RANGE  = $(TR $(TD Range) $(TD $0))
 */

module ocean.math.Math;

import ocean.transition;

static import ocean.stdc.math;
import ocean.math.IEEE;


version(TangoNoAsm) {

} else version(D_InlineAsm_X86) {
    version = Naked_D_InlineAsm_X86;
} else version(D_InlineAsm_X86_64) {
    version = Naked_D_InlineAsm_X86_64;
}

/*
 * Constants
 */

const real E =          2.7182818284590452354L;  /** e */ // 3.32193 fldl2t 0x1.5BF0A8B1_45769535_5FF5p+1L
const real LOG2T =      0x1.a934f0979a3715fcp+1; /** $(SUB log, 2)10 */ // 1.4427 fldl2e
const real LOG2E =      0x1.71547652b82fe178p+0; /** $(SUB log, 2)e */ // 0.30103 fldlg2
const real LOG2 =       0x1.34413509f79fef32p-2; /** $(SUB log, 10)2 */
const real LOG10E =     0.43429448190325182765;  /** $(SUB log, 10)e */
const real LN2 =        0x1.62e42fefa39ef358p-1; /** ln 2 */  // 0.693147 fldln2
const real LN10 =       2.30258509299404568402;  /** ln 10 */
const real PI =         0x1.921fb54442d1846ap+1; /** $(_PI) */ // 3.14159 fldpi
const real PI_2 =       1.57079632679489661923;  /** $(PI) / 2 */
const real PI_4 =       0.78539816339744830962;  /** $(PI) / 4 */
const real M_1_PI =     0.31830988618379067154;  /** 1 / $(PI) */
const real M_2_PI =     0.63661977236758134308;  /** 2 / $(PI) */
const real M_2_SQRTPI = 1.12837916709551257390;  /** 2 / $(SQRT)$(PI) */
const real SQRT2 =      1.41421356237309504880;  /** $(SQRT)2 */
const real SQRT1_2 =    0.70710678118654752440;  /** $(SQRT)$(HALF) */

//const real SQRTPI  = 1.77245385090551602729816748334114518279754945612238L; /** &radic;&pi; */
//const real SQRT2PI = 2.50662827463100050242E0L; /** &radic;(2 &pi;) */
//const real SQRTE   = 1.64872127070012814684865078781416357L; /** &radic;(e) */

const real MAXLOG = 0x1.62e42fefa39ef358p+13L;  /** log(real.max) */
const real MINLOG = -0x1.6436716d5406e6d8p+13L; /** log(real.min*real.epsilon) */
const real EULERGAMMA = 0.57721_56649_01532_86060_65120_90082_40243_10421_59335_93992L; /** Euler-Mascheroni constant 0.57721566.. */

/*
 * Primitives
 */

/**
 * Calculates the absolute value
 *
 * For complex numbers, abs(z) = sqrt( $(POWER z.re, 2) + $(POWER z.im, 2) )
 * = hypot(z.re, z.im).
 */
real abs(real x)
{
    return ocean.math.IEEE.fabs(x);
}

/** ditto */
long abs(long x)
{
    return x>=0 ? x : -x;
}

/** ditto */
int abs(int x)
{
    return x>=0 ? x : -x;
}

/** ditto */
real abs(creal z)
{
    return hypot(z.re, z.im);
}

/** ditto */
real abs(ireal y)
{
    return ocean.math.IEEE.fabs(y.im);
}

unittest
{
    assert(isIdentical(0.0L,abs(-0.0L)));
    assert(isNaN(abs(real.nan)));
    assert(abs(-real.infinity) == real.infinity);
    assert(abs(-3.2Li) == 3.2L);
    assert(abs(71.6Li) == 71.6L);
    assert(abs(-56) == 56);
    assert(abs(2321312L)  == 2321312L);
    assert(abs(-1.0L+1.0Li) == sqrt(2.0L));
}

/**
 * Complex conjugate
 *
 *  conj(x + iy) = x - iy
 *
 * Note that z * conj(z) = $(POWER z.re, 2) + $(POWER z.im, 2)
 * is always a real number
 */
creal conj(creal z)
{
    return z.re - z.im*1i;
}

/** ditto */
ireal conj(ireal y)
{
    return -y;
}

unittest
{
    assert(conj(7 + 3i) == 7-3i);
    ireal z = -3.2Li;
    assert(conj(z) == -z);
}

private {
    // Return the type which would be returned by a max or min operation
template minmaxtype(T...){
    static if(T.length == 1) alias T[0] minmaxtype;
    else static if(T.length > 2)
        alias minmaxtype!(minmaxtype!(T[0..2]), T[2..$]) minmaxtype;
    else alias typeof (T[1].init > T[0].init ? T[1].init : T[0].init) minmaxtype;
}
}

unittest
{
    static assert (is(minmaxtype!(int, long) == long));
}

/** Return the minimum of the supplied arguments.
 *
 * Note: If the arguments are floating-point numbers, and at least one is a NaN,
 * the result is undefined.
 */
minmaxtype!(T) min(T...)(T arg){
    static if(arg.length == 1) return arg[0];
    else static if(arg.length == 2) return arg[1] < arg[0] ? arg[1] : arg[0];
    static if(arg.length > 2) return min(arg[1] < arg[0] ? arg[1] : arg[0], arg[2..$]);
}

/** Return the maximum of the supplied arguments.
 *
 * Note: If the arguments are floating-point numbers, and at least one is a NaN,
 * the result is undefined.
 */
minmaxtype!(T) max(T...)(T arg){
    static if(arg.length == 1) return arg[0];
    else static if(arg.length == 2) return arg[1] > arg[0] ? arg[1] : arg[0];
    static if(arg.length > 2) return max(arg[1] > arg[0] ? arg[1] : arg[0], arg[2..$]);
}
unittest
{
    assert(max('e', 'f')=='f');
    assert(min(3.5, 3.8)==3.5);
    // check implicit conversion to integer.
    assert(min(3.5, 18)==3.5);

}

/** Returns the minimum number of x and y, favouring numbers over NaNs.
 *
 * If both x and y are numbers, the minimum is returned.
 * If both parameters are NaN, either will be returned.
 * If one parameter is a NaN and the other is a number, the number is
 * returned (this behaviour is mandated by IEEE 754R, and is useful
 * for determining the range of a function).
 */
real minNum(real x, real y) {
    if (x<=y || isNaN(y)) return x; else return y;
}

/** Returns the maximum number of x and y, favouring numbers over NaNs.
 *
 * If both x and y are numbers, the maximum is returned.
 * If both parameters are NaN, either will be returned.
 * If one parameter is a NaN and the other is a number, the number is
 * returned (this behaviour is mandated by IEEE 754-2008, and is useful
 * for determining the range of a function).
 */
real maxNum(real x, real y) {
    if (x>=y || isNaN(y)) return x; else return y;
}

/** Returns the minimum of x and y, favouring NaNs over numbers
 *
 * If both x and y are numbers, the minimum is returned.
 * If both parameters are NaN, either will be returned.
 * If one parameter is a NaN and the other is a number, the NaN is returned.
 */
real minNaN(real x, real y) {
    return (x<=y || isNaN(x))? x : y;
}

/** Returns the maximum of x and y, favouring NaNs over numbers
 *
 * If both x and y are numbers, the maximum is returned.
 * If both parameters are NaN, either will be returned.
 * If one parameter is a NaN and the other is a number, the NaN is returned.
 */
real maxNaN(real x, real y) {
    return (x>=y || isNaN(x))? x : y;
}

unittest
{
    assert(maxNum(NaN(0xABC), 56.1L)== 56.1L);
    assert(isIdentical(maxNaN(NaN(1389), 56.1L), NaN(1389)));
    assert(maxNum(28.0, NaN(0xABC))== 28.0);
    assert(minNum(1e12, NaN(0xABC))== 1e12);
    assert(isIdentical(minNaN(1e12, NaN(23454)), NaN(23454)));
    assert(isIdentical(minNum(NaN(489), NaN(23)), NaN(489)));
}

/*
 * Trig Functions
 */

/***********************************
 * Returns cosine of x. x is in radians.
 *
 *      $(TABLE_SV
 *      $(TR $(TH x)                 $(TH cos(x)) $(TH invalid?))
 *      $(TR $(TD $(NAN))            $(TD $(NAN)) $(TD yes)     )
 *      $(TR $(TD $(PLUSMN)$(INFIN)) $(TD $(NAN)) $(TD yes)     )
 *      )
 * Bugs:
 *      Results are undefined if |x| >= $(POWER 2,64).
 */

real cos(real x) /* intrinsic */
{
    version(D_InlineAsm_X86)
    {
        asm
        {
            fld x;
            fcos;
        }
    }
    else
    {
        return ocean.stdc.math.cosl(x);
    }
}

unittest {
    // NaN payloads
    assert(isIdentical(cos(NaN(314)), NaN(314)));
}

/***********************************
 * Returns sine of x. x is in radians.
 *
 *      $(TABLE_SV
 *      $(TR $(TH x)               $(TH sin(x))      $(TH invalid?))
 *      $(TR $(TD $(NAN))          $(TD $(NAN))      $(TD yes))
 *      $(TR $(TD $(PLUSMN)0.0)    $(TD $(PLUSMN)0.0) $(TD no))
 *      $(TR $(TD $(PLUSMNINF))    $(TD $(NAN))      $(TD yes))
 *      )
 * Bugs:
 *      Results are undefined if |x| >= $(POWER 2,64).
 */
real sin(real x) /* intrinsic */
{
    version(D_InlineAsm_X86)
    {
        asm
        {
            fld x;
            fsin;
        }
    }
    else
    {
        return ocean.stdc.math.sinl(x);
    }
}

unittest {
    // NaN payloads
    assert(isIdentical(sin(NaN(314)), NaN(314)));
}

/**
 * Returns tangent of x. x is in radians.
 *
 *	$(TABLE_SV
 *	$(TR $(TH x)               $(TH tan(x))       $(TH invalid?))
 *	$(TR $(TD $(NAN))          $(TD $(NAN))       $(TD yes))
 *	$(TR $(TD $(PLUSMN)0.0)    $(TD $(PLUSMN)0.0) $(TD no))
 *	$(TR $(TD $(PLUSMN)$(INFIN)) $(TD $(NAN))     $(TD yes))
 *	)
 */
real tan(real x)
{
    asm
    {
        fld x[EBP]      ; // load theta
        fxam            ; // test for oddball values
        fstsw   AX      ;
        sahf            ;
        jc  trigerr     ; // x is NAN, infinity, or empty
                              // 387's can handle denormals
SC18:   fptan           ;
        fstp    ST(0)   ; // dump X, which is always 1
        fstsw   AX      ;
        sahf            ;
        jnp Lret        ; // C2 = 1 (x is out of range)

        // Do argument reduction to bring x into range
        fldpi           ;
        fxch            ;
SC17:   fprem1          ;
        fstsw   AX      ;
        sahf            ;
        jp  SC17        ;
        fstp    ST(1)   ; // remove pi from stack
        jmp SC18        ;

trigerr:
        jnp Lret        ; // if x is NaN, return x.
        fstp    ST(0)   ; // dump x, which will be infinity
    }
    return NaN(TANGO_NAN.TAN_DOMAIN);
Lret:
    ;
}

unittest
{
    static real[2][] vals =     // angle,tan
    [
            [   0,   0],
            [   .5,  .5463024898],
            [   1,   1.557407725],
            [   1.5, 14.10141995],
            [   2,  -2.185039863],
            [   2.5,-.7470222972],
            [   3,  -.1425465431],
            [   3.5, .3745856402],
            [   4,   1.157821282],
            [   4.5, 4.637332055],
            [   5,  -3.380515006],
            [   5.5,-.9955840522],
            [   6,  -.2910061914],
            [   6.5, .2202772003],
            [   10,  .6483608275],

            // special angles
            [   PI_4,   1],
            //[   PI_2,   real.infinity], // PI_2 is not _exactly_ pi/2.
            [   3*PI_4, -1],
            [   PI,     0],
            [   5*PI_4, 1],
            //[   3*PI_2, -real.infinity],
            [   7*PI_4, -1],
            [   2*PI,   0],
    ];
    int i;

    for (i = 0; i < vals.length; i++)
    {
        real x = vals[i][0];
        real r = vals[i][1];
        real t = tan(x);

        //printf("tan(%Lg) = %Lg, should be %Lg\n", x, t, r);
        if (!isIdentical(r, t)) assert(fabs(r-t) <= .0000001);

        x = -x;
        r = -r;
        t = tan(x);
        //printf("tan(%Lg) = %Lg, should be %Lg\n", x, t, r);
        if (!isIdentical(r, t) && !(isNaN(r) && isNaN(t)))
            assert(fabs(r-t) <= .0000001);
    }
    // overflow
    assert(isNaN(tan(real.infinity)));
    assert(isNaN(tan(-real.infinity)));
    // NaN propagation
    assert(isIdentical( tan(NaN(0x0123L)), NaN(0x0123L) ));
}

/*****************************************
 * Sine, cosine, and arctangent of multiple of &pi;
 *
 * Accuracy is preserved for large values of x.
 */
real cosPi(real x)
{
    return cos((x%2.0)*PI);
}

/** ditto */
real sinPi(real x)
{
    return sin((x%2.0)*PI);
}

/** ditto */
real atanPi(real x)
{
    return PI * atan(x); // BUG: Fix this.
}

unittest {
    assert(isIdentical(sinPi(0.0), 0.0));
    assert(isIdentical(sinPi(-0.0), -0.0));
    assert(isIdentical(atanPi(0.0), 0.0));
    assert(isIdentical(atanPi(-0.0), -0.0));
}

/***********************************
 *  sine, complex and imaginary
 *
 *  sin(z) = sin(z.re)*cosh(z.im) + cos(z.re)*sinh(z.im)i
 *
 * If both sin(&theta;) and cos(&theta;) are required,
 * it is most efficient to use expi(&theta).
 */
creal sin(creal z)
{
  creal cs = expi(z.re);
  return cs.im * cosh(z.im) + cs.re * sinh(z.im) * 1i;
}

/** ditto */
ireal sin(ireal y)
{
  return cosh(y.im)*1i;
}

unittest
{
  assert(sin(0.0+0.0i) == 0.0);
  assert(sin(2.0+0.0i) == sin(2.0L) );
}

/***********************************
 *  cosine, complex and imaginary
 *
 *  cos(z) = cos(z.re)*cosh(z.im) + sin(z.re)*sinh(z.im)i
 */
creal cos(creal z)
{
  creal cs = expi(z.re);
  return cs.re * cosh(z.im) - cs.im * sinh(z.im) * 1i;
}

/** ditto */
real cos(ireal y)
{
  return cosh(y.im);
}

unittest
{
  assert(cos(0.0+0.0i)==1.0);
  assert(cos(1.3L+0.0i)==cos(1.3L));
  assert(cos(5.2Li)== cosh(5.2L));
}

/***************
 * Calculates the arc cosine of x,
 * returning a value ranging from 0 to $(PI).
 *
 *      $(TABLE_SV
 *      $(TR $(TH x)         $(TH acos(x)) $(TH invalid?))
 *      $(TR $(TD $(GT)1.0)  $(TD $(NAN))  $(TD yes))
 *      $(TR $(TD $(LT)-1.0) $(TD $(NAN))  $(TD yes))
 *      $(TR $(TD $(NAN))    $(TD $(NAN))  $(TD yes))
 *      )
 */
real acos(real x)
{
    return ocean.stdc.math.acosl(x);
}

unittest {
    // NaN payloads
    version(darwin){}
    else {
        assert(isIdentical(acos(NaN(254)), NaN(254)));
    }
}

/***************
 * Calculates the arc sine of x,
 * returning a value ranging from -$(PI)/2 to $(PI)/2.
 *
 *      $(TABLE_SV
 *      $(TR $(TH x)            $(TH asin(x))      $(TH invalid?))
 *      $(TR $(TD $(PLUSMN)0.0) $(TD $(PLUSMN)0.0) $(TD no))
 *      $(TR $(TD $(GT)1.0)     $(TD $(NAN))       $(TD yes))
 *      $(TR $(TD $(LT)-1.0)    $(TD $(NAN))       $(TD yes))
 *      )
 */
real asin(real x)
{
    return ocean.stdc.math.asinl(x);
}

unittest {
    // NaN payloads
    version(darwin){}
    else{
        assert(isIdentical(asin(NaN(7249)), NaN(7249)));
    }
}

/***************
 * Calculates the arc tangent of x,
 * returning a value ranging from -$(PI)/2 to $(PI)/2.
 *
 *      $(TABLE_SV
 *      $(TR $(TH x)                 $(TH atan(x))      $(TH invalid?))
 *      $(TR $(TD $(PLUSMN)0.0)      $(TD $(PLUSMN)0.0) $(TD no))
 *      $(TR $(TD $(PLUSMN)$(INFIN)) $(TD $(NAN))       $(TD yes))
 *      )
 */
real atan(real x)
{
    return ocean.stdc.math.atanl(x);
}

unittest
{
    // NaN payloads
    assert(isIdentical(atan(NaN(9876)), NaN(9876)));
}

/***************
 * Calculates the arc tangent of y / x,
 * returning a value ranging from -$(PI) to $(PI).
 *
 *      $(TABLE_SV
 *      $(TR $(TH y)                 $(TH x)            $(TH atan(y, x)))
 *      $(TR $(TD $(NAN))            $(TD anything)     $(TD $(NAN)) )
 *      $(TR $(TD anything)          $(TD $(NAN))       $(TD $(NAN)) )
 *      $(TR $(TD $(PLUSMN)0.0)      $(TD $(GT)0.0)     $(TD $(PLUSMN)0.0) )
 *      $(TR $(TD $(PLUSMN)0.0)      $(TD +0.0)         $(TD $(PLUSMN)0.0) )
 *      $(TR $(TD $(PLUSMN)0.0)      $(TD $(LT)0.0)     $(TD $(PLUSMN)$(PI)))
 *      $(TR $(TD $(PLUSMN)0.0)      $(TD -0.0)         $(TD $(PLUSMN)$(PI)))
 *      $(TR $(TD $(GT)0.0)          $(TD $(PLUSMN)0.0) $(TD $(PI)/2) )
 *      $(TR $(TD $(LT)0.0)          $(TD $(PLUSMN)0.0) $(TD -$(PI)/2) )
 *      $(TR $(TD $(GT)0.0)          $(TD $(INFIN))     $(TD $(PLUSMN)0.0) )
 *      $(TR $(TD $(PLUSMN)$(INFIN)) $(TD anything)     $(TD $(PLUSMN)$(PI)/2))
 *      $(TR $(TD $(GT)0.0)          $(TD -$(INFIN))    $(TD $(PLUSMN)$(PI)) )
 *      $(TR $(TD $(PLUSMN)$(INFIN)) $(TD $(INFIN))     $(TD $(PLUSMN)$(PI)/4))
 *      $(TR $(TD $(PLUSMN)$(INFIN)) $(TD -$(INFIN))    $(TD $(PLUSMN)3$(PI)/4))
 *      )
 */
real atan2(real y, real x)
{
    return ocean.stdc.math.atan2l(y,x);
}

unittest
{
    // NaN payloads
    assert(isIdentical(atan2(5.3, NaN(9876)), NaN(9876)));
    assert(isIdentical(atan2(NaN(9876), 2.18), NaN(9876)));
}

/***********************************
 * Complex inverse sine
 *
 * asin(z) = -i log( sqrt(1-$(POWER z, 2)) + iz)
 * where both log and sqrt are complex.
 */
creal asin(creal z)
{
    return -log(sqrt(1-z*z) + z*1i)*1i;
}

unittest
{
   assert(asin(sin(0+0i)) == 0 + 0i);
}

/***********************************
 * Complex inverse cosine
 *
 * acos(z) = $(PI)/2 - asin(z)
 */
creal acos(creal z)
{
    return PI_2 - asin(z);
}


/***********************************
 * Calculates the hyperbolic cosine of x.
 *
 *      $(TABLE_SV
 *      $(TR $(TH x)                 $(TH cosh(x))      $(TH invalid?))
 *      $(TR $(TD $(PLUSMN)$(INFIN)) $(TD $(PLUSMN)0.0) $(TD no) )
 *      )
 */
real cosh(real x)
{
    //  cosh = (exp(x)+exp(-x))/2.
    // The naive implementation works correctly.
    real y = exp(x);
    return (y + 1.0/y) * 0.5;
}

unittest
{
    // NaN payloads
    assert(isIdentical(cosh(NaN(432)), NaN(432)));
}

/***********************************
 * Calculates the hyperbolic sine of x.
 *
 *      $(TABLE_SV
 *      $(TR $(TH x)                 $(TH sinh(x))           $(TH invalid?))
 *      $(TR $(TD $(PLUSMN)0.0)      $(TD $(PLUSMN)0.0)      $(TD no))
 *      $(TR $(TD $(PLUSMN)$(INFIN)) $(TD $(PLUSMN)$(INFIN)) $(TD no))
 *      )
 */
real sinh(real x)
{
    //  sinh(x) =  (exp(x)-exp(-x))/2;
    // Very large arguments could cause an overflow, but
    // the maximum value of x for which exp(x) + exp(-x)) != exp(x)
    // is x = 0.5 * (real.mant_dig) * LN2. // = 22.1807 for real80.
    if (fabs(x) > real.mant_dig * LN2) {
        return copysign(0.5*exp(fabs(x)), x);
    }
    real y = expm1(x);
    return 0.5 * y / (y+1) * (y+2);
}

unittest
{
    // NaN payloads
    assert(isIdentical(sinh(NaN(0xABC)), NaN(0xABC)));
}

/***********************************
 * Calculates the hyperbolic tangent of x.
 *
 *      $(TABLE_SV
 *      $(TR $(TH x)                 $(TH tanh(x))      $(TH invalid?))
 *      $(TR $(TD $(PLUSMN)0.0)      $(TD $(PLUSMN)0.0) $(TD no) )
 *      $(TR $(TD $(PLUSMN)$(INFIN)) $(TD $(PLUSMN)1.0) $(TD no))
 *      )
 */
real tanh(real x)
{
    //  tanh(x) = (exp(x) - exp(-x))/(exp(x)+exp(-x))
    if (fabs(x)> real.mant_dig * LN2){
        return copysign(1, x);
    }
    real y = expm1(2*x);
    return y/(y + 2);
}

unittest
{
    // NaN payloads
    assert(isIdentical(tanh(NaN(0xABC)), NaN(0xABC)));
}

/***********************************
 *  hyperbolic sine, complex and imaginary
 *
 *  sinh(z) = cos(z.im)*sinh(z.re) + sin(z.im)*cosh(z.re)i
 */
creal sinh(creal z)
{
  creal cs = expi(z.im);
  return cs.re * sinh(z.re) + cs.im * cosh(z.re) * 1i;
}

/** ditto */
ireal sinh(ireal y)
{
  return sin(y.im)*1i;
}

unittest
{
  assert(sinh(4.2L + 0i)==sinh(4.2L));
}

/***********************************
 *  hyperbolic cosine, complex and imaginary
 *
 *  cosh(z) = cos(z.im)*cosh(z.re) + sin(z.im)*sinh(z.re)i
 */
creal cosh(creal z)
{
  creal cs = expi(z.im);
  return cs.re * cosh(z.re) + cs.im * sinh(z.re) * 1i;
}

/** ditto */
real cosh(ireal y)
{
  return cos(y.im);
}

unittest
{
  assert(cosh(8.3L + 0i)==cosh(8.3L));
}


/***********************************
 * Calculates the inverse hyperbolic cosine of x.
 *
 *  Mathematically, acosh(x) = log(x + sqrt( x*x - 1))
 *
 *    $(TABLE_SV
 *    $(SVH  x,     acosh(x) )
 *    $(SV  $(NAN), $(NAN) )
 *    $(SV  $(LT)1,     $(NAN) )
 *    $(SV  1,      0       )
 *    $(SV  +$(INFIN),+$(INFIN))
 *  )
 */
real acosh(real x)
{
    if (x > 1/real.epsilon)
    return LN2 + log(x);
    else
    return log(x + sqrt(x*x - 1));
}

unittest
{
    assert(isNaN(acosh(0.9)));
    assert(isNaN(acosh(real.nan)));
    assert(acosh(1)==0.0);
    assert(acosh(real.infinity) == real.infinity);
    // NaN payloads
    assert(isIdentical(acosh(NaN(0xABC)), NaN(0xABC)));
}

/***********************************
 * Calculates the inverse hyperbolic sine of x.
 *
 *  Mathematically,
 *  ---------------
 *  asinh(x) =  log( x + sqrt( x*x + 1 )) // if x >= +0
 *  asinh(x) = -log(-x + sqrt( x*x + 1 )) // if x <= -0
 *  -------------
 *
 *    $(TABLE_SV
 *    $(SVH x,                asinh(x)       )
 *    $(SV  $(NAN),           $(NAN)         )
 *    $(SV  $(PLUSMN)0,       $(PLUSMN)0      )
 *    $(SV  $(PLUSMN)$(INFIN),$(PLUSMN)$(INFIN))
 *    )
 */
real asinh(real x)
{
    if (ocean.math.IEEE.fabs(x) > 1 / real.epsilon) // beyond this point, x*x + 1 == x*x
    return ocean.math.IEEE.copysign(LN2 + log(ocean.math.IEEE.fabs(x)), x);
    else
    {
    // sqrt(x*x + 1) ==  1 + x * x / ( 1 + sqrt(x*x + 1) )
    return ocean.math.IEEE.copysign(log1p(ocean.math.IEEE.fabs(x) + x*x / (1 + sqrt(x*x + 1)) ), x);
    }
}

unittest
{
    assert(isIdentical(0.0L,asinh(0.0)));
    assert(isIdentical(-0.0L,asinh(-0.0)));
    assert(asinh(real.infinity) == real.infinity);
    assert(asinh(-real.infinity) == -real.infinity);
    assert(isNaN(asinh(real.nan)));
    // NaN payloads
    assert(isIdentical(asinh(NaN(0xABC)), NaN(0xABC)));
}

/***********************************
 * Calculates the inverse hyperbolic tangent of x,
 * returning a value from ranging from -1 to 1.
 *
 * Mathematically, atanh(x) = log( (1+x)/(1-x) ) / 2
 *
 *
 *    $(TABLE_SV
 *    $(SVH  x,     acosh(x) )
 *    $(SV  $(NAN), $(NAN) )
 *    $(SV  $(PLUSMN)0, $(PLUSMN)0)
 *    $(SV  -$(INFIN), -0)
 *    )
 */
real atanh(real x)
{
    // log( (1+x)/(1-x) ) == log ( 1 + (2*x)/(1-x) )
    return  0.5 * log1p( 2 * x / (1 - x) );
}

unittest
{
    assert(isIdentical(0.0L, atanh(0.0)));
    assert(isIdentical(-0.0L,atanh(-0.0)));
    assert(isIdentical(atanh(-1),-real.infinity));
    // Fails with -O because of DMD : https://issues.dlang.org/show_bug.cgi?id=13743
    // Nothing can be done about it without feedback from DMD upstream
    //assert(isIdentical(atanh(1),real.infinity));
    assert(isNaN(atanh(-real.infinity)));
    // NaN payloads
    assert(isIdentical(atanh(NaN(0xABC)), NaN(0xABC)));
}

/** ditto */
creal atanh(ireal y)
{
    // Not optimised for accuracy or speed
    return 0.5*(log(1+y) - log(1-y));
}

/** ditto */
creal atanh(creal z)
{
    // Not optimised for accuracy or speed
    return 0.5 * (log(1 + z) - log(1-z));
}

/*
 * Powers and Roots
 */

/***************************************
 * Compute square root of x.
 *
 *      $(TABLE_SV
 *      $(TR $(TH x)         $(TH sqrt(x))   $(TH invalid?))
 *      $(TR $(TD -0.0)      $(TD -0.0)      $(TD no))
 *      $(TR $(TD $(LT)0.0)  $(TD $(NAN))    $(TD yes))
 *      $(TR $(TD +$(INFIN)) $(TD +$(INFIN)) $(TD no))
 *      )
 */
float sqrt(float x) /* intrinsic */
{
    version(D_InlineAsm_X86)
    {
        asm
        {
            fld x;
            fsqrt;
        }
    }
    else
    {
        return ocean.stdc.math.sqrtf(x);
    }
}

double sqrt(double x) /* intrinsic */ /// ditto
{
    version(D_InlineAsm_X86)
    {
        asm
        {
            fld x;
            fsqrt;
        }
    }
    else
    {
        return ocean.stdc.math.sqrt(x);
    }
}

real sqrt(real x) /* intrinsic */ /// ditto
{
    version(D_InlineAsm_X86)
    {
        asm
        {
            fld x;
            fsqrt;
        }
    }
    else
    {
        return ocean.stdc.math.sqrtl(x);
    }
}

/** ditto */
creal sqrt(creal z)
{

    if (z == 0.0) return z;
    real x,y,w,r;
    creal c;

    x = ocean.math.IEEE.fabs(z.re);
    y = ocean.math.IEEE.fabs(z.im);
    if (x >= y) {
        r = y / x;
        w = sqrt(x) * sqrt(0.5 * (1 + sqrt(1 + r * r)));
    } else  {
        r = x / y;
        w = sqrt(y) * sqrt(0.5 * (r + sqrt(1 + r * r)));
    }

    if (z.re >= 0) {
        c = w + (z.im / (w + w)) * 1.0i;
    } else {
        if (z.im < 0)  w = -w;
        c = z.im / (w + w) + w * 1.0i;
    }
    return c;
}

unittest {
    // NaN payloads
    assert(isIdentical(sqrt(NaN(0xABC)), NaN(0xABC)));
    assert(sqrt(-1+0i) == 1i);
    assert(isIdentical(sqrt(0-0i), 0-0i));
    assert(cfeqrel(sqrt(4+16i)*sqrt(4+16i), 4+16i)>=real.mant_dig-2);
}

/***************
 * Calculates the cube root of x.
 *
 *      $(TABLE_SV
 *      $(TR $(TH $(I x))            $(TH cbrt(x))           $(TH invalid?))
 *      $(TR $(TD $(PLUSMN)0.0)      $(TD $(PLUSMN)0.0)      $(TD no) )
 *      $(TR $(TD $(NAN))            $(TD $(NAN))            $(TD yes) )
 *      $(TR $(TD $(PLUSMN)$(INFIN)) $(TD $(PLUSMN)$(INFIN)) $(TD no) )
 *      )
 */
real cbrt(real x)
{
    return ocean.stdc.math.cbrtl(x);
}


unittest {
    // NaN payloads
    assert(isIdentical(cbrt(NaN(0xABC)), NaN(0xABC)));
}

public:

/**
 * Calculates e$(SUP x).
 *
 *  $(TABLE_SV
 *    $(TR $(TH x)                   $(TH e$(SUP x)) )
 *    $(TR $(TD +$(INFIN))           $(TD +$(INFIN)) )
 *    $(TR $(TD -$(INFIN))           $(TD +0.0)      )
 *    $(TR $(TD $(NAN))              $(TD $(NAN))    )
 *  )
 */
real exp(real x) {
    version(Naked_D_InlineAsm_X86) {
   //  e^x = 2^(LOG2E*x)
   // (This is valid because the overflow & underflow limits for exp
   // and exp2 are so similar).
    return exp2(LOG2E*x);
    } else {
        return ocean.stdc.math.expl(x);
    }
}

/**
 * Calculates the value of the natural logarithm base (e)
 * raised to the power of x, minus 1.
 *
 * For very small x, expm1(x) is more accurate
 * than exp(x)-1.
 *
 *  $(TABLE_SV
 *    $(TR $(TH x)             $(TH e$(SUP x)-1)  )
 *    $(TR $(TD $(PLUSMN)0.0)  $(TD $(PLUSMN)0.0) )
 *    $(TR $(TD +$(INFIN))     $(TD +$(INFIN))    )
 *    $(TR $(TD -$(INFIN))     $(TD -1.0)         )
 *    $(TR $(TD $(NAN))        $(TD $(NAN))       )
 *  )
 */
real expm1(real x)
{
    version(Naked_D_InlineAsm_X86) {
      enum { PARAMSIZE = (real.sizeof+3)&(0xFFFF_FFFC) } // always a multiple of 4
      asm {
        /*  expm1() for x87 80-bit reals, IEEE754-2008 conformant.
         * Author: Don Clugston.
         *
         *    expm1(x) = 2^(rndint(y))* 2^(y-rndint(y)) - 1 where y = LN2*x.
         *    = 2rndy * 2ym1 + 2rndy - 1, where 2rndy = 2^(rndint(y))
         *     and 2ym1 = (2^(y-rndint(y))-1).
         *    If 2rndy  < 0.5*real.epsilon, result is -1.
         *    Implementation is otherwise the same as for exp2()
         */
        naked;
        fld real ptr [ESP+4] ; // x
        mov AX, [ESP+4+8]; // AX = exponent and sign
        sub ESP, 12+8; // Create scratch space on the stack
        // [ESP,ESP+2] = scratchint
        // [ESP+4..+6, +8..+10, +10] = scratchreal
        // set scratchreal mantissa = 1.0
        mov dword ptr [ESP+8], 0;
        mov dword ptr [ESP+8+4], 0x80000000;
        and AX, 0x7FFF; // drop sign bit
        cmp AX, 0x401D; // avoid InvalidException in fist
        jae L_extreme;
        fldl2e;
        fmul ; // y = x*log2(e)
        fist dword ptr [ESP]; // scratchint = rndint(y)
        fisub dword ptr [ESP]; // y - rndint(y)
        // and now set scratchreal exponent
        mov EAX, [ESP];
        add EAX, 0x3fff;
        jle short L_largenegative;
        cmp EAX,0x8000;
        jge short L_largepositive;
        mov [ESP+8+8],AX;
        f2xm1; // 2^(y-rndint(y)) -1
        fld real ptr [ESP+8] ; // 2^rndint(y)
        fmul ST(1), ST;
        fld1;
        fsubp ST(1), ST;
        fadd;
        add ESP,12+8;
        ret PARAMSIZE;

L_extreme: // Extreme exponent. X is very large positive, very
        // large negative, infinity, or NaN.
        fxam;
        fstsw AX;
        test AX, 0x0400; // NaN_or_zero, but we already know x!=0
        jz L_was_nan;  // if x is NaN, returns x
        test AX, 0x0200;
        jnz L_largenegative;
L_largepositive:
        // Set scratchreal = real.max.
        // squaring it will create infinity, and set overflow flag.
        mov word  ptr [ESP+8+8], 0x7FFE;
        fstp ST(0);
        fld real ptr [ESP+8];  // load scratchreal
        fmul ST(0), ST;        // square it, to create havoc!
L_was_nan:
        add ESP,12+8;
        ret PARAMSIZE;
L_largenegative:
        fstp ST(0);
        fld1;
        fchs; // return -1. Underflow flag is not set.
        add ESP,12+8;
        ret PARAMSIZE;
      }
    } else version(D_InlineAsm_X86_64) {
        asm
        {
            naked;
        }
        asm
        {
            fld real ptr [RSP+8]; // x
            mov AX,[RSP+8+8]; // AX = exponent and sign
        }
        asm
        {
/* expm1() for x87 80-bit reals, IEEE754-2008 conformant.
* Author: Don Clugston.
*
* expm1(x) = 2^(rndint(y))* 2^(y-rndint(y)) - 1 where y = LN2*x.
* = 2rndy * 2ym1 + 2rndy - 1, where 2rndy = 2^(rndint(y))
* and 2ym1 = (2^(y-rndint(y))-1).
* If 2rndy < 0.5*real.epsilon, result is -1.
* Implementation is otherwise the same as for exp2()
*/
            sub RSP, 24; // Create scratch space on the stack
            // [RSP,RSP+2] = scratchint
            // [RSP+4..+6, +8..+10, +10] = scratchreal
            // set scratchreal mantissa = 1.0
            mov dword ptr [RSP+8], 0;
            mov dword ptr [RSP+8+4], 0x80000000;
            and AX, 0x7FFF; // drop sign bit
            cmp AX, 0x401D; // avoid InvalidException in fist
            jae L_extreme;
            fldl2e;
            fmul ; // y = x*log2(e)
            fist dword ptr [RSP]; // scratchint = rndint(y)
            fisub dword ptr [RSP]; // y - rndint(y)
            // and now set scratchreal exponent
            mov EAX, [RSP];
            add EAX, 0x3fff;
            jle short L_largenegative;
            cmp EAX,0x8000;
            jge short L_largepositive;
            mov [RSP+8+8],AX;
            f2xm1; // 2^(y-rndint(y)) -1
            fld real ptr [RSP+8] ; // 2^rndint(y)
            fmul ST(1), ST;
            fld1;
            fsubp ST(1), ST;
            fadd;
            add RSP,24;
            ret;

L_extreme: // Extreme exponent. X is very large positive, very
            // large negative, infinity, or NaN.
            fxam;
            fstsw AX;
            test AX, 0x0400; // NaN_or_zero, but we already know x!=0
            jz L_was_nan; // if x is NaN, returns x
            test AX, 0x0200;
            jnz L_largenegative;
L_largepositive:
            // Set scratchreal = real.max.
            // squaring it will create infinity, and set overflow flag.
            mov word ptr [RSP+8+8], 0x7FFE;
            fstp ST(0);
            fld real ptr [RSP+8]; // load scratchreal
            fmul ST(0), ST; // square it, to create havoc!
L_was_nan:
            add RSP,24;
            ret;

L_largenegative:
            fstp ST(0);
            fld1;
            fchs; // return -1. Underflow flag is not set.
            add RSP,24;
            ret;
        }
    } else {
        return ocean.stdc.math.expm1l(x);
    }
}

/**
 * Calculates 2$(SUP x).
 *
 *  $(TABLE_SV
 *    $(TR $(TH x)             $(TH exp2(x))   )
 *    $(TR $(TD +$(INFIN))     $(TD +$(INFIN)) )
 *    $(TR $(TD -$(INFIN))     $(TD +0.0)      )
 *    $(TR $(TD $(NAN))        $(TD $(NAN))    )
 *  )
 */
real exp2(real x)
{
    version(Naked_D_InlineAsm_X86) {
      enum { PARAMSIZE = (real.sizeof+3)&(0xFFFF_FFFC) } // always a multiple of 4
      asm {
        /*  exp2() for x87 80-bit reals, IEEE754-2008 conformant.
         * Author: Don Clugston.
         *
         * exp2(x) = 2^(rndint(x))* 2^(y-rndint(x))
         * The trick for high performance is to avoid the fscale(28cycles on core2),
         * frndint(19 cycles), leaving f2xm1(19 cycles) as the only slow instruction.
         *
         * We can do frndint by using fist. BUT we can't use it for huge numbers,
         * because it will set the Invalid Operation flag is overflow or NaN occurs.
         * Fortunately, whenever this happens the result would be zero or infinity.
         *
         * We can perform fscale by directly poking into the exponent. BUT this doesn't
         * work for the (very rare) cases where the result is subnormal. So we fall back
         * to the slow method in that case.
         */
        naked;
        fld real ptr [ESP+4] ; // x
        mov AX, [ESP+4+8]; // AX = exponent and sign
        sub ESP, 12+8; // Create scratch space on the stack
        // [ESP,ESP+2] = scratchint
        // [ESP+4..+6, +8..+10, +10] = scratchreal
        // set scratchreal mantissa = 1.0
        mov dword ptr [ESP+8], 0;
        mov dword ptr [ESP+8+4], 0x80000000;
        and AX, 0x7FFF; // drop sign bit
        cmp AX, 0x401D; // avoid InvalidException in fist
        jae L_extreme;
        fist dword ptr [ESP]; // scratchint = rndint(x)
        fisub dword ptr [ESP]; // x - rndint(x)
        // and now set scratchreal exponent
        mov EAX, [ESP];
        add EAX, 0x3fff;
        jle short L_subnormal;
        cmp EAX,0x8000;
        jge short L_overflow;
        mov [ESP+8+8],AX;
L_normal:
        f2xm1;
        fld1;
        fadd; // 2^(x-rndint(x))
        fld real ptr [ESP+8] ; // 2^rndint(x)
        add ESP,12+8;
        fmulp ST(1), ST;
        ret PARAMSIZE;

L_subnormal:
        // Result will be subnormal.
        // In this rare case, the simple poking method doesn't work.
        // The speed doesn't matter, so use the slow fscale method.
        fild dword ptr [ESP];  // scratchint
        fld1;
        fscale;
        fstp real ptr [ESP+8]; // scratchreal = 2^scratchint
        fstp ST(0);         // drop scratchint
        jmp L_normal;

L_extreme: // Extreme exponent. X is very large positive, very
        // large negative, infinity, or NaN.
        fxam;
        fstsw AX;
        test AX, 0x0400; // NaN_or_zero, but we already know x!=0
        jz L_was_nan;  // if x is NaN, returns x
        // set scratchreal = real.min
        // squaring it will return 0, setting underflow flag
        mov word  ptr [ESP+8+8], 1;
        test AX, 0x0200;
        jnz L_waslargenegative;
L_overflow:
        // Set scratchreal = real.max.
        // squaring it will create infinity, and set overflow flag.
        mov word  ptr [ESP+8+8], 0x7FFE;
L_waslargenegative:
        fstp ST(0);
        fld real ptr [ESP+8];  // load scratchreal
        fmul ST(0), ST;        // square it, to create havoc!
L_was_nan:
        add ESP,12+8;
        ret PARAMSIZE;
      }
    } else version(D_InlineAsm_X86_64) {
        asm
        {
            naked;
        }
        asm
        {
            fld real ptr [RSP+8]; // x
            mov AX,[RSP+8+8]; // AX = exponent and sign
        }
        asm
        {
/* exp2() for x87 80-bit reals, IEEE754-2008 conformant.
 * Author: Don Clugston.
 *
 * exp2(x) = 2^(rndint(x))* 2^(y-rndint(x))
 * The trick for high performance is to avoid the fscale(28cycles on core2),
 * frndint(19 cycles), leaving f2xm1(19 cycles) as the only slow instruction.
 *
 * We can do frndint by using fist. BUT we can't use it for huge numbers,
 * because it will set the Invalid Operation flag is overflow or NaN occurs.
 * Fortunately, whenever this happens the result would be zero or infinity.
 *
 * We can perform fscale by directly poking into the exponent. BUT this doesn't
 * work for the (very rare) cases where the result is subnormal. So we fall back
 * to the slow method in that case.
 */
            sub RSP, 24; // Create scratch space on the stack
            // [RSP,RSP+2] = scratchint
            // [RSP+4..+6, +8..+10, +10] = scratchreal
            // set scratchreal mantissa = 1.0
            mov dword ptr [RSP+8], 0;
            mov dword ptr [RSP+8+4], 0x80000000;
            and AX, 0x7FFF; // drop sign bit
            cmp AX, 0x401D; // avoid InvalidException in fist
            jae L_extreme;
            fist dword ptr [RSP]; // scratchint = rndint(x)
            fisub dword ptr [RSP]; // x - rndint(x)
            // and now set scratchreal exponent
            mov EAX, [RSP];
            add EAX, 0x3fff;
            jle short L_subnormal;
            cmp EAX,0x8000;
            jge short L_overflow;
            mov [RSP+8+8],AX;
L_normal:
            f2xm1;
            fld1;
            fadd; // 2^(x-rndint(x))
            fld real ptr [RSP+8] ; // 2^rndint(x)
            add RSP,24;
            fmulp ST(1), ST;
            ret;

L_subnormal:
            // Result will be subnormal.
            // In this rare case, the simple poking method doesn't work.
            // The speed doesn't matter, so use the slow fscale method.
            fild dword ptr [RSP]; // scratchint
            fld1;
            fscale;
            fstp real ptr [RSP+8]; // scratchreal = 2^scratchint
            fstp ST(0); // drop scratchint
            jmp L_normal;

L_extreme: // Extreme exponent. X is very large positive, very
            // large negative, infinity, or NaN.
            fxam;
            fstsw AX;
            test AX, 0x0400; // NaN_or_zero, but we already know x!=0
            jz L_was_nan; // if x is NaN, returns x
            // set scratchreal = real.min
            // squaring it will return 0, setting underflow flag
            mov word ptr [RSP+8+8], 1;
            test AX, 0x0200;
            jnz L_waslargenegative;
L_overflow:
            // Set scratchreal = real.max.
            // squaring it will create infinity, and set overflow flag.
            mov word ptr [RSP+8+8], 0x7FFE;
L_waslargenegative:
            fstp ST(0);
            fld real ptr [RSP+8]; // load scratchreal
            fmul ST(0), ST; // square it, to create havoc!
L_was_nan:
            add RSP,24;
            ret;
        }
    } else {
        return ocean.stdc.math.exp2l(x);
    }
}

unittest {
    // NaN payloads
    assert(isIdentical(exp(NaN(0xABC)), NaN(0xABC)));
}

unittest {
    // NaN payloads
    assert(isIdentical(expm1(NaN(0xABC)), NaN(0xABC)));
}

unittest {
    // NaN payloads
    assert(isIdentical(exp2(NaN(0xABC)), NaN(0xABC)));
}

/*
 * Powers and Roots
 */

/**************************************
 * Calculate the natural logarithm of x.
 *
 *    $(TABLE_SV
 *    $(TR $(TH x)            $(TH log(x))    $(TH divide by 0?) $(TH invalid?))
 *    $(TR $(TD $(PLUSMN)0.0) $(TD -$(INFIN)) $(TD yes)          $(TD no))
 *    $(TR $(TD $(LT)0.0)     $(TD $(NAN))    $(TD no)           $(TD yes))
 *    $(TR $(TD +$(INFIN))    $(TD +$(INFIN)) $(TD no)           $(TD no))
 *    )
 */
real log(real x)
{
    return ocean.stdc.math.logl(x);
}

unittest {
    // NaN payloads
    assert(isIdentical(log(NaN(0xABC)), NaN(0xABC)));
}

/******************************************
 *      Calculates the natural logarithm of 1 + x.
 *
 *      For very small x, log1p(x) will be more accurate than
 *      log(1 + x).
 *
 *  $(TABLE_SV
 *  $(TR $(TH x)            $(TH log1p(x))     $(TH divide by 0?) $(TH invalid?))
 *  $(TR $(TD $(PLUSMN)0.0) $(TD $(PLUSMN)0.0) $(TD no)           $(TD no))
 *  $(TR $(TD -1.0)         $(TD -$(INFIN))    $(TD yes)          $(TD no))
 *  $(TR $(TD $(LT)-1.0)    $(TD $(NAN))       $(TD no)           $(TD yes))
 *  $(TR $(TD +$(INFIN))    $(TD -$(INFIN))    $(TD no)           $(TD no))
 *  )
 */
real log1p(real x)
{
    return ocean.stdc.math.log1pl(x);
}

unittest {
    // NaN payloads
    assert(isIdentical(log1p(NaN(0xABC)), NaN(0xABC)));
}

/***************************************
 * Calculates the base-2 logarithm of x:
 * $(SUB log, 2)x
 *
 *  $(TABLE_SV
 *  $(TR $(TH x)            $(TH log2(x))   $(TH divide by 0?) $(TH invalid?))
 *  $(TR $(TD $(PLUSMN)0.0) $(TD -$(INFIN)) $(TD yes)          $(TD no) )
 *  $(TR $(TD $(LT)0.0)     $(TD $(NAN))    $(TD no)           $(TD yes) )
 *  $(TR $(TD +$(INFIN))    $(TD +$(INFIN)) $(TD no)           $(TD no) )
 *  )
 */
real log2(real x)
{
    return ocean.stdc.math.log2l(x);
}

unittest {
    // NaN payloads
    assert(isIdentical(log2(NaN(0xABC)), NaN(0xABC)));
}

/**************************************
 * Calculate the base-10 logarithm of x.
 *
 *      $(TABLE_SV
 *      $(TR $(TH x)            $(TH log10(x))  $(TH divide by 0?) $(TH invalid?))
 *      $(TR $(TD $(PLUSMN)0.0) $(TD -$(INFIN)) $(TD yes)          $(TD no))
 *      $(TR $(TD $(LT)0.0)     $(TD $(NAN))    $(TD no)           $(TD yes))
 *      $(TR $(TD +$(INFIN))    $(TD +$(INFIN)) $(TD no)           $(TD no))
 *      )
 */
real log10(real x)
{
    return ocean.stdc.math.log10l(x);
}

unittest {
    // NaN payloads
    assert(isIdentical(log10(NaN(0xABC)), NaN(0xABC)));
}

/***********************************
 * Exponential, complex and imaginary
 *
 * For complex numbers, the exponential function is defined as
 *
 *  exp(z) = exp(z.re)cos(z.im) + exp(z.re)sin(z.im)i.
 *
 *  For a pure imaginary argument,
 *  exp(&theta;i)  = cos(&theta;) + sin(&theta;)i.
 *
 */
creal exp(ireal y)
{
   return expi(y.im);
}

/** ditto */
creal exp(creal z)
{
  return expi(z.im) * exp(z.re);
}

unittest {
    assert(exp(1.3e5Li)==cos(1.3e5L)+sin(1.3e5L)*1i);
    assert(exp(0.0Li)==1L+0.0Li);
    assert(exp(7.2 + 0.0i) == exp(7.2L));
    creal c = exp(ireal.nan);
    assert(isNaN(c.re) && isNaN(c.im));
    c = exp(ireal.infinity);
    assert(isNaN(c.re) && isNaN(c.im));
}

/***********************************
 *  Natural logarithm, complex
 *
 * Returns complex logarithm to the base e (2.718...) of
 * the complex argument x.
 *
 * If z = x + iy, then
 *       log(z) = log(abs(z)) + i arctan(y/x).
 *
 * The arctangent ranges from -PI to +PI.
 * There are branch cuts along both the negative real and negative
 * imaginary axes. For pure imaginary arguments, use one of the
 * following forms, depending on which branch is required.
 * ------------
 *    log( 0.0 + yi) = log(-y) + PI_2i  // y<=-0.0
 *    log(-0.0 + yi) = log(-y) - PI_2i  // y<=-0.0
 * ------------
 */
creal log(creal z)
{
  return log(abs(z)) + atan2(z.im, z.re)*1i;
}

/*
 * feqrel for complex numbers. Returns the worst relative
 * equality of the two components.
 */
private int cfeqrel(creal a, creal b)
{
    int intmin(int a, int b) { return a<b? a: b; }
    return intmin(feqrel(a.re, b.re), feqrel(a.im, b.im));
}

unittest {

  assert(log(3.0L +0i) == log(3.0L)+0i);
  assert(cfeqrel(log(0.0L-2i),( log(2.0L)-PI_2*1i)) >= real.mant_dig-10);
  assert(cfeqrel(log(0.0L+2i),( log(2.0L)+PI_2*1i)) >= real.mant_dig-10);
}

/**
 * Fast integral powers.
 */
real pow(real x, uint n)
{
    real p;

    switch (n)
    {
    case 0:
        p = 1.0;
        break;

    case 1:
        p = x;
        break;

    case 2:
        p = x * x;
        break;

    default:
        p = 1.0;
        while (1){
            if (n & 1)
                p *= x;
            n >>= 1;
            if (!n)
                break;
            x *= x;
        }
        break;
    }
    return p;
}

/** ditto */
real pow(real x, int n)
{
    if (n < 0) return pow(x, cast(real)n);
    else return pow(x, cast(uint)n);
}

/*********************************************
 * Calculates x$(SUP y).
 *
 * $(TABLE_SV
 * $(TR $(TH x) $(TH y) $(TH pow(x, y))
 *      $(TH div 0) $(TH invalid?))
 * $(TR $(TD anything)      $(TD $(PLUSMN)0.0)                $(TD 1.0)
 *      $(TD no)        $(TD no) )
 * $(TR $(TD |x| $(GT) 1)    $(TD +$(INFIN))                  $(TD +$(INFIN))
 *      $(TD no)        $(TD no) )
 * $(TR $(TD |x| $(LT) 1)    $(TD +$(INFIN))                  $(TD +0.0)
 *      $(TD no)        $(TD no) )
 * $(TR $(TD |x| $(GT) 1)    $(TD -$(INFIN))                  $(TD +0.0)
 *      $(TD no)        $(TD no) )
 * $(TR $(TD |x| $(LT) 1)    $(TD -$(INFIN))                  $(TD +$(INFIN))
 *      $(TD no)        $(TD no) )
 * $(TR $(TD +$(INFIN))      $(TD $(GT) 0.0)                  $(TD +$(INFIN))
 *      $(TD no)        $(TD no) )
 * $(TR $(TD +$(INFIN))      $(TD $(LT) 0.0)                  $(TD +0.0)
 *      $(TD no)        $(TD no) )
 * $(TR $(TD -$(INFIN))      $(TD odd integer $(GT) 0.0)      $(TD -$(INFIN))
 *      $(TD no)        $(TD no) )
 * $(TR $(TD -$(INFIN))      $(TD $(GT) 0.0, not odd integer) $(TD +$(INFIN))
 *      $(TD no)        $(TD no))
 * $(TR $(TD -$(INFIN))      $(TD odd integer $(LT) 0.0)      $(TD -0.0)
 *      $(TD no)        $(TD no) )
 * $(TR $(TD -$(INFIN))      $(TD $(LT) 0.0, not odd integer) $(TD +0.0)
 *      $(TD no)        $(TD no) )
 * $(TR $(TD $(PLUSMN)1.0)   $(TD $(PLUSMN)$(INFIN))          $(TD $(NAN))
 *      $(TD no)        $(TD yes) )
 * $(TR $(TD $(LT) 0.0)      $(TD finite, nonintegral)        $(TD $(NAN))
 *      $(TD no)        $(TD yes))
 * $(TR $(TD $(PLUSMN)0.0)   $(TD odd integer $(LT) 0.0)      $(TD $(PLUSMNINF))
 *      $(TD yes)       $(TD no) )
 * $(TR $(TD $(PLUSMN)0.0)   $(TD $(LT) 0.0, not odd integer) $(TD +$(INFIN))
 *      $(TD yes)       $(TD no))
 * $(TR $(TD $(PLUSMN)0.0)   $(TD odd integer $(GT) 0.0)      $(TD $(PLUSMN)0.0)
 *      $(TD no)        $(TD no) )
 * $(TR $(TD $(PLUSMN)0.0)   $(TD $(GT) 0.0, not odd integer) $(TD +0.0)
 *      $(TD no)        $(TD no) )
 * )
 */
real pow(real x, real y)
{
    version (linux) // C pow() often does not handle special values correctly
    {
    if (isNaN(y))
        return y;

    if (y == 0)
        return 1;       // even if x is $(NAN)
    if (isNaN(x) && y != 0)
        return x;
    if (isInfinity(y))
    {
        if (ocean.math.IEEE.fabs(x) > 1)
        {
            if (signbit(y))
                return +0.0;
            else
                return real.infinity;
        }
        else if (ocean.math.IEEE.fabs(x) == 1)
        {
            return NaN(TANGO_NAN.POW_DOMAIN);
        }
        else // < 1
        {
            if (signbit(y))
                return real.infinity;
            else
                return +0.0;
        }
    }
    if (isInfinity(x))
    {
        if (signbit(x))
        {
            long i;
            i = cast(long)y;
            if (y > 0)
            {
                if (i == y && i & 1)
                return -real.infinity;
                else
                return real.infinity;
            }
            else if (y < 0)
            {
                if (i == y && i & 1)
                return -0.0;
                else
                return +0.0;
            }
        }
        else
        {
            if (y > 0)
                return real.infinity;
            else if (y < 0)
                return +0.0;
        }
    }

    if (x == 0.0)
    {
        if (signbit(x))
        {
            long i;

            i = cast(long)y;
            if (y > 0)
            {
                if (i == y && i & 1)
                return -0.0;
                else
                return +0.0;
            }
            else if (y < 0)
            {
                if (i == y && i & 1)
                return -real.infinity;
                else
                return real.infinity;
            }
        }
        else
        {
            if (y > 0)
                return +0.0;
            else if (y < 0)
                return real.infinity;
        }
    }
    }

    return ocean.stdc.math.powl(x, y);
}

unittest
{
    real x = 46;

    assert(pow(x,0) == 1.0);
    assert(pow(x,1) == x);
    assert(pow(x,2) == x * x);
    assert(pow(x,3) == x * x * x);
    assert(pow(x,8) == (x * x) * (x * x) * (x * x) * (x * x));
    // NaN payloads
    assert(isIdentical(pow(NaN(0xABC), 19), NaN(0xABC)));
}

/***********************************************************************
 * Calculates the length of the
 * hypotenuse of a right-angled triangle with sides of length x and y.
 * The hypotenuse is the value of the square root of
 * the sums of the squares of x and y:
 *
 *      sqrt($(POW x, 2) + $(POW y, 2))
 *
 * Note that hypot(x, y), hypot(y, x) and
 * hypot(x, -y) are equivalent.
 *
 *  $(TABLE_SV
 *  $(TR $(TH x)            $(TH y)            $(TH hypot(x, y)) $(TH invalid?))
 *  $(TR $(TD x)            $(TD $(PLUSMN)0.0) $(TD |x|)         $(TD no))
 *  $(TR $(TD $(PLUSMNINF)) $(TD y)            $(TD +$(INFIN))   $(TD no))
 *  $(TR $(TD $(PLUSMNINF)) $(TD $(NAN))       $(TD +$(INFIN))   $(TD no))
 *  )
 */
real hypot(real x, real y)
{
    // Scale x and y to avoid underflow and overflow.
    // If one is huge and the other tiny, return the larger.
    // If both are huge, avoid overflow by scaling by 1/sqrt(real.max/2).
    // If both are tiny, avoid underflow by scaling by sqrt(real.min_normal*real.epsilon).

    const real SQRTMIN = 0x8.0p-8195L; // 0.5 * sqrt(min_normal!(real)); // This is a power of 2.
    const real SQRTMAX = 1.0L / SQRTMIN; // 2^^((max_exp)/2) = nextUp(sqrt(real.max))

    static assert(2 * (SQRTMAX / 2) * (SQRTMAX / 2) <= real.max);

    // Proves that sqrt(real.max) ~~  0.5/sqrt(real.min_normal)
    static assert(min_normal!(real) * real.max > 2 && min_normal!(real) * real.max <= 4);

    real u = fabs(x);
    real v = fabs(y);
    if (!(u >= v))  // check for NaN as well.
    {
        v = u;
        u = fabs(y);
        if (u == real.infinity) return u; // hypot(inf, nan) == inf
        if (v == real.infinity) return v; // hypot(nan, inf) == inf
    }

    // Now u >= v, or else one is NaN.
    if (v >= SQRTMAX * 0.5)
    {
            // hypot(huge, huge) -- avoid overflow
        u *= SQRTMIN * 0.5;
        v *= SQRTMIN * 0.5;
        return sqrt(u * u + v * v) * SQRTMAX * 2.0;
    }

    if (u <= SQRTMIN)
    {
        // hypot (tiny, tiny) -- avoid underflow
        // This is only necessary to avoid setting the underflow
        // flag.
        u *= SQRTMAX / real.epsilon;
        v *= SQRTMAX / real.epsilon;
        return sqrt(u * u + v * v) * SQRTMIN * real.epsilon;
    }

    if (u * real.epsilon > v)
    {
        // hypot (huge, tiny) = huge
        return u;
    }

    // both are in the normal range
    return sqrt(u * u + v * v);
}

unittest
{
    static real[3][] vals = // x,y,hypot
    [
        [ 0.0,   0.0,  0.0],
        [ 0.0,  -0.0,  0.0],
        [-0.0,  -0.0,  0.0],
        [ 3.0,   4.0,  5.0],
        [-300,  -400,  500],
        [ 0.0,   7.0,  7.0],
        [ 9.0,   9.0 * real.epsilon, 9.0],
        [ 0xb.0p+8188L /+88 / (64 * sqrt(real.min_normal))+/, 0xd.2p+8188L /+105 / (64 * sqrt(real.min_normal))+/, 0x8.9p+8189L /+137 / (64 * sqrt(real.min_normal))+/],
        [ 0xb.0p+8187L /+88 / (128 * sqrt(real.min_normal))+/, 0xd.2p+8187L /+105 / (128 * sqrt(real.min_normal))+/, 0x8.9p+8188L /+137 / (128 * sqrt(real.min_normal))+/],
        [ 3 * min_normal!(real) * real.epsilon, 4 * min_normal!(real) * real.epsilon, 5 * min_normal!(real) * real.epsilon],
        [ min_normal!(real), min_normal!(real),  0x1.6a09e667f3bcc908p-16382L /+sqrt(2.0L) * real,min_normal+/],
        [ real.max / 2.0, real.max / 2.0, 0x1.6a09e667f3bcc908p+16383L /+real.max / sqrt(2.0L)+/],
        [ 0x1.6a09e667f3bcc908p+16383L /+real.max / sqrt(2.0L)+/, 0x1.6a09e667f3bcc908p+16383L /+real.max / sqrt(2.0L)+/, real.max],
        [ real.max, 1.0, real.max],
        [ real.infinity, real.nan, real.infinity],
        [ real.nan, real.infinity, real.infinity],
        [ real.nan, real.nan, real.nan],
        [ real.nan, real.max, real.nan],
        [ real.max, real.nan, real.nan]
    ];

    for (int i = 0; i < vals.length; i++)
    {
        real x = vals[i][0];
        real y = vals[i][1];
        real z = vals[i][2];
        real h = hypot(x, y);

        assert(isIdentical(z, h));
    }
    // NaN payloads
    assert(isIdentical(hypot(NaN(0xABC), 3.14), NaN(0xABC)));
    assert(isIdentical(hypot(7.6e39, NaN(0xABC)), NaN(0xABC)));
}

/***********************************
 * Evaluate polynomial A(x) = $(SUB a, 0) + $(SUB a, 1)x + $(SUB a, 2)$(POWER x,2)
 *                          + $(SUB a,3)$(POWER x,3); ...
 *
 * Uses Horner's rule A(x) = $(SUB a, 0) + x($(SUB a, 1) + x($(SUB a, 2)
 *                         + x($(SUB a, 3) + ...)))
 * Params:
 *      A =     array of coefficients $(SUB a, 0), $(SUB a, 1), etc.
 *      x =  point in which to evaluate polynomial
 */
T poly(T)(T x, T[] A)
in
{
    assert(A.length > 0);
}
body
{
  version (Naked_D_InlineAsm_X86) {
      const bool Use_D_InlineAsm_X86 = true;
  } else const bool Use_D_InlineAsm_X86 = false;

  // BUG (Inherited from Phobos): This code assumes a frame pointer in EBP.
  // This is not in the spec.
  static if (Use_D_InlineAsm_X86 && is(T==real) && T.sizeof == 10) {
    asm // assembler by W. Bright
    {
        // EDX = (A.length - 1) * real.sizeof
        mov     ECX,A[EBP]          ; // ECX = A.length
        dec     ECX                 ;
        lea     EDX,[ECX][ECX*8]    ;
        add     EDX,ECX             ;
        add     EDX,A+4[EBP]        ;
        fld     real ptr [EDX]      ; // ST0 = coeff[ECX]
        jecxz   return_ST           ;
        fld     x[EBP]              ; // ST0 = x
        fxch    ST(1)               ; // ST1 = x, ST0 = r
        align   4                   ;
    L2:  fmul    ST,ST(1)           ; // r *= x
        fld     real ptr -10[EDX]   ;
        sub     EDX,10              ; // deg--
        faddp   ST(1),ST            ;
        dec     ECX                 ;
        jne     L2                  ;
        fxch    ST(1)               ; // ST1 = r, ST0 = x
        fstp    ST(0)               ; // dump x
        align   4                   ;
    return_ST:                      ;
        ;
    }
  } else static if ( Use_D_InlineAsm_X86 && is(T==real) && T.sizeof==12){
    asm // assembler by W. Bright
    {
        // EDX = (A.length - 1) * real.sizeof
        mov     ECX,A[EBP]          ; // ECX = A.length
        dec     ECX                 ;
        lea     EDX,[ECX*8]         ;
        lea     EDX,[EDX][ECX*4]    ;
        add     EDX,A+4[EBP]        ;
        fld     real ptr [EDX]      ; // ST0 = coeff[ECX]
        jecxz   return_ST           ;
        fld     x                   ; // ST0 = x
        fxch    ST(1)               ; // ST1 = x, ST0 = r
        align   4                   ;
    L2: fmul    ST,ST(1)            ; // r *= x
        fld     real ptr -12[EDX]   ;
        sub     EDX,12              ; // deg--
        faddp   ST(1),ST            ;
        dec     ECX                 ;
        jne     L2                  ;
        fxch    ST(1)               ; // ST1 = r, ST0 = x
        fstp    ST(0)               ; // dump x
        align   4                   ;
    return_ST:                      ;
        ;
        }
  } else {
        ptrdiff_t i = A.length - 1;
        real r = A[i];
        while (--i >= 0)
        {
            r *= x;
            r += A[i];
        }
        return r;
  }
}

unittest
{
    real x = 3.1;
    const real[] pp = [56.1L, 32.7L, 6L];

    assert( poly(x, pp) == (56.1L + (32.7L + 6L * x) * x) );

    assert(isIdentical(poly(NaN(0xABC), pp), NaN(0xABC)));
}

package {
    T rationalPoly(T)(T x, T [] numerator, T [] denominator)
    {
        return poly(x, numerator)/poly(x, denominator);
    }
}

/*
 * Rounding (returning real)
 */

/**
 * Returns the value of x rounded downward to the next integer
 * (toward negative infinity).
 */
real floor(real x)
{
    return ocean.stdc.math.floorl(x);
}

unittest {
    assert(isIdentical(floor(NaN(0xABC)), NaN(0xABC)));
}

/**
 * Returns the value of x rounded upward to the next integer
 * (toward positive infinity).
 */
real ceil(real x)
{
    return ocean.stdc.math.ceill(x);
}

unittest {
    assert(isIdentical(ceil(NaN(0xABC)), NaN(0xABC)));
}

/**
 * Return the value of x rounded to the nearest integer.
 * If the fractional part of x is exactly 0.5, the return value is rounded to
 * the even integer.
 */
real round(real x)
{
    return ocean.stdc.math.roundl(x);
}

unittest {
    assert(isIdentical(round(NaN(0xABC)), NaN(0xABC)));
}

/**
 * Returns the integer portion of x, dropping the fractional portion.
 *
 * This is also known as "chop" rounding.
 */
real trunc(real x)
{
    return ocean.stdc.math.truncl(x);
}

unittest {
    assert(isIdentical(trunc(NaN(0xABC)), NaN(0xABC)));
}

/**
* Rounds x to the nearest int or long.
*
* This is generally the fastest method to convert a floating-point number
* to an integer. Note that the results from this function
* depend on the rounding mode, if the fractional part of x is exactly 0.5.
* If using the default rounding mode (ties round to even integers)
* rndint(4.5) == 4, rndint(5.5)==6.
*/
int rndint(real x)
{
    version(Naked_D_InlineAsm_X86)
    {
        int n;
        asm
        {
            fld x;
            fistp n;
        }
        return n;
    }
    else
    {
        return cast(int) ocean.stdc.math.lrintl(x);
    }
}

/** ditto */
long rndlong(real x)
{
    version(Naked_D_InlineAsm_X86)
    {
        long n;
        asm
        {
            fld x;
            fistp n;
        }
        return n;
    }
    else
    {
        return ocean.stdc.math.llrintl(x);
    }
}

version(D_InlineAsm_X86)
{
    // Won't work for anything else yet

    unittest
    {
        int r = getIeeeRounding;
        assert(r==RoundingMode.ROUNDTONEAREST);
        real b = 5.5;
        int cnear = ocean.math.Math.rndint(b);
        assert(cnear == 6);
        auto oldrounding = setIeeeRounding(RoundingMode.ROUNDDOWN);
        scope (exit) setIeeeRounding(oldrounding);

        assert(getIeeeRounding==RoundingMode.ROUNDDOWN);

        int cdown = ocean.math.Math.rndint(b);
        assert(cdown==5);
    }

    unittest
    {
        // Check that the previous test correctly restored the rounding mode
        assert(getIeeeRounding==RoundingMode.ROUNDTONEAREST);
    }
}

/***************************************************************************

    Integer pow function. Returns the power'th power of base

    Params:
        base  = base number
        power = power

    Returns:
        the power'th power of base

***************************************************************************/

public ulong pow ( ulong base, ulong power )
{
    ulong res = void;

    switch (power)
    {
        case 0:
            res = 1;
            break;
        case 1:
            res = base;
            break;
        case 2:
            res = base * base;
            break;

        default:
            res = 1;

            while (1)
            {
                if (power & 1) res *= base;
                power >>= 1;
                if (!power) break;
                base *= base;
            }
            break;
    }

    return res;
}

unittest
{
    ulong x = 46;

    assert(pow(x,0UL) == 1);
    assert(pow(x,1UL) == x);
    assert(pow(x,2UL) == x * x);
    assert(pow(x,3UL) == x * x * x);
    assert(pow(x,8UL) == (x * x) * (x * x) * (x * x) * (x * x));
}

/*******************************************************************************

    Does an integer division, rounding towards the nearest integer.
    Rounds to the even one if both integers are equal near.

    Params:
        a = number to divide
        b = number to divide by

    Returns:
        number divided according to given description

*******************************************************************************/

T divRoundEven(T)(T a, T b)
{
    // both integers equal near?
    if (b % 2 == 0 && (a % b == b / 2 || a % b == -b / 2))
    {
        auto div_rounded_down = a / b;

        auto add = div_rounded_down < 0 ? -1 : 1;

        return div_rounded_down % 2 == 0 ?
            div_rounded_down : div_rounded_down + add;
    }

    if ( (a >= 0) != (b >= 0) )
    {
        return (a - b / 2) / b;
    }
    else
    {
        return (a + b / 2) / b;
    }
}

version (UnitTest)
{
    import ocean.math.Math : rndlong;
}

unittest
{
    long roundDivCheat ( long a, long b )
    {
        real x = cast(real)a / cast(real)b;
        return rndlong(x);
    }

    assert(divRoundEven(-3, 2)  == -2);
    assert(divRoundEven(3, 2)   == 2);
    assert(divRoundEven(-3, -2) == 2);
    assert(divRoundEven(3, -2)  == -2);

    assert(divRoundEven(7, 11) == 1);
    assert(divRoundEven(11, 11) == 1);
    assert(divRoundEven(16, 11) == 1);
    assert(divRoundEven(-17, 11) == -2);
    assert(divRoundEven(-17, 11) == -2);
    assert(divRoundEven(-16, 11) == -1);

    assert(divRoundEven(17, -11) == -2);
    assert(divRoundEven(16, -11) == -1);
    assert(divRoundEven(-17, -11) == 2);
    assert(divRoundEven(-16, -11) == 1);

    for (int i = -100; i <= 100; ++i) for (int j = -100; j <= 100; ++j)
    {
        if (j != 0)
        {
            assert (divRoundEven(i,j) == roundDivCheat(i,j));
        }
    }
}

