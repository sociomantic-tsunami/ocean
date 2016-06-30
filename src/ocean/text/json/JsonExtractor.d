/******************************************************************************

    Toolkit to extract values from JSON content of an expected structure.

    Usage example:

    ---

    const content =
    `{`
        `"id":"8c97472e-098e-4baa-aa63-4a3f2aab10c6",`
        `"imp":`
        `[`
            `{`
                 `"impid":"7682f6f1-810c-49b0-8388-f91ba4a00c1d",`
                 `"h":480,`
                 `"w":640,`
                 `"btype": [ 1,2,3 ],`
                 `"battr": [ 3,4,5 ]`
            `}`
        `],`
        `"site":`
        `{`

            `"sid":"1",`
            `"name":"MySite",`
            `"pub":"MyPublisher",`
            `"cat": [ "IAB1", "IAB2" ],`
            `"page":"http://www.example.com/"`
        `},`
        `"user":`
        `{`
            `"uid":"45FB778",`
            `"buyeruid":"100"`
        `},`
        `"device":`
        `{`
            `"ip":"192.168.0.1",`
            `"ua":"Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/534.30 `
                  `(KHTML, like Gecko) Chrome/12.0.742.53 Safari/534.30"`
        `},`
        `"cud":`
        `{`
            `"age":"23",`
            `"gender":"female"`
        `}`
    `}`;

    // Aliases to avoid polluting this example with dozens of "JsonExtractor.".

    alias JsonExtractor.Parser    Parser;   // actually aliases JsonParserIter
    alias JsonExtractor.GetField  GetField;
    alias JsonExtractor.GetObject GetObject;
    alias JsonExtractor.GetArray  GetArray;
    alias JsonExtractor.Main      Main;
    alias JsonExtractor.Type      Type;     // actually aliases JsonParser.Token

    // Create JSON parser instance.

    Parser json = new Parser;

    // Create one GetField instance for each JSON object field to extract.

    GetField id    = new GetField,
             impid = new GetField,
             page  = new GetField,
             uid   = new GetField,
             h     = new GetField,
             w     = new GetField;

    // Create one GetObject instance for each JSON subobject that contains
    // fields to extract and pass an associative array of name/GetField
    // instance pairs to define the fields that should be extracted in this
    // subobject.

    GetObject site = new GetObject(json, ["page": page]),
              user = new GetObject(json, ["uid": uid]),
                            // cast needed to prevent array type inference error
       imp_element = new GetObject(json, ["impid"[]: impid, "w": w, "h": h]);


    // Create one IterateArray instance for each JSON array that contains
    // members to extract.

    GetArray imp = new GetArray(json, [imp_element]
                               (uint i, Type type, cstring value)
                               {
                                   // This delegate will be called for each
                                   // "imp" array element with i as index. Note
                                   // that value is meaningful only if type is
                                   // type.String or type.Number.
                                   // We are interested in the first array
                                   // element only, which we expect to be an
                                   // object, so we call imp_element.set() when
                                   // i is 0. We return true if we handle the
                                   // element or false to make imp skip it.

                                   bool handled = i == 0;

                                   if (handled)
                                   {
                                       if (type == type.BeginObject)
                                       {
                                           imp_element.set(type);
                                       }
                                       else throw new Exception
                                       (
                                           "\"imp\" array element is not an "
                                           "object as expected!"
                                       );
                                   }

                                   return handled;
                               });

    // Create a Main (GetObject subclass) instance for the main JSON object and
    // pass the top level getters.

    Main main = new Main(json, ["id"[]: id, "imp": imp, "site": site,
                                "user": user]);

    // Here we go.

    main.parse(content);

    // id.type  is now Type.String
    // id.value is now "8c97472e-098e-4baa-aa63-4a3f2aab10c6"

    // impid.type  is now Type.String
    // impid.value is now "7682f6f1-810c-49b0-8388-f91ba4a00c1d"

    // page.type  is now Type.String
    // page.value is now "http://www.example.com/"

    // uid.type  is now Type.String
    // uid.value is now "45FB778"

    // h.type  is now Type.Number
    // h.value is now "480"

    // w.type  is now Type.Number
    // w.value is now "640"

    ---

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

 ******************************************************************************/

module ocean.text.json.JsonExtractor;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.text.json.JsonParserIter;
import ocean.core.Array;
import ocean.core.Enforce : enforce;
import ocean.core.Test;
import ocean.util.ReusableException;


/*******************************************************************************

    Exception which only can be thrown by JsonExtractor

*******************************************************************************/

