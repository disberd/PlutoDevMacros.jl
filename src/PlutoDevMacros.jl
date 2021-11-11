module PlutoDevMacros

using MacroTools
using PlutoHooks: @skip_as_script as @plutohookskip

# This hack is the only way I found to access @skip_as_script as PlutoDevMacros.@skip_as_script
@eval const $(Symbol("@skip_as_script")) = $(Symbol("@plutohookskip"))

export @only_in_nb, @only_out_nb, include_mapexpr, @skip_as_script
export notebook_to_source

include("mapexpr.jl")
include(include_mapexpr([default_exprlist..., :InteractiveUtils]),"ingredients_macro.jl")

function is_notebook_local(filesrc)
	if isdefined(Main,:PlutoRunner)
		# Try to see if the last 36 character of the source file are a UUID (Pluto cells have their cell_id appended to the file_source)
		cell_id = tryparse(Base.UUID,last(filesrc,36))
		cell_id !== nothing && cell_id === Main.PlutoRunner.currently_running_cell_id[] && return true
	end
	return false
end

macro only_in_nb(ex) is_notebook_local(String(__source__.file::Symbol)) ? esc(ex) : nothing end
macro only_out_nb(ex) is_notebook_local(String(__source__.file::Symbol)) ? nothing : esc(ex) end



end # module
