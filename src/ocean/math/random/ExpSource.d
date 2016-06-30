/*******************************************************************************

        Copyright:
            Copyright (c) 2008. Fawzi Mohamed
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: July 2008

        Authors: Fawzi Mohamed

*******************************************************************************/
module ocean.math.random.ExpSource;
import Integer = ocean.text.convert.Integer_tango;
import ocean.math.Math:exp,log;
import ocean.math.random.Ziggurat;
import ocean.core.Traits:isRealType;

/// class that returns exponential distributed numbers (f=exp(-x) for x>0, 0 otherwise)
final class ExpSource(RandG,T){
    static assert(isRealType!(T),T.stringof~" not acceptable, only floating point variables supported");
    /// probability distribution
    static real probDensityF(real x){ return exp(-x); }
    /// inverse probability distribution
    static real invProbDensityF(real x){ return -log(x); }
    /// complement of the cumulative density distribution (integral x..infinity probDensityF)
    static real cumProbDensityFCompl(real x){ return exp(-x); }
    /// tail for exponential distribution
    static T tailGenerator(RandG r, T dMin)
    {
        return dMin-log(r.uniform!(T));
    }
    alias Ziggurat!(RandG,T,probDensityF,tailGenerator,false) SourceT;
    /// internal source of exp distribued numbers
    SourceT source;
    /// initializes the probability distribution
    this(RandG r){
        source=SourceT.create!(invProbDensityF,cumProbDensityFCompl)(r,0xf.64ec94bf5dc14bcp-1L);
    }
    /// chainable call style initialization of variables (thorugh a call to randomize)
    ExpSource opCall(U,S...)(ref U a,S args){
        randomize(a,args);
        return this;
    }
    /// returns a exp distribued number
    T getRandom(){
        return source.getRandom();
    }
    /// returns a exp distribued number with the given beta (survival rate, average)
    /// f=1/beta*exp(-x/beta)
    T getRandom(T beta){
        return beta*source.getRandom();
    }
    /// initializes the given variable with an exponentially distribued number
    U randomize(U)(ref U x){
        return source.randomize(x);
    }
    /// initializes the given variable with an exponentially distribued number with
    /// scale parameter beta
    U randomize(U,V)(ref U x,V beta){
        return source.randomizeOp((T el){ return el*cast(T)beta; },x);
    }
    /// initializes the given variable with an exponentially distribued number and maps op on it
    U randomizeOp(U,S)(S delegate(T)op,ref U a){
        return source.randomizeOp(op,a);
    }
    /// exp distribution with different default scale parameter beta
    /// f=1/beta*exp(-x/beta) for x>0, 0 otherwise
    struct ExpDistribution{
        T beta;
        ExpSource source; // does not use Ziggurat directly to keep this struct small
        /// constructor
        static ExpDistribution create()(ExpSource source,T beta){
            ExpDistribution res;
            res.beta=beta;
            res.source=source;
            return res;
        }
        /// chainable call style initialization of variables (thorugh a call to randomize)
        ExpDistribution opCall(U,S...)(ref U a,S args){
            randomize(a,args);
            return *this;
        }
        /// returns a single number
        T getRandom(){
            return beta*source.getRandom();
        }
        /// initialize a
        U randomize(U)(ref U a){
            return source.randomizeOp((T x){return beta*x; },a);
        }
        /// initialize a
        U randomize(U,V)(ref U a,V b){
            return source.randomizeOp((T x){return (cast(T)b)*x; },a);
        }
    }
    /// returns an exp distribution with a different beta
    ExpDistribution expD(T beta){
        return ExpDistribution.create(this,beta);
    }
}
