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