private class JsonException : ReusableException {}


struct JsonExtractor
{
    static:

    /**************************************************************************

        Type aliases for using code

     **************************************************************************/

    alias JsonParserIter!(false) Parser;

    alias JsonParserIter!(false).Token Type;

    /***************************************************************************

        JSON main/top level object getter

     **************************************************************************/

    class Main : GetObject
    {
        /***********************************************************************

            JSON parser instance

         **********************************************************************/

        private Parser json;

        /***********************************************************************

            Constructor, specifies getters for named and unnamed fields.

            If the i-th object field is not named and the i-th instance element
            in get_indexed_fields is not null, it will be invoked with that
            field.

            Params:
                json               = JSON parser
                get_named_fields   = list of getters for named fields,
                                     associated with field names
                get_indexed_fields = list of getters for fields without name,
                                     may contain null elements to ignore fields.

         **********************************************************************/

        public this ( Parser json, GetField[cstring] get_named_fields,
                      GetField[] get_indexed_fields ... )
        {
            super(this.json = json, get_named_fields, get_indexed_fields);
        }

        /***********************************************************************

            Resets all type/value results and parses content, extracting types
            and values for the fields to extract.

            Params:
                content = JSON content to parse

            Returns:
                true on success or false otherwise.

            Throws:
                Propagates exceptions thrown in
                ocean.text.json.JsonParser.parse().

         **********************************************************************/

        bool parse ( cstring content )
        {
            super.reset();

            bool ok = this.json.reset(content);

            if (ok)
            {
                super.set(this.json.type);
            }

            return ok;
        }
    }

    /***************************************************************************

        JSON field getter, extracts type and value of a field.

     **************************************************************************/

    class GetField
    {
        /**********************************************************************

            Field type

         **********************************************************************/

        Type type;

        /***********************************************************************

            Field value, meaningful only for certain types, especially
            Type.String and Type.Number. Corresponds to the value returned by
            JsonParser.value() for this field.

         **********************************************************************/

        public cstring value = null;

        /***********************************************************************

            Sets type and value for the field represented by this instance.

            Params:
                type  = field type
                value = field value if meaningful (depends on type)

         **********************************************************************/

        final void set ( Type type, cstring value = null )
        {
            this.type  = type;
            this.value = value;
            this.set_();
        }

        /**********************************************************************

            Resets type and value.

         **********************************************************************/

        final void reset ( )
        {
            this.type  = this.type.init;
            this.value = null;
            this.reset_();
        }

        /***********************************************************************

            To be overridden, called when set() has finished.

         **********************************************************************/

        protected void set_ ( ) { }

        /***********************************************************************

            To be overridden, called when reset() has finished.

         **********************************************************************/

        protected void reset_ ( ) { }
    }

    /**************************************************************************

        JSON object getter, invokes registered field getters with type and value
        of the corresponding fields in a JSON object.

     **************************************************************************/

    class GetObject : IterateAggregate
    {
        /***********************************************************************

            If enabled, any unmatched field will result in an exception.

         *********************************************************************/

        public bool strict;

        /***********************************************************************

            List of getters for named fields, each associated with the name of a
            field.

         **********************************************************************/

        private GetField[cstring] get_named_fields;

        /***********************************************************************

            List of getters for fields without name, may contain null elements
            to ignore fields.  If the i-th object field is not named and the
            i-th instance element is not null, it will be invoked with that
            field.

         **********************************************************************/

        private GetField[]       get_indexed_fields;


        /***********************************************************************

            Thrown as indicator when strict behavior enforcement fails.

         *********************************************************************/

        private JsonException field_unmatched;

        /***********************************************************************

            Constructor, specifies getters for named and unnamed fields.

            If the i-th object field is not named and the i-th instance element
            in get_indexed_fields is not null, it will be invoked with that
            field.

            Params:
                json               = JSON parser
                get_named_fields   = list of getters for named fields,
                                     associated with field names
                get_indexed_fields = list of getters for fields without name,
                                     may contain null elements to ignore fields.

         **********************************************************************/

        public this ( Parser json, GetField[cstring] get_named_fields,
                      GetField[] get_indexed_fields ... )
        {
            this(json, false, get_named_fields, get_indexed_fields);
        }

        /***********************************************************************

            Constructor, specifies getters for named and unnamed fields.

            If the i-th object field is not named and the i-th instance element
            in get_indexed_fields is not null, it will be invoked with that
            field.

            Params:
                json               = JSON parser
                skip_null          = should a potential null value be skipped?
                get_named_fields   = list of getters for named fields,
                                     associated with field names
                get_indexed_fields = list of getters for fields without name,
                                     may contain null elements to ignore fields.

         **********************************************************************/

