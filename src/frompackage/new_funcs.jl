const EMPTY_PIPE = Pipe()
const MODEXPR = Ref{Function}(identity)

struct RemoveThisExpr end

before_loading_hooks(::FromPackageController) = (process_skiplines!, process_settings!)

function eval_module_expr!(p::FromPackageController, ex)
    Meta.isexpr(ex, :module) || error("You provided a non module expression to the eval_module_expr function")
	mod_name = ex.args[2]
    block = ex.args[3]
	new_module = redirect_stderr(EMPTY_PIPE) do # Apparently giving devnull as stream is not enough to suprress the warning, but Pipe works
		Core.eval(parent_module, :(module $mod_name end))
	end
    parent = p.current_module
    # We change the current module to the newly created one
    p.current_module = new_module
    eval_toplevel_expr!(p, block)
    # We put back the module
    p.current_module = parent
    return nothing
end

function eval_toplevel_expr!(p::FromPackageController, ex)
    @assert Meta.isexpr(ex, :toplevel) "The provided expression is not a :toplevel one"
    _mod = p.current_module
    modexpr = MODEXPR[]
	# Taken/addapted from `include_string` in `base/loading.jl`
	loc = LineNumberNode(1, nameof(_mod))
	for ex in args
		if ex isa LineNumberNode
			loc = ex
			continue
		end
		eval_in_module!(p, modexpr(ex))
	end
	return nothing
end

function eval_in_module!(p::FromPackageController, ex)
    for (predicate, early_return) in early_return_conditions(p)
        if predicate(p, ex)
            return early_return isa Base.Callable ? early_return(p, ex) : early_return
        end
    end
    # If we reach here we did not return early
	if process_expr!(ex, loc, dict, _mod)
		Core.eval(_mod, line_and_ex) 
	end
	return nothing
end

function should_skip_line(p::FromPackageController, ex)
    lines_to_skip = p.lines_to_skip
    return should_skip(loc, lines_to_skip)
end

_any(fs...) = (p, ex) -> any(fs) do f
    f(p, ex)
end
_isa(type) = (p, ex) -> ex isa type
is_expr(head) = (p, ex) -> Meta.isexpr(ex, head)
is_include(p, ex) = Meta.isexpr(ex, :call) && first(ex.args) === :include
is_nonexpr(p, ex) = !isa(ex, Expr)

function early_return_conditions(::FromPackageController)
    (
        (is_nonexpr, nothing), # Skip non expression
        (should_skip_line, nothing), # Skip lines to skip
        (is_expr(:toplevel), eval_toplevel_expr!), # Recurse into toplevel
        (is_expr(:module), eval_module_expr!), # Recurse into module
        (is_include, eval_include_expr!), # Recurse into include
    )
end

# This cause the cycle to break if the ex is not an expr. 
skip_nonexprs(ex) = ex, isa(ex, Expr)

#### New approach stuff ####

# This function will return, for each package of the expression, two outputs which represent the modname path of the package being used, and the list of imported names
function extract_import_names(ex::Expr)
    @assert Meta.isexpr(ex, (:using, :import)) "The `extract_import_names` only accepts `using` or `import` statements as input"
    out = map(ex.args) do arg
        if Meta.isexpr(arg, :(:))
            # This is the form `using PkgName: name1, name2, ...`
            package_expr, names_expr... = arg.args
            package_path = package_expr.args .|> Symbol
            # We extract the last symbol as we can also do e.g. `import A: B.C`, which will bring C in scope
            imported_names = map(ex -> last(ex.args) |> Symbol, names_expr)
            return package_path, imported_names
        else
            package_path = arg.args .|> Symbol
            imported_names = Symbol[]
            return package_path, imported_names
        end
    end
    return out
end

# This function will add to p.using_names the names either specified by `imported_names` or exported by the module pointed at by `modname_path`. 
function add_using_names!(p::FromPackageController, modname_path::Vector{Symbol}, imported_names::Vector{Symbol})
    @nospecialize
    base_module = first(modname_path)
    key, _module = if base_module === :. # This is a local module
        m = p.current_module
        # We remove the first dot
        popfirst!(modname_path)
        while first(modname_path) === :.
            # We pop one from the modname
            popfirst!(modname_path)
            # We pop the last from the module path
            m = parentmodule(m)
        end
        # We now eventually go down in the remaining modname_path
        for name in modname_path
            m = getproperty(m, name)::Module
        end
        # We get the path of this module relative to the package root (1 and 2 in the fullname are Main._FromPackage_TempModule_)
        _, _, relative_path... = fullname(m)
        # We join the path
        collect(relative_path), m
    else
        # We are loading a normal package not located within the loaded module
        path = copy(modname_path)
        base_name = popfirst!(path)
        m = get_loaded_module(p, basename)
        for name in path
            m = getproperty(m, name)::Module
        end
        # This is another package, we just use the modname_path as it is
        modname_path, m
    end
    names_set = get!(Set{Symbol}, p.using_names, key)
    # We check whether we explicitly imported or just did `using PkgName`
    to_add = isempty(imported_names) ? names(m) : imported_names
    union!(names_set, to_add)
    return p
