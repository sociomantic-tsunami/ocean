## Replace `Time.toString` with `asPrettyStr(time)`

`ocean.time.Time`

`toString` methods have been deprecated to eventually break circular
dependency beween time structs and big chunk of text formatting code. To keep
old formatting with next ocean major please adapt code which looks like this:

```D
format("{}", time);
```

To be instead written like this:

```D
import ocean.text.convert.DateTime_tango;
format("{}", asPrettyStr(time));
```
