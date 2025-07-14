function maybe_call_init(m::Module)
    invokelatest() do 
        # Check if it exists
        isdefined(m, :__init__) || return nothing
        # Check if it's owned by this module
        which(m, :__init__) === m || return nothing
        f = getproperty(m, :__init__)
        # Verify that is a function
        f isa Function || return nothing
        Core.eval(m, :(__init__()))
    end
    return nothing
end

## ExprSplitter stuff ##
# This function separate the LNN and expression that are contained in the :block expressions returned by iteration with ExprSplitter. It is based on the assumption that each `ex` obtained while iterating with `ExprSplitter` are :block expressions with exactly two arguments, the first being a LNN and the second being the relevant expression
function destructure_expr(ex::Expr)
    @assert Meta.isexpr(ex, :block) && length(ex.args) === 2 "The expression does not seem to be coming out of iterating an `ExprSplitter` object"
    lnn, ex = ex.args
end

# This function will use ExprSplitter from JuliaInterpreter to cycle through expression and execute them one by one
function split_and_execute!(p::FromPackageController, ast::Expr, f=p.custom_walk)
    @nospecialize
    top_mod = prev_mod = p.current_module
    for (mod, ex) in ExprSplitter(top_mod, ast)
        # Update the current module
        p.current_module = mod
        process_exprsplitter_item!(p, ex, f)
        if prev_mod !== top_mod && mod !== prev_mod
            maybe_call_init(prev_mod) # We try calling init in the last module after switching
        end
        prev_mod = mod
    end
end

function process_exprsplitter_item!(p::AbstractEvalController, ex, process_func::Function=p.custom_walk)
    # We update the current line under evaluation
    lnn, ex = destructure_expr(ex)
    p.current_line = lnn
    # @info "Original" ex
    new_ex = process_func(ex)
    # @info "Change" new_ex
    if !isa(new_ex, RemoveThisExpr) && !target_reached(p)
        Core.eval(p.current_module, new_ex)
    end
    return
end

## Misc ##
# Returns the name (as Symbol) of the variable where the controller will be stored within the generated module
variable_name(p::FromPackageController) = (@nospecialize; :_frompackage_controller_)

# This is a callback to add any new loaded package to the Main._FromPackage_TempModule_._LoadedModules_ module
function mirror_package_callback(modkey::Base.PkgId)
    target = get_loaded_modules_mod()
    name = Symbol(modkey)
    m = Base.root_module(modkey)
    Core.eval(target, :(const $name = $m))
    if isassigned(CURRENT_FROMPACKAGE_CONTROLLER)
        try_load_extensions!(CURRENT_FROMPACKAGE_CONTROLLER[])
    end
    return
end

# This will try to see if the extensions of the target package can be loaded
function try_load_extensions!(p::FromPackageController)
    @nospecialize
    loaded_modules = get_loaded_modules_mod()
    (; extensions, deps, weakdeps) = p.project
    package_name = p.project.name
    (; options) = p
    for (name, triggers) in extensions
        name in p.loaded_extensions && continue
        nactive = 0
        for trigger_name in triggers
            trigger_uuid = weakdeps[trigger_name]
            unique_name = unique_module_name(trigger_uuid, trigger_name)
            is_loaded = isdefined(loaded_modules, unique_name)
            nactive += is_loaded
        end
        if nactive === length(triggers)
            options.verbose && @info "Loading code of extension $name for package $package_name"
            entry_path = find_ext_path(p.project, name)
            # Set the module to the package module parent, which is a temp module in the Pluto workspace
            p.current_module = get_temp_module()
            try
                # We have to recreate the module of the extension, as ExprSplitter will not recreate it if it's already there and it will still have inside a reference to an old version of the package of interest. Not sure if this was a non-found bug before or it's only a problem with either julia 1.12 or JuliaIntepreterv0.10
                Core.eval(p.current_module, :(module $(name |> Symbol) end))
                # Load the extension module inside the package module
                process_include_expr!(p, entry_path)
                push!(p.loaded_extensions, name)
            finally
                p.current_module = get_temp_module(p)
            end
        end
    end
end

