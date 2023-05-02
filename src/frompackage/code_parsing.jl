## Basic skip/remove

_wrap_import(ex) = Expr(:__wrapped_import__, ex)
_skip(ex) = Expr(:__skip_expr__, ex)
_remove(ex) = Expr(:__remove_expr__, ex)
can_skip(ex) = Meta.isexpr(ex, [:__wrapped_import__, :__skip_expr__, :__remove_expr__]) || ex isa LineNumberNode
# This function check if the search stopped either because we found the target
should_stop_parsing(dict) = haskey(dict, "Stopped Parsing")

## Extract Module Expression

extract_module_expression(packagepath::AbstractString, _module) = extract_module_expression(get_package_data(packagepath), _module)
function extract_module_expression(package_dict, _module)
	# We check if there are specific expressions that we want to avoid
	get!(package_dict, "Expr to Remove") do
		if isdefined(_module, _remove_expr_var_name)
			Core.eval(_module, _remove_expr_var_name)
		else
			[]
		end
	end
	
	ast = extract_file_ast(package_dict["file"])
	ex = let
		process_ast(ast, package_dict)
	end
	# We combine all the packages loaded
	packages = package_dict["Loaded Packages"]
	extracted_names = map(values(packages)) do d
		get(d, :Names, Set{Symbol}())
	end
	packages[:_Overall_][:Names] = union(extracted_names...)
	mod_exp = getfirst(x -> Meta.isexpr(x, :module), ex.args)
	mod_exp, package_dict
end

## Extract File AST
# Parse the content of the file and return the parsed expression
function extract_file_ast(filename)
	code = read(filename, String)
	ast = Meta.parseall(code; filename)
	@assert Meta.isexpr(ast, :toplevel)
	ast
end

## Remove Pluto exprs
function isbind(ex)
	ex isa Expr || return false
	ex.head == :(=) && return isbind(ex.args[2])
	ex.head == :macrocall && ex.args[1] == Symbol("@bind") && return true
	return false
end
function remove_pluto_exprs(ex, dict)
	ex.head == :(=) && ex.args[1] ∈ (:PLUTO_PROJECT_TOML_CONTENTS, :PLUTO_MANIFEST_TOML_CONTENTS) && return _remove(ex)
	return ex
end

## Remove Custom Exprs
function remove_custom_exprs(ex, dict)
	exprs = dict["Expr to Remove"]
	for check in exprs
		if check isa LineNumberNode
			# We remove whatever expression is at the given LineNumberNode
			check == get(dict, "Last Parsed Line", nothing) && (return _remove(ex))
		else
			ex == check && return _remove(ex)
		end
	end
	return ex
end

## Process Linenumber
# Update the last parsed LineNumber and eventually stop parsing if the stopping condnition has been reached 
function process_linenumber(ex, dict)
	ex isa LineNumberNode || return ex
	# We first save the current line as the last one parsed
	dict["Last Parsed Line"] = ex
	# We check if we reached the stopping condition
	stop_line = get(dict,"Stop After Line",LineNumberNode(0,:_NotProvided_)) 
	stop_line isa LineNumberNode || error("The key 'Stop After Line' only accepts object of type LineNumberNode")
	if stop_line.file == ex.file && stop_line.line <= ex.line
		dict["Stopped Parsing"] = "Target LineNumber Reached"
	end
	return ex
end

## Skip basic exprs
# Check if the provided Expr is internally generating another Expr (like a quote)
function skip_basic_exprs(ex, dict)
	# We skip everything that is not an expr
	ex isa Expr || return _skip(ex)
	# We skip Expr/quote inside the Expr
	ex.head == :call && ex.args[1] == :Expr && return _skip(ex)
	ex.head == :quote && return _skip(ex)
	# We avoid calls to other @fromparent
	ex.head == :macrocall && ex.args[1] ∈ Symbol.(("@fromparent", "@removeexpr")) && return _skip(ex)
	# We leave the rest untouched
	return ex
end

## Extract Package Names
# This function expects as input a vector of Expr or LineNumberNodes that are
# the list of `import` or `using` statements have been found during the
# processing of the current module. These statements are parsed to extract the
# package names that will be used to check if the calling notebook has missing dependencies
function process_extracted_packages(package_exprs)
	set = Set{Symbol}()
	for ex in package_exprs
		ex isa LineNumberNode && continue
		add_package_names!(set, ex)
	end
	return set
end
# This function takes a `using` or `import` expression and collects a list of all the imported packages inside the `set` provided as first argument
function add_package_names!(set, ex)
	# Here we alaredy know that the expression is an import, so we can directly look at the args
	args = if length(ex.args) > 1
		# We have multiple packages
		ex.args
	else
		arg = ex.args[1]
		# We only have one package in this expression, we put it in a vector
		[arg.head == :(:) ? arg.args[1] : arg]
	end
	skip_names = (:Main, :Core, :Base)
	for arg in args
		arg.head == :(.) || error("Something unexpected happened")
		# If the import or using is of the type `import .NAME: something` we ignore it as it's not a package but a local module
		arg.args[1] == :(.) && continue
		mod_name = getfirst(x -> x ∉ skip_names, arg.args)
		mod_name isa Nothing && continue
		mod_name ∈ (:module, :*) && continue # Ignore instructions from this module
		push!(set, mod_name)
	end
	return set
end
function extract_packages(ex, dict)
	ex.head ∈ (:using, :import) || return ex
	return _wrap_import(ex)
end

