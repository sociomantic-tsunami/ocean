/*******************************************************************************

        Copyright:
            Copyright (C) 2008 Kris Bell.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version: Initial release: March 2008

        Authors: Kris

*******************************************************************************/

module ocean.text.xml.DocTester;

import ocean.core.Exception_tango;

import ocean.text.xml.Document;

import ocean.text.convert.Format;

/*******************************************************************************

        Validate a document

        TODO: add various tests here, or in subclasses, as required

*******************************************************************************/

protected class DocTester(T)
{
        private alias Document!(T) Doc;         /// the typed document
        private alias Doc.Node     Node;        /// generic document node

        /***********************************************************************

                Generate a text representation of the document tree

        ***********************************************************************/

        final void validate (Doc doc)
        {
                validate (doc.elements);
        }

        /***********************************************************************

                Generate a representation of the given node-subtree

        ***********************************************************************/

        final void validate (Node node)
        {
                switch (node.id)
                       {
                       case XmlNodeType.Document:
                            foreach (n; node.children)
                                     validate (n);
                            break;

                       case XmlNodeType.Element:
                            element (node);

                            foreach (n; node.attributes)
                                     attribute (n);

                            foreach (n; node.children)
                                     validate (n);
                            break;

                       case XmlNodeType.Attribute:
                            attribute (node);
                            break;

                       case XmlNodeType.Data:
                            data (node);
                            break;

                       case XmlNodeType.Comment:
                            comment (node);
                            break;

                       case XmlNodeType.PI:
                            pi (node);
                            break;

                       case XmlNodeType.CData:
                            cdata (node);
                            break;

                       case XmlNodeType.Doctype:
                            doctype (node);
                            break;
                       }
        }

        /***********************************************************************

                validate an element

        ***********************************************************************/

        void element (Node node)
        {
                uniqueAttrNames (node);
        }

        /***********************************************************************

                validate an attribute

        ***********************************************************************/

        void attribute (Node node)
        {
        }

        /***********************************************************************

                validate a data node

        ***********************************************************************/

        void data (Node node)
        {
        }

        /***********************************************************************

                validate a comment node

        ***********************************************************************/

        void comment (Node node)
        {
        }

        /***********************************************************************

                validate a pi node

        ***********************************************************************/

        void pi (Node node)
        {
        }

        /***********************************************************************

                validate a cdata node

        ***********************************************************************/

        void cdata (Node node)
        {
        }

        /***********************************************************************

                validate a doctype node

        ***********************************************************************/

        void doctype (Node node)
        {
        }

        /***********************************************************************

                Ensure attribute names are unique within the element

        ***********************************************************************/

        static void uniqueAttrNames (Node node)
        {
                T[128]  name1 = void,
                        name2 = void;

                // non-optimal, but is it critical?
                foreach (attr; node.attributes)
                        {
                        auto name = attr.name (name1);
                        auto next = attr.nextSibling;
                        while (next !is null)
                              {
                              if (name == next.name(name2))
                                  error ("duplicate attribute name '{}' for element '{}'",
                                          name, node.name(name2));
                              next = attr.nextSibling;
                              }
                        }
        }

        /***********************************************************************

                halt validation

        ***********************************************************************/

        static void error (char[] format, ...)
        {
                throw new TextException (Format.convert(_arguments, _argptr, format));
        }
}




/*******************************************************************************

*******************************************************************************/

debug (DocTester)
{
        void main()
        {
                auto v = new DocTester!(char);
        }
}
