# Other Functions
This package also exports some additional convenience macros for simplifying package development aided by Pluto notebooks.

## Utilities Macros
```@docs
@addmethod
@only_in_nb
@only_out_nb
@current_pluto_cell_id
@current_pluto_notebook_file
```

## HTL Script
The `Script` submodule implements and exports some functionality (built on top of HypertextLiteral.jl) to simplify building javascript content by combining multiple snippets together.

None of the functions/types below are exported by `PlutoDevMacros` itself, but only by its `Script` submodule

```@docs
PlutoDevMacros.Script.HTLScript
PlutoDevMacros.Script.HTLScriptPart
PlutoDevMacros.Script.HTLBypass
PlutoDevMacros.Script.combine_scripts
```