### Fix function to check for UTF-8 string type

`ocean.meta.traits.Arrays`

The function `ocean.meta.traits.Arrays.isUTF8StringType()` is suggested to
replace the deprecated `ocean.core.Traits.isStringType()` but it failed to
check for static arrays and now it is fixed to support both basic kind of
arrays.

Fixes #778
