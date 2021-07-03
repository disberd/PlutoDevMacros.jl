# PlutoDevMacros

This is a super lightweight package (currently containing only two macros) to help develop Packages using [Pluto](https://github.com/fonsp/Pluto.jl) notebooks as building blocks

The exported macro `@only_in_nb` ensures that the content of a cell are only executed when ran from the notebook where they are defined.

Similarly, the macro `@only_out_nb` only executes code in the cell when this is included by calling `include` on the notebook file from another julia file

This is useful especially when you want to create and test a functionality in a standalone notebook in which you would use `import Pkg` and `using` in some cells at the beginning of the notebook, but you don't want to have the code in these cells to be executed when the notebook file is included from somewhere else.

The code was inspired and heavily based on the `@skip_as_script` and `@only_as_script` macros that are found [inside the Pluto main package](https://github.com/fonsp/Pluto.jl/blob/main/src/webserver/Firebasey.jl) and in [PlutoTest](https://github.com/JuliaPluto/PlutoTest.jl).

The need for this separate macros is for two reasons:
- The original Pluto macros are not limiting execution to in or out of the specific notebook, but in or out of a Pluto session (if you `include` a notebook from another notebook, all the `@skip_as_script` macros are executed
- I had an issue making the original Pluto macros work together with @requires from [Requires](https://github.com/JuliaPackaging/Requires.jl) while developing a personal package and this macro seems to solve the issue
