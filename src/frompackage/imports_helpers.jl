mutable struct ImportAs
    original::Vector{Symbol}
    as::Union{Symbol,Nothing}
end
ImportAs(nm::Symbol) = ImportAs([nm], nothing)
function ImportAs(original::Vector)
    @assert all(nm -> isa(nm, Symbol), original) "Only vectors containing just symbols are valid inputs to the ImportAs constructor."
    ImportAs(Symbol.(original), nothing)
end
function ImportAs(ex::Expr)
    if ex.head === :.
        ImportAs(ex.args)
    elseif ex.head === :as
        as = last(ex.args)
        original = first(ex.args).args
        ImportAs(original, as)
    else
        error("The provided expression is not valid for constructing ImportAs.\nOnly `:.` and `:as` are supported as expression head.")
    end
end

function reconstruct_import_statement(ia::ImportAs)
    ex = Expr(:., ia.original...)
    if ia.as !== nothing
        ex = Expr(:as, ex, ia.as)
    end
    return ex
end

abstract type ImportData end

mutable struct ModuleWithNames <: ImportData
    head::Symbol
    modname::ImportAs
    imported::Vector{ImportAs}
end
function ModuleWithNames(ex::Expr)
    args = ex.args
    is_valid = Meta.isexpr(ex, (:using, :import)) && length(args) == 1 && Meta.isexpr(first(args), :(:))
    @assert is_valid "Only import/using expression with an explicit list of imported names are valid inputs to the ModuleWithNames constructor."
    # We extract the :(:) expression
    args = first(args).args
    # The first arg is the module
    modname = ImportAs(first(args))
    # The remaining args are the imported names
    imported = map(ImportAs, args[2:end])
    ModuleWithNames(ex.head, modname, imported)
end
function reconstruct_import_statement(mwn::ModuleWithNames; head=mwn.head)
    inner_expr = Expr(:(:), reconstruct_import_statement(mwn.modname), map(reconstruct_import_statement, mwn.imported)...)
    Expr(head, inner_expr)
end

mutable struct JustModules <: ImportData
    head::Symbol
    modnames::Vector{ImportAs}
end
function JustModules(ex::Expr)
    args = ex.args
    is_valid = Meta.isexpr(ex, (:using, :import)) && all(x -> Meta.isexpr(x, (:., :as)), args)
    @assert is_valid "Only import/using expression with multiple imported/used modules are valid inputs to the JustModules constructor."
    JustModules(ex.head, map(ImportAs, args))
end
function reconstruct_import_statement(jm::JustModules)
    Expr(jm.head, map(reconstruct_import_statement, jm.modnames)...)
end
# This is used to reconstruct a mwn with empty import list
function JustModules(mwn::ModuleWithNames)
    @assert isempty(mwn.imported) "You can only construct a JustModules object with a ModuleWithNames object with an empty import list."
    JustModules(mwn.head, [mwn.modname])
end


function extract_import_data(ex::Expr)
    @assert Meta.isexpr(ex, (:using, :import)) "You can only use import or using expression as input to the `extract_import_data` function."
    id = if Meta.isexpr(first(ex.args), :(:))
        ModuleWithNames(ex)
    else
        JustModules(ex)
    end
    return id
end

is_catchall(ia::ImportAs) = length(ia.original) == 1 && first(ia.original) === :*
is_catchall(v::Vector{ImportAs}) = length(v) === 1 && is_catchall(first(v))
is_catchall(mwn::ModuleWithNames) = any(is_catchall, (mwn.imported, mwn.modname))

iterate_imports(mwn::ModuleWithNames) = [mwn]
function iterate_imports(jm::JustModules)
    f(modname::ImportAs) = ModuleWithNames(jm.head, modname, Symbol[])
    map(f, jm.modnames)
end
iterate_imports(ex::Expr) = extract_import_data(ex) |> iterate_imports

# This function will add the explicitly imported names to the set of imported names
function add_imported_names!(p::FromPackageController, mwn::ModuleWithNames)
    @nospecialize
    foreach(mwn.imported) do ia
        nm = something(ia.as, last(ia.original))
        push!(p.imported_names, nm)
    end
