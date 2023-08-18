import ..Script: HTLScript, HTLScriptPart, make_script, combine_scripts
import Pkg, TOML
const _stdlibs = first.(values(Pkg.Types.stdlibs()))

const fromparent_module = Ref{Module}()
const macro_cell = Ref("undefined")
const manifest_names = ("JuliaManifest.toml", "Manifest.toml")

get_temp_module() = fromparent_module[]

struct PkgInfo 
	name::String
	uuid::String
	version::String
end

## Return calling DIR, basically copied from the definigion of the @__DIR__ macro
function __DIR__(__source__)
    __source__.file === nothing && return nothing
    _dirname = dirname(String(__source__.file::Symbol))
    return isempty(_dirname) ? pwd() : abspath(_dirname)
end

function get_manifest_file(project_file::String)
	dict = try
		TOML.parsefile(project_file)
	catch e
		@error "The given project_file $project_file is not a valid TOML file"
		rethrow()
	end
	get_manifest_file(project_file, dict)
end
# This function is extracted from `Base.project_file_manifest_path` without the caching part
function get_manifest_file(project_file::String, d)
    dir = abspath(dirname(project_file))
    explicit_manifest = get(d, "manifest", nothing)::Union{String, Nothing}
    manifest_path = nothing
    if explicit_manifest !== nothing
        manifest_file = normpath(joinpath(dir, explicit_manifest))
        if Base.isfile_casesensitive(manifest_file)
            manifest_path = manifest_file
        end
    end
    if manifest_path === nothing
        for mfst in manifest_names
            manifest_file = joinpath(dir, mfst)
            if Base.isfile_casesensitive(manifest_file)
                manifest_path = manifest_file
                break
            end
        end
    end
	return manifest_path
end

# Function to get the package dependencies from the manifest
function package_dependencies(project_location::String)
	project_file = Base.current_project(project_location)
	project_file isa Nothing && error("No parent project was found starting from the path $project_location")
	proj_dict = TOML.parsefile(project_file)
	# We identify the names of the direct project dependencies
	proj_deps = get(proj_dict,"deps",Dict{String,Any}())
	manifest_file = get_manifest_file(project_file, proj_dict)
	direct = Dict{String, PkgInfo}()
	indirect = Dict{String, PkgInfo}()
	# manifest_file isa Nothing && error("No Manifest was found.
	# The project located at $project_file does not seem to have a corresponding Manifest file. 
	# Please make sure that the project has a Manifest file by calling `Pkg.resolve` in its environment")
	if manifest_file isa Nothing
		# In case there is not Manifest, we just populate the direct entry
		for (name, uuid) in proj_deps
			direct[name] = PkgInfo(name, uuid, "N/A")
		end
	else
		manifest_deps = Base.get_deps(TOML.parsefile(manifest_file))
	for (k,vv) in manifest_deps
		v = vv[1]
			d = haskey(proj_deps, k) ? direct : indirect
		d[k] = PkgInfo(k, v["uuid"], get(v,"version", "stdlib"))
	end
	end
	direct, indirect
end
package_dependencies(d::Dict) = package_dependencies(d["project"])

struct LineNumberRange
	first::LineNumberNode
	last::LineNumberNode
	function LineNumberRange(ln1::LineNumberNode, ln2::LineNumberNode)
		@assert ln1.file === ln2.file "A range of LineNumbers can only be specified with LineNumbers from the same file"
		first, last = ln1.line <= ln2.line ? (ln1, ln2) : (ln2, ln1)
		new(first, last)
	end
end
LineNumberRange(ln::LineNumberNode) = LineNumberRange(ln, ln)
LineNumberRange(file::AbstractString, first::Int, last::Int) = LineNumberRange(
	LineNumberNode(first, Symbol(file)),
	LineNumberNode(last, Symbol(file))
)
## Inclusion in LinuNumberRange
function _inrange(ln::LineNumberNode, lnr::LineNumberRange)
	ln.file === lnr.first.file || return false # The file is not the same
	if ln.line >= lnr.first.line && ln.line <= lnr.last.line
		return true
	else
		return false
	end
end
_inrange(ln::LineNumberNode, ln2::LineNumberNode) = ln === ln2

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
	length(LOAD_PATH) > 1 && LOAD_PATH[2] != entry && insert!(LOAD_PATH, 2, entry)
end
function clean_loadpath(entry::String)
	LOAD_PATH[2] == entry && deleteat!(LOAD_PATH, 2)
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

## package extensions helpers
has_extensions(package_data) = haskey(package_data, "extensions") && haskey(package_data, "weakdeps")

## get parent data
function get_package_data(packagepath::AbstractString)
	project_file = Base.current_project(packagepath)
	project_file isa Nothing && error("No project was found starting from $packagepath")
	project_file = abspath(project_file)

	package_dir = dirname(project_file) |> abspath
	package_data = TOML.parsefile(project_file)
	haskey(package_data, "name") || error("The project found at $project_file is not a package, simple environments are currently not supported")

	# Check for extensions
	if has_extensions(package_data)
		@info package_data
	end

	# Check that the package file actually exists
	package_file = joinpath(package_dir,"src", package_data["name"] * ".jl")
	isfile(package_file) || error("The package package main file was not found at path $package_file")
	package_data["dir"] = package_dir
	package_data["project"] = project_file
	package_data["file"] = package_file
	package_data["target"] = packagepath

	# We extract the PkgInfo for all packages in this environment
	d,i = package_dependencies(project_file)
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

# This function, if appearing inside a capture log message in Pluto (not with
# println, just the @info, @warn, etc ones), will hide itself. It is mostly used
# in combination with other scripts to inject some javascript in the notebook
# without having an ugly empty log below the cell 
function hide_this_log()
	body = HTLScriptPart("""
	const logs_positioner = currentScript.closest('pluto-log-dot-positioner')
	if (logs_positioner == undefined) {return}
	const logs = logs_positioner.parentElement
	const logs_container = logs.parentElement

	const observer = new MutationObserver((mutationList, observer) => {
		for (const child of logs.children) {
			if (!child.hasAttribute('hidden')) {
				logs.style.display = "block"
				logs_container.style.display = "block"
				return
			}
		}
		// If we reach here all the children are hidden, so we hide the container as well		
		logs.style.display = "none"
		logs_container.style.display = "none"
	})

	observer.observe(logs, {subtree: true, attributes: true, childList: true})
	logs_positioner.toggleAttribute('hidden',true)
	""")
	invalidation = HTLScriptPart("""
		console.log('invalidation')
		observer.disconnect()
	""")
	return HTLScript(body, invalidation)
end

function html_reload_button(cell_id; text = "Reload @frompackage", err = false)
	id = string(cell_id)
	container = HTLScript(@htl """
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
	make_script(combine_scripts([container, hide_this_log()]))
end