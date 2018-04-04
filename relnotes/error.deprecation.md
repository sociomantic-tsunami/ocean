### Deprecate aliases in `ExceptionDefinions` that forward to errors

Symbols like `AssertException` or `OutOfMemoryException` are in fact `Error`
derivatives in D2. During original ocean porting compatibility aliases for
those were added to `ocean.core.ExceptionDefinions` module to simplify stage 2
migration. However now that we put most effort into stages 3 and 4, this
becomes a liability as catching those errors is never correct when D2 build is
deployed.

For example, throwing/catching `ArrayBoundsExceptions` should be replaced by
explicitly checking if element is present in array before access and throwing
custom exception type instead. Similar approach can be applied to most
deprecated symbols.

`AssertError` is special here because after conversion to `verify` it should not
ever be thrown by libraries and thus can be simply removed.
