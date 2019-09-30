### Function `ocean.text.Util : layout` has been deprecated

`ocean.text.Util`

This function was duplicating the functionality of `Formatter`.
Additionally, the speed advantage does not apply anymore,
as the overhead of the old Tango `Layout` was due to the usage of `TypeInfo`,
and performances should be equivalent nowadays.
Lastly, most usage in Ocean were to format temporaries into buffer,
and later pass them to a delegate,
something that can be done without temporary using `sformat`.
