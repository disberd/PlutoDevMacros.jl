# PlutoDevMacros

Documentation for [PlutoDevMacros](https://github.com/disberd/PlutoDevMacros.jl).

This is a package containing macros/functions to help develop Packages using [Pluto](https://github.com/fonsp/Pluto.jl) notebooks testing/prototyping aids.

The major feature contribution of this package is the @fromparent macro, which allows to load a local package in Pluto and have its code re-parsed and updated upon manual re-run of the cell containing the macro call.

## Quickstart

To load the parent package of a notebook, i.e. the package that is in the same directory or parent directory of a notebook file use:

```julia
using PlutoDevMacros

@fromparent import *
```

In Pluto you will then see a `Reload` button which can be used to reload the module on any changes.

For more information please refer to the explanations linked below.

## @frompackage/@fromparent
```@contents
Pages = [
    "frompackage/introduction.md",
    "frompackage/basic_use.md",
    "frompackage/import_statements.md",
    "frompackage/skipping_parts.md",
    "frompackage/use_with_plutopkg.md",
    "frompackage/package_extensions.md",
]
Depth = 1
```