### Load Module ###
function load_direct_deps(p::FromPackageController)
    @nospecialize
    deps_mod = get_direct_deps_mod()
    for (name, uuid) in p.project.deps
        name_uuid = unique_module_name(uuid, name)
        isdefined(deps_mod, name_uuid) && continue
        Core.eval(deps_mod, :(import $(Symbol(name)) as $name_uuid))
    end
end

function load_module!(p::FromPackageController{name}; reset=true) where {name}
    @nospecialize
    # Add to LOAD_PATH if not present
    update_loadpath(p)
    # Reinitialize the current module to the base one
    p.current_module = get_temp_module()
    if reset
        # This reset is currently always true, it will be relevant mostly when trying to incorporate Revise
        # We create the module holding the target package inside the calling pluto workspace. This is done to have Pluto automatically remove any binding the the previous module upon re-run of the cell containing the macro. Not doing so will cause some very weird inconsistencies as some functions will still refer to the previous version of the module which should not exist anymore from within the notebook
        temp_mod = Core.eval(p.caller_module, :(module $(gensym(:TempModule)) end))
        # We create our actal module of interest inside this temp module
        m = Core.eval(temp_mod, :(module $name end))
        # We mirror the generated module inside the temp_module module, so we can alwyas access it without having to know the current workspace
        Core.eval(get_temp_module(), :($name = $m))
        p.options.rootmodule && register_target_as_root(p)
        # We put the controller inside the module
        Core.eval(m, :($(variable_name(p)) = $p))
    end
    # We put the controller in the Ref
    CURRENT_FROMPACKAGE_CONTROLLER[] = p
    load_direct_deps(p) # We load the direct dependencies
    Core.eval(p.current_module, process_include_expr!(p, p.entry_point))
    # Maybe call init
    maybe_call_init(get_temp_module(p))
    # We populate the loaded modules
    (; verbose) = p.options
    populate_loaded_modules(p ;verbose)
    # Try loading extensions
    try_load_extensions!(p)
    # We increment the number of loads
    LOADED_TIMES[name] = get!(LOADED_TIMES, name, 0) + 1
    p.nloads = LOADED_TIMES[name]
    return p
end

function get_filepath(path::AbstractString, caller_file::Union{Nothing, AbstractString})
    @nospecialize
    base_dir = if isnothing(caller_file)
        pwd()
    else
        dirname(caller_file)
    end
    return abspath(base_dir, path)
end

# This will process include statements by extracting the ast and evaluating the extracted code using ExprSplitter and applying the custom_walk! function to each expression.
function process_include_expr!(p::FromPackageController, path::AbstractString, caller_path = nothing)
    @nospecialize
    process_include_expr!(p, identity, path, caller_path)
end
function process_include_expr!(p::FromPackageController, mapexpr::Function, path::AbstractString, caller_path = nothing)
    @nospecialize
    filepath = get_filepath(path, caller_path)
    # @info "Custom Including $(basename(filepath))"
    if issamepath(p.target_path, filepath)
        p.target_location = p.current_line
        p.target_module = p.current_module
        return nothing
    end
    _f = p.custom_walk
    f = if mapexpr === identity
        _f
    else
        # We compose
        _f ∘ mapexpr
    end
    ast = extract_file_ast(filepath)
    split_and_execute!(p, ast, f)
    return nothing
end

# This function will register the module of the target package as a root module.
# This relies on Base internals (and even the C API) so it's disable by default but will allow make the loaded module behave more like if we simply did `using TargetPackage` without the macro
function register_target_as_root(p::FromPackageController)
    @nospecialize
    (;name, uuid) = p.project
    m = get_temp_module(p)
    id = Base.PkgId(uuid, name)
    (; verbose) = p.options
    @lock Base.require_lock begin
        # Set the uuid of this module with the C API. This is required to get the correct UUID just from the module within `register_root_module`
        ccall(:jl_set_module_uuid, Cvoid, (Any, NTuple{2, UInt64}), m, uuid)
        @static if VERSION >= v"1.11.99" # We need to also set the module as parent of itself in 1.12
            ccall(:jl_set_module_parent, Cvoid, (Any, Any), m, m) 
        end
        # Register this module as root
        logger = verbose ? Logging.current_logger() : Logging.NullLogger()
        Logging.with_logger(logger) do
            Base.register_root_module(m)
        end
        # Set the path of the module to the actual package
        Base.set_pkgorigin_version_path(id, p.entry_point)
    end
end