# Instantiate the environment of the target package

With the default settings, `@fromparent` uses the manifest file of the target
package as it is. If the target package has no manifest, the cell shows this
error:

```
AssertionError: A manifest could not be found at the project's location.
```

Use the `manifest` setting to let `@fromparent` fix the environment before
it loads the target package. The [`@frompackage`](@ref) reference describes
all the settings.

## Make a missing manifest or install missing packages

Add `manifest = :instantiate` to the `@fromparent` cell:

```julia
@fromparent import * manifest = :instantiate
```

The macro runs `Pkg.instantiate` on the environment of the target package.
This makes the manifest if it does not exist and installs the packages that
the manifest lists. Use it after you clone a package that does not commit
its manifest.

## Update the manifest after you change `Project.toml`

Add `manifest = :resolve` to the `@fromparent` cell:

```julia
@fromparent import * manifest = :resolve
```

The macro runs `Pkg.resolve` on the environment of the target package. Use
it after you add a dependency or change a compat entry in `Project.toml` by
hand.

## Keep reloads fast

The macro runs `Pkg.instantiate` or `Pkg.resolve` each time it loads the
target package, also when you click the reload button. Remove the setting
when the manifest is correct.

You can also do this step once in the Julia REPL, outside the notebook:

```julia
import Pkg
Pkg.activate("path/to/MyPkg")
Pkg.instantiate()
```

## Versioned and workspace manifests

`@fromparent` finds the manifest file in the same way as Julia. It uses a
versioned manifest, for example `Manifest-v1.12.toml`, when it matches the
Julia version. When the target package is a project of a Julia workspace,
it uses the manifest in the folder of the workspace.
