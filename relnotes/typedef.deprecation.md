* `ocean.core.Traits`

  `StripTypedef` and `isTypedef` templates are deprecated with intention to
  revisit every place where those have been used and evaluate if such custom
  handling is still needed in D2 builds. New `ocean.transition.isD1Typedef`
  and `ocean.transition.TypedefBaseType` templates were added to clearly
  differentiate such places after decision will be made.
