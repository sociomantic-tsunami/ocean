## The old Tango Layout modules were removed

* `ocean.text.convert.Layout`, `ocean.text.convert.Layout_tango`, `ocean.core.RuntimeTraits`

Those modules where removed. The Layout one should be completely replaced with the Formatter.
`RuntimeTraits` was only used by Layout_tango, and provided incomplete support for its functionalities, especially in D2.
