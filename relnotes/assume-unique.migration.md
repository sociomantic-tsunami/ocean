### Move `assumeUnique` to `ocean.core.TypeConvert`

`ocean.core.TypeConvert`, `ocean.transition`

This helper function is not merely transitional: as an ocean counterpart
to the Phobos `std.exception.assumeUnique` function it will continue to
be useful even in D2-only code.  The function has therefore been moved
to an appropriate non-transitional module.

`ocean.transition` retains access to the function via a `public import`,
so there should be no impact on downstream apps or libraries, but code
transitioning to D2 only can import the new module in order to bypass
any `ocean.transition` dependency.
