function detect_custom_macro!(ex, macro_name::Symbol)
	block = if Meta.isexpr(ex, :block)
		ex
	else
        # We don't support custom macros for single statements
        return nothing
	end
    idx = 0
	for i ∈ eachindex(block.args)
		arg = block.args[i]	
		if Meta.isexpr(arg, :macrocall) && arg.args[1] === macro_name
			idx = i
			break
		end
	end
	idx != 0 || return nothing
    # We extract the arg and delete it from the expr
    arg = block.args[idx]
    deleteat!(block.args, idx)
    return arg
end

# This function checks for settings and eventually stores them in the package_dict
function process_settings!(ex, dict)
    settings_arg = detect_custom_macro!(ex, Symbol("@settings"))
    !isnothing(settings_arg) || return ex
    parse_settings(settings_arg, dict)
    return ex
end

function parse_settings(ex, dict)
    maybe_block_arg = ex.args[3]
    setting_args = if Meta.isexpr(maybe_block_arg, :block)
        maybe_block_arg.args
    else
        ex.args[3:end]
    end
    for arg in setting_args
        arg isa LineNumberNode && continue
        @assert Meta.isexpr(arg, :(=)) && length(arg.args) == 2 "Only `var = value` statements are allowed within the `@settings` block"
        custom_settings = get!(Dict{Symbol, Any}, dict, "Custom Settings")
        k,v = arg.args
        @assert !(v isa Expr) "Only primitive values are allowed as values in the `@settings` block"
        name = Settings.setting_name(k)
        custom_settings[name] = v
    end
end

# New stuff

function should_exclude_using_names!(ex::Expr)
    Meta.isexpr(ex, :macrocall) || return false
    macro_name = ex.args[1]
    exclude_name = Symbol("@exclude_using")
    @assert macro_name === exclude_name "The provided input expression is not supported.\nExpressions should be only import statements, at most prepended by the `@exclude_using` decorator."
    # If we reach here, we have the include usings. We just extract the underlying expression
    actual_ex = ex.args[end]
    ex.head = actual_ex.head
    ex.args = actual_ex.args
    return true
end

# This function will parse the input expression and eventually
function process_input_expr(p::FromPackageController, ex)
    # Eventually remove `@exclude_using`
    exclude_usings = should_exclude_using_names!(ex)
    modname_first = get_modpath_root(ex)
    process_func = if modname_first in (:ParentModule, :<, :.)
        RelativeImport
    elseif modname_first in (:PackageModule, :^)
        PackageImport
    elseif modname_first === :>
        DepsImport
    elseif modname_first === :*
        CatchAllImport
    end
    new_ex = process_func(p, ex; exclude_usings)
    return new_ex
end


# This will construct the catchall import expression for the module `m`
function catchall_import_expression(p::FromPackageController, m::Module; exclude_usings::Bool=false)
    @nospecialize
    modname_path = fullname(m) |> collect
    imported_names = filterednames(p, m)
    id = ImportStatementData(modname_path, imported_names)
    # We use `import` explicitly as Pluto does not deal well with `using` not directly handled by the PkgManager
    ex = reconstruct_import_statement(:import, id)
    # We simplty return this if we exclude usings
    exclude_usings && return ex
    # Otherwise, we have to add
    block = quote
        $ex
    end
    # We extract the using expression that were encountered while loading the specified module
    using_expressions = get(Set{Expr}, p.using_expressions, m)
    for ex in using_expressions
        for out in extract_import_names(ex)
            ex = process_input_statement(p, out; is_import = false, allow_manifest = false, pop_first = false)
            push!(block.args, ex)
        end
    end
    return block
end

# This function will generate an importa statement by expanding the modname_path to the correct path based on the provided `starting_module`. It will also expand imported names if a catchall expression is found
function generate_import_statement(p::FromPackageController, ex::Expr, starting_module::Module; pop_first::Bool=true, exclude_usings::Bool=false)
    @nospecialize
    # We extract the arguments of the statement
    (; modname_path, imported_names) = id = extract_input_import_names(ex)
    # We remove the first dot as it's a relative import with potentially invalid first name
    pop_first && popfirst!(modname_path)
    import_module = extract_nested_module(starting_module, modname_path; first_dot_skipped=true) # We already skipped the first dot
    catchall = length(imported_names) === 1 && first(imported_names) === :*
    if catchall
        catchall_import_expression(p, import_module; exclude_usings)
    else
        # We have to update the modname_path
        id.modname_path = fullname(import_module) |> collect
        return reconstruct_import_statement(ex.head, id)
    end
end

function RelativeImport(p::FromPackageController, ex::Expr; exclude_usings::Bool)
    @nospecialize
    @assert !isnothing(p.target_module) "You can not use relative imports while calling the macro from a notebook that is not included in the package"
    new_ex = generate_import_statement(p, ex, p.target_module; pop_first=true, exclude_usings)
    return new_ex
end

function PackageImport(p::FromPackageController, ex::Expr; exclude_usings::Bool)
    @nospecialize
    new_ex = generate_import_statement(p, ex, get_temp_module(p); pop_first=true, exclude_usings)
    return new_ex
end

