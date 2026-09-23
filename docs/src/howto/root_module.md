# Load the target package as a root module

Use `rootmodule = true` when the code of the target package needs
`pkgdir`, `pathof`, or `pkgversion` of its own module. For example, a
package that reads data files from `pkgdir(@__MODULE__)` needs this setting.

!!! warning
    This setting uses Julia internals. A new Julia version can break it.

## Why the default fails

`@fromparent` evaluates the code of the target package in a module inside
the notebook. Julia does not know this module as a package, so these
functions return `nothing`:

```julia
pkgdir(MyPkg), pathof(MyPkg), pkgversion(MyPkg)
```

## Register the module

Add `rootmodule = true` to the `@fromparent` cell:

```julia
@fromparent import * rootmodule = true
```

The macro registers the loaded module as the root module of the target
package. The same three functions now return the folder of the package, the
path of `src/MyPkg.jl`, and the version in `Project.toml`.

With `verbose = true`, each reload also shows a `Replacing module` log
message. Julia shows it when the new module replaces the previous one.

The [`@frompackage`](@ref) reference describes all the settings.
