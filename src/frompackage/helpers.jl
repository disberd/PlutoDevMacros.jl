import ..PlutoDevMacros: hide_this_log

# This function imitates Base.find_ext_path to get the path of the extension specified by name, from the project in p
function find_ext_path(p::ProjectData, extname::String)
    project_path = dirname(p.file)
    extfiledir = joinpath(project_path, "ext", extname, extname * ".jl")
    isfile(extfiledir) && return extfiledir
    return joinpath(project_path, "ext", extname * ".jl")
end

function inside_extension(p::FromPackageController{name}) where name
    @nospecialize
    m = p.current_module
    nm = nameof(m)
    exts = keys(p.project.extensions)
    while nm ∉ (:Main, name)
        nm = nameof(m)
        String(nm) in exts && return true
        m = parentmodule(m)
    end
    return false
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

## execute only in notebook
# We have to create our own simple check to only execute some stuff inside the notebook where they are defined. We have stuff in basics.jl but we don't want to include that in this notebook
function is_notebook_local(calling_file::String)
    name_cell = split(calling_file, "#==#")
    return length(name_cell) == 2 && length(name_cell[2]) == 36
end

# # Get the first element in itr that satisfies predicate p, or nothing if itr is empty or no elements satisfy p
# function getfirst(p, itr)
#     for el in itr
#         p(el) && return el
#     end
#     return nothing
# end
# getfirst(itr) = getfirst(x -> true, itr)


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

function html_reload_button(cell_id; text="Reload @frompackage", err=false)
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


function beautify_package_path(p::FromPackageController{name}) where name
    @nospecialize
    temp_name = join(fullname(get_temp_module()), raw"\.")
"""
    <script>
        // We have a mutationobserver for each cell:
        const mut_observers = {
            current: [],
        }

const createCellObservers = () => {
	mut_observers.current.forEach((o) => o.disconnect())
	mut_observers.current = Array.from(notebook.querySelectorAll("pluto-cell")).map(el => {
		const o = new MutationObserver(updateCallback)
		o.observe(el, {attributeFilter: ["class"]})
		return o
	})
}
createCellObservers()

// And one for the notebook's child list, which updates our cell observers:
const notebookObserver = new MutationObserver(() => {
	updateCallback()
	createCellObservers()
})
notebookObserver.observe(notebook, {childList: true})
    	const cell_id = "a360000b-d9bb-4e12-a64b-276bff027591"
    	const cell = document.getElementById(cell_id)
    	const output = cell.querySelector('pluto-output')
    	const regex = /Main\\._FromPackage_TempModule_\\.(PlutoDevMacros)?/g
    	const replacement = "PlutoDevMacros"
    	const content = output.lastChild
    	function replaceTextInNode(node, pattern, replacement) {
          if (node.nodeType === Node.TEXT_NODE) {
            node.textContent = node.textContent.replace(pattern, replacement);
          } else {
            node.childNodes.forEach(child => replaceTextInNode(child, pattern, replacement));
          }
        }
    	replaceTextInNode(content, regex, replacement);
    </script>
"""
end

function generate_manifest_deps(proj_file::String)
    envdir = dirname(abspath(proj_file))
    manifest_file = ""
    for name in ("Manifest.toml", "JuliaManifest.toml")
        path = joinpath(envdir, name)
        if isfile(path)
            manifest_file = path
            break
        end
    end
    @assert !isempty(manifest_file) "A manifest could not be found at the project's location.\nYou have to provide an instantiated environment."
    d = TOML.parsefile(manifest_file)
    out = Dict{Base.UUID, String}()
    for (name, data) in d["deps"]
        # We use only here because I believe the entry will always contain a single dict wrapped in an array. If we encounter a case where this is not true the only will throw instead of silently taking just the first
        uuid = only(data)["uuid"] |> Base.UUID
        out[uuid] = name
    end
    return out
end

function update_loadpath(p::FromPackageController)
    @nospecialize
    proj_file = p.project.file 
    if proj_file ∉ LOAD_PATH
        push!(LOAD_PATH, proj_file)
    end
end

# This function traverse a path to access a nested module from a `starting_module`. It is used to extract the corresponding module from `import/using` statements.
function extract_nested_module(starting_module::Module, nested_path; first_dot_skipped=false)
    m = starting_module
    for name in nested_path
        m = if name === :.
            first_dot_skipped ? parentmodule(m) : m
        else
            @assert isdefined(m, name) "The module `$name` could not be found inside parent module `$(nameof(m))`"
            getproperty(m, name)::Module
        end
        first_dot_skipped = true
    end
    return m
