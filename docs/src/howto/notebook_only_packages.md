# Use packages that only the notebook needs

Load the package in a notebook cell with `using` or `import`:

```julia
using BenchmarkTools
```

The Pluto package manager installs the package in the environment of the
notebook. The `Project.toml` file of the target package does not change.
Use these packages to plot, benchmark, or make interactive controls for the
code of the target package. For example, with the `MyPkg` package from the
tutorials:

```julia
@benchmark distance($(Point(2, 3, 6)))
```

## Use a dependency of the target package

To use a package that the target package depends on, load it with `>.` in
the `@fromparent` cell:

```julia
@fromparent begin
    import *
    import >.Dates
end
```

The notebook then uses the same package as the target package. The Pluto
package manager does not add it to the notebook environment.

## Know which version loads

`@fromparent` adds the `Project.toml` file of the target package to the end
of `LOAD_PATH`. Julia looks for a package in the environments of `LOAD_PATH`
in order, so it looks in the notebook environment first. When the notebook
environment and the target package both contain a package, Julia loads the
version from the notebook environment.

Do not load a dependency of the target package with a plain `using` in the
notebook if the version must match the manifest of the target package. Use
`>.` for it.

The page
[How @frompackage loads the target package](../explanation/loading.md)
explains the role of `LOAD_PATH`.