end

# Extracts the name (as Symbol) of the loaded package
function symbol_name(::FromPackageController{T})::Symbol where T
    @nospecialize
    return T
end
# Returns the name (as Symbol) of the variable where the controller will be stored within the generated module
variable_name(p::FromPackageController) = (@nospecialize; :_frompackage_controller_)


should_skip(p::AbstractEvalController, loc::LineNumberNode) = (@nospecialize; false)
function should_skip(p::FromPackageController, loc::LineNumberNode)
    @nospecialize
    skip = any(p.lines_to_skip) do lr
        _inrange(loc, lr)
    end
    return skip
end

# This function is inspired by MacroTools.walk (and prewalk/postwalk). It allows to specify custom way of parsing the expressions of an included file/package. The first method is used to process the include statement as the `modexpr` in the two-argument `include` method (i.e. `include(modexpr, file)`)
function custom_walk!(p::AbstractEvalController) 
    @nospecialize
    function modexpr(ex)
        out = custom_walk!(p, ex)
        return out
    end
    return modexpr
end
custom_walk!(p::AbstractEvalController, ex) = (@nospecialize; ex)
custom_walk!(p::AbstractEvalController, ex::Expr) = (@nospecialize; custom_walk!(p, ex, Val{ex.head}()))
custom_walk!(p::AbstractEvalController, ex::Expr, ::Val) = (@nospecialize; Expr(ex.head, map(custom_walk!(p), ex.args)...))

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

valparam(::Val{T}) where T = (@nospecialize; T)

# This process each argument of the block, and then fitlers out elements which are not expressions and clean up eventual LineNumberNodes hanging from removed expressions
function custom_walk!(p::AbstractEvalController, ex::Expr, val::Union{Val{:block}, Val{:toplevel}})
    @nospecialize
    f = custom_walk!(p)
    args = ex.args
    loc = LineNumberNode(1, :something)
    # We go through all the lines in order to check if any should be skipped
    for (i, arg) in enumerate(args)
        if arg isa LineNumberNode
            loc = arg
            continue
        end
        args[i] = should_skip(p, loc) ? RemoveThisExpr() : f(arg)
    end
    # We now go in reverse, and remove all the RemoveThisExpr (and corresponding LineNumberNodes)
    valids = trues(length(args))
    next_arg = RemoveThisExpr()
    for i in reverse(eachindex(args))
        this_arg = args[i]
        valids[i] = valid_blockarg(this_arg, next_arg)
        next_arg = this_arg
    end
    return Expr(valparam(val), args[valids]...)
end
# This handles removing PLUTO expressions
function custom_walk!(p::AbstractEvalController, ex::Expr, ::Val{:(=)})
    if ex.args[1] in (:PLUTO_PROJECT_TOML_CONTENTS, :PLUTO_MANIFEST_TOML_CONTENTS) && ex.args[2] isa String
        return RemoveThisExpr()
    else
        return Expr(:(=), map(custom_walk!(p), ex.args)...)
    end
end

# This handles modules, by storing the current module in the controller at the beginning of the module and restoring it to the parent module before exiting. It also ensure the __init__ function is executed just before restoring the module
function custom_walk!(p::AbstractEvalController, ex::Expr, ::Val{:module})
    # We first process the block
    block = ex.args[3] |> custom_walk!(p)
    args = block.args
    # Change the current module of the controller to this module
    pushfirst!(args, :($p.current_module = @__MODULE__))
    # Call init function if present
    push!(args, :($maybe_call_init(@__MODULE__)))
    # We change back the current module to the parentmodule
    push!(args, :($p.current_module = parentmodule(@__MODULE__)))
    ex.args[3] = block
    return ex
end

function maybe_call_init(m::Module)
    # Check if it exists
    isdefined(m, :__init__) || return nothing
    # Check if it's owned by this module
    which(m, :__init__) === m || return nothing
    f = getproperty(m, :__init__)
    # Verify that is a function
    f isa Function || return nothing
    f() # execute it
    return nothing
end

nested_getproperty_expr(name::Symbol) = QuoteNode(name)
# This function creates the expression to access a nested property specified by a path. For example, if `path = [:Main, :ASD, :LOL]`, `nested_getproperty_expr(path...)` will return the expression equivalent to `Main.ASD.LOL`. This is not to be used within `import/using` statements as the synthax for accessing nested modules is different there.
function nested_getproperty_expr(names_path::Symbol...)
    @nospecialize
    others..., tail = names_path
    last_arg = nested_getproperty_expr(tail)
    first_arg = length(others) === 1 ? first(others) : nested_getproperty_expr(others...)
    ex = isempty(others) ? arg : Expr(:., first_arg, last_arg)
    return ex
end