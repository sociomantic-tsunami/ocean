### Deprecation of `FullQueryParamSet`

This class was not used in our code in any way that can't be replaced by plain
`QueryParamSet` and had inconsistencies in its API design. Rather than trying
to fix those, it was decided to deprecate/remove this unused utility altogether.
