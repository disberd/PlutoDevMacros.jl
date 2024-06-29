function extract_file_ast(filename)
    code = read(filename, String)
    ast = Meta.parseall(code; filename)
    @assert Meta.isexpr(ast, :toplevel)
    ast
end


## custom_walk! ##
# This function is inspired by MacroTools.walk (and prewalk/postwalk). It allows to specify custom way of parsing the expressions of an included file/package. The first method is used to process the include statement as the `mapexpr` in the two-argument `include` method (i.e. `include(mapexpr, file)`)
function custom_walk!(p::AbstractEvalController)
    @nospecialize
    function mapexpr(ex)
        out = custom_walk!(p, ex)
        return out
    end
    return mapexpr
end
function custom_walk!(p::AbstractEvalController, ex)
    @nospecialize
    if p.target_reached
        return RemoveThisExpr()
    else
        ex isa Expr || return ex
        if isdef(ex)
            ex = longdef(ex)
        end
        # We pass through all non Expr, and process the Exprs
        return custom_walk!(p, ex, Val{ex.head}())
    end
end
# By defaults, all expression which are not explicitly customized simply return the input expression
function custom_walk!(p::AbstractEvalController, ex::Expr, ::Val)
    @nospecialize
    return ex
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

# For function and macro calls, we want to be able to specialize on the name of the function being called
function custom_walk!(p::AbstractEvalController, ex::Expr, v::Union{Val{:call}, Val{:macrocall}})
    @nospecialize
    called_name = first(ex.args) |> Symbol
    return custom_walk!(p, ex, v, Val{called_name}())
end
function custom_walk!(::AbstractEvalController, ex::Expr, ::Union{Val{:call}, Val{:macrocall}}, ::Val)
    @nospecialize
    return ex
end

# This handles include calls, by adding p.custom_walk as the mapexpr
function custom_walk!(p::AbstractEvalController, ex::Expr, ::Val{:call}, ::Val{:include})
    @nospecialize
    (; current_line) = p
    new_ex = :($process_include_expr!($p))
    append!(new_ex.args, ex.args[2:end])
    push!(new_ex.args, String(current_line.file))
    return new_ex
end

# This handles include calls, by adding p.custom_walk as the mapexpr
function custom_walk!(p::AbstractEvalController, ex::Expr, ::Val{:macrocall}, ::Union{
    Val{Symbol("@frompackage")},
    Val{Symbol("@fromparent")},
})
    @nospecialize
    # This will only process and returns the import block of the macro. We process it to exclude invalid statements outside pluto and eventualy track usings
    new_ex = process_outside_pluto(p, ex.args[end])
    return new_ex
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

function process_include_expr!(p::FromPackageController, path::AbstractString, caller_path = nothing)
    @nospecialize
    process_include_expr!(p, identity, path, caller_path)
end
function process_include_expr!(p::FromPackageController, mapexpr::Function, path::AbstractString, caller_path = nothing)
    @nospecialize
    filepath = get_filepath(path, caller_path)
    # @info "Custom Including $(basename(filepath))"
    if issamepath(p.target_path, filepath)
        p.target_reached = true
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

# This function will eventually modify using/import expressions inside extensions modules. Outside of extension modules, it will simply return the provided expression
function handle_extensions_imports(p::FromPackageController, ex::Expr)
    @nospecialize
    @assert Meta.isexpr(ex, (:using, :import)) "You can only call this function with using or import expressions as second argument"
    return inside_extension(p) ? process_import_statement(p, ex; inside_extension = true) : ex
end