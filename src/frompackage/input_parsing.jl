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

# This funtion tries to look within the expression fed to @frompackage to look for calls to @skiplines
function process_skiplines!(ex, dict)
    skiplines_arg = detect_custom_macro!(ex, Symbol("@skiplines"))
    !isnothing(skiplines_arg) || return ex
	# We initialize the Vector of LineRanges to skip
	dict["Lines to Skip"] = LineNumberRange[]
	parse_skiplines(skiplines_arg, dict)
	return ex
end

function isdoc(ex)
	Meta.isexpr(ex, :macrocall) || return false
	arg = ex.args[1]
	arg isa GlobalRef || return false
	arg.mod === Core && arg.name === Symbol("@doc")
end

maybe_expand_docs(ex) = isdoc(ex) ? (ex.args[3], ex.args[4]) : (ex,)

function parse_skiplines(ex, dict)
	@assert length(ex.args) == 3 "The @skipline call only accept a single String or a begin end block of strings as only argument"
	temp = ex.args[3]
	skiplines_vector = dict["Lines to Skip"]
	mainfile = dict["file"]
	if temp isa String 
		push!(skiplines_vector, parse_skipline(temp, mainfile))
		return
	end
	# Here instead we have a block of arguments
	for arg in temp.args
		arg isa LineNumberNode && continue
		for str in maybe_expand_docs(arg)
			push!(skiplines_vector, parse_skipline(str, mainfile))
		end
	end
end

function parse_skipline(str, mainfile)
	srcpath = dirname(mainfile)
	@assert str isa String "The @skipline call only accept a single String or a begin end block of strings as only argument"
	out = split(str, ":::")
	errmsg = """Unuspported format in string `$str`
	The following formats are supported when specifying lines to skip:
	- `filepath:::firstline-lastline` # Skip a range of lines in given file
	- `filepath:::line` # Skip a single line in given file
	- `filepath` # skip the full given file
	- `line` # Skip a single line in the package main file
	- `firstline-lastline` # Skip a range of lines in the package main file
	"""
	@assert length(out) ∈ (1,2) errmsg
 	path, lines = if length(out) == 1
		t = out[1]
		if endswith(t, ".jl")
			# It's a path
			t, "1-1000000"
		else
			# It's a line or line range
			mainfile, t
		end
	else
		out
	end

	full_path = isabspath(path) ? path : abspath(srcpath, path)
	@assert isfile(full_path) "No file was found at $full_path"
	range = split(lines, '-')
	firstline, lastline = if length(range) == 1
		n = parse(Int, range[1])
		n,n
	elseif length(range) == 2
		parse(Int, range[1]), parse(Int, range[2])
	else
		error(errmsg)
	end
	return LineNumberRange(full_path, firstline, lastline)
end

## process outside pluto
# We parse all the expressions in the block provided as input to @fromparent
function process_outside_pluto!(ex, dict)
	ex isa LineNumberNode && return ex
	if Meta.isexpr(ex, :block)
		args = ex.args
		for (i,arg) ∈ enumerate(args)
			args[i] = process_outside_pluto!(arg, dict)
		end
		return ex
	else
		# Single expression
		return valid_outside_pluto!(ex, dict) ? ex : nothing
	end
end

function valid_outside_pluto!(ex, dict)
	ex isa Expr || return false
	Meta.isexpr(ex, :macrocall) && return false
	package_name = Symbol(dict["name"])
	mod_name, imported_names = extract_import_args(ex)
	first_name = mod_name.args[1]
	first_name ∈ (:FromPackage, :FromParent, :*, package_name, :<, :^) && return false
	contains_catchall(imported_names) && return false # We don't support the catchall outside import outside Pluto
	first_name === :. && return true
	# Now we try to check for direct dependencies
	if first_name === :>
		args = mod_name.args
		# We remove the 
		popfirst!(args)
		s = String(args[1])
		(;direct, indirect) = dict["PkgInfo"]
		if s ∈ keys(direct)
            return true
        end
	end
	# s ∈ _stdlibs && return true
	# s ∈ keys(indirect) && return true
	return false
end


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
