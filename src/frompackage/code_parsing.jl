function extract_file_ast(filename)
	code = read(filename, String)
	ast = Meta.parseall(code; filename)
	@assert Meta.isexpr(ast, :toplevel)
	ast
end

## Extract Module Expression

extract_module_expression(packagepath::AbstractString, _module) = extract_module_expression(get_package_data(packagepath), _module)
function extract_module_expression(package_dict, _module)
	ast = extract_file_ast(package_dict["file"])
	mod_exp = getfirst(x -> Meta.isexpr(x, :module), ast.args)
	mod_exp, package_dict
end

## Remove Pluto Exprs
function remove_pluto_exprs(ex)
	ex.head == :(=) && ex.args[1] ∈ (:PLUTO_PROJECT_TOML_CONTENTS, :PLUTO_MANIFEST_TOML_CONTENTS) && return false
	return true
end

_is_include(ex) = Meta.isexpr(ex, :call) && ex.args[1] === :include
_is_block(ex) = Meta.isexpr(ex, :block)

# process_expr, performs potential modification to ex and return true if this expression has to be kept/evaluated
function process_expr!(ex, loc, dict) 
	ex isa Nothing && return false # We skip nothings
	ex isa Expr || return true # Apart from Nothing, we keep everything that is not an expr
	_is_block(ex) && return process_block!(ex, loc, dict)
	_is_include(ex) && error("A call to include not at toplevel was found around line $loc. This is not permitted")
	keep = remove_pluto_exprs(ex)
end

# Process a begin-end block
function process_block!(ex, loc, dict)
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
		keep_inds[loc_idx] |= keep_inds[i] = process_expr!(arg, loc, dict)
	end
	keepat!(args, keep_inds)
	return any(keep_inds)
end