# Other Functions
This package also exports some additional convenience macros for simplifying package development aided by Pluto notebooks.

Additionally, the *non-exported* function [`hide_this_log`](@ref) can be used for sending javascript code through logs to Pluto and hide the corresponding log from view (without stopping the javascript code to execute)

## Utilities Macros
```@docs
@addmethod
@only_in_nb
@only_out_nb
@current_pluto_cell_id
@current_pluto_notebook_file
```

## Utilities Functions
```@docs
PlutoDevMacros.hide_this_log
```