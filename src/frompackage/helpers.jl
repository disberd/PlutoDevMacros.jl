import ..PlutoDevMacros: hide_this_log


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

nested_getproperty_expr(name::Symbol) = QuoteNode(name)
# This function creates the expression to access a nested property specified by a path. For example, if `path = [:Main, :ASD, :LOL]`, `nested_getproperty_expr(path...)` will return the expression equivalent to `Main.ASD.LOL`. This is not to be used within `import/using` statements as the synthax for accessing nested modules is different there.
function nested_getproperty_expr(names_path::Symbol...)
    @nospecialize
    others..., tail = names_path
    last_arg = nested_getproperty_expr(tail)
    first_arg = length(others) === 1 ? first(others) : nested_getproperty_expr(others...)
    ex = isempty(others) ? arg : Expr(:., first_arg, last_arg)
    return ex
end

### Input Parsing
# This function will extract the first name of a module identifier from `import/using` statements
function get_modpath_root(ex::Expr)
    (;modname_path) = extract_input_import_names(ex)
    modname_first = first(modname_path)
    return modname_first
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
        m = Core.eval(Main, :(module $TEMP_MODULE_NAME
        module _LoadedModules_ end
        module _DirectDeps_ end
        end))::Module
    end
end
get_temp_module(s::Symbol) = getproperty(get_temp_module(), s)
function get_temp_module(names::Vector{Symbol})
    out = get_temp_module()
    for name in names
        getproperty(out, name)
    end
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
    empty!(Base.package_callbacks) ### IMPORTANT, TO REMOVE ###
    if mirror_package_callback ∉ Base.package_callbacks
        # Add the package callback if not already present
        push!(Base.package_callbacks, mirror_package_callback)
    end
end

function get_dep_from_manifest(p::FromPackageController, base_name)
    @nospecialize
    (; manifest_deps) = p
    name_str = string(base_name)
    for (uuid, name) in manifest_deps
        if name === name_str
            id = Base.PkgId(uuid, name)
            return get_dep_from_loaded_modules(id)
        end
    end
    return nothing
end
function get_dep_from_loaded_modules(id::Base.PkgId)
    loaded_modules = get_loaded_modules_mod()
    key = Symbol(id)
    isdefined(loaded_modules, key) || error("The module $key can not be found in the loaded modules.")
    m = getproperty(loaded_modules, Symbol(id))::Module
    return m
end
function get_dep_from_loaded_modules(p::FromPackageController{name}, base_name; allow_manifest=false, allow_stdlibs=true)::Module where {name}
    @nospecialize
    base_name === name && return get_temp_module(p)
    package_name = string(base_name)
    if allow_stdlibs
        uuid = get(STDLIBS_DATA, package_name, nothing)
        uuid !== nothing && return get_dep_from_loaded_modules(Base.PkgId(uuid, package_name))
    end
    proj = p.project
    uuid = get(proj.deps, package_name) do
        get(proj.weakdeps, package_name) do
            out = allow_manifest ? get_dep_from_manifest(p, base_name) : nothing
            isnothing(out) && error("The package with name $package_name could not be found as deps or weakdeps of the target project, as indirect dep of the manifest, or as standard library")
            return out
        end
    end
    id = Base.PkgId(uuid, package_name)
    return get_dep_from_loaded_modules(id)
end