        public this ( Parser json, bool skip_null,
                      GetField[cstring] get_named_fields,
                      GetField[] get_indexed_fields ... )
        {
            super(json, Type.BeginObject, Type.EndObject, skip_null);

            this.field_unmatched = new JsonException();
            this.get_named_fields = get_named_fields.rehash;
            this.get_indexed_fields = get_indexed_fields;
        }

        /***********************************************************************

            Add the field to the list of named objects to get.

            Params:
                name = the name of the field
                field = the field instance

         **********************************************************************/

        public void addNamedField ( cstring name, GetField field )
        {
            this.get_named_fields[name] = field;
        }

        /***********************************************************************

            Remove a field from the list of named objects to get.

            Params:
                name = the name of the field

         **********************************************************************/

        public void removeNamedField ( cstring name )
        {
            this.get_named_fields.remove(name);
        }

        /***********************************************************************

            Called by super.reset() to reset all field getters.

         **********************************************************************/

        protected override void reset_ ( )
        {
            foreach (get_field; this.get_named_fields)
            {
                get_field.reset();
            }

            foreach (get_field; this.get_indexed_fields)
            {
                get_field.reset();
            }
        }

        /***********************************************************************

            Called by super.reset() to reset all field getters.

         **********************************************************************/

        protected override void set_ ( )
        {
            super.set_();

            if (this.strict)
            {
                foreach (name, field; this.get_named_fields)
                {
                    if (field.type == Type.Empty)
                    {
                        throw this.field_unmatched
                            .set("Field '")
                            .append(name)
                            .append("' not found in JSON");
                    }
                }

                foreach (i, field; this.get_indexed_fields)
                {
                    if (field.type == Type.Empty)
                    {
                        throw this.field_unmatched
                            .set("Unnamed field not found in JSON");
                    }
                }
            }
        }

        /***********************************************************************

            Picks the field getter responsible for the field corresponding to
            name, or i if unnamed, and sets its type and value.

            Params:
                i     = field index
                type  = field type
                name  = field name or null if unnamed.
                value = field value, meaningful only for certain types.

            Returns:
                true if a getter handled the field or false to skip it.

         **********************************************************************/

        protected override bool setField ( uint i, Type type, cstring name, cstring value )
        {
            GetField get_field = this.getGetField(i, name);

            bool handle = get_field !is null;

            if (handle)
            {
                get_field.set(type, value);
            }

            return handle;
        }

        /***********************************************************************

            Picks the field getter responsible for the field corresponding to
            name, or i if unnamed.

            Params:
                i     = field index
                name  = field name or null if unnamed

            Returns:
                GetField instance responsible for the field or null if there is
                no responsible getter.

         **********************************************************************/

        private GetField getGetField ( uint i, cstring name )
        {
            GetField* get_field = name?
                                    name in this.get_named_fields :
                                    (i < this.get_indexed_fields.length)?
                                        &this.get_indexed_fields[i] :
                                        null;

            return get_field? *get_field : null;
        }
    }

    /**************************************************************************

        JSON array getter, invokes a callback delegate with each element in a
        JSON array.

     **************************************************************************/

    class GetArray : IterateArray
    {
        /***********************************************************************

            Iteration callback delegate type alias. The delegate must either use
            an appropriate GetField (or subclass) instance to handle and move
            the parser to the end of the field or indicate that this field is
            ignored and unhandled.

            Params:
                i     = element index counter, starts with 0
                type  = element type
                value = element value, meaningful only for certain types.

            Returns:
                true if an appropriate GetField (or subclass) instance was used
                to handle and move the parser to the end of the field or false
                if the field is ignored and unhandled and should be skipped.

         **********************************************************************/

        public alias bool delegate ( uint i, Type type, cstring value) IteratorDg;

        /***********************************************************************

            Iteration callback delegate

         **********************************************************************/

        private IteratorDg iterator_dg;

        /***********************************************************************

            List of fields to reset when this.reset is called.

         **********************************************************************/

        private GetField[] fields_to_reset;

        /***********************************************************************

            Constructor

            Params:
                json            = JSON parser
                fields_to_reset = fields to reset when this.reset is called
                iterator_dg     = iteration callback delegate
                skip_null       = should a potential null value be skipped? If
                                  false and a null value is found a
                                  JsonException will be thrown.

         **********************************************************************/