function CatchAllImport(p::FromPackageController, ex::Expr; exclude_usings::Bool)
    @nospecialize
    m = isnothing(p.target_module) ? get_temp_module(p) : p.target_module
    new_ex = catchall_import_expression(p, m; exclude_usings)
    return new_ex
end

# This will modify the input import statements by updating the modname_path and eventually extracting exported names from the module and explicitly import them. It will also always return an `import` statement because `using` are currently somehow broken in Pluto if not handled by the PkgManager
function process_input_statement(p::FromPackageController, out::ImportStatementData; pop_first::Bool = false, allow_manifest = false, is_import::Bool = true)
    (; modname_path, imported_names) = out
    pop_first && popfirst!(modname_path)
    root_name = first(modname_path)
    target_module, new_modname = if root_name === :.
        _m = extract_nested_module(m, modname_path)
        _m, fullname(_m) |> collect
    else
        _m = get_dep_from_loaded_modules(p, root_name; allow_manifest)
        new_modname = Symbol[
            :Main, TEMP_MODULE_NAME, :_LoadedModules_,
            Symbol(Base.PkgId(_m)),
            modname_path[2:end]...
        ]
        _m, new_modname
    end
    ex = if isempty(imported_names)
        # We are just plain using, so we have to explicitly extract the exported names
        nms = if is_import 
            [nameof(target_module)]
        else 
            filter(names(target_module)) do name
                Base.isexported(target_module, name)
            end
        end
        reconstruct_import_statement(:import, ImportStatementData(new_modname, nms))
    else
        # We have an explicit list of names, so we simply modify the using to import
        reconstruct_import_statement(:import, ImportStatementData(new_modname, imported_names))
    end
    return ex
end

function DepsImport(p::FromPackageController, ex::Expr; exclude_usings::Bool=false)
    @nospecialize
    is_import = ex.head === :import
    id = extract_input_import_names(ex)
    new_ex = process_input_statement(p, id; pop_first=true, allow_manifest = true, is_import)
    return new_ex
end

function excluded_names(p::FromPackageController)
    @nospecialize
    excluded = (:eval, :include, variable_name(p), Symbol("@bind"), :PLUTO_PROJECT_TOML_CONTENTS, :PLUTO_MANIFEST_TOML_CONTENTS, :__init__)
    return excluded
end

function filterednames_filter_func(p::FromPackageController)
    @nospecialize
    f(s) =
        let excluded = excluded_names(p)
            Base.isgensym(s) && return false
            s in excluded && return false
            return true
        end
    return f
end

## Similar to names but allows to exclude names by applying a filtering function to the output of `names`.
function filterednames(m::Module, filter_func; all=true, imported=true)
    mod_names = names(m; all, imported)
    filter(filter_func, mod_names)
end
function filterednames(p::FromPackageController, m::Module; kwargs...)
    @nospecialize
    filter_func = filterednames_filter_func(p)
    return filterednames(m, filter_func; kwargs...)
end

# This is just for doing some check on the inputs and returning the list of expressions
function extract_input_args(ex)
    # Single import
    Meta.isexpr(ex, (:import, :using)) && return [ex]
    # Block of imports
    Meta.isexpr(ex, :block) && return ex.args
    # single statement preceded by @exclude_using
    Meta.isexpr(ex, :macrocall) && ex.args[1] === Symbol("@exclude_using") && return [ex]
    error("You have to call this macro with an import statement or a begin-end block of import statements")
end


# This is basically `extract_import_names` that enforces a single package per statement. It is used for parsing the input statements.
function extract_input_import_names(ex)
    outs = extract_import_names(ex)
    @assert length(outs) === 1 "For import statements in the input block fed to the macro, you can only deal with one module/package per statement.\nStatements of the type `using A, B` are not allowed."
    return first(outs)
end

# This function will return, for each package of the expression, two outputs which represent the modname path of the package being used, and the list of imported names
function extract_import_names(ex::Expr)
    @assert Meta.isexpr(ex, (:using, :import)) "The `extract_import_names` only accepts `using` or `import` statements as input"
    out = map(ex.args) do arg
        if Meta.isexpr(arg, :(:))
            # This is the form `using PkgName: name1, name2, ...`
            package_expr, names_expr... = arg.args
            package_path = package_expr.args .|> Symbol
            # We extract the last symbol as we can also do e.g. `import A: B.C`, which will bring C in scope
            full_names = map(ex -> ex.args |> Vector{Symbol}, names_expr)
            imported_names = map(x -> Symbol(last(x)), full_names)
            return ImportStatementData(package_path, imported_names, full_names)
        else
            package_path = arg.args .|> Symbol
            return ImportStatementData(package_path)
        end
    end
    return out
end

function reconstruct_import_statement(id::ImportStatementData)
    package_path = id.modname_path
    full_names = id.imported_fullnames
    pkg = Expr(:., package_path...)
    isempty(full_names) && return pkg
    names = map(full_names) do path
        if path isa Symbol
            Expr(:., path)
        else
            Expr(:., path...)
        end
    end
    return Expr(:(:), pkg, names...)
end
function reconstruct_import_statement(outs::Vector{ImportStatementData})
    map(outs) do id
        reconstruct_import_statement(id)
    end
end
function reconstruct_import_statement(head::Symbol, args...)
    inner = reconstruct_import_statement(args...)
    inner isa Vector || (inner = [inner])
    return Expr(head, inner...)
end