## Process include
function process_include(ex, dict)
	ex.head === :call && ex.args[1] == :include || return ex
	filename = ex.args[2]
	if !(filename isa String) 
		@warn "Only calls to include which are given direct strings are supported, instead $ex was found as expression"
		return ex
	end
	srcdir = joinpath(dict["dir"], "src")
	fullpath = startswith(filename, srcdir) ? filename : normpath(joinpath(srcdir, filename))
	is_target = fullpath == dict["target"]
	if is_target
		# We save the reason why we stopped parsing to allow skipping following parsing and we just return the expression to be removed
		dict["Stopped Parsing"] = "Target Found"
		# We also save a copy of the module path where the target resides
		dict["Target Path"] = deepcopy(dict["Module Path"])
		return _remove(ex)
	else
		# We directly process the include and return the processed expression
		ast = extract_file_ast(fullpath)
		newex = process_ast(ast, dict)
		return _skip(newex)
	end
end

## Process Module
function preprocess_module(ex, dict)
	Meta.isexpr(ex, :module) || return ex
	path = dict["Module Path"]
	module_name = ex.args[2]
	
	# Add the current module to the path
	pushfirst!(path, module_name)
	
	# Reset the module specific data
	dict["Loaded Packages"][module_name] = Dict{Symbol, Any}(:Exprs => [], :Names => Set{Symbol}())

	return ex
end
function postprocess_module(ex, dict)
	Meta.isexpr(ex, :module) || return ex
	path = dict["Module Path"]
	module_name = ex.args[2]

	# We have to create an import statement with all the packages used inside the Module and put it as first expression to avoid problems with macro expansion
	package_exprs = get(dict["Loaded Packages"][module_name], :Exprs, [])
	names_set = process_extracted_packages(package_exprs)
	# We put the set of names in the Loaded Packages for this module
	dict["Loaded Packages"][module_name][:Names] = names_set
	## FOR THE MOMENT WE AVOID ADDING STUFF
	# if !isempty(package_exprs) && length(path) > 1 # We don't do this for the top level module as it's not needed there
	# 	# We add a begin-end block with all the using/import statements (and their linenumbers) at the beginning of the module
	# 	import_block = Expr(:block, package_exprs...)
	# 	pushfirst!(ex.args[end].args, import_block)
	# end
	
	# We pop the current module from the path
	popfirst!(path)
	return ex
end

## Process ast
function process_ast(ex, dict)
	# We try to add the module to the path
	preprocess_module(ex, dict)
	# It is important that the process_linenumber is the first function to use, as LineNumbers are skipped at the first `can_skip`
	for f in (process_linenumber, skip_basic_exprs, remove_custom_exprs, remove_pluto_exprs, extract_packages, process_include)
		ex = f(ex, dict)
		can_skip(ex) && return ex
	end
	# Process all arguments
	last_idx = 0
	newargs = ex.args
	stop_parsing = false
	for (i,arg) in enumerate(newargs)
		newarg = process_ast(arg, dict)
		newargs[i] = newarg
		stop_parsing = should_stop_parsing(dict)
		if stop_parsing
			# We found the target, we can stop parsing
			last_idx = i
			break
		end
	end
	if stop_parsing && last_idx > 0 && last_idx != lastindex(newargs)
		newargs = newargs[1:last_idx]
	end
	# Remove the linunumbernodes that are directly before another nothing or LinuNumberNode
	cloned_exprs = clean_args!(newargs)
	# We check if we are in a module, and we do add the cloned expressions to the loaded packages.
	# If not in a module, the expressions are still cloned to the generic dict entry to later extract the package names
	path = get(dict, "Module Path", [])
	mod_name = isempty(path) ? :_Overall_ : first(path)
	package_exprs = let
		general_dict = get!(dict, "Loaded Packages", Dict{Symbol, Any}())
		current_dict = get!(general_dict, mod_name, Dict{Symbol, Any}())
		get!(current_dict, :Exprs, [])
	end
	append!(package_exprs, cloned_exprs)

	# We try to remove the module from the path
	postprocess_module(ex, dict)
	return Expr(ex.head, newargs...)
end

## clearn args
function clean_args!(newargs)
	last_invalid = last_popup = 0
	cloned_exprs = []
	for i ∈ reverse(eachindex(newargs))
		arg = newargs[i]
		if Meta.isexpr(arg, :__skip_expr__)
			# We remove the wrapper
			newargs[i] = arg.args[1]
		elseif Meta.isexpr(arg, :__remove_expr__)
			deleteat!(newargs, i)
			last_invalid = i
		elseif Meta.isexpr(arg, :__wrapped_import__)
			# We have a wrapped import statement, we unwrap it and also put it in the vector to return
			ex = arg.args[1]
			newargs[i] = ex
			# We add the expression to the vector, and we also mark the counter to copy the related LineNumberNode as well, but we add information to the LineNumberNode
			pushfirst!(cloned_exprs, ex)
			last_popup = i
		elseif arg isa LineNumberNode
			# We eventually delete or add the linenumbers
			(last_invalid == i+1) && deleteat!(newargs, i)
			# We put a note that this was added by fromparent
			(last_popup == i+1) && pushfirst!(cloned_exprs, LineNumberNode(arg.line, Symbol("Added by @fromparent => ", arg.file)))
			# We set this as the last invalid so that we can delete hanging LineNumberNodes that are all bundled together, likely coming from expression that were delete in the ast processing
			last_invalid = i
		end
	end
	return cloned_exprs
end
