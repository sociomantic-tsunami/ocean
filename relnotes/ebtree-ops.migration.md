### Replacement of IEBtree protected operators

* `ocean.util.container.ebtree.IEBTree`

The `opAddAssign` and `opSubAssign` operators have been replaced with
`increaseNodeCount` and `decreaseNodeCount`.
These are protected member functions used only in the implementation of
the EBTree classes, so no impact on user code is expected.
