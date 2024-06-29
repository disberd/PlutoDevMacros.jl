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
    return process_import_statement(p, ex; exclude_usings, inner=false)
end

function excluded_names(p::FromPackageController)
    @nospecialize
    excluded = (:eval, :include, variable_name(p), Symbol("@bind"), :PLUTO_PROJECT_TOML_CONTENTS, :PLUTO_MANIFEST_TOML_CONTENTS, :__init__, PREV_CONTROLLER_NAME)
    return excluded
end

function filterednames_filter_func(p::FromPackageController)
    @nospecialize
    previous = if isdefined(p.caller_module, PREV_CONTROLLER_NAME)
        prev_p = getproperty(p.caller_module, PREV_CONTROLLER_NAME)::FromPackageController
        prev_p.imported_names
    else
        Set{Symbol}()
    end
    caller_module = p.caller_module
    f(s)::Bool =
        let excluded = excluded_names(p), previous = previous, caller_module = caller_module
            Base.isgensym(s) && return false
            s in excluded && return false
            isdefined(caller_module, s) && return s in previous
            return true
        end
    return f
end

## Similar to `_names` but allows to exclude names by applying an additional filtering function to the output of `_names`. The default filtering function always returns true
function filterednames(m::Module, filter_func = _ -> true; kwargs...)
    mod_names = _names(m; kwargs...)
    filter!(filter_func, mod_names)
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

function process_outside_pluto(p::FromPackageController, ex::Expr)
    @nospecialize
    # Remove `@exclude_using` if present
    should_exclude_using_names!(ex)
    args = extract_input_args(ex)
    block = Expr(:block)
    for arg in args
        arg isa Expr || continue
        for mwn in iterate_imports(arg)
            # We extract the head to keep it
            modname_path = mwn.modname.original
            root_name = first(modname_path)
            # We only support relative and deps imports
            if root_name === :.
                # Relative import, we just make sure it's not a catch all
                is_catchall(mwn) && continue
            elseif root_name === :>
                @assert !is_catchall(mwn) "You can't use the catch-all expression when importing from dependencies"
                # Deps import, we have to make sure we are only importing direct dependencies
                # We remove the first symbol as its :>
                popfirst!(modname_path)
                depname = first(modname_path)
                String(depname) in keys(p.project.deps) || continue
            else
                continue
            end
            import_data = isempty(mwn.imported) ? JustModules(mwn) : mwn
            ex = reconstruct_import_statement(import_data)
            push!(block.args, ex)
        end
    end
    return block
end