## Improved memory usage by XML PullParser in D2 builds

`ocean.text.xml.PullParser`

Now doesn't copy input text neither in D1, nor in D2 builds, operating on const
slices only. Used to have different code path for D2, resulting in new
allocations each time it was reset.

`ocean.text.xml.Document`

Following changes in `PullParser`, will copy more data from its slices into XML
node element. Memory usage by `Document` will increase (but will stay fixed for
a given document), but combined memory usage of `PullParser` + `Document` will
be the same or even smaller.
