import Base: stacktrace, catch_backtrace

_id_name(cell_id) = Symbol(:_fromparent_cell_id_, cell_id)

function is_call_unique(cell_id, _module)
	current_id = macro_cell[]
	current_id == cell_id && return true
	# If we get here we have a potential multiple call
	id_name = _id_name(current_id)
	return if isdefined(_module, id_name) 
		false
	else
		# We have the update the cell reference
		macro_cell[] = cell_id
		true
	end
end


## @frompackage

function frompackage(ex, target_file, caller, _module; macroname)
	is_notebook_local(caller) || return process_outside_pluto!(ex)
	cell_id = split(caller, "#==#")[2]
	id_name = _id_name(cell_id)
	ex isa Expr || error("You have to call this macro with an import statement or a begin-end block of import statements")
	# Construct the basic block where the module is import under name _PackageModule_. The module is only parsed if _PackageModule_ is not already defined in the calling module
	dict = if is_call_unique(cell_id, _module)
		load_module(target_file, caller, _module)
	else
		error("Multiple Calls: The $macroname is already present in cell with id $(macro_cell[]), you can only have one call-site per notebook")
	end
	args = []
	# We put the cell id variable
	push!(args, :($id_name = true))
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
		push!(args, parseinput(arg, dict))
	end
	# We add the html button
	text = "Reload $macroname"
	push!(args, :($html_reload_button($cell_id; text = $text)))
	out = Expr(:block, args...)
	return out
end

function _combined(ex, target, calling_file, __module__; macroname)
	try
		frompackage(ex, target, calling_file, __module__; macroname)
	catch e
		bt = stacktrace(catch_backtrace())
		out = Expr(:block)
		if !(e isa ErrorException && startswith(e.msg, "Multiple Calls: The"))
			cell_id = split(calling_file, "#==#")[2]
			text = "Reload $macroname"
			# We add a log to maintain the reload button
			push!(out.args, :(@info $html_reload_button($cell_id; text = $text, err = true)))
		end
		push!(out.args,	:(CapturedException($e, $bt)))
		out
	end
end

macro frompackage(target::String, ex)
	calling_file = String(__source__.file)
	out = _combined(ex, target, calling_file, __module__; macroname = "@frompackage")
	esc(out)
end

macro fromparent(ex)
	calling_file = String(__source__.file)
	out = _combined(ex, calling_file, calling_file, __module__; macroname = "@fromparent")
	esc(out)
end
