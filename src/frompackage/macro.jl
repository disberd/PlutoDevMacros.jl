## @removeexpr
macro removeexpr(ex)
	ex = if is_notebook_local(__source__.file)
		:($_remove_expr_var_name = $ex)
	else
		nothing
	end
	esc(ex)
end

## @fromparent
### Basic Idea

function fromparent(ex, calling_file, _module)
	is_notebook_local(calling_file) || return process_outside_pluto!(ex)
	ex isa Expr || error("You have to call this macro with an import statement or a begin-end block of import statements")
	# Construct the basic block where the module is import under name _PackageModule_. The module is only parsed if _PackageModule_ is not already defined in the calling module
	block, _PackageModule_ = load_module(calling_file, _module)
	# We extract the parse dict
	dict = _PackageModule_._fromparent_dict_
	ex_args = if Meta.isexpr(ex, [:import, :using])
		[ex]
	elseif Meta.isexpr(ex, :block)
		ex.args
	else
		error("You have to call this macro with an import statement or a begin-end block of import statements")
	end
	# We now process/parse all the import/using statements
	for arg in ex_args
		arg isa LineNumberNode && continue
		push!(block.args, parseinput(arg, _PackageModule_, dict))
	end
	return block
end

macro fromparent(ex)
	calling_file = String(__source__.file)
	out = fromparent(ex, calling_file, __module__)
	@info out
	esc(out)
end
