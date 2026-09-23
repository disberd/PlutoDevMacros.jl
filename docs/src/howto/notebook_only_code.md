# Run code only inside or outside the notebook

A Pluto notebook file is a Julia file, so the target package can `include`
it as source code. Use [`@only_in_nb`](@ref) for code that must run only
when you open the notebook, such as examples and checks. Use
[`@only_out_nb`](@ref) for code that must run only when the package loads
the file.

The example on this page adds a notebook `scale.jl` to the `MyPkg` package
from the tutorials.

## Add the dependencies

The first lines of a notebook file contain `using Markdown` and
`using InteractiveUtils`. The package code also calls `using PlutoDevMacros`.
Add these three packages to the dependencies of `MyPkg`. In the Julia REPL,
run:

```julia
import Pkg
Pkg.activate("path/to/MyPkg")
Pkg.add(["PlutoDevMacros", "Markdown", "InteractiveUtils"])
```

## Write the notebook

Save a new notebook as `MyPkg/src/scale.jl`, with these cells:

```julia
using PlutoDevMacros
```

```julia
@fromparent import *
```

```julia
scale(p::Point, k) = Point(k * p.x, k * p.y, k * p.z)
```

```julia
@only_in_nb scale(Point(1, 2, 3), 2)
```

Add this line to `MyPkg/src/MyPkg.jl`, before `end # module MyPkg`:

```julia
include("scale.jl")
```

## Know what runs where

In the notebook `scale.jl`, `@fromparent` loads `MyPkg` up to the
`include("scale.jl")` line. The `@only_in_nb` cell runs and shows the scaled
point.

When `MyPkg` loads in any other way, the `@only_in_nb` cell does nothing.
This is the case for `using MyPkg` in the Julia REPL, and for a different
notebook that loads `MyPkg` with `@fromparent`. In these cases,
`@only_out_nb` code runs, and `scale` is a function of `MyPkg`.

Outside of the notebook, `@fromparent` keeps only some import statements.
The [`@frompackage`](@ref) reference lists them.
