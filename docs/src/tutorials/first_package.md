# Develop your first package in a notebook

In this tutorial, you make a small package called `MyPkg` and load it into a
Pluto notebook with [`@fromparent`](@ref). Then you change a function and a
struct of the package, and you see the changes in the notebook without a
restart. At the end, you add a package that only the notebook uses.

```@raw html
<!-- TODO: add the GIF of the reload button here (docs/src/assets/reload_button.gif). -->
```

You need Julia 1.10 or later, and Pluto in your global environment. The
[Pluto installation guide](https://plutojl.org/en/docs/install/) shows how to
install Pluto.

The finished package is in the
[`docs/examples/MyPkg` folder on GitHub](https://github.com/disberd/PlutoDevMacros.jl/tree/master/docs/examples/MyPkg).
You can also download the finished notebook,
[`first_steps.jl`](https://github.com/disberd/PlutoDevMacros.jl/blob/master/docs/examples/MyPkg/notebooks/first_steps.jl).

## Make the package

Open the Julia REPL in a folder of your choice. Run this code to make the
package and write its manifest file:

```julia
import Pkg
Pkg.generate("MyPkg")
Pkg.activate("MyPkg")
Pkg.instantiate()
Pkg.activate()
```

The folder `MyPkg` now contains `Project.toml`, `Manifest.toml`, and
`src/MyPkg.jl`.

Replace all the text in `MyPkg/src/MyPkg.jl` with this code:

```julia
module MyPkg

export Point, greet, distance

struct Point
    x::Float64
    y::Float64
end

greet(name) = "Hello, $(name)!"

distance(p::Point) = sqrt(p.x^2 + p.y^2)

end # module MyPkg
```

## Put a notebook in the package

Make a folder `notebooks` in the `MyPkg` folder. Then start Pluto from the
Julia REPL:

```julia
import Pluto
Pluto.run()
```

Pluto opens in your browser. Create a new notebook. Use the file path box at
the top of the notebook to save it as `MyPkg/notebooks/first_steps.jl`. Write
the full path of the file.

The top of the notebook shows the new file name, `first_steps.jl`.

## Load the package

Type this code in the first cell of the notebook and run the cell:

```julia
using PlutoDevMacros
```

Pluto installs PlutoDevMacros in the environment of the notebook. This can
take some time.

Add a cell with this code and run it:

```julia
@fromparent import *
```

A button with the text **Reload MyPkg** appears in the top-right corner of
the notebook. `@fromparent` found `MyPkg` from the location of the notebook
file, loaded it, and imported all its names.

Add a cell that calls a function of `MyPkg`:

```julia
greet("Pluto")
```

The cell shows `"Hello, Pluto!"`.

## Change a function

In `MyPkg/src/MyPkg.jl`, change the `greet` function to this code, and save
the file:

```julia
greet(name) = "Hi, $(name)!"
```

Click **Reload MyPkg**. The `greet("Pluto")` cell runs again and shows
`"Hi, Pluto!"`.

## Change a struct

Add two cells to the notebook:

```julia
p = Point(3, 4)
```

```julia
distance(p)
```

The first cell shows the fields of `p`. The second cell shows `5.0`.

Now give `Point` a third field. In `MyPkg/src/MyPkg.jl`, replace the `Point`
struct and the `distance` function with this code, and save the file:

```julia
struct Point
    x::Float64
    y::Float64
    z::Float64
end

distance(p::Point) = sqrt(p.x^2 + p.y^2 + p.z^2)
```

Click **Reload MyPkg**. The `p = Point(3, 4)` cell shows a `MethodError`,
because `Point` now needs three numbers. Change the cell to this code and run
it:

```julia
p = Point(2, 3, 6)
```

The `distance(p)` cell shows `7.0`. You changed a struct without a restart of
the notebook. The page
[How @frompackage loads the target package](../explanation/loading.md) explains
why this works.

## Add a package that only the notebook uses

Add a cell with this code and run it:

```julia
using PlutoUI
```

The Pluto package manager installs PlutoUI in the environment of the
notebook. The `MyPkg/Project.toml` file does not change, so PlutoUI is not a
dependency of `MyPkg`.

Add a cell with a text box:

```julia
@bind name TextField(default = "Pluto")
```

The cell shows a text box that contains `Pluto`. Change the
`greet("Pluto")` cell to this code and run it:

```julia
greet(name)
```

Type a different name in the text box. The `greet(name)` cell shows the new
name.

## Next steps

You made a package, loaded it in a notebook, and changed its code with the
notebook open. To continue:

- Add a package extension to `MyPkg` in the next tutorial,
  [Develop a package extension in a notebook](package_extension.md).
- Read the [`@frompackage`](@ref) reference for the import syntax and the
  settings.
