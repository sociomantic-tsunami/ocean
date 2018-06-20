### Deprecate UnixSocketExt.add/removeInteractiveHandler

There's no need to separate addHandler/removeHandler for
different types of handlers, instead overloads of `addHandler`/
`removeHandler` should be used.
