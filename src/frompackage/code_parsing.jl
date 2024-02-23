function extract_file_ast(filename)
	code = read(filename, String)
	ast = Meta.parseall(code; filename)
	@assert Meta.isexpr(ast, :toplevel)
	ast
end

## Extract Module Expression

function extract_module_expression(module_filepath::AbstractString)
	ast = extract_file_ast(module_filepath)
	mod_exp = getfirst(x -> Meta.isexpr(x, :module), ast.args)
	mod_exp === nothing || return mod_exp
	# We throw an error as parsing did not create a valid `module` expression
	ex = last(ast.args)
	e = ex.args[end]
	if VERSION < v"1.10"
		e isa String && error("Parsing $module_filepath did not generate a valid `module` expression because of the following error:\n$e")
	else
		throw(e)
	end
end

## Remove Pluto Exprs
function remove_pluto_exprs(ex)
	ex.head == :(=) && ex.args[1] ∈ (:PLUTO_PROJECT_TOML_CONTENTS, :PLUTO_MANIFEST_TOML_CONTENTS) && return false
	return true
end
remove_pluto_exprs(ex, args...) = remove_pluto_exprs(ex)

# This will substitute PackageName with the correct path pointed to the loaded module
function modify_package_using!(ex::Expr, loc, package_dict::Dict, eval_module::Module)
	Meta.isexpr(ex, (:using, :import)) || return true
	package_name = Symbol(package_dict["name"])
	package_expr, _ = extract_import_args(ex)
	package_expr_args = package_expr.args
	extracted_package_name = first(package_expr_args)
	if extracted_package_name === package_name
		prepend!(package_expr_args, modname_path(fromparent_module[])) 
	end
	return true
end

# This will simply make the using/import statements of the calling package point to the parent module
function modify_extension_using!(ex::Expr, loc, package_dict::Dict, eval_module::Module)
	Meta.isexpr(ex, (:using, :import)) || return true
	has_extensions(package_dict) || return true
	loaded_exts = get!(package_dict, "loaded extensions", Set{Symbol}())
	package_name = Symbol(package_dict["name"])
	# If we are not currently evaluating expressions inside the extension module, we return
	eval_module_name = nameof(eval_module)
	eval_module_name in loaded_exts || return true
	ecg = default_ecg()
	target_project = ecg |> get_target |> get_project
	ext_mod_name = String(eval_module_name)
	# Extract the name of the weakdep that triggered this extension
	weakdep = target_project.exts[ext_mod_name] |> Symbol
	package_expr, _ = extract_import_args(ex)
	package_expr_args = package_expr.args
	extracted_package_name = first(package_expr_args)
	if extracted_package_name === weakdep
		# We first add :_LoadedModules_
		pushfirst!(package_expr_args, :_LoadedModules_)
		# We also add the module path of the fromparent_module which contains _LoadedModules_
		prepend!(package_expr_args, modname_path(fromparent_module[])) 
	end
	return true
end

_is_include(ex) = Meta.isexpr(ex, :call) && ex.args[1] === :include
_is_block(ex) = Meta.isexpr(ex, :block)

function should_skip(loc, lines_to_skip)
	# We skip the line as it's in the list of lines to skip
	skip = any(lines_to_skip) do lr
		_inrange(loc, lr)
	end
	# skip && @info "Skipping $loc"
	skip
end

# process_expr, performs potential modification to ex and return true if this
# expression has to be kept/evaluated
function process_expr!(ex, loc, dict, eval_module) 
	ex isa Nothing && return false # We skip nothings
	ex isa Expr || return true # Apart from Nothing, we keep everything that is not an expr
	_is_block(ex) && return process_block!(ex, loc, dict, eval_module)
	_is_include(ex) && error("A call to include not at toplevel was found around line $loc. This is not permitted")
	keep = all((remove_pluto_exprs, modify_package_using!, modify_extension_using!)) do f
		f(ex, loc, dict, eval_module)
	end
end

# Process a begin-end block
function process_block!(ex, loc, dict, eval_module)
	# We create an array of flags to check which portions to keep
	args = ex.args
	loc_idx = 0
	keep_inds = falses(length(args))
	for (i, arg) in enumerate(args)
		if arg isa LineNumberNode
			loc = arg
			loc_idx = i
			continue
		end
		# We keep the LineNumberNode if it has at least a valid associated expression
		keep_inds[loc_idx] |= keep_inds[i] = process_expr!(arg, loc, dict, eval_module)
	end
	keepat!(args, keep_inds)
	return any(keep_inds)
end