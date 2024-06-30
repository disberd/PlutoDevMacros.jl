# This function imitates Base.find_ext_path to get the path of the extension specified by name, from the project in p
function find_ext_path(p::ProjectData, extname::String)
    project_path = dirname(p.file)
    extfiledir = joinpath(project_path, "ext", extname, extname * ".jl")
    isfile(extfiledir) && return extfiledir
    return joinpath(project_path, "ext", extname * ".jl")
end

function inside_extension(p::FromPackageController{name}) where {name}
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

## HTML Popup

function _popup_style()
#! format: off
"""
fromparent-container {
  height: 20px;
  position: fixed;
  top: 40px;
  right: 10px;
  margin-top: 5px;
  padding-right: 5px;
  z-index: 200;
  background: var(--overlay-button-bg);
  padding: 5px 8px;
  border: 3px solid var(--overlay-button-border);
  border-radius: 12px;
  height: 35px;
  font-family: "Segoe UI Emoji", "Roboto Mono", monospace;
  font-size: 0.75rem;
  visibility: visible;
}

fromparent-container.PlutoDevMacros {
  right: auto;
  left: 10px;
}
fromparent-container.PlutoDevMacros:before {
  content: "Reload PlutoDevMacros"
}

fromparent-container.errored {
  border-color: var(--error-cell-color);
}
fromparent-container:hover {
  font-weight: 800;
  cursor: pointer;
}
body.disable_ui fromparent-container {
  display: none;
}
"""
#! format: on
end

function html_reload_button(p::FromPackageController; kwargs...)
    @nospecialize
    (; name) = p.project
    simple_html_cat(
        beautify_package_path(p),
        html_reload_button(p.cell_id; name, kwargs...),
    )
end
function html_reload_button(cell_id; name="@frompackage", err=false)
    id = string(cell_id)
    text_content = "Reload $name"
    style_content = _popup_style()
    #! format: off
    # We add the text content based on the package name
    style_content *= """
fromparent-container:before {
  content: '$text_content';
}
    """
    html_content = """
<script id='html_reload_button'>
  const container = html`<fromparent-container class='$name'>`
  // We set the errored state
  container.classList.toggle('errored', $err)
  const style = container.appendChild(html`<style>`)
  style.innerHTML = `$(style_content)`
  const cell = document.getElementById('$id')
  const actions = cell._internal_pluto_actions
  container.onclick = (e) => {
    if (e.ctrlKey) {
      history.pushState({}, '')
      cell.scrollIntoView({
        behavior: 'auto',
        block: 'center',
      })
    } else {
      actions.set_and_run_multiple(['$id'])
    }
  }

  return container
</script>
    """
    #! format: on
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

is_raw_str(ex) = Meta.isexpr(ex, :macrocall) && first(ex.args) === Symbol("@raw_str")
# This function extracts the target path by evaluating the ex of the target in the caller module. It will error if `ex` is not a string or a raw string literal if called outside of Pluto
function extract_target_path(ex, caller_module::Module; calling_file, notebook_local::Bool=is_notebook_local(calling_file))
    valid_outside = ex isa AbstractString || is_raw_str(ex)
    # If we are not inside a notebook and the path is not provided as string or raw string, we throw an error as the behavior is not supported
    @assert notebook_local || valid_outside "When calling `@frompackage` outside of a notebook, the path must be provided as `String` or `@raw_str` (i.e. an expression of type `raw\"...\"`)."
    path = Core.eval(caller_module, ex)
    # Make the path absolute
    path = abspath(dirname(calling_file), path)
    # Eventuallly remove the cell_id from the target
    path = cleanpath(path)
    @assert ispath(path) "The extracted path does not seem to be a valid path.\n-`extracted_path`: $path"
    return path
end

function beautify_package_path(p::FromPackageController)
    @nospecialize
    modpath..., name = fullname(get_temp_module(p))
    modpath = map(enumerate(modpath)) do (i, s)
        Base.isgensym(s) || return String(s)
        return "var\"$s\""
    end
    regex = """/$(join(modpath, "\\."))(\\.$(name))?/g"""
    Docs.HTML(
        #! format: off
"""
<script id='frompackage-text-replace'>
  // We have a mutationobserver for each cell:
  const notebook = document.querySelector('pluto-notebook')

  const mut_observers = {
    current: [],
  }
  currentScript.mut_observers = mut_observers
  function replaceTextInNode(node, pattern, replacement, originals = []) {
    if (node.nodeType === Node.TEXT_NODE) {
      const content = node.textContent
      if (!pattern.test(content)) {return}
      originals.push({node, content})
      node.textContent = content.replace(pattern, replacement);
    } else {
      node.childNodes.forEach(child => replaceTextInNode(child, pattern, replacement, originals));
    }
  }
  function execute_cell_observer(observer) {
    if (invalidated.current) {
      observer.disconnect()
      return
    }
    const { cell, regex, replacement, originals } = observer
    const output = cell.querySelector('pluto-output')
    const content = output.lastChild
    replaceTextInNode(content, regex, replacement, originals);
  }

  function revert_cell_original_text(observer) {
    observer.originals?.forEach(item => {
      item.node.textContent = item.content
    })
  }

  currentScript.revert_original_text = () => {
    mut_observers.current.forEach(revert_cell_original_text)
  }

  const invalidated = { current: false }

  const createCellObservers = () => {
    mut_observers.current.forEach((o) => o.disconnect())
    mut_observers.current = Array.from(notebook.querySelectorAll("pluto-cell")).map(el => {
      const o = new MutationObserver((mutations, observer) => {execute_cell_observer(observer)})
      o.cell = el
      o.regex = $regex
      o.replacement = '$name'
      o.originals = []
      o.observe(el, { attributeFilter: ["class"] })
      execute_cell_observer(o)
      return o
    })
  }
  createCellObservers()

  // And one for the notebook's child list, which updates our cell observers:
  const notebookObserver = new MutationObserver((mutations, observer) => {
    if (invalidation.current) {
      observer.disconnect()
      return
    }
    createCellObservers()
  })
  notebookObserver.observe(notebook, { childList: true })

  const cell = currentScript.closest('pluto-cell')

  invalidation.then(() => {
    invalidated.current = true
    const revert = cell?.querySelector("script[id='frompackage-text-replace']") == null
    notebookObserver.disconnect()
    mut_observers.current.forEach((o) => {
      revert && revert_cell_original_text(o)
      o.disconnect()
    })
  })
</script>
   """
   #! format: on
    )
