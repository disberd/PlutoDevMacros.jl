struct StopEval 
	reason::String
	loc::LineNumberNode
end
StopEval(reason::String) = StopEval(reason, LineNumberNode(0))

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
	if process_expr!(ex, loc, dict, _mod)
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
	if issamepath(filepath, cleanpath(dict["target"]))
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

# This will evaluate an expression which defines a new module or submodule. It will first create the module in the parent module and then evaluate each expression within this newly created module. It will also deal with processing/collecting of the names coming from `using PkgName` or `using PkgName: names...` as these can not be retrieved by simply calling `Base.names(module)`.
function eval_module_expr(parent_module, ex, dict)
	mod_name = ex.args[2]
    is_target_module = mod_name === Symbol(dict["name"])
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
    # We extract the using names currently collected for the parent module
    empty_names_collector = (;
        explicit_names = Set{Symbol}(), # Will contain names explicitly import, via `using A: a,b,c`
        used_packages = Set{Symbol}(), # Will contain names of packages without explicit imports, like `using A`
    )
    parent_using_names = if is_target_module
        dict["Using Names"] = empty_names_collector
    else
        # Save the parent names collector
        parent_names = dict["Using Names"]
        # Store a new empty collector for the module which will be generated
        dict["Using Names"] = empty_names_collector
        parent_names
    end
	out = eval_toplevel(new_module, args, dict)
    if out isa StopEval || is_target_module
        # We have to extract all of the exported names from the `used` Packages and put them in the explicit_names
        (; explicit_names, used_packages) = empty_names_collector
        for module_name in used_packages
            _m = getfield(new_module, module_name)
            for name in names(_m)
                isdefined(new_module, name) && push!(explicit_names, name)
            end
        end
    else
        # In case we didn't stop evaluating, we have to put back in "Using Names" the parent module collector
        dict["Using Names"] = parent_using_names
    end
	# If the module has an __init__ function, we call it
	if isdefined(new_module, :__init__) && new_module.__init__ isa Function
		# We do Core.eval instead of just new_module.__init__() because of world age (it will error with new_module.__init__())
		Core.eval(new_module, :(__init__()))
	end
	return out isa StopEval ? out : nothing
end

function maybe_create_module(m::Module)
	if !isassigned(fromparent_module) 
		fromparent_m = Core.eval(m, :(module $(gensym(:frompackage)) 
		end))
        # We create the dummy module where all the direct dependencies will be loaded
		Core.eval(fromparent_m, :(module _DirectDeps_ end))
		# We also set a reference to LoadedModules for access from the notebook
		Core.eval(fromparent_m, :(const _LoadedModules_ = $LoadedModules))
		fromparent_module[] = fromparent_m
	end
	return fromparent_module[]
end

# This will explicitly import each direct dependency of the package inside the LoadedModules module. Loading all of the direct dependencies will help make every dependency available even if not directly loaded in the target source code.
function load_direct_deps(package_dict, fromparent_module)
    DepsModule = fromparent_module._DirectDeps_
	(;direct) = package_dict["PkgInfo"]
    for pkg in values(direct)
        package_name_symbol = Symbol(pkg.name)
        package_uuid_symbol = Symbol(pkg.uuid)
        # If this is already loaded, we just skip
        isdefined(DepsModule, package_uuid_symbol) && continue
        # If not already defined, we import this. Note that this function will work correctly only if executed after the target environment has been added to the LOAD_PATH. In this DepsModule, we load packages with their UUID as name to potentially avoid clashes with two packages with same name.
        Core.eval(DepsModule, :(import $(package_name_symbol) as $(package_uuid_symbol)))
        # We also load this inside LoadedModules
        maybe_add_loaded_module(to_pkgid(pkg))
    end
end


## load module
function load_module_in_caller(target_file::String, caller_module)
	package_dict = get_package_data(target_file)
	load_module_in_caller(package_dict, caller_module)
end
function load_module_in_caller(package_dict::Dict, caller_module)
	package_file = package_dict["file"]
	mod_exp = extract_module_expression(package_file)
	load_module_in_caller(mod_exp, package_dict, caller_module)
end
function load_module_in_caller(mod_exp::Expr, package_dict::Dict, caller_module)
	target_file = package_dict["target"]
	ecg = default_ecg()
	# If the module Reference inside fromparent_module is not assigned, we create the module in the calling workspace and assign it
	_MODULE_ = maybe_create_module(caller_module)
	# We reset the module path in case it was not cleaned
	mod_name = mod_exp.args[2]
	# We inject the project in the LOAD_PATH if it is not present already
	add_loadpath(ecg; should_prepend = get_setting(package_dict, :SHOULD_PREPEND_LOAD_PATH))
    # We start by loading each of the direct dependencies in the LoadedModules submodule
    load_direct_deps(package_dict, _MODULE_)
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
	# We put the dict inside the loaded module
	Core.eval(__module, :(_fromparent_dict_ = $package_dict))
    # Register this module as root module. 
    register_target_module_as_root(package_dict)
	return package_dict
end