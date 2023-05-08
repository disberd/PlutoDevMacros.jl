# PlutoDevMacros

This is a package containing macros/functions to help develop Packages using [Pluto](https://github.com/fonsp/Pluto.jl) notebooks as building blocks

## @plutoinclude macro

`@plutoinclude` is a macro aimed at simplifying the development of packages with multiple connected notebooks as building blocks. 

When creating a package whose functionality is divided into various notebooks that are included in the main package file, `@plutoinclude` can be used inside each notebook to serially chain the code definition from one notebook to the next. Each notebook (except the first one) should contain a `@plutoinclude` call to the one preceding it (in the same order you `include` the notebooks in the main package source).

When called from inside a Pluto notebook, `@plutoinclude` takes care of including all variables and function definitions from _included_ notebook into the _including_ one. If called just with the notebook path, it only include variables and function **explicitly** marked with `export`. The string `"all"` can be given as second argument to the macrocall to import all variables and functions defined in the _included_ notebook into the _including_ one.
Lastly, the macro creates a button on the notebook front-end that can be clicked to trigger a re-computation of the inclusion, modifying the imported variables and definition following a modification of the _included_ notebook.

See the video example below, or check the [plutoinclude_macro](./notebooks/plutoinclude_macro.jl), [plutoinclude_test](./notebooks/plutoinclude_test.jl) for basic usage or [test1](./notebooks/test1.jl), [test2](./notebooks/test2.jl), [test3](./notebooks/test3.jl) for chained inclusion examples:

https://user-images.githubusercontent.com/12846528/157840718-29f754b0-2649-41ed-934f-b554bdab13b9.mp4

## `@only_in_nb`, `@only_out_nb`

The exported macro `@only_in_nb` ensures that the content of a cell are only executed when ran from the notebook where they are defined.

Similarly, the macro `@only_out_nb` only executes code in the cell when this is included by calling `include` on the notebook file from another julia file

This is useful especially when you want to create and test a functionality in a standalone notebook in which you would use `import Pkg` and `using` in some cells at the beginning of the notebook, but you don't want to have the code in these cells to be executed when the notebook file is included from somewhere else.

The code was inspired and heavily based on the `@skip_as_script` and `@only_as_script` macros that are found [inside the Pluto main package](https://github.com/fonsp/Pluto.jl/blob/main/src/webserver/Firebasey.jl) and in [PlutoTest](https://github.com/JuliaPluto/PlutoTest.jl).

The need for this separate macros is for two reasons:
- The original Pluto macros are not limiting execution to in or out of the specific notebook, but in or out of a Pluto session (if you `include` a notebook from another notebook, all the `@skip_as_script` macros are executed
- I had an issue making the original Pluto macros work together with @requires from [Requires](https://github.com/JuliaPackaging/Requires.jl) while developing a personal package and this macro seems to solve the issue

## @frompackage macro

```julia
@frompackage target import_block
```

The macro is basically taking a local Package (derived from `target`), loading it as a submodule of the current Pluto workspace and then process the various import/using statements inside `import_block` to extract varables/functions from the local Package into the notebook.

When changes to the code of the local Package are made, the cell containing the call to `@frompackage` can be re-executed to reload the most recent version of the module, allowing to work within Pluto with a workflow similar to Revise, with the added advantage that some of the limitations of Revise requiring to restart the Julia session (like redefining structs) are avoided.

The main purpose of this is to be able to create packages starting from Pluto notebooks as building blocks. While this approach to Package development has its disadvantages, it can be very convenient to speed up the workflow especially at the beginning of development thanks to avoiding the need to restart Julia when redefining structs, and exploiting the reactivity of Pluto to quickly assess *automagically* that your code update did indeed fix the issues by just having some cells that depend on your changed functions in a notebook.

While the points mentioned above are achievable within a single pluto notebook without requiring to use this macro, when notebooks become quite complex, containing many cells, they start to become quite sluggish or unresponsive, so it is quite conveniente to be able to split the code into various notebook and be able to access the functionality defined in other notebooks from a single cell within a new notebook.

To simply import other notebooks, `@ingredients` from [PlutoHooks](https://github.com/JuliaPluto/PlutoLinks.jl) or `@plutoinclude` (which is inspired from `@ingredients`) from this PlutoDevMacros already exist, but I found that they do have some limitations for what concerns directly using notebooks as building blocks for a package.

Here are more details on the two arguments expected by the macro

### `target`

`target` has to be a String containing the path (either absolute or relative to the file calling the macro) that points to a local Package (the path can be to any file or subfolder within the Package folder) or to a specific file that is *included* in the Package (so the `target` file appears within the Package module definition inside an `include` call).
- When `target` is not pointing directly to a file included in the Package, the full code of the module defining the Package will be parsed and loaded in the Pluto workspace of the notebook calling the macro.
- When `target` is actually a file included inside the Package. The macro will just parse the Package module code up to and excluding the inclusion of `target` and discard the rest of the code, thus loading inside Pluto just a reduced part of the package. This is mimicking the behavior of `include` within a package, such that each `included` file only has visibility on the code that was loaded _before_ its inclusion. This behavior is also essential when using this macro from a notebook that is also included in the target Package, to avoid problems with variable redefinitions within the Pluto notebook (this is also the original usecase of the macro).

### `import_block` 

The second argument to the macro is supposed to be either a single using/import statement, or multiple using/import statements wrapped inside a `begin...end` block.

These statements are used to conveniently select which of the loaded Package names have te be imported within the notebook. 
Most of these import statements are only relevant when called within Pluto, so `@frompackage` simply avoid loading the target Package and deletes these import statements **in most cases** when called oustide of Pluto. There is a specific type of import statement (relative import) that is relevant and applicable also outside of Pluto, so this kind of statement is maintained in the macro output even outside of Pluto.

The macro respects the differentiation between `using` and `import` as in normal Julia, so statements containing `using Module` without any variable name specifier will import all the exported names of `Module`.

All supported statements also allow the following (catch-all) notation `import Module: *`, which imports within the notebook all the variables that are created or imported within `Module`. This is useful when one wants to avoid having either export everything from the module file directly, or specify all the names of the module when importing it into the notebook.

**Each import statement can only contain one module**, so statements like `import Module1, Module2` are not supported. In case multiple imports are needed, use multiple statements within a `begin...end` block.

The type of import statements that are supported by the macro are of 4 Types:
- Relative Imports 
- Imports from the Package module
- Import from the Parent module (or submodule)
- Direct dependency import.

#### Relative Imports
Relative imports are the ones where the module name starts with a dot (.). These are mostly relevant when the loaded module contains multiple submodules and they are **the only supported statement that is kept also outside of Pluto**.

While _catch-all_ notation is supported also with relative imports (e.g. `import ..SiblingModule: *`), the extraction of all the names from the desired relative module requires loading and inspecting the full Package module and is thus only functional inside of Pluto. **This kind of statement is deleted when @frompackage is called outside of Pluto**.

#### Imports from Package module
These are all the import statements that have the name `PackageModule` as the
first identifier, e.g.: - `using PackageModule.SubModule` - `import PackageModule:
varname` - `import PackageModule.SubModule.SubSubModule: *` These statements are
processed by the macro and transformed so that `PackageModule` actually points to
the module that was loaded by the macro.

#### Imports from Package module (or submodule)
These statements are similar to the previous (imports from Package module) ones, with two main difference:
- They only work if the `target` file is actually a file that is included in the
loaded Package, giving an error otherwise
- `ParentModule` does not point to the loaded Package, but the module that
contains the line that calls `include(target)`. If `target`  is loaded from the
Package main module, and not from one of its submodules, then `ParentModule` will
point to the same module as `PackageModule`.

##### Catch-All
A special kind parent module import is the form:
```julia
import *
```
which is equivalent to `import FromParent: *`. 

This tries to reproduce within the namespace of the calling notebook, the
namespace that would be visible by the notebook file when it is loaded as part
of the Package module outside of Pluto.

#### Imports from Direct dependencies

All import statements whose first module identifier is a direct dependency of
the loaded Package are also supported both inside and outside Pluto. These kind
of statements can not be used in combination with the `catch-all` imported name
(*).

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

### Skipping Package Parts
The macro also allows to specify parts of the source code of the target Package that have to be skipped when loading it within Pluto. This is achieved by adding a statement inside the `import_block` like the following:
```julia
@skiplines lines
```
The `@skiplines` macro is not defined within the package, it's just processed during the parsing of the `@frompackage` macro.

`lines` is expected to either be a single String, or a group of Strings within a `begin ... end` block.
Each string represent a part of a file that has to be skipped, with the following formats being supported:
1. `filpeath:::firstline-lastline`: This specifies that all the lines between `firstline` and `lastline` (extrema included) in the file present at `filepath` must be skipped when loading the Package module
2. `filepath:::line`: Like 1. but a single line is skipped
3. `filepath`: Like 1. but the full file located at `filepath` is ignored when loading the module 
4. `line`: Ignores line number `line` in the Package entry point (i.e. the file at `src/PackageName.jl` in the folder of PackageName)
5. `firstline-lastline`: Like 4., but ignores a range of lines.

In all of the examples above `filepath` can be provided as either an absolute path, or as a relative path **starting from the `src` subfolder of the Package folder**

The functionality of skipping lines is only used when `@frompackage` is called inside Pluto. 
When calling the macro from outside of Pluto, the eventual statement with `@skiplines` is discarded.

#### Example

For an example consider the source file of the `TestPackage` defined within the test subfolder with the contents shown below:
![image](https://user-images.githubusercontent.com/12846528/236829189-dc30414a-d936-4a63-831b-963664249558.png)

The notebook locate at gives an example of how to use the new functionality.
Considering the notebook to be located in the main folder of the TestPackage folder, the following call to `@fromparent` is used to import the `TestPackage` in the notebook's workspace while removing some of the code that is present in the original source of `TestPackage`:
```julia
@fromparent begin
	import TestPackage
	@skiplines begin
		"11" # Skip line 11 in the main file TestPackage.jl.
		"test_macro2.jl" # This skips the whole file test_macro2.jl
		"22-23" # This skips from line 21 to 22 in the main file, including extrema.
		"test_macro1.jl:::28-10000" # This skips parts of test_macro1.jl
	end
end
```
The output of the notebook is also pasted here for reference:
![image](https://user-images.githubusercontent.com/12846528/236829732-09853734-3dff-46bb-ad3a-51035126cd83.png)

### Reload Button
The macro, when called within Pluto, also creates a convenient button that can be used to re-execute the cell calling the macro to reloade the Package code due to a change. It can also be used to quickly navigate to the position of the cell containing the macro by using Ctrl+Click. The reload button will change appearance (getting a red border) when the macrocall encountered an error either due to incorrect import statement (like if a `FromParent` import is used without a proper target) or due to an error encountered when loading the package code.

Here is a short video showing the reload button. The window on the left has opened the [specific_imports1.jl](https://github.com/disberd/PlutoDevMacros.jl/blob/8e481f552fdce1562cc9e45970cb11e8b54faa71/test/TestPackage/src/specific_imports1.jl) notebook, while the one on the right has the [specific_imports2.jl](https://github.com/disberd/PlutoDevMacros.jl/blob/8e481f552fdce1562cc9e45970cb11e8b54faa71/test/TestPackage/src/specific_imports2.jl) one. Both are included in the TestPackage using for tests as follows:
https://github.com/disberd/PlutoDevMacros.jl/blob/8e481f552fdce1562cc9e45970cb11e8b54faa71/test/TestPackage/src/TestPackage.jl#L20-L25

https://user-images.githubusercontent.com/12846528/236453634-c95aa7b2-61eb-492f-85f5-6539bbb714d5.mp4

## @fromparent macro
The `@fromparent` macro only accepts the `import_block` as single argument, and it uses the calling file as the target, so:
```julia
(@fromparent import_block) == (@frompackage @__FILE__ import_block)
```

## @addmethod macro
The `@fromparent`/`@frompackage` functions rely (like `@ingredients` and `@plutoinclude`) in generating temporary  modules and importing variables from those modules. This causes problems because Pluto currently does not support directly adding methods to functions imported from other modules (see #2). To circumvent this, PlutoDevMacros also exports the `@addmethod` function which simply takes care of _pre-pending_ the correct module name in the function signature.

So the code
```julia
@addmethod func(args...;kwargs...) = something
```
is simply translated to
```julia
DefiningModule.func(args...;kwargs...) = something
```
where `DefiningModule` is the module where `func` is defined. When called outside of Pluto, `@addmethod` simply returns the given expression without modifying it.

This is useful to avoid multiple definition errors inside Pluto but has the caveat that defining a method with `@addmethod` does not trigger a reactive run of all cells that call the modified function.
This also mean that when removing the cell with the `@addmethod` call, the actual method added to the `DefiningModule` will not be automatically erased by Pluto and is still accessible until it is not overwritten with another method with the same signature.
This is easy to fix in the case of adding methods to modules loaded with `@frompackage`/`@fromparent` as reloading the module is sufficient to remove the hanging method.

See this video for an example:

https://user-images.githubusercontent.com/12846528/236472989-da86a311-4501-4966-9f0b-1298bbd9d53b.mp4

## Use of @fromparent/@frompackage with Pluto PkgManager

As the module of the Package is loaded/evaluated by the macro inside the notebook workspace, the notebook environment should also contain all the packages that are used by the target Package inside its own environment. 

Ideally this is achieved by deactivating the Pluto PkgManger by activating an environment that also contains the local Package as a dependency.

This is sometime inconvenient, as the Pluto PkgManager has many advantages. If one wants to maintain the PkgManager, the notebook should also contain a cell import all the packages of the loaded module.

This macro currently has a hack to allow loading the target Package module (and its direct dependencies) without having to add all of its dependencies to the notebook environment.
It does so by adding the Package environment to the `LOAD_PATH` just before attempting to load it, and removing it from the `LOAD_PATH` just after evaluating the various import statements.

The macro tries to catch all possible exceptions that are thrown either during macro compilation or during the resulting expression evaluation (using a try catch) to correctly clean `LOAD_PATH` after the macro is executed.

This approach is quite brittle, as it may cause issues in case the notebook and the package environment share some dependencies at different version. In this case, the one that was loaded first is the actual version used within the notebook (and within the Package module when loaded in the notebook).

Adding the package environment at the second position in the LOAD_PATH (so after the notebook environment) should minimize the potential issues as the notebook environment is parsed first to find the packages.
This does not prevent the case when a package (for example DataFrames) that is only used by the loaded package, is also added to the notebook after the target Package has been loaded. 
In this case, the version of DataFrames used by the notebook will be the version loaded by Package, and not the one installed in the notebook environment.
Upon restarting the notebook, the situation will flip. Since now DataFrames is in the notebook environment, the notebook version will be loaded both in the notebook and in the Package module, potentially causing issues with the PackageCode if it was depending on a different version of DataFrames.

**Due to the issues just mentioned, use the macro knowing that it might break if you want to use the Pluto PkgManager without manually adding all depending packages to the notebook environment**.
