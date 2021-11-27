module PlutoDevMacros

using MacroTools
using PlutoHooks: @skip_as_script
using Requires

# This hack is the only way I found to access @skip_as_script as PlutoDevMacros.@skip_as_script
# @eval const $(Symbol("@skip_as_script")) = $(Symbol("@plutohookskip"))

# export @only_in_nb, @only_out_nb, include_mapexpr, @skip_as_script
# export notebook_to_source

include("../notebooks/basics.jl") # @only_in_nb, @only_out_nb, is_notebook_local, plutodump, @current_pluto_cell_id, @current_pluto_notebook_file
include("../notebooks/mapexpr.jl") # hasexpr, default_exprlist, include_mapexpr
include("../notebooks/plutoinclude_macro.jl") # hasexpr, default_exprlist, include_mapexpr

function __init__()
	@require WhereTraits="c9d4e05b-6318-49cb-9b56-e0e2b0ceadd8" include("../notebooks/pluto_traits.jl") # This defines and exports the @plutotraits macro
end

end # module
