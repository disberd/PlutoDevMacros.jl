import ..PlutoDevMacros: hide_this_log

function get_temp_module() 
    @assert isassigned(fromparent_module) "You have to assing the parent module by calling `maybe_create_module` with a Pluto workspace module as input before you can use `get_temp_module`"
    fromparent_module[]
end

# Extract the module that is the target in dict
get_target_module(dict) = get_target_module(Symbol(dict["name"]))
get_target_module(mod_name::Symbol) = getfield(get_temp_module(), mod_name)

function get_target_uuid(dict) 
    uuid = get(dict, "uuid", nothing)
    if !isnothing(uuid)
        uuid = Base.UUID(uuid)
    end
    return uuid
end

function get_target_pkgid(dict)
    mod_name = dict["name"]
    uuid = get_target_uuid(dict)
    Base.PkgId(uuid, mod_name)
end

#=
We don't use manual rerun so we just comment this till after we can use it
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
=#

# Functions to add and remove from the LOAD_PATH
function add_loadpath(entry::String; should_prepend)
    idx = findfirst(==(entry), LOAD_PATH)
    if isnothing(idx)
        f! = should_prepend ? pushfirst! : push!
        # We add
        f!(LOAD_PATH, entry)
    end
    return nothing
end
add_loadpath(ecg::EnvCacheGroup; kwargs...) = add_loadpath(ecg |> get_active |> get_project_file; kwargs...)

## execute only in notebook
# We have to create our own simple check to only execute some stuff inside the notebook where they are defined. We have stuff in basics.jl but we don't want to include that in this notebook
function is_notebook_local(calling_file::String)
	name_cell = split(calling_file, "#==#")
	return length(name_cell) == 2 && length(name_cell[2]) == 36
end

## package extensions helpers
has_extensions(package_data) = haskey(package_data, "extensions") && haskey(package_data, "weakdeps")

function maybe_add_loaded_module(id::Base.PkgId)
	symname = id.name |> Symbol
	# We just returns if the module is already loaded
	isdefined(LoadedModules, symname) && return nothing
    loaded_module = Base.maybe_root_module(id)
	isnothing(loaded_module) && error("The package $id does not seem to be loaded")
	Core.eval(LoadedModules, :(const $(symname) = $(loaded_module)))
	return nothing
end

## get parent data
function get_package_data(packagepath::AbstractString)
	project_file = Base.current_project(packagepath)
	project_file isa Nothing && error("No project was found starting from $packagepath")
	project_file = abspath(project_file)

	ecg = default_ecg()

	maybe_update_envcache(project_file, ecg; notebook = false)
	target = get_target(ecg)
	# We update the notebook and active envcaches to be up to date
	update_ecg!(ecg)

	# Check that the package file actually exists
	package_file = get_entrypoint(target)
	package_dir = dirname(package_file) |> abspath

	isfile(package_file) || error("The package package main file was not found at path $package_file")

	package_data = deepcopy(target.project.other)
    package_data["project"] = project_file
	package_data["dir"] = package_dir
	package_data["file"] = package_file
	package_data["target"] = packagepath
	package_data["ecg"] = ecg

	# We extract the PkgInfo for all packages in this environment
	d,i = target_dependencies(target)
	package_data["PkgInfo"] = (;direct = d, indirect = i)
	
	return package_data
end

## getfirst
function getfirst(p, itr)
    for el in itr
        p(el) && return el
    end
    return nothing
end
getfirst(itr) = getfirst(x -> true, itr)

## filterednames
function filterednames(m::Module, caller_module = nothing; all = true, imported = true, explicit_names = nothing, package_dict = nothing)
	excluded = (:eval, :include, :_fromparent_dict_, Symbol("@bind"))
    mod_names = names(m;all, imported)
    filter_args = if explicit_names isa Set{Symbol}
        for name in mod_names
            push!(explicit_names, name)
        end
        collect(explicit_names)
    else
        mod_names
    end
    filter_func = filterednames_filter_func(m; excluded, caller_module, package_dict)
	filter(filter_func, filter_args)
end

function filterednames_filter_func(m; excluded, caller_module, package_dict)
    f(s) = let excluded = excluded, caller_module = caller_module, package_dict = package_dict
        Base.isgensym(s) && return false
        s in excluded && return false
        if caller_module isa Module
            previous_target_module = get_stored_module(package_dict)
            # We check and avoid putting in scope symbols which are already in the caller module
            isdefined(caller_module, s) || return true
            # Here we have to extract the symbols to compare them
            mod_val = getfield(m, s)
            caller_val = getfield(caller_module, s)
            if caller_val !== mod_val 
                if isdefined(previous_target_module, s) && caller_val === getfield(previous_target_module, s)
                    # We are just replacing the previous implementation of this call's target package, so we want to overwrite
                    return true
                else
                    @warn "Symbol `:$s`, is already defined in the caller module and points to a different object. Skipping"
                end
            end
            return false
        else # We don't check for names clashes with a caller module
            return true
        end
    end
    return f
end


## HTML Popup

