## Accept string to split in (Chr/Str)SplitIterators' constructor

* `ocean.text.util.SplitIterator`

  `ChrSplitIterator` and `StrSplitIterator` now can accept data to split
  as early as in the constructor, so the pattern `new Iterator('x'); it.reset(data)`
  can be avoided if more convenient.

