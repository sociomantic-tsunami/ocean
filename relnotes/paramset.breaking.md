### Ignore remaining elements in `FullQueryParamSet.opApply`

Now `opApply` behavior in `FullQueryParamSet` is consistent with other methods
such as `opIn` and will ignore remaining (not specified in constructor)
elements.

This is a silent breaking change in runtime behavior - please review your app
usage of `FullQueryParamSet` carefully and switch to plain `QueryParamSet` if
necessary.
