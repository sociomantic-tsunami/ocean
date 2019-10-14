/*******************************************************************************

    Copyright:
        Copyright (C) 2017 dunnhumby Germany GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.meta.types.Templates;

/*******************************************************************************

    Emulates `static if (Type : Template!(Args), Args...)`, which is a D2
    feature

    Given a template and an instance of it, allows to get the arguments used
    to instantiate this type.

    An example use case is when you want to wrap an aggregate which is templated
    and need your `Wrapper` class to be templated on the aggregate's template
    arguments:
    ---
    class Wrapper (TArgs...) { /+ Magic stuff +/ }
    class Aggregate (TArgs...) { /+ Some more magic +/ }

    Wrapper!(TemplateInstanceArgs!(Aggregate, Inst)) wrap (Inst) (Inst i)
    {
        auto wrapper = new Wrapper!(TemplateInstanceArgs!(Aggregate, Inst))(i);
        return wrapper;
    }
    ---

    This can also be used to see if a given symbol is an instance of a template:
    `static if (is(TemplateInstanceArgs!(Template, PossibleInstance)))`

    Note that eponymous templates can lead to surprising behaviour:
    ---
    template Identity (T)
    {
        alias T Identity;
    }

    // The following will fail, because `Identity!(char)` resolves to `char` !
    static assert(is(TemplateInstanceArgs!(Identity, Identity!(char))));
    ---

    As a result, this template is better suited for template aggregates,
    or templates with multiple members.

    Params:
        Template = The template symbol (uninstantiated)
        Type     = An instance of `Template`

*******************************************************************************/

public template TemplateInstanceArgs (alias Template, Type : Template!(TA), TA...)
{
    public alias TA TemplateInstanceArgs;
}

version (unittest)
{
    private class BaseTestClass (T) {}
    private class DerivedTestClass (T) : BaseTestClass!(T) {}
}

unittest
{
    // Same type
    static assert (is(TemplateInstanceArgs!(BaseTestClass, BaseTestClass!(int[]))));
    // Derives
    static assert (is(TemplateInstanceArgs!(BaseTestClass, DerivedTestClass!(int))));
    // Not a template
    static assert (!is(TemplateInstanceArgs!(Object, BaseTestClass!(int))));
    // Not a type
    static assert (!is(TemplateInstanceArgs!(BaseTestClass, BaseTestClass)));
    // Doesn't derive / convert
    static assert (!is(TemplateInstanceArgs!(int, BaseTestClass)));
}

