# We define here the types to identify the imports
abstract type ImportType end
for name in (:FromParentImport, :FromPackageImport, :FromDepsImport, :RelativeImport)
	expr = :(struct $name <: ImportType
		mod_name::Symbol
	end) 
	eval(expr)
end

function import_type(first_name::Symbol, dict)
	mod_name = Symbol(dict["name"])
	first_name ∈ (:PackageModule, mod_name) && return FromPackageImport(mod_name)	
	first_name === :. && return RelativeImport(mod_name)
	first_name ∈ (:*, :ParentModule) && return FromParentImport(mod_name)
	(;direct, indirect) = dict["PkgInfo"]
	String(first_name) ∈ keys(direct) && return FromDepsImport(mod_name)
	String(first_name) ∈ _stdlibs && return FromDepsImport(mod_name)
	String(first_name) ∈ keys(indirect) && return FromDepsImport(mod_name)
	# If we reach here we don't have a supported import type
	error("The provided import expression is not supported, please look at @frompackage documentation to see the supported imports")
end

# Get the full path of the module as array of Symbols starting from Main
function modname_path(m::Module)
	args = [nameof(m)]
	_m = parentmodule(m)
	while _m !== Main
		pushfirst!(args, nameof(_m))
		_m = parentmodule(_m)
	end
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
		return valid_outside_pluto(ex, dict) ? ex : nothing
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

function valid_outside_pluto(ex, dict)
	package_name = Symbol(dict["name"])
	mod_name, imported_names = extract_import_args(ex)
	first_name = mod_name.args[1]
	first_name ∈ (:FromPackage, :FromParent, :*, package_name) && return false
	contains_catchall(imported_names) && return false # We don't support the catchall outside import outside Pluto
	first_name === :. && return true
	s = String(first_name)
	(;direct, indirect) = dict["PkgInfo"]
	s ∈ keys(direct) && return true
	s ∈ _stdlibs && return true
	s ∈ keys(indirect) && return true
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
	first_name = args[1]
	type = import_type(first_name, dict)
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
process_imported_nameargs!(args, dict, ::FromDepsImport) = args

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
	# In case we have simply a dependency import, we maintain the expression
	type isa FromDepsImport && return ex
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
