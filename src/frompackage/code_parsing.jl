function extract_file_ast(filename)
    code = read(filename, String)
    ast = Meta.parseall(code; filename)
    @assert Meta.isexpr(ast, :toplevel)
    ast
end

## custom_walk! ##
# This function is inspired by MacroTools.walk (and prewalk/postwalk). It allows to specify custom way of parsing the expressions of an included file/package. The first method is used to process the include statement as the `modexpr` in the two-argument `include` method (i.e. `include(modexpr, file)`)
function custom_walk!(p::AbstractEvalController)
    @nospecialize
    function modexpr(ex)
        out = custom_walk!(p, ex)
        return out
    end
    return modexpr
end
function custom_walk!(p::AbstractEvalController, ex)
    @nospecialize
    if p.target_reached
        return RemoveThisExpr()
    else
        # We pass through all non Expr, and process the Exprs
        new_ex = ex isa Expr ? custom_walk!(p, ex, Val{ex.head}()) : ex
        return new_ex
    end
end
custom_walk!(p::AbstractEvalController, ex::Expr, ::Val) = (@nospecialize; Expr(ex.head, map(p.custom_walk, ex.args)...))

# This process each argument of the block, and then fitlers out elements which are not expressions and clean up eventual LineNumberNodes hanging from removed expressions
function custom_walk!(p::AbstractEvalController, ex::Expr, ::Val{:block})
    @nospecialize
    f = p.custom_walk
    args = map(f, ex.args)
    # We now go in reverse args order, and remove all the RemoveThisExpr (and corresponding LineNumberNodes)
    valids = trues(length(args))
    next_arg = RemoveThisExpr()
    for i in reverse(eachindex(args))
        this_arg = args[i]
        valids[i] = valid_blockarg(this_arg, next_arg)
        next_arg = this_arg
    end
    any(valids) || return RemoveThisExpr()
    return Expr(:block, args[valids]...)
end

# This will add calls below the `using` to track imported names
function custom_walk!(p::AbstractEvalController, ex::Expr, ::Val{:using})
    @nospecialize
    new_ex = if inside_extension(p)
        # We are inside an extension code, we do not need to track usings
        handle_extensions_imports(p, ex)
    else # Here we want to track the using expressions
        # We add the expression to the set for the current module
        expr_set = get!(Set{Expr}, p.using_expressions, p.current_module)
        push!(expr_set, ex)
        # We just leave the expression unchanged
        ex
    end
    return new_ex
end

function custom_walk!(p::AbstractEvalController, ex::Expr, ::Val{:import})
    @nospecialize
    return handle_extensions_imports(p, ex)
end

# We need to do this because otherwise we mess with struct definitions
function custom_walk!(p::AbstractEvalController, ex::Expr, ::Val{:struct})
    @nospecialize
    return ex
end

# This handles include calls, by adding p.custom_walk as the modexpr
function custom_walk!(p::AbstractEvalController, ex::Expr, ::Val{:call})
    @nospecialize
    f = p.custom_walk
    # We just process this expression if it's not an `include` call
    first(ex.args) === :include || return Expr(:call, map(f, ex.args)...)
    new_ex = :($process_include_expr!($p))
    append!(new_ex.args, ex.args[2:end])
    return new_ex
end

# This handles include calls, by adding p.custom_walk as the modexpr
function custom_walk!(p::AbstractEvalController, ex::Expr, ::Val{:macrocall})
    @nospecialize
    # We just process this expression if it's not an `include` call
    first(ex.args) in (Symbol("@frompackage"), Symbol("@fromparent")) || return ex
    # This will only process and returns the import block of the macro. We process it to exclude invalid statements outside pluto and eventualy track usings
    new_ex = process_outside_pluto(p, ex.args[end])
    return new_ex
end

## custom_walk! Helpers ##
function valid_blockarg(this_arg, next_arg)
    @nospecialize
    if this_arg isa RemoveThisExpr
        return false
    elseif this_arg isa LineNumberNode
        return !isa(next_arg, LineNumberNode) && !isa(next_arg, RemoveThisExpr)
    else
        return true
    end
end

function get_filepath(p::FromPackageController, path::AbstractString)
    @nospecialize
    (; current_line) = p
    base_dir = if isnothing(current_line)
        pwd()
    else
        p.current_line.file |> string |> dirname
    end
    return abspath(base_dir, path)
end

function process_include_expr!(p::FromPackageController, path::AbstractString)
    @nospecialize
    process_include_expr!(p, identity, path)
end
function process_include_expr!(p::FromPackageController, modexpr::Function, path::AbstractString)
    @nospecialize
    filepath = get_filepath(p, path)
    # @info "Custom Including $(basename(filepath))"
    if issamepath(p.target_path, filepath)
        p.target_reached = true
        p.target_location = p.current_line
        p.target_module = p.current_module
        return nothing
    end
    _f = p.custom_walk
    f = if modexpr isa ComposedFunction{typeof(_f),<:Any}
        modexpr # We just use that directly
    else
        # We compose
        _f ∘ modexpr
    end
    # @info "Custom Including $(basename(filepath))"
    ast = extract_file_ast(filepath)
    split_and_execute!(p, ast, f)
    return nothing
end

# This function will eventually modify using/import expressions inside extensions modules. Outside of extension modules, it will simply return the provided expression
function handle_extensions_imports(p::FromPackageController, ex::Expr)
    @nospecialize
    @assert Meta.isexpr(ex, (:using, :import)) "You can only call this function with using or import expressions as second argument"
    return inside_extension(p) ? process_import_statement(p, ex; inside_extension = true) : ex
end