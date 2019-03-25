### Replace `package_.d` with `package.d`

Now that ocean is D2-only, existing `package_.d` modules that imitated wildcard
imports got replaced with actual `package.d` system. In practice that means that
any import of `some.mod.package_` needs to be replaced with import of
`some.mod`.
