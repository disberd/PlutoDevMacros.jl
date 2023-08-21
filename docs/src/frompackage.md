## Introduction
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

## Basic Use
```julia
@fromparent import_block
@frompackage target import_block
```

The `@frompackage` macro takes a local Package (derived from the `target` path), loads it as
a submodule of the current Pluto workspace and then process the various
import/using statements inside `import_block` to extract varables/functions from
the local Package into the notebook workspace.

!!! note
    `@fromparent` is simply a convenience synthax that uses the calling notebook file as `target`. More details on how the target path is processed are given below.\
    \
    Due to the equivalence in functionality between `@frompackage` and `@fromparent`, the rest of the documentation will only refer to `@frompackage` for convenience.

When changes to the code of the local Package are made, the cell containing the
call to `@frompackage` can be re-executed to reload the most recent version of
the module. Thanks to Pluto's reactivity, this will automatically trigger
re-execution of all cells that use functionality defined in the local package
loaded by the macro.

When testing functionalities of the local package using statements in the notebook cells, this reactivity simplifies the workflow as one does not need to manually re-run tests. At the same time, re-loading the full package module at each statement (similar to what Revise does) would most likely generate a significant overhead.

For this reason the *reload* of local code is only triggered manually within `@frompackage` and happens only when manually re-running the cell containing the macro call. (As explained below, the macro also shows a convenience reload button within the notebook that is always visible.)

### `target` path

The first argument to `@frompackage` (`target`) has to be a String containing the path (either
absolute or relative to the file calling the macro) that points to a local
Package (the path can be to any file or subfolder within the Package folder).

The main module of the package identified by the `target` path will be used as the module to process and load within the calling notebook

### `import_block`

The second argument to the macro is supposed to be either a single `using`/`import` statement, or multiple statements wrapped inside a `begin...end` block.

These statements are used to select which parts of the loaded Package module have to be evaluated and which of its variables have te be imported within the notebook scope.
Most of these import statements are only relevant when called within Pluto, so
`@frompackage` simply avoid loading the target Package and deletes these import
statements **in most cases** when called oustide of Pluto. There is a specific
type of import statement (relative import) that is relevant and applicable also
outside of Pluto, so this kind of statement is maintained in the macro output
even outside of Pluto.

The macro respects the differentiation between `using` and `import` as in normal
Julia, so statements containing `using Module` without any variable name
specifier will import all the exported names of `Module`.

## Supported import statements
The macro supports 4 different types of import statements:
- Relative Imports 
- Imports from the Package module
- Import from the Parent module (or submodule)
- Direct dependency import.
which are explained in more details in their respective section

All of them also allow the following (*catch-all*) notation `import
Module: *`, which imports within the notebook all the variables that are created
or imported within `Module`. This is useful when one wants to quickly import all the names defined in `Module` for testing without requiring to either:
- export all names in the definition of `Module`
- explicitly import each name using the `import Module: name1, name2, ...` synthax

**Each import statement can only contain one module**, so statements like
*`import Module1, Module2` are not supported. In case multiple imports are
*needed, use multiple statements within a `begin...end` block.

### Relative Imports
Relative imports are the ones where the module name starts with a dot (.).
These are mostly relevant when the loaded module contains multiple submodules.\
**Relative imports only supported kind of statement when the macro is called from Pluto**.

!!! note
    Relative imports are mostly useful when creating packages with notebooks as building blocks (i.e. notebooks that are *included* within the local package module)\
    \
    While _catch-all_ notation is supported also with relative imports (e.g. `import ..SiblingModule: *`), the extraction of all the names from the desired relative module requires loading and inspecting the full Package module and is thus only functional inside of Pluto.\
    **A relative-import with catch-all notation is deleted when @frompackage is called outside of Pluto**.

### Imports from Package module
These are all the import statements that have the name `PackageModule` or `^` as the
first identifier, e.g.: 
- `using PackageModule.SubModule` 
- `import PackageModule: varname` 
- `import PackageModule.SubModule.SubSubModule: *` 
These statements are
processed by the macro and transformed so that `PackageModule` actually points to
the module that was loaded by the macro.

The alternative notation `^` can also be used to represent the `PackageModule`, so one can write the two expressions below interchangeably
```julia
@fromparent import PackageModule: var_name
@fromparent import ^: var_name
```
This is to avoid triggering the Pkg statusmark within Pluto which always appears when a valid name of a package is typed (`^` is not valid so it doesn't create the status mark). See image below:
![image](https://user-images.githubusercontent.com/12846528/236888015-454183e6-44c1-4cd0-b9f8-9faf67aa0da6.png)

### Imports from Parent module (or submodule)
These statements are similar to the previous (imports from Package module) ones, with two main difference:
- They only work if the `target` file is actually a file that is included in the loaded Package, giving an error otherwise
- `ParentModule` does not point to the loaded Package, but the module that contains the line that calls `include(target)`.
If `target`  is loaded from the Package main module, and not from one of its submodules, then `ParentModule` will point to the same module as `PackageModule`.

#### Catch-All
A special kind parent module import is:
```julia
import *
```
which is equivalent to `import ParentModule: *`. 

This tries to reproduce within the namespace of the calling notebook, the
namespace that would be visible by the notebook file when it is loaded as part
of the Package module outside of Pluto.

### Imports from Direct dependencies

It is possible to to import direct dependencie of the target Package from within the `@frompackage` macro. To do so, one must prepend the package name with `>.`, so for example if one wants to load the `BenchmarkTools` package from the macro, assuming that it is indeed a direct dependency of the target package, one can do:
```julia
@frompackage target begin
    using >.BenchmarkTools
end
```
This modification is necessary when trying to use `@frompackage` in combination with the Pluto PkgManager, as explained in https://github.com/disberd/PlutoDevMacros.jl/pull/10.

These kind of statements (import/using from Direct Dependencies) are also supported both inside and outside Pluto, which means for example that the following code will effectively translate to `using BenchmarkTools` both inside and outside of Pluto"
```julia
@frompackage target begin
    using >.BenchmarkTools
end
```
These kind of statements can not be used in combination with the `catch-all`
imported name (*).

This feature is useful when trying to combine `@frompackage` with the integrated
Pluto PkgManager. In this case, is preferable to keep in the Pluto notebook
environment just the packages that are not also part of the loaded Package
environment, and load the eventual packages that are also direct dependencies of
the loaded Package directly from within the `@frompackage` `import_block`.

Doing so minimizes the risk of having issues caused by versions collision
between dependencies that are shared both by the notebook environment and the
loaded Package environment. Combining the use of `@frompackage` with the Pluto
PkgManager is a very experimental feature that comes with significant caveats.
Please read the [related section](#use-of-fromparentfrompackage-with-pluto-pkgmanager) at the end of this README