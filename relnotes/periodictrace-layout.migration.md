## `PeriodicTrace` and `StaticTrace` were switched to the Formatter

* `ocean.util.log.PeriodicTrace`, `ocean.util.log.StaticTrace`

Those modules now use `ocean.text.convert.Formatter` for string formatting instead of
`ocean.text.convert.Layout_tango`.
As a result, they cannot have runtime variadic arguments forwarded to them
(only `PeriodicTrace` was offering such an interface).
As a result, code forwarding runtime vararg should switch to CT vararg:

```D
public void trace (cstring fmt, ...)
{
    PeriodicTrace.format(fmt, __va_argsave, _arguments);
}

// Should become:
public void trace (Args...) (cstring fmt, Args args)
{
    PeriodicTrace.format(fmt, args);
}
```

Non-forwarding usages are expected to be either unaffected or provide better output.
