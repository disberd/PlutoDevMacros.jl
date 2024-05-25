import ..PlutoCombineHTL: make_html, make_script
import ..PlutoDevMacros: hide_this_log

get_temp_module() = fromparent_module[]

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
function add_loadpath(entry::String)
	entry ∈ LOAD_PATH || push!(LOAD_PATH, entry)
	return nothing
end
add_loadpath(ecg::EnvCacheGroup) = add_loadpath(ecg |> get_active |> get_project_file)

## execute only in notebook
# We have to create our own simple check to only execute some stuff inside the notebook where they are defined. We have stuff in basics.jl but we don't want to include that in this notebook
function is_notebook_local(calling_file::String)
	name_cell = split(calling_file, "#==#")
	return length(name_cell) == 2 && length(name_cell[2]) == 36
end

## package extensions helpers
has_extensions(package_data) = haskey(package_data, "extensions") && haskey(package_data, "weakdeps")

# This will extract all the useful extension data for each weakdep
function get_extension_data(env::EnvCache)
	project = env |> get_project
	out = Dict{String, Any}()
	isempty(project.exts) && return out
	ext_dir = extensions_dir(env)
	weakdeps = project.weakdeps
	exts = Dict((v,k) for (k,v) in project.exts)
	for (k,uuid) in weakdeps
		module_name = exts[k]
		filename = module_name * ".jl"
		file_found = false
		module_location = ""
		for mid in ("", module_name)
			file_found && break
			module_location = joinpath(ext_dir, mid, filename)
			isfile(module_location) && (file_found = true)
		end
		file_found || error("The module location for extension $module_name could not be found.")
		module_name = Symbol(module_name)
		out[k] = (;module_name, uuid, module_location)
	end
	out
end

function maybe_add_loaded_module(id::Base.PkgId)
	symname = id.name |> Symbol
	# We just returns if the module is already loaded
	isdefined(LoadedModules, symname) && return nothing
    loaded_module = Base.maybe_root_module(id)
	isnothing(loaded_module) && error("The package $id does not seem to be loaded")
	Core.eval(LoadedModules, :(const $(symname) = $(loaded_module)))
	return nothing
end


function maybe_add_extensions!(package_module::Module, package_dict)
	# This is to trigger reloading potential indirect extensions that failed loading
	Base.retry_load_extensions()
	has_extensions(package_dict) || return nothing # We skip this if no extensions are in the package
	ecg = default_ecg()
	ext_datas = package_dict["extension data"]
	loaded_ext_names = get!(package_dict, "loaded extensions", Set{Symbol}())
	for (weakdep, ext_data) in ext_datas
		(;module_name, uuid, module_location) = ext_data
		module_name in loaded_ext_names && continue
		for env in (get_active(ecg), get_notebook(ecg))
			module_name in loaded_ext_names && break
			manifest = get_manifest(env)
			haskey(manifest.deps, uuid) || continue # We don't have this as dependency, we skip
			pkgid = Base.PkgId(uuid, manifest.deps[uuid].name)
			# Add the required module to LoadedModules if not there already
			maybe_add_loaded_module(pkgid)
			# We push this as loaded extension
			push!(loaded_ext_names, module_name)
			# Now we evaluate the extension code in the package module
			mod_exp = extract_module_expression(module_location)
			eval_in_module(package_module,Expr(:toplevel, LineNumberNode(1, Symbol(module_location)), mod_exp), package_dict)
			# We already evaluated this so we stop
			break
		end
	end
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
	isnothing(target.pkg) && error("The project found at $project_file is not a package, simple environments are currently not supported")
	# We update the notebook and active envcaches to be up to date
	update_ecg!(ecg)

	# Check that the package file actually exists
	package_file = get_entrypoint(target)
	package_dir = dirname(package_file) |> abspath

	isfile(package_file) || error("The package package main file was not found at path $package_file")

	package_data = deepcopy(target.project.other)
	package_data["dir"] = package_dir
	package_data["file"] = package_file
	package_data["target"] = packagepath
	package_data["ecg"] = ecg

	# Check for extensions
	if has_extensions(package_data)
		package_data["extension data"] = get_extension_data(target)
		package_data["loaded extensions"] = Set{Symbol}()
	end

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
function filterednames(m::Module; all = true, imported = true, explicit_names = nothing)
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
	filter(filter_args) do s
		Base.isgensym(s) && return false
		s in excluded && return false
		return true
	end
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
	container = @htl("""
	<script>
			const container = document.querySelector('fromparent-container') ?? document.body.appendChild(html`<fromparent-container>`)
			container.innerHTML = $text
			// We set the errored state
			container.classList.toggle('errored', $err)
			const style = container.querySelector('style') ?? container.appendChild(html`<style>`)
			style.innerHTML = $(_popup_style(id))
			const cell = document.getElementById($id)
			const actions = cell._internal_pluto_actions
			container.onclick = (e) => {
				if (e.ctrlKey) {
					history.pushState({},'')			
					cell.scrollIntoView({
						behavior: 'auto',
						block: 'center',				
					})
				} else {
					actions.set_and_run_multiple([$id])
				}
			}
	</script>
	""")
	make_script([container, hide_this_log()]) |> make_html
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