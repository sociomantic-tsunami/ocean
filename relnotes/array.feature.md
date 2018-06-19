### New array search utilities

`ocean.core.array.Search`

New added bcontains function doesn't require you to pass
a position variable to tell you the position of the
found item. It only checks if the array contains the
item by using bsearch.

New added bsubset function takes two arrays and
checks if the first one contains all the items of
the second one by using bcontains function.
