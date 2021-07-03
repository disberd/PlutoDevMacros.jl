module PlutoDevMacros

export @only_in_nb, @only_out_nb

function is_notebook_local(filesrc)
	if isdefined(Main,:PlutoRunner)
		cell_id = tryparse(Base.UUID,last(filesrc,36))
		cell_id !== nothing && cell_id === Main.PlutoRunner.currently_running_cell_id[] && return true
	end
	return false
end

macro only_in_nb(ex) is_notebook_local(String(__source__.file::Symbol)) ? esc(ex) : nothing end
macro only_out_nb(ex) is_notebook_local(String(__source__.file::Symbol)) ? nothing : esc(ex) end


end # module
