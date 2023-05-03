struct StopEval 
	reason::String
	loc::LineNumberNode
end
StopEval(reason::String) = StopEval(reason, LineNumberNode(0))

# Function to clean the filepath from the Pluto cell delimiter if present
cleanpath(path::String) = first(split(path, "#==#"))

## general
function eval_in_module(_mod, line_and_ex, dict)
	loc, ex = line_and_ex.args
	ex isa Expr || return nothing
	Meta.isexpr(ex, :toplevel) && return eval_toplevel(_mod, ex.args,dict)
	Meta.isexpr(ex, :module) && return eval_module_expr(_mod, ex,dict)
	Meta.isexpr(ex, :call) && ex.args[1] === :include && return eval_include_expr(_mod, loc, ex, dict)
	# We modify the expr, which also modifies the content of line_and_ex
	if process_expr!(ex, loc, dict)
		# If the processing return true, we can evaluate the processed expression
	Core.eval(_mod, line_and_ex)
	end
	return nothing
end

## include
function eval_include_expr(_mod, loc, ex, dict)
	# we have an include statement, but we only support the version with a single argument
	length(ex.args) == 2 || error("The @frompackage macro currently does not support the 2-argument version of `include`.")
	filename = ex.args[2]
	filename_str = filename isa String ? filename : Core.eval(_mod, filename)
	# We transform this to an absolute path, using the package directory as basis
	filepath = if isabspath(filename_str)
		filename_str
	else
		calling_dir = dirname(String(loc.file))
		normpath(calling_dir, filename_str)
	end
	# We check whether the file to be included is the target put as input to the macro
	if filepath == cleanpath(dict["target"]) 
		# We have to store the Module path
		package_name = Symbol(dict["name"])
		current = _mod
		dict["Target Path"] = namepath = [nameof(current)]
		while nameof(current) ∉ (package_name, :Main)
			current = parentmodule(current)
			push!(namepath, nameof(current))
		end
		return StopEval("Target Found", loc)
	end
	ast = extract_file_ast(filepath)
	eval_toplevel(_mod, ast.args, dict)
end

## toplevel
function eval_toplevel(_mod, args, dict)
	# Taken/addapted from `include_string` in `base/loading.jl`
	loc = LineNumberNode(1, nameof(_mod))
	line_and_ex = Expr(:toplevel, loc, nothing)
	for ex in args
		if ex isa LineNumberNode
			loc = ex
			line_and_ex.args[1] = ex
			continue
		end
		# Wrap things to be eval'd in a :toplevel expr to carry line
		# information as part of the expr.
		line_and_ex.args[2] = ex
		out = eval_in_module(_mod, line_and_ex, dict)
		if out isa StopEval 
			return out
		end
	end
	return nothing
end

## module_expr
function eval_module_expr(parent_module, ex, dict)
	mod_name = ex.args[2]
	block = ex.args[3]
	# We create or overwrite the current module in the parent
	new_module = Core.eval(parent_module, :(module $mod_name end))
	# If the block is empty, we just skip this block
	isempty(block.args) && return nothing
	# We process the instructions within the module
	args = if length(block.args) > 1 || !Meta.isexpr(block.args[1], :toplevel)
		block.args
	else
		block.args[1].args
	end
	out = eval_toplevel(new_module, args, dict)
	return out isa StopEval ? out : nothing
end

## load module
function load_module(calling_file, _module)
	# If the macro was not called from a notebook, we just return nothing
	# is_notebook_local(calling_file) || return nothing
	mod_exp, package_dict = extract_module_expression(calling_file, _module)
	# This is a notebook, so we check the dependencies
	proj_file = Core.eval(_module, :(Base.active_project()))
	notebook_project = TOML.parsefile(proj_file)
	notebook_deps =  Set(map(Symbol, keys(notebook_project["deps"]) |> collect))
	# loaded_packages = get(package_dict["Loaded Packages"][:_Overall_], :Names, Set{Symbol}())
	# missing_packages = setdiff(loaded_packages, notebook_deps, Set([:Markdown, :Random, :InteractiveUtils]))
	# if !isempty(missing_packages)
	# 	msg = """The following packages are used in the parent module but are not currently imported in this notebook's environment:
	# 	$(collect(missing_packages))
	# 	Consider adding those in a cell with:
	# 	`import $(join(collect(missing_packages),", "))`
	# 	"""
	# 	@warn msg
	# end
	# If the module Reference inside fromparent_module is not assigned, we create the module in the calling workspace and assign it
	if !isassigned(fromparent_module) 
		fromparent_module[] = Core.eval(_module, :(module $(gensym(:fromparent)) 
			# We import PlutoRunner in this module, or we just create a dummy module otherwise
			PlutoRunner = let p = parentmodule(@__MODULE__)
				if isdefined(p, :PlutoRunner)
					p.PlutoRunner
				else
					@eval baremodule PlutoRunner
					end
				end
			end
		end))
	end
	# We reset the module path in case it was not cleaned
	mod_name = mod_exp.args[2]
	_MODULE_ = fromparent_module[]
	insert!(LOAD_PATH, 2, package_dict["project"])
	# We try evaluating the expression within the custom module
	stop_reason = try
		reason = eval_in_module(_MODULE_,Expr(:toplevel, LineNumberNode(1, Symbol(calling_file)), mod_exp), package_dict)
		package_dict["Stopping Reason"] = reason isa Nothing ? StopEval("Loading Complete") : reason
	catch e
		package_dict["Stopping Reason"] = StopEval("Loading Error")
		rethrow(e)
	finally
		deleteat!(LOAD_PATH, 2)
	end
	# Get the moduleof the parent package
	__module = getfield(_MODULE_, mod_name)
	__module._fromparent_dict_ = package_dict
	block = quote
		_PackageModule_ = $__module
	end
	# @info block, __module
	return block, __module
end