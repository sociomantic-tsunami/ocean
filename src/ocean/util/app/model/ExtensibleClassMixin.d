/*******************************************************************************

    Mixin for classes that support extensions.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.app.model.ExtensibleClassMixin;



/*******************************************************************************

    Imports

    Do not import stuff that's used inside the mixin implementation, see the
    comment in ExtensibleClassMixin for more details.

*******************************************************************************/

// TODO: import ocean.util.app.model.IExtension;



/*******************************************************************************

    Mixin for classes that support extensions.

    It just provides a simple container for extensions (ordered in the order
    provided by BaseExtension.order()) registering of extensions, and getting an
    extension based on its type.

    Typical usage:

    ---

    interface ISomeExtension : IExtension
    {
        void someMethod ( );
    }

    class SomeExtensibleClass
    {
        mixin ExtensibleClassMixin!(ISomeExtension);

        void something ( )
        {
            foreach (ext; this.extensions)
            {
                ext.someMethod();
            }
        }
    }

    ---

    TODO: Assert that ExtensionClass is derived from IExtension

*******************************************************************************/

template ExtensibleClassMixin ( ExtensionClass )
{

    /*******************************************************************************

        Unfortunatelly template mixins needs to have all the symbols they use
        available in the code making the mixing. For that reason, symbols
        needed by this template are made public inside the template as the less
        ugly solution. The class namespace will be polluted with the import
        symbols but nothing else. The symbols imported are prepended with
        mixin_ to make clear where they came from and to avoid accidental name
        clashing.

     *******************************************************************************/

    import ocean.core.Array : mixin_sort = sort;


    /***************************************************************************

        List of extensions. Will be kept sorted by extension order when using
        the registerExtension() method.

    ***************************************************************************/

    ExtensionClass[] extensions;


    /***************************************************************************

        Register a new extension, keeping extensions list sorted.

        Extensions are considered unique by type, so is invalid to register
        2 extensions with the exact same type.

        Params:
            ext = new extension to register

    ***************************************************************************/

    public void registerExtension ( ExtensionClass ext )
    {
        // TODO: Assert that we don't already have an extension of the same type

        this.extensions ~= ext;
        mixin_sort(this.extensions,
            ( ExtensionClass e1, ExtensionClass e2 )
            {
                return e1.order < e2.order;
            });
    }


    /***************************************************************************

        Get an extension based on its type.

        Returns:
            the instance of the extension of the type Ext, or null if not found

    ***************************************************************************/

    public Ext getExtension ( Ext ) ( )
    {
        // TODO: Assert that Ext is derived from ExtensionClass
        foreach (e; this.extensions)
        {
            Ext ext = cast(Ext) e;
            if ( ext !is null )
            {
                return ext;
            }
        }

        return null;
    }

}