_popup_style(id) = """
	fromparent-container {
	    height: 20px;
	    position: fixed;
	    top: 40px;
		right: 10px;
	    margin-top: 5px;
	    padding-right: 5px;
	    z-index: 200;
		background: #ffffff;
	    padding: 5px 8px;
	    border: 3px solid #e3e3e3;
	    border-radius: 12px;
	    height: 35px;
	    font-family: "Segoe UI Emoji", "Roboto Mono", monospace;
	    font-size: 0.75rem;
	}
	fromparent-container.errored {
		border-color: var(--error-cell-color)
	}
	fromparent-container:hover {
	    font-weight: 800;
		cursor: pointer;
	}
	body.disable_ui fromparent-container {
		display: none;
	}
	pluto-log-dot-positioner[hidden] {
		display: none;
	}
"""

function html_reload_button(cell_id; text = "Reload @frompackage", err = false)
	id = string(cell_id)
    style_content = _popup_style(id)
	html_content = """
	<script>
			const container = document.querySelector('fromparent-container') ?? document.body.appendChild(html`<fromparent-container>`)
			container.innerHTML = '$text'
			// We set the errored state
			container.classList.toggle('errored', $err)
			const style = container.querySelector('style') ?? container.appendChild(html`<style>`)
			style.innerHTML = `$(style_content)`
			const cell = document.getElementById('$id')
			const actions = cell._internal_pluto_actions
			container.onclick = (e) => {
				if (e.ctrlKey) {
					history.pushState({},'')			
					cell.scrollIntoView({
						behavior: 'auto',
						block: 'center',				
					})
				} else {
					actions.set_and_run_multiple(['$id'])
				}
			}
	</script>
	"""
    # We make an HTML object combining this content and the hide_this_log functionality
    return hide_this_log(html_content)
end

# Function to clean the filepath from the Pluto cell delimiter if present
cleanpath(path::String) = first(split(path, "#==#")) |> abspath
# Check if two paths are equal, ignoring case on the drive letter on windows.
function issamepath(path1::String, path2::String)
	path1 = abspath(path1)
	path2 = abspath(path2)
	if Sys.iswindows()
		uppercase(path1[1]) == uppercase(path2[1]) || return false
		path1[2:end] == path2[2:end] && return true
	else
		path1 == path2 && return true
	end
end
issamepath(path1::Symbol, path2::Symbol) = issamepath(String(path1), String(path2))

# Create a Base.PkgId from a PkgInfo
to_pkgid(p::PkgInfo) = Base.PkgId(p.uuid, p.name)

# This will extract the string from a raw_str macro, and will throw an error otherwise
function extract_raw_str(ex::Expr)
    valid = Meta.isexpr(ex, :macrocall) && ex.args[1] === Symbol("@raw_str")
    if valid
        return ex.args[end], true
    else
        return "", false
    end
end
extract_raw_str(s::AbstractString) = String(s), true

function get_extensions_ids(old_module::Module, parent::Base.PkgId)
    package_dict = old_module._fromparent_dict_
    out = Base.PkgId[]
    if has_extensions(package_dict)
        for ext in keys(package_dict["extensions"])
            id = Base.PkgId(Base.uuid5(parent.uuid, ext), ext)
            push!(out, id)
        end
    end
    return out
end

# This function will register the target module for `dict` as a root module.
# This relies on Base internals (and even the C API) but will allow make the loaded module behave more like if we simply did `using TargetPackage` in the REPL
function register_target_module_as_root(package_dict)
    name_str = package_dict["name"]
    m = get_target_module(Symbol(name_str))
    id = get_target_pkgid(package_dict)
    uuid = id.uuid
    entry_point = package_dict["file"]
    @lock Base.require_lock begin
        # Set the uuid of this module with the C API. This is required to get the correct UUID just from the module within `register_root_module`
        ccall(:jl_set_module_uuid, Cvoid, (Any, NTuple{2, UInt64}), m, uuid)
        # Register this module as root
        Base.with_logger(Base.NullLogger()) do
            Base.register_root_module(m)
        end
        # Set the path of the module to the actual package
        Base.set_pkgorigin_version_path(id, entry_point)
    end
end

function try_load_extensions(package_dict::Dict)
    has_extensions(package_dict) || return
    m = get_target_module(package_dict)
    proj_file = package_dict["project"]
    id = Base.PkgId(m)
    ext_ids = get_extensions_ids(m, id)
    @lock Base.require_lock begin
        # We try to clean up the eventual extensions (with target as parent) that we loaded with the previous version
        for id in ext_ids
            haskey(Base.EXT_PRIMED, id) && delete!(Base.EXT_PRIMED, id)
            haskey(Base.loaded_modules, id) && delete!(Base.loaded_modules, id)
        end
        Base.insert_extension_triggers(proj_file, id)
        Base.redirect_stderr(Base.DevNull()) do
            Base.run_extension_callbacks(id)
        end
    end
    return
end

# This function will get the module stored in the created_modules dict based on the entry point
get_stored_module(package_dict) = get_stored_module(package_dict["uuid"])
get_stored_module(key::String) = get(created_modules, key, nothing)
# This will store in it
update_stored_module(key::String, m::Module) = created_modules[key] = m
function update_stored_module(package_dict::Dict)
    uuid = package_dict["uuid"]
    m = get_target_module(package_dict)
    update_stored_module(uuid, m)
end