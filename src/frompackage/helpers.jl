import ..PlutoDevMacros: hide_this_log

function get_temp_module()
    isdefined(Main, TEMP_MODULE_NAME) || return nothing
    return getproperty(Main, TEMP_MODULE_NAME)::Module
end

# Extract the module that is the target in dict
get_target_module(dict) = dict["Created Module"]

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

    maybe_update_envcache(project_file, ecg; notebook=false)
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
    d, i = target_dependencies(target)
    package_data["PkgInfo"] = (; direct=d, indirect=i)

    return package_data
end

# Get the first element in itr that satisfies predicate p, or nothing if itr is empty or no elements satisfy p
function getfirst(p, itr)
    for el in itr
        p(el) && return el
    end
    return nothing
end
getfirst(itr) = getfirst(x -> true, itr)

## Similar to names but allows to exclude names and add explicit ones. It also filter names based on whether they are defined already in the caller module
function filterednames(m::Module; all=true, imported=true, explicit_names=Set{Symbol}(), caller_module::Module)
    excluded = (:eval, :include, :_fromparent_dict_, Symbol("@bind"))
    mod_names = names(m; all, imported)
    filter_args = union(mod_names, explicit_names)
    filter_func = filterednames_filter_func(; excluded, caller_module)
    filter(filter_func, filter_args)
end

function has_ancestor_module(target::Module, ancestor_name::Symbol; previous=nothing, only_rootmodule=false)
    has_ancestor_module(target, (ancestor_name,); previous, only_rootmodule)
end
function has_ancestor_module(target::Module, ancestor_names; previous=nothing, only_rootmodule=false)
    nm = nameof(target)
    ancestor_found = nm in ancestor_names
    !only_rootmodule && ancestor_found && return true # Ancestor found, and no check on only_rootmodule
    nm === previous && return ancestor_found # The target is the same as previous, so we reached a top-level module. We return whether the ancestor was found and is a parent of itself
    return has_ancestor_module(parentmodule(target), ancestor_names; previous=nm, only_rootmodule)
end

# This returns two flags: whether the name can be included and whether a warning should be generated
function can_import_in_caller(name::Symbol, caller::Module)
    isdefined(caller, name) || return true, false # If is not defined we can surely import it
    owner = which(caller, name)
    # Skip (and do not warn) for things defined in Base or Core
    invalid_ancestor = has_ancestor_module(owner, (:Base, :Core, :Markdown, :InteractiveUtils))
    invalid_ancestor && return false, false
    # We check if the name is inside the list of symbols imported by the previous module
    in_previous = name in PREVIOUS_CATCHALL_NAMES
    return in_previous, !in_previous
end

function filterednames_filter_func(; excluded, caller_module)
    f(s) =
        let excluded = excluded, caller = caller_module
            Base.isgensym(s) && return false
            s in excluded && return false
            should_include, should_warn = can_import_in_caller(s, caller)
            if should_warn
                owner = which(caller, s)
                @warn "The name `$s`, defined in $owner, is already present in the caller module and will not be imported."
            end
            return should_include
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

# This function will get the module stored in the created_modules dict based on the entry point
get_stored_module() = STORED_MODULE[]
# This will store in it
update_stored_module(m::Module) = STORED_MODULE[] = m
function update_stored_module(package_dict::Dict)
    m = get_target_module(package_dict)
    update_stored_module(m)
end

overwrite_imported_symbols(package_dict::Dict) = overwrite_imported_symbols(get(Set{Symbol}, package_dict, "Catchall Imported Symbols"))
# This overwrites the PREVIOUSLY_IMPORTED_SYMBOLS with the contents of new_symbols
function overwrite_imported_symbols(new_symbols)
    empty!(PREVIOUS_CATCHALL_NAMES)
    union!(PREVIOUS_CATCHALL_NAMES, new_symbols)
    nothing
end

function beautify_package_path()
    html"""
    <script>
    	const cell_id = "a360000b-d9bb-4e12-a64b-276bff027591"
    	const cell = document.getElementById(cell_id)
    	const output = cell.querySelector('pluto-output')
    	const regex = /Main\._FromPackage_TempModule_\.(PlutoDevMacros)?/g
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