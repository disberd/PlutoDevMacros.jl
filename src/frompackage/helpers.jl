const fromparent_module = Ref{Module}()
const parent_package = Ref{Symbol}()
_remove_expr_var_name = :__fromparent_expr_to_remove__


## simulate manual rerun
"""
	simulate_manual_rerun(cell_id::Base.UUID; PlutoRunner)
	simulate_manual_rerun(cell_id::String; PlutoRunner)
	simulate_manual_rerun(cell_id::Array; PlutoRunner)
This function takes as input a cell_id or an array of cell_ids (either as `UUID` or as `String`) and simulate a manual rerun for each of the provided cell_ids.

This is useful when one wants to programmatically rerun a cell with a macro and recompile the macro like it's done upon manual rerun, but doesn't require to click on the run button on the cell.

This is using internal Pluto API so it might break if the Pluto internals change until PlutoDevMacros itself is updated.
It works by deleting the cached expression of the cell before triggering a re-run using `PlutoRunner.run_channel`
"""
function simulate_manual_rerun(cell_id::Base.UUID; PlutoRunner)
	delete!(PlutoRunner.cell_expanded_exprs, cell_id)
	delete!(PlutoRunner.computers, cell_id)
	push!(PlutoRunner.run_channel, cell_id)
	return nothing
end
# String version
simulate_manual_rerun(cell_id::String; kwargs...) = simulate_manual_rerun(Base.UUID(cell_id);kwargs...)
# Array version
function simulate_manual_rerun(cell_ids::Array; kwargs...)
	for cell_id in cell_ids
		simulate_manual_rerun(cell_id;kwargs...)
	end
end

## execute only in notebook
# We have to create our own simple check to only execute some stuff inside the notebook where they are defined. We have stuff in basics.jl but we don't want to include that in this notebook
function is_notebook_local()
	cell_id = try
		Main.PlutoRunner.currently_running_cell_id[]
	catch e
		return false
	end
	caller = stacktrace()[2] # We get the function calling this function
	calling_file = caller.file |> string
	return endswith(calling_file, string(cell_id))
end
# We have to create our own simple check to only execute some stuff inside the notebook where they are defined. We have stuff in basics.jl but we don't want to include that in this notebook
function is_notebook_local(calling_file::String)
	name_cell = split(calling_file, "#==#")
	return length(name_cell) == 2 && length(name_cell[2]) == 36
end
is_notebook_local(calling_file::Symbol) = is_notebook_local(String(calling_file))

## get parent data
function get_parent_data(filepath::AbstractString)
	# Eventually remove the Pluto cell part
	filepath = first(split(filepath, "#==#"))
	endswith(filepath, ".jl") || error("It looks like the provided file path $filepath does not end with .jl, so it's not a julia file")
	
	project_file = Base.current_project(dirname(filepath))
	project_file isa Nothing && error("The current notebook is not part of a Package")

	parent_dir = dirname(project_file)
	parent_data = TOML.parsefile(project_file)

	# Check that the package file actually exists
	parent_file = joinpath(parent_dir,"src", parent_data["name"] * ".jl")
	isfile(parent_file) || error("The parent package main file was not found at path $parent_file")
	parent_data["dir"] = parent_dir
	parent_data["project"] = project_file
	parent_data["file"] = parent_file
	parent_data["target"] = filepath
	parent_data["Module Path"] = Symbol[]
	parent_data["Loaded Packages"] = Dict{Symbol, Any}(:_Overall_ => Dict{Symbol, Any}(:Names => Set{Symbol}()))
	
	return parent_data
end

## getfirst
function getfirst(p, itr)
    for el in itr
        p(el) && return el
    end
    return nothing
end

## filterednames
function filterednames(m::Module; all = true)
	excluded = (:eval, :include, :_fromparent_dict_, Symbol("@bind"), :_PackageModule_)
	filter(names(m;all)) do s
		Base.isgensym(s) && return false
		s in excluded && return false
		return true
	end
end
