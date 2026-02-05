# Introduction
The main functionality provided by PlutoDevMacros is the possibility of loading local packages within a Pluto notebook without requiring to activate a local environment (and thus deactivate the Pluto package manager).

This functionality is implemented inside the `FromPackage` submodule of `PlutoDevMacros` and accessed throught the [`@fromparent`](@ref) or [`@frompackage`](@ref) macros.
!!! note
    Both [`@fromparent`](@ref) and [`@frompackage`](@ref) are exported by `PlutoDevMacros` itself without requiring to explicitly use `FromPackage`.

While the [`@fromparent`](@ref) macro was initially developed in order to facilitate creating Julia packages using Pluto notebooks as building blocks, in its current implementation it helps a lot with prototyping and testing during local package development, even when creating normal packages not relying on Pluto notebooks as building blocks.

This macro allows in fact to load the module of a local package within a running Pluto notebook and permits to easily reload the local code upon request similar to a `Revise`-based workflow but with a few notable advantages:
- Package code can be re-evaluated correctly without requiring a julia restart even when re-defining structs or constants
- Local code reload, triggered manually via a floating button in the Pluto notebook, automatically triggers execution of all dependent cells, simplifying the process of testing changes of code on specific runtime paths
- Possibilty of adding packages to the notebook environment which are not dependencies of the local package, very useful for testing plotting or benchmarking of the local package code without having to put the related packages in either the global or package-local environment
- Support for the package extensions functionality added in julia 1.9, which together with the point on notebook environment above simplify the testing and development of extensions on the local package under development.

More details on the synthax and functionality of these macros is given in the following sections.

```@docs
PlutoDevMacros.FromPackage.@frompackage
PlutoDevMacros.FromPackage.@fromparent
```
