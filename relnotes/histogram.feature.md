### New binary logarithmic histogram for integer values

`ocean.math.BinaryHistogram`

The new struct template `BinaryHistogram` is useful for tracking stats on the
distribution of any kind of integer values, separated into power of two bins.
The struct provides a method for convenient passing of the aggregated stats to a
`StatsLog` instance.

