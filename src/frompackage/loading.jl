struct StopEval 
	reason::String
	loc::LineNumberNode
end
StopEval(reason::String) = StopEval(reason, LineNumberNode(0))

# Function to clean the filepath from the Pluto cell delimiter if present
cleanpath(path::String) = first(split(path, "#==#")) |> abspath

## general
function eval_in_module(_mod, line_and_ex, dict)
	loc, ex = line_and_ex.args
	ex isa Expr || return nothing
	lines_to_skip = get(dict,"Lines to Skip",())
	should_skip(loc, lines_to_skip) && return nothing
	Meta.isexpr(ex, :toplevel) && return eval_toplevel(_mod, ex.args,dict)
	Meta.isexpr(ex, :module) && return eval_module_expr(_mod, ex,dict)
	Meta.isexpr(ex, :call) && ex.args[1] === :include && return eval_include_expr(_mod, loc, ex, dict)
	# If the processing return true, we can evaluate the processed expression
	if process_expr!(ex, loc, dict)
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
		abspath(calling_dir, filename_str)
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
	# We create or overwrite the current module in the parent, and we redirect stderr to avoid the replace warning
	new_module = redirect_stderr(Pipe()) do # Apparently giving devnull as stream is not enough to suprress the warning, but Pipe works
		Core.eval(parent_module, :(module $mod_name end))
	end
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

function maybe_create_module(m::Module)
	if !isassigned(fromparent_module) 
		fromparent_module[] = Core.eval(m, :(module $(gensym(:frompackage)) 
		end))
	end
	return fromparent_module[]
end

function deps_submodule_expr(dict)
	(;direct) = dict["PkgInfo"]
	ex = :(module _DirectDeps_ end)
	toplevel = ex.args[end]
	args = toplevel.args
	for pkg in values(direct)
		n = Symbol(pkg.name)
		push!(args, :(import $n))
	end
	return ex
end

## load module
function load_module(target_file::String, _module)
	package_dict = get_package_data(target_file)
	mod_exp, _ = extract_module_expression(package_dict, _module)
	load_module(mod_exp, package_dict, _module)
end
function load_module(package_dict::Dict, _module)
	target_file = package_dict["target"]
	mod_exp, _ = extract_module_expression(target_file, _module)
	load_module(mod_exp, package_dict, _module)
end
function load_module(mod_exp::Expr, package_dict::Dict, _module)
	target_file = package_dict["target"]
	# If the module Reference inside fromparent_module is not assigned, we create the module in the calling workspace and assign it
	_MODULE_ = maybe_create_module(_module)
	# We reset the module path in case it was not cleaned
	mod_name = mod_exp.args[2]
	proj_file = Base.current_project(target_file)
	# We inject the project in the LOAD_PATH if it is not present already
	add_loadpath(proj_file)
	# We try evaluating the expression within the custom module
	stop_reason = try
		reason = eval_in_module(_MODULE_,Expr(:toplevel, LineNumberNode(1, Symbol(target_file)), mod_exp), package_dict)
		package_dict["Stopping Reason"] = reason isa Nothing ? StopEval("Loading Complete") : reason
	catch e
		package_dict["Stopping Reason"] = StopEval("Loading Error")
		rethrow(e)
	end
	# Get the moduleof the parent package
	__module = getfield(_MODULE_, mod_name)
	# We now create a submodule of the loaded one to import all the direct dependencies
	Core.eval(__module, deps_submodule_expr(package_dict))
	Core.eval(__module, :(_fromparent_dict_ = $package_dict))
	# @info block, __module
	return package_dict
end