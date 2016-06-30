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

module ocean.text.xml.DocPrinter;

import ocean.transition;

import ocean.io.model.IConduit;

import ocean.text.xml.Document;

import ocean.core.Exception_tango : XmlException;

version (UnitTest)
{
    import ocean.text.xml.Document;
}


/*******************************************************************************

        Simple Document printer, with support for serialization caching
        where the latter avoids having to generate unchanged sub-trees

*******************************************************************************/

class DocPrinter(T)
{
        public alias Document!(T) Doc;  /// the typed document
        public alias Doc.Node Node;             /// generic document node

        private bool quick = true;
        private uint indentation = 2;

        private const Eol = "\n";

        /***********************************************************************

                Sets the number of spaces used when increasing indentation
                levels. Use a value of zero to disable explicit formatting

        ***********************************************************************/

        final DocPrinter indent (uint indentation)
        {
                this.indentation = indentation;
                return this;
        }

        /***********************************************************************

                Enable or disable use of cached document snippets. These
                represent document branches that remain unaltered, and
                can be emitted verbatim instead of traversing the tree

        ***********************************************************************/

        final DocPrinter cache (bool yes)
        {
                this.quick = yes;
                return this;
        }

        /***********************************************************************

                Generate a text representation of the document tree

        ***********************************************************************/

        final Const!(T)[] print (Doc doc, T[] content=null)
        {
                if(content !is null)
                    print (doc.tree, (Const!(T)[][] s...)
                        {
                            size_t i=0;
                            foreach(t; s)
                            {
                                if(i+t.length >= content.length)
                                    throw new XmlException("Buffer is to small");

                                content[i..t.length] = t;
                                i+=t.length;
                            }
                            content.length = i;
                        });
                else
                    print (doc.tree, (Const!(T)[][] s...){foreach(t; s) content ~= t;});
                return content;
        }

        /***********************************************************************

                Generate a text representation of the document tree

        ***********************************************************************/

        final void print (Doc doc, OutputStream stream)
        {
                print (doc.tree, (Const!(T)[][] s...){foreach(t; s) stream.write(t);});
        }

        /***********************************************************************

                Generate a representation of the given node-subtree

        ***********************************************************************/

        final void print (Node root, void delegate(Const!(T)[][]...) emit)
        {
                T[256] tmp;
                T[256] spaces = ' ';

                // ignore whitespace from mixed-model values
                Const!(T)[] rawValue (Node node)
                {
                        foreach (c; node.rawValue)
                                 if (c > 32)
                                     return node.rawValue;
                        return null;
                }

                void printNode (Node node, uint indent)
                {
                        // check for cached output
                        if (node.end && quick)
                           {
                           auto p = node.start;
                           auto l = node.end - p;
                           // nasty hack to retain whitespace while
                           // dodging prior EndElement instances
                           if (*p is '>')
                               ++p, --l;
                           emit (p[0 .. l]);
                           }
                        else
                        switch (node.id)
                               {
                               case XmlNodeType.Document:
                                    foreach (n; node.children)
                                             printNode (n, indent);
                                    break;

                               case XmlNodeType.Element:
                                    if (indentation > 0)
                                        emit (Eol, spaces[0..indent]);
                                    emit ("<", node.toString(tmp));

                                    foreach (attr; node.attributes)
                                             emit (` `, attr.toString(tmp), `="`, attr.rawValue, `"`);

                                    auto value = rawValue (node);
                                    if (node.child)
                                       {
                                       emit (">");
                                       if (value.length)
                                           emit (value);
                                       foreach (child; node.children)
                                                printNode (child, indent + indentation);

                                       // inhibit newline if we're closing Data
                                       if (node.lastChild.id != XmlNodeType.Data && indentation > 0)
                                           emit (Eol, spaces[0..indent]);
                                       emit ("</", node.toString(tmp), ">");
                                       }
                                    else
                                       if (value.length)
                                           emit (">", value, "</", node.toString(tmp), ">");
                                       else
                                          emit ("/>");
                                    break;

                                    // ingore whitespace data in mixed-model
                                    // <foo>
                                    //   <bar>blah</bar>
                                    //
                                    // a whitespace Data instance follows <foo>
                               case XmlNodeType.Data:
                                    auto value = rawValue (node);
                                    if (value.length)
                                        emit (node.rawValue);
                                    break;

                               case XmlNodeType.Comment:
                                    emit ("<!--", node.rawValue, "-->");
                                    break;

                               case XmlNodeType.PI:
                                    emit ("<?", node.rawValue, "?>");
                                    break;

                               case XmlNodeType.CData:
                                    emit ("<![CDATA[", node.rawValue, "]]>");
                                    break;

                               case XmlNodeType.Doctype:
                                    emit ("<!DOCTYPE ", node.rawValue, ">");
                                    break;

                               default:
                                    emit ("<!-- unknown node type -->");
                                    break;
                               }
                }

                printNode (root, 0);
        }
}

///
unittest
{
    istring document = "<blah><xml>foo</xml></blah>";

    auto doc = new Document!(char);
    doc.parse (document.dup);

    auto p = new DocPrinter!(char);
    char[1024] buf;
    auto newbuf = p.print (doc, buf);
    assert(document == newbuf);
    assert(buf.ptr == newbuf.ptr);
    assert(document == p.print(doc));
}