end

# This function will make all root module imports inside of a package code be relative, as it seems that since 1.12 things don't work well with plain root module imports (See issue #67). It returns a potentially modified expression if it contained the root module as first element of the import path
function make_rootmodule_imports_relative!(ia::ImportAs, rootname::Symbol, submodule_level::Int)
    if first(ia.original) === rootname
        for _ in 0:submodule_level # We start from 0 as we always have to add 1 additional .
            pushfirst!(ia.original, :.)
        end
    end
    return ia
end
function make_rootmodule_imports_relative!(mwn::ModuleWithNames, rootname::Symbol, submodule_level::Int)
    make_rootmodule_imports_relative!(mwn.modname, rootname, submodule_level)
    return reconstruct_import_statement(mwn)
end
function make_rootmodule_imports_relative!(jm::JustModules, rootname::Symbol, submodule_level::Int)
    foreach(jm.modnames) do ia
        make_rootmodule_imports_relative!(ia, rootname, submodule_level)
    end
    return reconstruct_import_statement(jm)
end
# This is the actual outer function being called
function make_rootmodule_imports_relative(ex::Expr, p::FromPackageController{name}) where {name}
    @nospecialize
    sm_level = submodule_level(p)
    sm_level > 0 || return ex
    return make_rootmodule_imports_relative!(extract_import_data(ex), name, sm_level)
end

# This function will update the modname_path to make always start from Main. The inner flag specifies whether the provided import expression was found inside the package/extension code, or inside the code given as input to the macro
function process_modpath!(mwn::ModuleWithNames, p::FromPackageController{name}; inner::Bool=false) where {name}
    @nospecialize
    inner && process_inner_imports!(mwn, p)
    modname = mwn.modname
    path = modname.original
    root_name = popfirst!(path)
    if root_name in (:ParentModule, :<)
        @assert !isnothing(p.target_module) "You can't import from the Parent Module when the calling file is not a file `included` in the target package."
        m = p.target_module
        prepend!(path, _fullname(m))
    elseif root_name in (:PackageModule, :^, name)
        m = get_temp_module(p)
        prepend!(path, _fullname(m))
    elseif root_name === :>
        # Deps import
        @assert !is_catchall(mwn) "You can't use the catch-all expression when importing from dependencies"
        modname = first(path)
        m = if modname in (:Base, :Core)
            modname == :Base ? Base : Core
        else
            get_dep_from_loaded_modules(p, first(path); allow_manifest=true)
        end
        # Replace the deps name with the uuid_name symbol from loaded modules
        path[1] = unique_module_name(m)
        # Add the loaded module path
        prepend!(path, fullname(get_loaded_modules_mod()))
    elseif root_name === :*
        # Here we simply substitute the path of the current module, and :* to the imported names
        imported = mwn.imported
        @assert isempty(imported) "You can't use the catchall import statement `import *` with explicitly imported names"
        m = @something p.target_module get_temp_module(p)
        prepend!(path, _fullname(m))
        push!(mwn.imported, ImportAs(:*))
    elseif root_name === :.
        @assert inner || !isnothing(p.target_module) "You can't use relative imports when the calling file is not a file `included` in the target package."
        starting_module = @something p.target_module get_temp_module(p)
        m = extract_nested_module(starting_module, path; first_dot_skipped=true)
        modname.original = _fullname(m) |> collect
    else
        error("The provided import statement is not a valid input for the @frompackage macro.\nIf you want to import from a dependency of the target package, prepend `>.` in front of the package name, e.g. `using >.BenchmarkTools`.")
    end
    return
end

# This function will modify inner imports (i.e. import statements that have been collected while evaluating the package code, rather than ones seen as input to the @frompackage macro) so that they point to the correct module (mostly prepending :> to dependencies)
function process_inner_imports!(mwn::ModuleWithNames, ::FromPackageController{name}) where {name}
    @nospecialize
    modname_path = mwn.modname.original
    root_name = modname_path |> first
    if root_name ∉ (:., name)
        # If not a relative path and not targeting directly the package module, assume it's a dependency
        pushfirst!(modname_path, :>)
    end
    return
