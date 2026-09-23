# How @frompackage loads the target package

Each time you run the `@frompackage` cell, the macro reads all the code of the
target package again and evaluates it in a new module inside the notebook.
Then it changes the import statements of the cell so that they import from
this new module. The reload button runs the cell again, so each click gives a
new module that contains the current code of the package.

This page uses `@fromparent` and the `MyPkg` package from the tutorials.
`@fromparent` is the short form of `@frompackage`, and both load the target
package in the same way.

## One load of the target package

The macro starts from the `target` path and looks for the first
`Project.toml` file in that folder or in a folder above it. That project is
the target package. The macro reads its manifest, and the `manifest` setting
can instantiate or resolve the environment first.

The macro then makes a new module `MyPkg` inside a new temporary module in
the notebook workspace. It loads the direct dependencies of the target
package with the normal package loader of Julia. After that, it reads
`src/MyPkg.jl`, parses it, and evaluates it one top-level expression at a
time. It follows each `include` call in the same way. When the code is
evaluated, the macro calls `__init__` if the package defines it, and loads
the package extensions whose trigger packages are already loaded.

Last, the macro changes the statements of the cell. For example,
`import *` becomes an `import` statement with an explicit list of the names
of the new `MyPkg` module. The cell output also contains the reload button.

## Why each load makes a new module

On Julia 1.10 and 1.11, a module cannot get a new definition of a struct that
it defines already. A new module has no old definition, so a new definition
of `Point` works without a restart of the notebook on all Julia versions. Constants and global variables also start again from the
values in the code.

The names that the `@fromparent` cell imports now point to the new module.
Pluto knows that the cell defines these names, so it runs again all the cells
that use them. The old module stays in memory, but no cell uses it.

The cell outputs show the short name, `MyPkg.Point`, and not the full path
of the module inside the notebook workspace.

## The reload button

The macro reads the files of the target package only when you run its cell.
A change to a file does not run the cell, so the notebook does not see the
change until the next run. The reload button runs the `@fromparent` cell, in
the same way as the run button of the cell.

The button stays visible when the load fails, so you can fix the code and
load again.

## `LOAD_PATH` and dependencies

The macro adds the `Project.toml` file of the target package to the end of
`LOAD_PATH`. With this entry, Julia finds the dependencies of the target
package in its manifest, also the dependencies that the notebook environment
does not contain. The notebook environment stays first in `LOAD_PATH`, so
the Pluto package manager keeps control of the packages that the notebook
installs.

The dependencies are normal Julia packages. Julia loads each of them once for
each Julia process. The reload button does not load them again. This is also
true for a dependency that you added with `Pkg.develop` from a local path. A
change to the code of such a dependency is visible only after a restart of
the notebook.

Inside the code of the target package, an `import` or `using` statement that
starts with the name of the package, such as `using MyPkg.Shapes`, becomes a
relative import. The name `MyPkg` is not a package that Julia loaded, so the
macro points these statements to the new module.

## Notebooks that the target package includes

The target package can `include` a notebook file as source code. When that
notebook calls `@fromparent`, the macro stops the load at the `include` call
of the notebook file. The notebook then sees the package as it is at that
line, and the notebook can import from the module that includes it with
`ParentModule`. The code of the notebook itself runs in the cells, so it
does not run two times.

## Behavior outside Pluto

Outside of a notebook, the macro does not load anything. It keeps the
relative imports without `*` and the `>.` imports of direct dependencies,
as plain `import` and `using` statements. It removes all the other
statements. So a notebook that the package includes works as package code:
`@fromparent import >.Dates` becomes `import Dates`, and `@fromparent import *`
does nothing.

The macro does the same when it finds a `@fromparent` call in the code of the
target package during a load from a different notebook.

## Comparison with Revise

[Revise](https://timholy.github.io/Revise.jl/stable/) also updates the code of
a package in a running Julia session. It tracks the source files and changes
only the methods that changed. The two tools work in different ways:

- `@fromparent` evaluates all the code again at each reload. Revise changes
  only the parts that changed, so it is faster for a large package.
- `@fromparent` makes a new module, so it can change a struct on all the
  Julia versions that PlutoDevMacros supports. Revise on Julia 1.10 and 1.11
  cannot change a struct definition.
- A click on the reload button makes Pluto run all the cells that use the
  package. Pluto does not know when Revise changes a method, so the cells
  that use it do not run again.
- `@fromparent` loads the target package without a change to the notebook
  environment. To load a local package with `using`, you must turn off the
  Pluto package manager, for example with `Pkg.activate` in a cell.
- The code of the target package is not precompiled. Each function compiles
  when the notebook calls it the first time after a reload.
