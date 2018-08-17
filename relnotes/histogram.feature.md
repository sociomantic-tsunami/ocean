### Add statistics counter for generating a time histogram

* `ocean.math.TimeHistogram`

A timing statistics counter for any sort of transaction that takes a
microsecond to a second to complete. Collects the following statistical
information:

- a logarithmic time histogram with bins from ≥1µs to <1s, three bins per
  power of ten in a  stepping of 1 .. 2 .. 5 .., plus one bin for each <1µs
  and ≥1s,

- the total number of transactions and the aggregated total completion time.

