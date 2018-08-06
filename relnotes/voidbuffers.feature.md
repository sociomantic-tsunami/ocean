### Safe wrapper for casting a `void[]` to another array type

`ocean.util.container.VoidBufferAsArrayOf`

It is, of course, possible to simply cast a `void[]` to another type of array
and use it directly. However, care must be taken when casting to an array type
with a different element size. Experience has shown that this is likely to hit
undefined behaviour. For example, casting the array then sizing it has been
observed to cause segfaults, e.g.:

```
    void[]* void_array; // acquired from somewhere

    struct S { int i; hash_t h; }
    auto s_array = cast(S[]*)void_array;
    s_array.length = 23;
```

The exact reason for the segfaults is not known, but this usage appears to lead
to corruption of internal GC data (possibly type metadata associated with the
array's pointer).

Sizing the array first, then casting is fine, e.g.:

```
    void[]* void_array; // acquired from somewhere

    struct S { int i; hash_t h; }
    (*void_array).length = 23 * S.sizeof;
    auto s_array = cast(S[])*void_array;
```

The helper `VoidBufferAsArrayOf` simplifies this procedure and removes the risk
of undefined behaviour by always handling the `void[]` as a `void[]` internally.