end

# This function will include all the names of the module as explicit imports in the import statement. It will modify the provided mwn in place and unless usings are excluded, it will also add all the using statements being parsed while evaluating the target module
function catchall_import_expression!(mwn::ModuleWithNames, p::FromPackageController, m::Module; exclude_usings::Bool)
    @nospecialize
    mwn.imported = invokelatest(filterednames, p, m) .|> ImportAs
    ex = reconstruct_import_statement(mwn; head=:import)
    # If we exclude using, we simply return the expression
    exclude_usings && return ex
    # Otherwise, we add the using statements we collected for this module
    block = quote
        $ex
    end
    # We extract the using expression that were encountered while loading the specified module
    using_expressions = get(Set{Expr}, p.using_expressions, m)
    old_current = p.current_module
    try
        p.current_module = m
        for ex in using_expressions
            new_ex = process_import_statement(p, ex; exclude_usings, inner=true)
            push!(block.args, new_ex)
        end
    finally
        p.current_module = old_current
    end
    return block
end

# This will modify the import statements provided as input to `@frompackage` by updating the modname_path and eventually extracting exported names from the module and explicitly import them. It will also transform each statement into using explicit imported names (even for simple imports) are import/using without explicit names are currently somehow broken in Pluto if not handled by the PkgManager
function complete_imported_names!(mwn::ModuleWithNames, p::FromPackageController; exclude_usings::Bool=false, inside_extension::Bool=false, inner::Bool=inside_extension)::Expr
    catchall = is_catchall(mwn)
    inner && catchall && error("You can't use the catchall import statement `import *` inside package code")
    if !isempty(mwn.imported) && !catchall
        # If we already have an explicit list of imports, we do not modify and simply return the corresponding expression
        # Here we do not modify the list of explicitily imported names, as it's better to get an error if you explicitly import something that was already defined in the notebook
        return reconstruct_import_statement(mwn; head=:import)
    end
    nested_path = mwn.modname.original
    m = extract_nested_module(Main, nested_path)
    if catchall
        # We extract all the names, potentially include usings encountered
        return catchall_import_expression!(mwn, p, m; exclude_usings)
    else
        if mwn.head === :import
            # We explicitly import the module itself
            modname = mwn.modname
            import_as = ImportAs(nameof(m))
            as = modname.as
            if as !== nothing
                # We remove the `as` from the module name expression
                modname.as = nothing
                # We add it to the imported name
                import_as.as = as
            end
            push!(mwn.imported, import_as)
        else
            # We export the names exported by the module
            mwn.imported = _names(m; only_exported=true) .|> ImportAs
        end
    end
    if !inside_extension
        # We have to filter the imported names to exclude ones that are already defined in the caller
        filter_func = filterednames_filter_func(p)
        filter!(mwn.imported) do import_as
            as = import_as.as
            imported_name = something(as, last(import_as.original))
            return filter_func(imported_name)
        end
    end
    # The list of imported names should be empty only when inner=false
    ex = isempty(mwn.imported) ? quote
        QuoteNode(:_Removed_Import_Statement)
    end : reconstruct_import_statement(mwn; head=:import)
    return ex
end

# This function will generate an importa statement by expanding the modname_path to the correct path based on the provided `starting_module`. It will also expand imported names if a catchall expression is found
function process_import_statement(p::FromPackageController, ex::Expr; exclude_usings::Bool=false, inside_extension::Bool=false, inner::Bool=inside_extension)
    @nospecialize
    # Extract the import statement data
    block = quote end
    for isd in iterate_imports(ex)
        process_modpath!(isd, p; inner)
        ex = complete_imported_names!(isd, p; exclude_usings, inside_extension, inner)
        # We add the imported names to the controller if not evaluating extension code
        inside_extension || add_imported_names!(p, isd)
        push!(block.args, ex)
    end
    return block
end