        public this ( Parser json, GetField[] fields_to_reset,
                      IteratorDg iterator_dg, bool skip_null = false )
        {
            super(json, skip_null);

            this.fields_to_reset = fields_to_reset;

            this.iterator_dg = iterator_dg;
        }

        /***********************************************************************

            Invokes the iteration callback delegate.

            Params:
                i     = field index
                type  = field type
                name  = (ignored)
                value = field value

            Returns:
                passes through the return value of the delegate.

         **********************************************************************/

        protected override bool setField ( uint i, Type type, cstring name,
            cstring value )
        {
            return this.iterator_dg(i, type, value);
        }


        /***********************************************************************

            Called by super.reset() to reset all field given by fields_to_reset.

         **********************************************************************/

        protected override void reset_ ( )
        {
            foreach (get_field; this.fields_to_reset)
            {
                get_field.reset();
            }
        }
    }

    /**************************************************************************

        Abstract JSON array iterator. As an alternative to the use of an
        iteration callback delegate with GetArray one can derive from this
        class and implement setField().

     **************************************************************************/

    abstract class IterateArray : IterateAggregate
    {
        /***********************************************************************

            Constructor

            Params:
                type = expected parameter type
                key  = parameter name
                skip_null  = should a potential null value be skipped? If false
                             and a null value is found an JsonException will
                             be thrown.

         **********************************************************************/

        public this ( Parser json, bool skip_null = false )
        {
            super(json, Type.BeginArray, Type.EndArray, skip_null);
        }
    }

    /**************************************************************************

        JSON object or array iterator.

     **************************************************************************/

    abstract class IterateAggregate : GetField
    {

        /***********************************************************************

            Skip null value?

         **********************************************************************/

        private bool skip_null;

        /**********************************************************************

            Start and end token type, usually BeginObject/EndObject or
            BeginArray/EndArray.

         **********************************************************************/

        public Type start_type, end_type;

        /***********************************************************************

            JSON parser instance

         **********************************************************************/

        private Parser json;

        /***********************************************************************

            Exception throw to indicate errors during parsing.

         **********************************************************************/

        protected JsonException exception;

        /***********************************************************************

            Constructor

            Params:
                json       = JSON parser, can't be null
                start_type = opening token type of the aggregate this instance
                             iterates over (usually BeginObject or BeginArray)
                end_type   = closing token type of the aggregate this instance
                             iterates over (usually EndObject or EndArray)
                skip_null  = should a potential null value be skipped? If false
                             and a null value is found an AssertException will
                             be thrown.

         **********************************************************************/

        public this ( Parser json, Type start_type, Type end_type,
                      bool skip_null = false )
        {
            assert(json !is null);
            this.start_type = start_type;
            this.end_type   = end_type;
            this.json       = json;
            this.exception  = new JsonException();
            this.skip_null  = skip_null;
        }

        /***********************************************************************

            Invoked by super.set() to iterate over the JSON object or array.
            Expects the type of the current token to be
             - the start type if this.skip_null is false or
             - the start type or null if this.skip_null is true.

            Throws:
                JsonException if the type of the current token is not as
                expected.

         **********************************************************************/

        protected override void set_ ( )
        {
            enforce(this.exception,
                    (this.type == this.start_type) ||
                    (this.skip_null && this.type == Type.Null),
                    "type mismatch");

            uint i = 0;

            if (this.json.next()) foreach (type, name, value; this.json)
            {
                if (type == this.end_type)
                {
                    break;
                }
                else if (!this.setField(i++, type, name, value))
                {
                    this.json.skip();
                }
            }
        }

        /***********************************************************************

            Abstract iteration method, must either use an appropriate GetField
            (or subclass) instance to handle and move the parser to the end of
            the field or indicate that this field is ignored and unhandled.

            Params:
                i     = element index counter, starts with 0.
                name  = field name or null if the field is unnamed or iterating
                        over an array.
                type  = element type
                value = element value, meaningful only for certain types.

            Returns:
                true if an appropriate GetField (or subclass) instance was used
                to handle and move the parser to the end of the field or false
                if the field is ignored and unhandled and should be skipped.

         **********************************************************************/

        abstract protected bool setField ( uint i, Type type, cstring name,
                                           cstring value );
    }

    /**************************************************************************/

