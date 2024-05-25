# Basic Use
```julia
@fromparent import_block
@frompackage target import_block
```

The `@frompackage` macro takes a local Package (derived from the `target` path),
loads it as a submodule of the current Pluto workspace and then process the
various import/using statements inside `import_block` to extract
varables/functions from the local Package into the notebook workspace.

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

For this reason the *reload* of local code is only triggered manually within `@frompackage` and happens only when manually re-running the cell containing the macro call. This process is simplified by the reload button explained [below](#Reload-Button).

## `target` path

The first argument to `@frompackage` (`target`) has to be an AbstractString (or
a `@raw_str`) containing the path (either absolute or relative to the file
calling the macro) that points to a local Package (the path can be to any file
or subfolder within the Package folder).

The main module of the package identified by the `target` path will be used as the module to process and load within the calling notebook

## `import_block`

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

## Reload Button
When called within Pluto, the `@frompackage` macro also creates a convenient button that can be used to re-execute the cell calling the macro to reload the Package code due to a change in the source files.

This button can also be used to quickly navigate to the position of the cell
containing the macro by using **Ctrl+Click**.\
The reload button will change
appearance (getting a red border) when the macrocall incur in a runtime error either
due to incorrect import statement (like if a relative import is used without
a proper target) or due to an error encountered when loading the package code.

Here is a short video showing the reload button. The window on the left has opened the [specific_imports1.jl](https://github.com/disberd/PlutoDevMacros.jl/blob/8e481f552fdce1562cc9e45970cb11e8b54faa71/test/TestPackage/src/specific_imports1.jl) notebook, while the one on the right has the [specific_imports2.jl](https://github.com/disberd/PlutoDevMacros.jl/blob/8e481f552fdce1562cc9e45970cb11e8b54faa71/test/TestPackage/src/specific_imports2.jl) one. 

Both are included in the TestPackage using for tests and defined in [test/TestPackage/src/TestPackage.jl](https://github.com/disberd/PlutoDevMacros.jl/blob/f7b2bbf3a89ca677ab1765a2d4fcb3a1600d66f6/test/TestPackage/src/TestPackage.jl)

```@raw html
<video controls=true>
<source src="https://user-images.githubusercontent.com/12846528/236453634-c95aa7b2-61eb-492f-85f5-6539bbb714d5.mp4" type="video/mp4">
</video>
```
