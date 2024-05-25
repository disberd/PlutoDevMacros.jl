# Supported import statements
The macro supports 4 different types of import statements:
- Relative Imports 
- Imports from the Package module
- Import from the Parent module (or submodule)
- Import from the Package dependencies (direct or indirect).
which are explained in more details in their respective section

All of them also allow the following (*catch-all*) notation `import
Module: *`, which imports within the notebook all the variables that are created
or imported within `Module`. This is useful when one wants to quickly import all the names defined in `Module` for testing without requiring to either:
- export all names in the definition of `Module`
- explicitly import each name using the `import Module: name1, name2, ...` synthax

**Each import statement can only contain one module**, so statements like
*`import Module1, Module2` are not supported. In case multiple imports are
*needed, use multiple statements within a `begin...end` block.

## Relative Imports
Relative imports are the ones where the module name starts with a dot (.).
These are mostly relevant when the loaded module contains multiple submodules.\
**Relative import statements are also produced when the macro is called from Pluto**.

!!! note
    Relative imports are mostly useful when creating packages with notebooks as building blocks (i.e. notebooks that are *included* within the local package module)\
    \
    While _catch-all_ notation is supported also with relative imports (e.g. `import ..SiblingModule: *`), the extraction of all the names from the desired relative module requires loading and inspecting the full Package module and is thus only functional inside of Pluto.\
    **A relative-import with catch-all notation is deleted when @frompackage is called outside of Pluto**.

## Imports from Package module
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

## Imports from Parent module (or submodule)
These statements are similar to the previous (imports from Package module) ones, with two main difference:
- They only work if the `target` file is actually a file that is included in the loaded Package, giving an error otherwise
- `ParentModule` does not point to the loaded Package, but the module that contains the line that calls `include(target)`.
If `target`  is loaded from the Package main module, and not from one of its submodules, then `ParentModule` will point to the same module as `PackageModule`.

### Catch-All
A special kind parent module import is:
```julia
import *
```
which is equivalent to:
- `import ParentModule: *` if the `target` file provided to `@frompackage`/`@fromparent` **is** a file *included* in the target Package. 
  - This tries to reproduce within the namespace of the calling notebook, the namespace that would be visible by the notebook file when it is loaded as part of the Package module outside of Pluto.
- `import PackageModule: *` if the `target` file provided to `@frompackage`/`@fromparent` **is not** a file *included* in the target Package. 


## Imports from Package dependencies

It is possible to to import direct (or indirect) dependencies of the target
Package from within the `@frompackage` macro. Direct dependencies are the ones
directy listed within the `[deps]` section of the `Project.toml`. Indirect
dependencies are instead all the packages within the Package's `Manifest.toml`
which are not direct dependencies. To import a package dependency from the
`@frompackage` macro, one must prepend the package name with `>.`, so for
example if one wants to load the `BenchmarkTools` package from the macro,
assuming that it is indeed a dependency of the target package, one can do:
```julia
@frompackage target begin
    using >.BenchmarkTools
end
```
This modification is necessary when trying to use `@frompackage` in combination with the Pluto PkgManager, as explained in [Issue 10](https://github.com/disberd/PlutoDevMacros.jl/pull/10).

These kind of statements (import/using from Dependencies) are also supported
both inside and outside Pluto. **Outside of Pluto, only direct dependencies are
supported** (as that is how julia works) which means that the example code above
will effectively translate to `using BenchmarkTools` both inside and outside of
Pluto if BenchmarkTools is a direct dependency.


!!! note
    These kind of statements can not be used in combination with the `catch-all` imported name (*).\
    \
    Imports from package dependencies are useful when trying to combine `@frompackage` with the integrated Pluto PkgManager. In this case, is preferable to keep in the Pluto notebook environment just the packages that are not also part of the target/loaded Package environment, and load the eventual packages that are also in the environment of the loaded Package directly from within the `@frompackage` `import_block`.\
    \
    Doing so minimizes the risk of having issues caused by versions collision between dependencies that are shared both by the notebook environment and the loaded Package environment. Combining the use of `@frompackage` with the Pluto PkgManager is a very experimental feature that comes with significant caveats.  Please read the [related section](#use-of-fromparentfrompackage-with-pluto-pkgmanager) at the end of this README


## Re-export `using` names with Catch-All
Prior to version v0.7.3 of PlutoDevMacros, the catch-all import would not allow to automatically import names in the scope of the parent/package module that were added via `using` statements.
See https://github.com/disberd/PlutoDevMacros.jl/issues/11 for more details on the reasons.

This meant that to effectively have access to all of the names in the parent/package scope, the statement `@fromparent import *` would not be sufficient.
If for example you had `using Base64` at the top of your module, to effectively have access to also the names of the `Base64` stdlib, you would have to call the macro as follows:
```julia
@fromparent begin
    import *
    using >.Base64
end
```
This is now not strictly necessary anymore, as `@frompackage`/`@fromparent` now recognize the special macro `@include_using` during expansion. This macro is not actually defined in the package but tells the `@fromparent` call to also re-export names exposed by `using` statements when paired with a [Catch-all statement](#catch-all).
Since v0.7.3, you can re-export everything including names from `using` statements with the following:
```julia
@fromparent @include_using import *
```
This statement can be used alone or coupled with other valid import statements within a `begin ... end` block.
!!! note
    Only a catch-all statement is supported after the `@include_using` macro.
    \
    \
    For the moment this behavior is opt-in (via `@include_using`) to avoid a breaking change, but it will likely become the default catch-all behavior at the next breaking release.