    unittest
    {
        const content =
        `{`
            `"id":"8c97472e-098e-4baa-aa63-4a3f2aab10c6",`
            `"imp":`
            `[`
                `{`
                     `"impid":"7682f6f1-810c-49b0-8388-f91ba4a00c1d",`
                     `"h":480,`
                     `"w":640,`
                     `"btype": [ 1,2,3 ],`
                     `"battr": [ 3,4,5 ]`
                `},`
                `{`
                    `"Hello": "World!"`
                `},`
                `12345`
            `],`
            `"site":`
            `{`
                `"sid":"1",`
                `"name":"MySite",`
                `"pub":"MyPublisher",`
                `"cat": [ "IAB1", "IAB2" ],`
                `"page":"http://www.example.com/"`
            `},`
            `"bcat": null,`
            `"user":`
            `{`
                `"uid":"45FB778",`
                `"buyeruid":"100"`
            `},`
            `"device":`
            `{`
                `"ip":"192.168.0.1",`
                `"ua":"Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/534.30 `
                     `(KHTML, like Gecko) Chrome/12.0.742.53 Safari/534.30"`
            `},`
            `"cud":`
            `{`
                `"age":"23",`
                `"gender":"female"`
            `}`
        `}`;

        auto t = new NamedTest("JsonExtractor");


        scope json        = new Parser,
              id          = new GetField,
              impid       = new GetField,
              page        = new GetField,
              uid         = new GetField,
              h           = new GetField,
              w           = new GetField,
              not         = new GetField,
              site        = new GetObject(json, ["page": page]),
              user        = new GetObject(json, ["uid": uid]),
              imp_element = new GetObject(json, ["impid"[]: impid,
                                                 "w": w]),
              bcat        = new GetObject(json, true, ["not":not]),
              imp         = new GetArray(json, [imp_element],
                                       (uint i, Type type, cstring value)
                                       {
                                           bool handled = i == 0;

                                           if (handled)
                                           {
                                               t.test!("==")(type,
                                                             type.BeginObject);
                                               imp_element.set(type);
                                           }

                                           return handled;
                                       }),
           main          = new Main(json, ["id"[]: id, "imp": imp,
                                           "site": site, "user": user]);

        imp_element.addNamedField("h", h);

        bool ok = main.parse(content);

        t.test(ok, "parse didn't return true");

        t.test!("==")(id.type, Type.String);
        t.test!("==")(id.value, "8c97472e-098e-4baa-aa63-4a3f2aab10c6"[]);

        t.test!("==")(impid.type, Type.String);
        t.test!("==")(impid.value, "7682f6f1-810c-49b0-8388-f91ba4a00c1d"[]);

        t.test!("==")(page.type, Type.String);
        t.test!("==")(page.value, "http://www.example.com/"[]);

        t.test!("==")(uid.type, Type.String);
        t.test!("==")(uid.value, "45FB778"[]);

        t.test!("==")(not.type, Type.Empty);
        t.test!("==")(not.value, ""[]);

        t.test!("==")(h.type, Type.Number);
        t.test!("==")(h.value, "480"[]);

        t.test!("==")(w.type, Type.Number);
        t.test!("==")(w.value, "640"[]);

        imp_element.removeNamedField("h");
        h.reset();

        ok = main.parse(content);

        t.test(ok, "parse didn't return true"[]);

        t.test!("==")(h.type, Type.Empty);
        t.test!("==")(h.value, ""[]);


        ok = main.parse("{}");

        t.test(ok, "parse didn't return true"[]);

        t.test!("==")(id.value, ""[]);
        t.test!("==")(id.type, Type.Empty);

        t.test!("==")(impid.value, ""[]);
        t.test!("==")(impid.type, Type.Empty);

        t.test!("==")(page.value, ""[]);
        t.test!("==")(page.type, Type.Empty);

        t.test!("==")(uid.value, ""[]);
        t.test!("==")(uid.type, Type.Empty);

        t.test!("==")(not.type, Type.Empty);
        t.test!("==")(not.value, ""[]);

        t.test!("==")(h.value, ""[]);
        t.test!("==")(h.type, Type.Empty);

        t.test!("==")(w.value, ""[]);
        t.test!("==")(w.type, Type.Empty);

        const content2 = `{"imp":null}`;

        try
        {
            main.parse(content2);
            t.test(false, "parse didn't throw"[]);
        }
        catch (JsonException e)
        {
            t.test!("==")(getMsg(e), "type mismatch"[]);
        }

        bool fun (uint i, Type type, cstring value)
        {
            return false;
        }

        scope imp2  = new GetArray(json, null, &fun, true),
              main2 = new Main(json, ["imp": imp2]);

        ok = main2.parse(content2);

        t.test(ok, "parse didn't return true"[]);

    }
}