end

function get_temp_module()
    if isdefined(Main, TEMP_MODULE_NAME)
        getproperty(Main, TEMP_MODULE_NAME)::Module
    else
        Core.eval(Main, :(module $TEMP_MODULE_NAME
        module _LoadedModules_ end
        module _DirectDeps_ end
        end))::Module
    end
end
get_temp_module(s::Symbol) = get_temp_module([s])
function get_temp_module(names::Vector{Symbol})
    temp = get_temp_module()
    out = extract_nested_module(temp, names)::Module
    return out
end
function get_temp_module(::FromPackageController{name}) where {name}
    @nospecialize
    get_temp_module(name)::Module
end

get_loaded_modules_mod() = get_temp_module(:_LoadedModules_)::Module

function populate_loaded_modules()
    loaded_modules = get_loaded_modules_mod()
    @lock Base.require_lock begin
        for (id, m) in Base.loaded_modules
            name = Symbol(id)
            isdefined(loaded_modules, name) && continue
            Core.eval(loaded_modules, :(const $name = $m))
        end
    end
    callbacks = Base.package_callbacks
    if mirror_package_callback ∉ callbacks
        # We just make sure to delete previous instances of the package callbacks when relading this package itself
        for i in reverse(eachindex(callbacks))
            f = callbacks[i]
            nameof(f) === :mirror_package_callback || continue
            nameof(parentmodule(f)) === nameof(@__MODULE__) || continue
            # We delete this as it's a previous version of the mirror_package_callback function
            deleteat!(callbacks, i)
        end
        # Add the package callback if not already present
        push!(callbacks, mirror_package_callback)
    end
end

# This function will extract a module from the _LoadedModules_ module which will be populated when each package is loaded in julia
function get_dep_from_loaded_modules(id::Base.PkgId)
    loaded_modules = get_loaded_modules_mod()
    key = Symbol(id)
    isdefined(loaded_modules, key) || error("The module $key can not be found in the loaded modules.")
    m = getproperty(loaded_modules, Symbol(id))::Module
    return m
end
# This is internally calls the previous function, allowing to control which packages can be loaded (by default only direct dependencies and stdlibs are allowed)
function get_dep_from_loaded_modules(p::FromPackageController{name}, base_name::Symbol; allow_manifest=false, allow_weakdeps = inside_extension(p), allow_stdlibs=true)::Module where {name}
    @nospecialize
    base_name === name && return get_temp_module(p)
    package_name = string(base_name)
    # Construct the custom error message
    error_msg = let 
        msg = """The package with name $package_name could not be found as a dependency$(allow_weakdeps ? " (or weak dependency)" : "") of the target project"""
        both = allow_manifest && allow_stdlibs
        allow_manifest && (msg *= """$(both ? "," : " or") as indirect dependency from the manifest""")
        allow_stdlibs && (msg *= """ or as standard library""")
        msg *= "."
    end
    if allow_stdlibs
        uuid = get(STDLIBS_DATA, package_name, nothing)
        uuid !== nothing && return get_dep_from_loaded_modules(Base.PkgId(uuid, package_name))
    end
    proj = p.project
    uuid = get(proj.deps, package_name) do
        # Throw error unless either of manifest/weakdeps is allowed
        allow_weakdeps | allow_manifest || error(error_msg)
        out = get(proj.weakdeps, package_name, nothing)
        !isnothing(out) && return out
        allow_manifest || error(error_msg)
        for (uuid, dep_name) in p.manifest_deps
            package_name === dep_name && return uuid
        end
        error(error_msg)
    end
    id = Base.PkgId(uuid, package_name)
    return get_dep_from_loaded_modules(id)
end

# Basically Base.names but ignores names that are not defined in the module and allows to restrict to only exported names (since 1.11 added also public names as out of names). It also defaults `all` and `imported` to true (to be more precise, to the opposite of `only_exported`)
function _names(m::Module; only_exported = false, all=!only_exported, imported=!only_exported, kwargs...)
    mod_names = names(m; all, imported, kwargs...)
    filter!(mod_names) do nm
        isdefined(m, nm) || return false
        only_exported && return Base.isexported(m, nm)
        return true
    end
end