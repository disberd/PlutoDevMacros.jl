## @frompackage

function frompackage(ex, target_file, caller, _module)
	is_notebook_local(caller) || return process_outside_pluto!(ex)
	ex isa Expr || error("You have to call this macro with an import statement or a begin-end block of import statements")
	# Construct the basic block where the module is import under name _PackageModule_. The module is only parsed if _PackageModule_ is not already defined in the calling module
	dict = load_module(target_file, caller, _module)
	block = Expr(:block)
	# We extract the parse dict
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
		push!(block.args, parseinput(arg, dict))
	end
	return block
end

macro frompackage(target::String, ex)
	calling_file = String(__source__.file)
	out = frompackage(ex, target, calling_file, __module__)
	esc(out)
end

macro fromparent(ex)
	calling_file = String(__source__.file)
	out = frompackage(ex, calling_file, calling_file, __module__)
	esc(out)
end
