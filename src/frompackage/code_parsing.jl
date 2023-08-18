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
end

## Remove Pluto Exprs
function remove_pluto_exprs(ex)
	ex.head == :(=) && ex.args[1] ∈ (:PLUTO_PROJECT_TOML_CONTENTS, :PLUTO_MANIFEST_TOML_CONTENTS) && return false
	return true
end
remove_pluto_exprs(ex, args...) = remove_pluto_exprs(ex)

# This will simply make the using/import statements of the calling package point to the parent module
modify_extension_using!(x, args...) = true
function modify_extension_using!(ex::Expr, loc, package_dict::Dict, eval_module::Module)
	Meta.isexpr(ex, (:using, :import)) || return true
	has_extensions(package_dict) || return true
	loaded_exts = package_dict["loaded extensions"]
	package_name = Symbol(package_dict["name"])
	nameof(eval_module) in loaded_exts || return true
	package, _ = extract_import_args(ex)
	if first(package.args) === package_name
		# @info "Found extension" (;ex, loc, package_dict, eval_module)
		# We just add .. to the name because the extension module was added to the toplevel of the parent
		prepend!(package.args, (:., :.))
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
	keep = all((remove_pluto_exprs, modify_extension_using!)) do f
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