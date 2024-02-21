import ..PlutoCombineHTL: make_html, make_script
import ..PlutoDevMacros: hide_this_log
import Pkg, TOML
using Pkg.Types: write_project

get_temp_module() = fromparent_module[]

extensions_dir(ecg::EnvCacheGroup) = extensions_dir(get_target(ecg))
function extensions_dir(env::EnvCache)
	pkg = env.pkg
	isnothing(pkg) && return nothing
	ext_dir = joinpath(pkg.path, "ext")
end
get_manifest_file(e::EnvCache) = e.manifest_file
get_project_file(e::EnvCache) = e.project_file
get_manifest(e::EnvCache) = e.manifest
get_project(e::EnvCache) = e.project
function get_entrypoint(e::EnvCache)
	pkg = e.pkg
	isnothing(pkg) && return ""
	entrypoint = joinpath(pkg.path, "src", pkg.name * ".jl")
end
get_active(ecg::EnvCacheGroup) = ecg.active
get_target(ecg::EnvCacheGroup) = ecg.target
get_notebook(ecg::EnvCacheGroup) = ecg.notebook

function maybe_update_envcache(projfile::String, ecg::EnvCacheGroup; notebook = false)
	f = notebook ? get_notebook : get_target
	env = f(ecg)
	if isnothing(env) || env.project_file != projfile
		setproperty!(ecg, notebook ? :notebook : :target, EnvCache(projfile))
	end
	return nothing
end


function update_envcache!(e::EnvCache)
	e.project = read_project(e.project_file)
	e.manifest = read_manifest(e.manifest_file)
	return e
end
# Update the active EnvCache by eventually copying reduced project and manifest from the package EnvCache
function update_ecg!(ecg::EnvCacheGroup; force = false, io::IO = devnull, instantiate = force)
	c = Context(; io)
	# Update the target and notebook ecg 
	update_envcache!(ecg |> get_target)
	update_envcache!(ecg |> get_notebook)
	active = get_active(ecg)
	active_manifest = active |> get_manifest_file
	active_project = active |> get_manifest_file
	target_manifest = get_target(ecg) |> get_manifest_file
	if !isfile(active_manifest) || !isfile(active_project)
		force = true
	end
	if !force
		active_mtime = mtime(active_manifest)
		target_mtime = mtime(ecg |> get_target |> get_manifest_file)
		force = force || active_mtime < target_mtime
	end
    if force
		mkpath(dirname(active_manifest))
		# We copy a reduced version of the project, only with deps and compat
        pd = ecg.target.project.other
        ad = Dict{String, Any}((k => pd[k] for k in ("deps", "compat") if haskey(pd, k)))
        write_project(ad, active_project)
        # We copy the Manifest
        cp(target_manifest, active_manifest; force = true)
        # We call instantiate
		update_envcache!(ecg.active)
		c.env = ecg.active
        Pkg.instantiate(c)
    end
    return ecg
end

## Return calling DIR, basically copied from the definigion of the @__DIR__ macro
function __DIR__(__source__)
    __source__.file === nothing && return nothing
    _dirname = dirname(String(__source__.file::Symbol))
    return isempty(_dirname) ? pwd() : abspath(_dirname)
end

# Function to get the package dependencies from the manifest
function target_dependencies(target::EnvCache)
	manifest_deps = target.manifest.deps
	proj_deps = target.project.deps
	direct = Dict{String, PkgInfo}()
	indirect = Dict{String, PkgInfo}()
	for (uuid,pkgentry) in manifest_deps
		(;name, version) = pkgentry
		d = haskey(proj_deps, name) ? direct : indirect
		d[name] = PkgInfo(name, uuid, version)
	end
	direct, indirect
end


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

# Functions to add and remove from the LOAD_PATH
function add_loadpath(entry::String)
	entry ∈ LOAD_PATH || push!(LOAD_PATH, entry)
	return nothing
end
add_loadpath(ecg::EnvCacheGroup) = add_loadpath(ecg |> get_active |> get_project_file)
function clean_loadpath(entry::String)
	for i in length(LOAD_PATH):-1:1
		if LOAD_PATH[i] == entry
			deleteat!(LOAD_PATH, i)
		end
	end
	return nothing
end
clean_loadpath(ecg::EnvCacheGroup) = clean_loadpath(ecg |> get_active |> get_project_file)

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

## package extensions helpers
has_extensions(package_data) = haskey(package_data, "extensions") && haskey(package_data, "weakdeps")

# This will extract all the useful extension data for each weakdep
get_extension_data(ecg::EnvCacheGroup) = ecg |> get_target |> get_extension_data
function get_extension_data(env::EnvCache)
	project = env |> get_project
	out = Dict{String, Any}()
	isempty(project.exts) && return out
	ext_dir = extensions_dir(env)
	weakdeps = project.weakdeps
	exts = Dict((v,k) for (k,v) in project.exts)
	for (k,v) in weakdeps
		module_name = exts[k]
		uuid = Base.UUID(v)
		filename = module_name * ".jl"
		file_found = false
		module_location = ""
		for mid in ("", module_name)
			file_found && break
			module_location = joinpath(ext_dir, mid, filename)
			isfile(module_location) && (file_found = true)
		end
		file_found || error("The module location for extension $module_name could not be found.")
		out[k] = (;module_name, uuid, module_location)
	end
	out
end

function maybe_add_extensions!(package_module::Module, package_dict, caller_module::Module)
	# This is to trigger reloading potential indirect extensions that failed loading
	Base.retry_load_extensions()
	has_extensions(package_dict) || return nothing # We skip this if no extensions are in the package
	ext_data = package_dict["extension data"]
	loaded_ext_names = get!(package_dict, "loaded extensions", Set{Symbol}())
	for (k,v) in ext_data
		isdefined(caller_module, Symbol(k)) || continue # We don't have this package loaded in the caller module
		pkgid = Base.identify_package(k)
		pkgid !== nothing && pkgid.uuid === v.uuid || continue # The UUID does not match
		push!(loaded_ext_names, Symbol(v.module_name))
		# Now we evaluate the extension code in the package module
		mod_exp = extract_module_expression(v.module_location)
		eval_in_module(package_module,Expr(:toplevel, LineNumberNode(1, Symbol(v.module_location)), mod_exp), package_dict)
	end
	return nothing
end

## get parent data
function get_package_data(packagepath::AbstractString)
	project_file = Base.current_project(packagepath)
	project_file isa Nothing && error("No project was found starting from $packagepath")
	project_file = abspath(project_file)

	ecg = ENVS

	maybe_update_envcache(project_file, ecg; notebook = false)
	target = get_target(update_ecg!(ecg))
	isnothing(target.pkg) && error("The project found at $project_file is not a package, simple environments are currently not supported")

	# Check that the package file actually exists
	package_file = get_entrypoint(target)
	package_dir = dirname(package_file) |> abspath

	isfile(package_file) || error("The package package main file was not found at path $package_file")

	package_data = deepcopy(target.project.other)
	package_data["dir"] = package_dir
	package_data["file"] = package_file
	package_data["target"] = packagepath

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
function filterednames(m::Module; all = true, imported = true)
	excluded = (:eval, :include, :_fromparent_dict_, Symbol("@bind"))
	filter(names(m;all, imported)) do s
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