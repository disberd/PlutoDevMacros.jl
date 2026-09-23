# Develop a package extension in a notebook

In this tutorial, you add a package extension to `MyPkg` and develop it in a
Pluto notebook. The extension loads when the notebook loads its trigger
package. Then you change the extension and load it again with the reload
button.

Do the first tutorial,
[Develop your first package in a notebook](first_package.md), before this
one. This tutorial starts from the `MyPkg` package that you made there.

The trigger package is [Example.jl](https://github.com/JuliaLang/Example.jl),
a small registered package. Its function `hello(who)` returns
`"Hello, $who"`.

The finished package is in the
[`docs/examples/MyPkg` folder on GitHub](https://github.com/disberd/PlutoDevMacros.jl/tree/master/docs/examples/MyPkg).
You can also download the finished notebook,
[`extension.jl`](https://github.com/disberd/PlutoDevMacros.jl/blob/master/docs/examples/MyPkg/notebooks/extension.jl).

## Add the extension to the package

Add these lines to the end of `MyPkg/Project.toml`:

```toml
[weakdeps]
Example = "7876af07-990d-54b4-ab0e-23690620f79a"

[extensions]
MyPkgExampleExt = "Example"
```

In `MyPkg/src/MyPkg.jl`, add `shout` to the `export` line. Then add a
function without methods before `end # module MyPkg`:

```julia
export Point, greet, distance, shout
```

```julia
# The methods of this function come from the MyPkgExampleExt extension.
function shout end
```

Make a folder `ext` in the `MyPkg` folder. In that folder, make the file
`MyPkgExampleExt.jl` with this code:

```julia
module MyPkgExampleExt

using MyPkg
using Example

MyPkg.shout(name) = uppercase(Example.hello(name))

end # module MyPkgExampleExt
```

The `MyPkg` folder now contains the folders `ext`, `notebooks`, and `src`.

## Load the package in a new notebook

Start Pluto and create a new notebook. Save it as
`MyPkg/notebooks/extension.jl`. Add these two cells and run them:

```julia
using PlutoDevMacros
```

```julia
@fromparent import * verbose = true
```

The **Reload MyPkg** button appears in the top-right corner of the notebook.
The `verbose = true` setting makes `@fromparent` show log messages about the
load steps. The second cell shows a message that starts with `Adding` and
ends with `to end of LOAD_PATH`.

## Load the trigger package

Add a cell that loads `Example`, and run it:

```julia
using Example
```

Pluto installs `Example` in the environment of the notebook. The cell shows
this log message:

```
Loading code of extension MyPkgExampleExt for package MyPkg
```

The extension loaded when the notebook loaded `Example`. The page
[How package extensions load](../explanation/extensions.md) explains how this
works.

Add a cell that calls the new method:

```julia
shout("Pluto")
```

The cell shows `"HELLO, PLUTO"`.

## Change the extension

In `MyPkg/ext/MyPkgExampleExt.jl`, change the `shout` method to this code,
and save the file:

```julia
MyPkg.shout(name) = uppercase(Example.hello(name)) * "!"
```

Click **Reload MyPkg**. The `@fromparent` cell shows the
`Loading code of extension MyPkgExampleExt for package MyPkg` message again.
The `shout("Pluto")` cell shows `"HELLO, PLUTO!"`.

## Next steps

You added an extension to `MyPkg`, loaded it from a notebook, and changed it
with the notebook open. To continue, read the [`@frompackage`](@ref)
reference for all the settings, including `verbose`.