end

function populate_manifest_deps!(p::FromPackageController)
    @nospecialize
    (;manifest_deps) = p
    d = TOML.parsefile(get_manifest_file(p))
    for (name, data) in d["deps"]
        # We use `only` here because I believe the entry will always contain a single dict wrapped in an array. If we encounter a case where this is not true the only will throw instead of silently taking just the first
        uuid = only(data)["uuid"] |> Base.UUID
        manifest_deps[uuid] = name
    end
    return manifest_deps
end

# This will extract the path of the manifest file. By default it will error if the manifest can not be found in the env directory, but it can be forced to instantiate/resolve using options
function get_manifest_file(p::FromPackageController)
    @nospecialize
    (; project, options) = p
    mode = options.manifest
    proj_file = project.file
    envdir = dirname(abspath(proj_file))
    manifest_file = if mode in (:instantiate, :resolve)
        context_kwargs = options.verbose ? (;) : (; io = devnull)
        c = Context(;env = EnvCache(proj_file), context_kwargs...)
        resolve = mode === :resolve
        if resolve
            Pkg.resolve(c)
        else
            Pkg.instantiate(c; update_registry = false, allow_build = false, allow_autoprecomp = false)
        end
        joinpath(envdir, "Manifest.toml")
    else
        manifest_file = ""
        for name in ("Manifest.toml", "JuliaManifest.toml")
            path = joinpath(envdir, name)
            if isfile(path)
                manifest_file = path
                break
            end
        end
        #! format: off
        @assert !isempty(manifest_file) "A manifest could not be found at the project's location.
You have to provide an instantiated environment or set the `manifest` option to `:resolve` or `:instantiate`.
EnvDir: $envdir"
        #! format: on
        manifest_file
    end
    return manifest_file
end

function update_loadpath(p::FromPackageController)
    @nospecialize
    (; verbose) = p.options
    proj_file = p.project.file
    if isassigned(CURRENT_FROMPACKAGE_CONTROLLER)
        prev_proj = CURRENT_FROMPACKAGE_CONTROLLER[].project.file
        prev_idx = findfirst(==(prev_proj), LOAD_PATH)
        if !isnothing(prev_idx) && prev_proj !== proj_file
            verbose && @info "Deleting $prev_proj from LOAD_PATH"
            deleteat!(LOAD_PATH, prev_idx)
        end
    end
    if proj_file ∉ LOAD_PATH
        verbose && @info "Adding $proj_file to end of LOAD_PATH"
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

# This will create a unique name for a module by translating the PkgId into a symbol
unique_module_name(m::Module) = Symbol(Base.PkgId(m))
unique_module_name(uuid::Base.UUID, name::AbstractString) = Symbol(Base.PkgId(uuid, name))

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
get_direct_deps_mod() = get_temp_module(:_DirectDeps_)::Module

function populate_loaded_modules(; verbose=false)
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
        for i in reverse(eachindex(callbacks))
            # This part is only useful when developing this package itself
            f = callbacks[i]
            nameof(f) === :mirror_package_callback || continue
            owner = parentmodule(f)
            nameof(owner) === nameof(@__MODULE__) || continue
            isdefined(owner, :IS_DEV) && owner.IS_DEV || continue
            # We delete this as it's a previous version of the mirror_package_callback function
            verbose && @warn "Deleting previous version of package_callback function"
            deleteat!(callbacks, i)
        end
        # Add the package callback if not already present
        push!(callbacks, mirror_package_callback)
    end
end

# This function will extract a module from the _LoadedModules_ module which will be populated when each package is loaded in julia
function get_dep_from_loaded_modules(key::Symbol)
    loaded_modules = get_loaded_modules_mod()
    isdefined(loaded_modules, key) || error("The module $key can not be found in the loaded modules.")
    m = getproperty(loaded_modules, key)::Module
    return m
end
# This is internally calls the previous function, allowing to control which packages can be loaded (by default only direct dependencies and stdlibs are allowed)
function get_dep_from_loaded_modules(p::FromPackageController{name}, base_name::Symbol; allow_manifest=false, allow_weakdeps=inside_extension(p), allow_stdlibs=true)::Module where {name}
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
        uuid !== nothing && return get_dep_from_loaded_modules(unique_module_name(uuid, package_name))
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
    key = unique_module_name(uuid, package_name)
    return get_dep_from_loaded_modules(key)
end

# Basically Base.names but ignores names that are not defined in the module and allows to restrict to only exported names (since 1.11 added also public names as out of names). It also defaults `all` and `imported` to true (to be more precise, to the opposite of `only_exported`)
function _names(m::Module; only_exported=false, all=!only_exported, imported=!only_exported, kwargs...)
    mod_names = names(m; all, imported, kwargs...)
    filter!(mod_names) do nm
        isdefined(m, nm) || return false
        only_exported && return Base.isexported(m, nm)
        return true
    end
end

# Check whether the FromPackageController has reached the target file while loading the module
target_reached(p::FromPackageController) = (@nospecialize; p.target_location !== nothing)