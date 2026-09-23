# Import specific names and submodules

`@fromparent import *` imports all the names of the target package. To import
fewer names, or names from a submodule or a dependency, change the import
statement. The [`@frompackage`](@ref) reference lists the full import syntax.

The examples on this page use the `MyPkg` package from the tutorials.

## Import some names

List the names after `^:`. The `^` symbol is the top module of the target
package:

```julia
@fromparent import ^: greet, distance
```

The name of the target package also works as the start of the module path:

```julia
@fromparent import MyPkg: greet, distance
```

## Import from a submodule

Put the path of the submodule after `^.`. For a submodule `MyPkg.Shapes`, this
cell imports the names that `Shapes` exports:

```julia
@fromparent using ^.Shapes
```

This cell imports only the module name `Shapes`:

```julia
@fromparent import ^.Shapes
```

Add `as` to give the module a different name in the notebook:

```julia
@fromparent import MyPkg.Shapes as S
```

## Load a dependency of the target package

Put `>.` before the name of the dependency. The dependency can be direct or
indirect:

```julia
@fromparent import >.Dates
```

The notebook environment does not have to contain the dependency. The Pluto
package manager does not add it to the notebook environment.

## Use more than one statement

Use one `@fromparent` cell for each notebook. Two cells with `@fromparent`
give a `Multiple definitions` error. Put all the statements in a
`begin ... end` block, and put the settings after `end`:

```julia
@fromparent begin
    import ^: greet, distance
    using ^.Shapes
    import >.Dates
end verbose = true
```

## Leave out the names from `using` statements

`import *` also imports the names that `using` statements in the target
package bring into scope. For example, `using Dates` in `MyPkg` makes
`import *` import `today`, `Date`, and the other exported names of `Dates`.
Put `@exclude_using` before the statement to import only the names that the
package defines or imports itself:

```julia
@fromparent @exclude_using import *
```

## Handle names that the notebook defines already

A statement without a list of names, such as `import *` or `using ^.Shapes`,
skips the names that a notebook cell defines already. The macro does not
show a warning for these names. To get the version from the package, rename
the variable in the notebook.

A statement with a list of names imports all the names in the list. If a
notebook cell also defines one of these names, Pluto shows a
`Multiple definitions` error.
