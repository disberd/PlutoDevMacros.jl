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

# Get the first element in itr that satisfies predicate p, or nothing if itr is empty or no elements satisfy p
function getfirst(p, itr)
    for el in itr
        p(el) && return el
    end
    return nothing
end
getfirst(itr) = getfirst(x -> true, itr)


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