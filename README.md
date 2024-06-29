# PlutoDevMacros

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://disberd.github.io/PlutoDevMacros.jl/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://disberd.github.io/PlutoDevMacros.jl/dev)
[![Build Status](https://github.com/disberd/PlutoDevMacros.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/disberd/PlutoDevMacros.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![Coverage](https://codecov.io/gh/disberd/PlutoDevMacros.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/disberd/PlutoDevMacros.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

> [!WARNING]
> This package is currently undergoing a significant refactoring, the documentation is still outdated and will be updated (together with the README) once the code is stabilized

This is a package containing macros/functions to help develop Packages using [Pluto](https://github.com/fonsp/Pluto.jl) notebooks testing/prototyping aids.

The major feature contribution of this package is the `@fromparent` macro, which allows to load a local package in Pluto and have its code re-parsed and updated upon manual re-run of the cell containing the macro call.
This is simlar to a `Revise`-based workflow but provides a few notable advantages:
- Package code can be re-evaluated correctly without requiring a julia restart even when re-defining structs or constants
- Local code reload, triggered manually via a floating button in the Pluto notebook, automatically triggers execution of all dependent cells, simplifying the process of testing changes of code on specific runtime paths
- Possibilty of adding packages to the notebook environment which are not dependencies of the local package, very useful for testing plotting or benchmarking of the local package code without having to put the related packages in either the global or package-local environment
- Support for the package extensions functionality added in julia 1.9, which together with the point on notebook environment above simplify the testing and development of extensions on the local package under development.

See the [documentation](https://disberd.github.io/PlutoDevMacros.jl/) for more details.
