# PlutoDevMacros

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://disberd.github.io/PlutoDevMacros.jl/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://disberd.github.io/PlutoDevMacros.jl/dev)
[![Build Status](https://github.com/disberd/PlutoDevMacros.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/disberd/PlutoDevMacros.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![Coverage](https://codecov.io/gh/disberd/PlutoDevMacros.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/disberd/PlutoDevMacros.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

Develop a Julia package from a [Pluto](https://github.com/fonsp/Pluto.jl)
notebook. Load the code of your package into the notebook, change it, and
click a button to load it again. The cells that use the package then run
again with the new code.

## Quickstart

Put a Pluto notebook in the folder of your package and run this code in a
cell:

```julia
using PlutoDevMacros

@fromparent import *
```

The cell loads your package and imports all its names into the notebook.
After you change the code of the package, click the reload button in the
top-right corner of the notebook.

The package needs a manifest file. For a new package, run `Pkg.instantiate()`
in its environment first, or use `@fromparent import * manifest = :instantiate`.

## Features

- A reload button that loads the package again, also after a change to a
  struct.
  See the [first tutorial](https://disberd.github.io/PlutoDevMacros.jl/dev/tutorials/first_package/).
- Import syntax for specific names, submodules, and dependencies of the
  package.
  See [Import specific names and submodules](https://disberd.github.io/PlutoDevMacros.jl/dev/howto/import_names/).
- Packages that only the notebook uses, from the Pluto package manager.
  See [Use packages that only the notebook needs](https://disberd.github.io/PlutoDevMacros.jl/dev/howto/notebook_only_packages/).
- Package extensions that load when the notebook loads their trigger
  packages.
  See the [extension tutorial](https://disberd.github.io/PlutoDevMacros.jl/dev/tutorials/package_extension/).
- `@only_in_nb`, `@only_out_nb`, and `@addmethod` for notebooks that are
  also package code.
  See the [reference of the other exports](https://disberd.github.io/PlutoDevMacros.jl/dev/reference/other_exports/).

The [documentation](https://disberd.github.io/PlutoDevMacros.jl/) has
tutorials, how-to guides, the reference, and explanations.

Talk: [PlutoDevMacros at JuliaCon 2024](https://www.youtube.com/watch?v=eHRURW6Wfpc)
([slides](https://github.com/disberd/JuliaCon2024)).
