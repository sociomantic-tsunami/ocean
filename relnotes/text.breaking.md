### De-templatize `ocean.text.Util` and `ocean.text.Search`

Most functions in these two modules have changed from templated to ones
accepting plain `cstring`/`mstring`/`inout(char)[]` arguments. This can cause
downstream breakage in two ways:

1) Trying to use these utilities with `wchar[]` and `dchar[]` strings is not
   supported anymore.
2) Code that tries to provide template arguments manually will fail to compile
   and needs to be adjusted to only provide runtime arguments.
