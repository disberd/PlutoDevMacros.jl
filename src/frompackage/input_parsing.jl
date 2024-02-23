# This funtion tries to look within the expression fed to @frompackage to look for calls to @skiplines
function process_skiplines!(ex, dict)
	block = if Meta.isexpr(ex, :block)
		ex
	else
		Expr(:block, ex)
	end
	skipline_arg = 0
	for i ∈ eachindex(block.args)
		arg = block.args[i]	
		if Meta.isexpr(arg, :macrocall) && arg.args[1] === Symbol("@skiplines")
			skipline_arg = i
			break
		end
	end
	skipline_arg != 0 || return ex
	# We initialize the Vector of LineRanges to skip
	dict["Lines to Skip"] = LineNumberRange[]
	parse_skiplines(block.args[skipline_arg], dict)
	deleteat!(ex.args, skipline_arg)
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

function import_type(args, dict)
	first_name = args[1]
	mod_name = Symbol(dict["name"])
	if first_name === :* 
		return target_found(dict) ? FromParentImport(mod_name) : FromPackageImport(mod_name)
	end
	first_name ∈ (:PackageModule, mod_name, :^) && return FromPackageImport(mod_name)	
	first_name === :. && return RelativeImport(mod_name)
	first_name ∈ (:ParentModule, :<) && return FromParentImport(mod_name)
	(;direct, indirect) = dict["PkgInfo"]
	first_name === :> && String(args[2]) ∈ keys(direct) && return FromDepsImport(mod_name)
	# String(first_name) ∈ _stdlibs && return FromDepsImport(mod_name)
	# String(first_name) ∈ keys(indirect) && return FromDepsImport(mod_name)
	# If we reach here we don't have a supported import type
	error("The provided import expression is not supported, please look at @frompackage documentation to see the supported imports")
end

# Get the full path of the module as array of Symbols starting from Main
function modname_path(m::Module)
	args = [nameof(m)]
	m_old = m
	_m = parentmodule(m)
	while _m !== m_old && _m !== Main
		m_old = _m
		pushfirst!(args, nameof(_m))
		_m = parentmodule(_m)
	end
	_m === Main || error("modname_path did not reach Main, this is not expected")
	pushfirst!(args, nameof(_m))
	return args
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

## validate import
function validate_import(ex)
	Meta.isexpr(ex, [:using, :import]) || error("You have to provide a `using` or `import` statement as input")
	length(ex.args) == 1 || error("Multiple imported modules per expression (e.g. `import moduleA, moduleB`) are not supported, please import a single module per line")
	return nothing 
end

## target found
target_found(dict) = haskey(dict, "Target Path")

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
		s ∈ keys(direct) && return true
	end
	# s ∈ _stdlibs && return true
	# s ∈ keys(indirect) && return true
	return false
end

## extract import args
# Extract the :(.) expressions of the module name and exported names from the module (first output is the modulename expr, second is the list of exported names)
function extract_import_args(ex)
	validate_import(ex)
	arg = ex.args[1]
	mod_expr, names_exprs... = arg.head == :(:) ? arg.args : [arg]
	return mod_expr, names_exprs
end

## reconstruct import expr
# Does the inverse of extract_import_args. Given an expression of a module name identifier and an array of exported names identifiers, it creates the resulting import expression.
function reconstruct_import_expr(mod_expr, names_exprs)
	if isempty(names_exprs)
		Expr(:import, mod_expr)
	else
		Expr(:import, Expr(:(:), mod_expr, names_exprs...))
	end
end

## contains catchall
# Take a vector of expressions representing imported names and returns true if it contains the catchall :* symbol, which implies the need to extract all the names defined in a module
function contains_catchall(names_exprs::Vector)
	out = Expr(:., :*) ∈ names_exprs
	out && length(names_exprs) > 1 && error("The catchall symbol `*` has to be the only imported name in the expression")
	return out
end

# This is the version on the expression
contains_catchall(import_expr::Expr) = contains_catchall(extract_import_args(import_expr)...)

# This is the version with modname and imported_names expressions
function contains_catchall(modname, imported_names)
	import_catchall = contains_catchall(imported_names)
	modname_catchall = modname == Expr(:.,:*)
	modname_catchall && !isempty(imported_names) && error("The catchall can only be used either in the modname without imported names, or as the only imported name.")
	return import_catchall || modname_catchall
end

## process imported nameargs, generic version
function process_imported_nameargs!(args, dict)
	# We modify the module name expression to point to the current path within the _PackageModule_ that is loaded in Pluto
	type = import_type(args, dict)
	# We process the args based on the type and return them
	process_imported_nameargs!(args, dict, type)
	return args, type
end
## Per-type versions
function process_imported_nameargs!(args, dict, t::FromPackageImport)
	name_init = modname_path(fromparent_module[])
	args[1] = t.mod_name
	prepend!(args, name_init)
end
function process_imported_nameargs!(args, dict, t::Union{FromParentImport, RelativeImport})
	mod_name = Symbol(dict["name"])
	name_init = modname_path(fromparent_module[])
	# Here transform the relative module name to the one based on the full loaded module path
	target_path = get(dict, "Target Path", []) |> reverse
	isempty(target_path) && error("The current file was not found included in the loaded module $(t.mod_name), so you can't use relative path imports")
	# We pop the first argument which is either `:.`, `:FromParent` or `:*`
	popfirst!(args)
	while getfirst(args) === :. 
		# We pop the dot
		popfirst!(args)
		# We also pop the last part of the target path
		pop!(target_path)
	end
	# We prepend the target_path to the args
	prepend!(args, name_init, target_path)
end
function process_imported_nameargs!(args, dict, ::FromDepsImport)
	args[1] = :_DirectDeps_
	mod_name = Symbol(dict["name"])
	pushfirst!(args, mod_name)
	name_init = modname_path(fromparent_module[])
	prepend!(args, name_init)
end

## parseinput
function parseinput(ex, dict)
	# We get the module
	modname_expr, importednames_exprs = extract_import_args(ex)
	# Check if we have a catchall
	catchall = contains_catchall(ex)
	# Check if the statement is a using or an import, this is used to check
	# which names to eventually import, but all statements are converted into
	# `import` if they are not of type FromDepsImport
	is_using = ex.head === :using 
	args, type = process_imported_nameargs!(modname_expr.args, dict)
	# Check that we don't catchall with imported dependencies
	if catchall && type isa FromDepsImport
		error("You can't use the catch-all name identifier (*) while importing dependencies of the Package Environment")
	end
	ex.head = :import
	# We try going towards the intended submodule, just to verify that in case
	# of relative imports, the provided submodule name actually exists
	_mod = Main
	for field in args[2:end]
		_mod = getfield(_mod, field)
	end
	# If we don't have a catchall and we are either importing or using just specific names from the module, we can just return the modified expression
	if !catchall && (!is_using || !isempty(importednames_exprs))
		return ex
	end
	# We extract the imported names either due to catchall or due to the standard using
	imported_names = filterednames(_mod; all = catchall, imported = catchall)
	# At this point we have all the names and we just have to create the final expression
	importednames_exprs = map(n -> Expr(:., n), imported_names)
	return reconstruct_import_expr(modname_expr, importednames_exprs)
end
