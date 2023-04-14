The `@fromparent` macro is intended for allow aiding the development of packages based on multiple notebook source files.
Its main use is from within Pluto notebooks that are part of (and used as source code files) for Julia Packages.

When called from within a Pluto notebook, the `@fromparent` macro will do the following steps:
1. record the name of the calling file and check whether it is indeed a pluto notebook.
2. Recover the package containing the calling file by using `Base.current_project(dirname(calling_file))`, erroring if no project is found 
3. Assume that the project is a package being developed and check the package main file located inside the `package_folder/src/PackageName.jl`
4. Parse the code of the package up to the point where `calling_file` is `included`, expanding all the included files encountered along the way using `Meta.parseall`

The parsing is stopped if the calling file is found as it is assumed that each file only has access to the expression that are defined in files included before it in the package.
The parsed code is evaluated inside a temporary module that is created in the calling Pluto notebook workspace (with a gensymd name created with `gensym(:fromparent)`) and that is inserted in the const module Ref `PlutoDevMacros.fromparent_module`.

Having the main module where the parsed expression is evaluated being inside the Pluto workspace (rather than directly created inside PlutoDevMacros) is important to have access to the various packages that are loaded in the notebooks. **TO INVESTIGATE BETTER** as it was giving error initially when the module was defined inside PlutoDevMacros.

The supported import/using statements are the following:
- `import/using module` → Just load the module in the current workspace and import the exported names if `using`.
  - **SHOULD ONLY WORK INSIDE PLUTO**.
- `import/using module.SubModule / module: vars / module.SubModule: vars` → Import or Use submodules or explicit names starting from the top-level parsed module.
  - **SHOULD ONLY WORK INSIDE PLUTO**.
- `import/using *` → Automatically import all names defined in the parent module
  - Use the module containing the target if the target is found, use the the top-level module otherwise
  - **SHOULD ONLY WORK INSIDE PLUTO**
- `import/using .ModName \ ..ModName \ .ModName: vars \ etc` → Import/Use a module or just some variables from a module starting from the path of the target. 
  -  Should execute the given expression as-is outside of Pluto
  -  Should give an error in Pluto if the target is not found.