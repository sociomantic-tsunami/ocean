module ocean.meta.traits.Aggregates_test;

import ocean.meta.traits.Aggregates;

// https://github.com/sociomantic-tsunami/ocean/issues/492

struct Test(T)
{
    void foo ( T x ) { }
}

unittest
{
    static assert (hasMethod!(Test!(int), "foo", void delegate(int)));
}
