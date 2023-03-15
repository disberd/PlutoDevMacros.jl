### A Pluto.jl notebook ###
# v0.19.22

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ 982cd9c4-c32b-11ed-2e41-ff955d3dc55f
# ╠═╡ skip_as_script = true
#=╠═╡
begin
	using PlutoExtras
	using BenchmarkTools
	using MacroTools
end
  ╠═╡ =#

# ╔═╡ fbbcf94e-0cfe-4b18-8fd2-2706b6d55fd9
begin
	using TOML
	using LoggingExtras
	using HypertextLiteral
end

# ╔═╡ 59f5445b-6295-49ab-8e58-8a55fa5b100f
#=╠═╡
ExtendedTableOfContents(;hide_preamble = false)
  ╠═╡ =#

# ╔═╡ 9f71009b-141b-43aa-ae71-6748ccc61b6d
md"""
# Variables
"""

# ╔═╡ 46126b08-73e4-4134-af04-81d4796406e2
const parent_package = Ref{Symbol}()

# ╔═╡ c3969684-8f43-42ca-96f8-a4937fa7f920
const module_path = Module[]

# ╔═╡ 983c2ecd-df26-4fcf-9d58-7712e2adf276
_remove_expr_var_name = :__fromparent_expr_to_remove__

# ╔═╡ a10949ca-75e7-416e-85c7-1259a9743f1f
md"""
# Helper Functions
"""

# ╔═╡ dfcee900-e383-4aae-ba9e-593f4a7979cc
md"""
## execute only in notebook
"""

# ╔═╡ 8cb1d823-85fc-4871-ae48-3c1fe0d8fe12
# We have to create our own simple check to only execute some stuff inside the notebook where they are defined. We have stuff in basics.jl but we don't want to include that in this notebook
function is_notebook_local()
	cell_id = try
		Main.PlutoRunner.currently_running_cell_id[]
	catch e
		return false
	end
	caller = stacktrace()[2] # We get the function calling this function
	calling_file = caller.file |> string
	return endswith(calling_file, string(cell_id))
end

# ╔═╡ 57935d8e-6e11-466f-b4cb-b7353fa3335b
# We have to create our own simple check to only execute some stuff inside the notebook where they are defined. We have stuff in basics.jl but we don't want to include that in this notebook
function is_notebook_local(calling_file::String)
	name_cell = split(calling_file, "#==#")
	return length(name_cell) == 2 && length(name_cell[2]) == 36
end

# ╔═╡ 87211218-8085-4885-90e8-aeb3cbf5c0d1
is_notebook_local(calling_file::Symbol) = is_notebook_local(String(calling_file))

# ╔═╡ 68a8033c-fe13-4060-8c71-672d3782098b
md"""
## get parent data
"""

# ╔═╡ ca76678d-6105-4186-bdef-876c69339a2d
function get_parent_data(filepath::AbstractString)
	# Eventually remove the Pluto cell part
	filepath = first(split(filepath, "#==#"))
	endswith(filepath, ".jl") || error("It looks like the provided file path $filepath does not end with .jl, so it's not a julia file")
	
	project_file = Base.current_project(dirname(filepath))
	project_file isa Nothing && error("The current notebook is not part of a Package")

	parent_dir = dirname(project_file)
	parent_data = TOML.parsefile(project_file)

	# Check that the package file actually exists
	parent_file = joinpath(parent_dir,"src", parent_data["name"] * ".jl")
	isfile(parent_file) || error("The parent package main file was not found at path $parent_file")
	parent_data["dir"] = parent_dir
	parent_data["project"] = project_file
	parent_data["file"] = parent_file
	parent_data["target"] = filepath
	parent_data["Module Path"] = Symbol[]
	parent_data["Loaded Packages"] = Dict{Symbol, Any}(:_Overall_ => Dict{Symbol, Any}(:Names => Set{Symbol}()))
	
	return parent_data
end

# ╔═╡ 64ae6575-0f8a-4efa-aabf-81688bb27878
md"""
## getfirst
"""

# ╔═╡ 11e8f78a-c271-43ee-95f9-ee4c00d727c4
function getfirst(p, itr)
    for el in itr
        p(el) && return el
    end
    return nothing
end

# ╔═╡ 81f0fccd-d175-4fa4-ae52-33607c4f0545
md"""
## filterednames
"""

# ╔═╡ 7bd53128-672e-4d59-a667-6a1d20be3c92
function filterednames(m::Module; all = true)
	excluded = (:eval, :include, :_fromparent_dict_, Symbol("@bind"))
	filter(names(m;all)) do s
		Base.isgensym(s) && return false
		s in excluded && return false
		return true
	end
end

# ╔═╡ 1939ea58-0fe3-4884-ab12-b31a59cf5d68
md"""
## load module
"""

# ╔═╡ 103c6cd7-b8a2-4f94-9f34-192cd75e6d00
md"""
# Parent Code Parsing
"""

# ╔═╡ b29ee2bd-da26-436b-bed6-cb49519ec3a9
md"""
## Basic skip/remove
"""

# ╔═╡ 4727093d-93b0-4b3f-bcf9-906017e29587
_wrap_import(ex) = Expr(:__wrapped_import__, ex)

# ╔═╡ 98fd5870-bd55-4e41-9538-ef5938458549
_skip(ex) = Expr(:__skip_expr__, ex)

# ╔═╡ 99f041bb-1857-4b27-9d14-07e4cf0768c6
_remove(ex) = Expr(:__remove_expr__, ex)

# ╔═╡ 2d4c6a8a-0324-4c42-9b87-a665c124fc78
can_skip(ex) = Meta.isexpr(ex, [:__wrapped_import__, :__skip_expr__, :__remove_expr__]) || ex isa LineNumberNode

# ╔═╡ c7369a67-cb15-4d56-b146-1c796fff5c81
# This function check if the search stopped either because we found the target
should_stop_parsing(dict) = haskey(dict, "Stopped Parsing")

# ╔═╡ ef468c27-ae88-460a-b788-8a2fc4b76941
md"""
## Extract Module Expression
"""

# ╔═╡ fc21f785-76cd-40bb-bbe0-d2d807bcc971
extract_module_expression(filename::AbstractString, _module) = extract_module_expression(get_parent_data(filename), _module)

# ╔═╡ e2a21d36-46c5-4da0-a075-655f61887ea7
md"""
## Extract File AST
"""

# ╔═╡ 028aa527-0394-4370-9dad-b7feb098b137
# Parse the content of the file and return the parsed expression
function extract_file_ast(filename)
	code = read(filename, String)
	ast = Meta.parseall(code; filename)
	@assert Meta.isexpr(ast, :toplevel)
	ast
end

# ╔═╡ bdc074af-9536-4965-832a-96fe4c31b9f0
md"""
## Remove Pluto exprs
"""

# ╔═╡ f688d00f-80e8-44ba-83b4-8b8f6dbdf084
function isbind(ex)
	ex isa Expr || return false
	ex.head == :(=) && return isbind(ex.args[2])
	ex.head == :macrocall && ex.args[1] == Symbol("@bind") && return true
	return false
end

# ╔═╡ eab2c973-8dbd-43fd-b2da-61893e64b46e
function remove_pluto_exprs(ex, dict)
	ex.head == :(=) && ex.args[1] ∈ (:PLUTO_PROJECT_TOML_CONTENTS, :PLUTO_MANIFEST_TOML_CONTENTS) && return _remove(ex)
	return ex
end

# ╔═╡ 03d4bce0-4c94-4a89-95f7-3619c2e50831
md"""
## Remove Custom Exprs
"""

# ╔═╡ beef92a2-83fe-438a-8a2d-a0aa6fbdf478
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

# ╔═╡ 8de2c0ad-ebd8-4827-9f27-c2c2efd24f21
md"""
## Process Linenumber
"""

# ╔═╡ 77e627f9-e1d8-4758-bfd0-611397306a2d
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

# ╔═╡ bcbab5be-8896-436d-92ab-dc18cceabe7f
md"""
## Skip basic exprs
"""

# ╔═╡ 5d153399-8226-4890-a9ed-0d7b452a8c20
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

# ╔═╡ c6c8a7f5-32d5-46af-ba36-d5a56cf92aaa
md"""
## Extract Package Names
"""

# ╔═╡ 575e85f1-3ea1-4d7d-aab0-09a326a5ea7f
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
		push!(set, mod_name)
	end
	return set
end

# ╔═╡ e992d999-1318-4393-9108-4108838ecd26
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

# ╔═╡ 40bbfd2c-ffa8-407c-86d3-c5a3091d419f
function extract_packages(ex, dict)
	ex.head ∈ (:using, :import) || return ex
	return _wrap_import(ex)
end

# ╔═╡ b0c5d79b-e00b-4cdc-b9c6-8cfe38d16979
md"""
## Process include
"""

# ╔═╡ c18c8f42-728a-4afc-b44f-9d989aac1188
md"""
## Process Module
"""

# ╔═╡ 220d5e24-d288-4d65-aec2-9eb53a721361
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

# ╔═╡ 1144610f-0a45-4883-be37-d42a314f664a
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

# ╔═╡ 0e9b21e4-8ec6-44bf-b06c-5bc9ec58a668
md"""
## Process ast
"""

# ╔═╡ 73962d0d-844e-423c-82ac-8cc8b959a7c4
md"""
## clearn args
"""

# ╔═╡ 81cd6445-3e7f-4230-8b8d-846e9c1da4e8
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

# ╔═╡ 42ce51c2-42a0-4fe2-b524-e34678923b38
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

# ╔═╡ ebc1ad90-90a7-4d0c-8f55-221cca2885fa
function extract_module_expression(data, _module)
	# We check if there are specific expressions that we want to avoid
	get!(data, "Expr to Remove") do
		if isdefined(_module, _remove_expr_var_name)
			Core.eval(_module, _remove_expr_var_name)
		else
			[]
		end
	end
	
	ast = extract_file_ast(data["file"])
	logger = EarlyFilteredLogger(current_logger()) do log
		log.level > Logging.Debug ? true : false
	end
	ex = let
	# ex, found = with_logger(logger) do
		process_ast(ast, data)
	end
	# We combine all the packages loaded
	packages = data["Loaded Packages"]
	extracted_names = map(values(packages)) do d
		get(d, :Names, Set{Symbol}())
	end
	packages[:_Overall_][:Names] = union(extracted_names...)
	mod_exp = getfirst(x -> Meta.isexpr(x, :module), ex.args)
	mod_exp, data
end

# ╔═╡ f95e4942-50c4-451e-bd88-3cf12a62e3fa
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
		dict["Target Path"] = dict["Module Path"]
		return _remove(ex)
	else
		# We directly process the include and return the processed expression
		ast = extract_file_ast(fullpath)
		newex = process_ast(ast, dict)
		return _skip(newex)
	end
end

# ╔═╡ 8b93d94e-07db-42c9-b4b6-f3691bedf960
md"""
# Eval In Module
"""

# ╔═╡ b09f91a4-0d31-4bfa-a08f-80d8de424d92
md"""
## module
"""

# ╔═╡ 0d4f9c34-f783-470b-b2a0-916a9630b744
md"""
## toplevel
"""

# ╔═╡ b3854ee1-ae7e-4ee3-a683-abda26e0fefd
md"""
## generic
"""

# ╔═╡ 1fafe21c-1d98-4f62-ad34-2bee849e644b
function eval_module_expr(ex)
	mod_name = ex.args[2]
	parent_module = last(module_path)
	# We create or overwrite the current module in the parent
	push!(module_path, Core.eval(parent_module, :(module $mod_name end)))
	# We process the instructions within the module
	block = ex.args[3]
	args = if length(block.args) > 1 || !Meta.isexpr(block.args[1], :toplevel)
		block.args
	else
		block.args[1].args
	end
	eval_toplevel(args)
	# Now we remove the module from the path
	pop!(module_path)
	nothing
end

# ╔═╡ 9df8ec58-b145-45b8-991e-e654f1a7e055
function eval_in_module(line_and_ex)
	_mod = last(module_path)
	loc, ex = line_and_ex.args
	ex isa Expr || return nothing
	Meta.isexpr(ex, :toplevel) && return eval_toplevel(ex.args)
	Meta.isexpr(ex, :module) && return eval_module_expr(ex)
	Core.eval(_mod, line_and_ex)
	return nothing
end

# ╔═╡ 2fe2579c-83e9-41cb-8f92-9da30a40185f
function load_module(calling_file, _module)
	mod_exp, dict = extract_module_expression(calling_file, _module)
	asd = if length(split(calling_file, "#==#")) == 1
		# This is not a notebook
	else
		# This is a notebook, so we check the dependencies
		proj_file = Core.eval(_module, :(Base.active_project()))
		notebook_project = TOML.parsefile(proj_file)
		notebook_deps =  Set(map(Symbol, keys(notebook_project["deps"]) |> collect))
		loaded_packages = get(dict["Loaded Packages"][:_Overall_], :Names, Set{Symbol}())
		missing_packages = setdiff(loaded_packages, notebook_deps, Set([:Markdown, :Random, :InteractiveUtils]))
		if !isempty(missing_packages)
			error("""The following packages are used in the parent module but are not currently imported in this notebook's environment:
			$(collect(missing_packages))
			Consider adding those in a cell with:
			`import $(join(collect(missing_packages),", "))`
			""")
		end
		# We reset the module path in case it was not cleaned
		mod_name = mod_exp.args[2]
		parent_package[] = mod_name
		keepat!(module_path, 1)
		# We add the extraction dictionary to the module
		# push!(mod_exp.args[end].args, esc(:(_fromparent_dict_ = $dict)))
			eval_in_module(Expr(:toplevel, LineNumberNode(1, Symbol(calling_file)), mod_exp))
		# Get the moduleof the parent package
		_MODULE_ = first(module_path)
		__module = getfield(_MODULE_, mod_name)
		__module._fromparent_dict_ = dict
		block = quote
			_PackageModule_ = $__module
		end
		return block, __module
	end
end

# ╔═╡ ce4640f6-eef4-41c9-a484-d14c376a69ef
function eval_toplevel(args)
	_mod = last(module_path)
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
		eval_in_module(line_and_ex)
	end
	return nothing
end

# ╔═╡ 01ae4ab1-17ff-4972-acb3-c98a8596522d
md"""
# Parse User expression 
"""

# ╔═╡ dbb8d64f-0d58-439f-9e26-e6683b817cd5
md"""
We want to parse import using statements. The following cases are supported:
- `import/using module` → Just load the module in the current workspace and import the exported names if `using`.
  - **SHOULD ONLY WORK INSIDE PLUTO**.
- `import/using module.SubModule / module: vars / module.SubModule: vars` → Import or Use submodules or explicit names starting from the top-level parsed module.
  - **SHOULD ONLY WORK INSIDE PLUTO**.
- `import/using *` → Automatically import all names defined in the parent module
  - Use the module containing the target if the target is found, use the the top-level module otherwise
  - **SHOULD ONLY WORK INSIDE PLUTO**
- `import/using .ModName \ ..ModName \ .ModName: vars \ etc` → Import/Use a module or just some variables from a module starting from the path of the target. 
  -  Should execute the given expression as-is outside of Pluto
  -  Should give an error in Pluto if the target is not found.
"""

# ╔═╡ 1ed28b37-23ee-42cf-b6ca-0b2d941c6546
md"""
## parseinput
"""

# ╔═╡ 16a1dd66-7548-4076-9db5-ed171cdca0b3
# Just support the import module or import module.submodule
function parseinput_simple(ex, _PackageModule_)
	Meta.isexpr(ex, [:using, :import]) || error("Only import or using are supported")
	length(ex.args) == 1 || error("Load only one package per line")
	mod_path, imported_names = if Meta.isexpr(ex.args[1], :(:))
		m, n... = ex.args[1].args 
		m.args, map(x -> x.args[1], n)
	else
		m = ex.args[1].args
		m, Symbol[]
	end
	# We check that all packages start with `module`
	first(mod_path) === :module || error("Only statements starting with `module` are supported")
	# We check that the catchall is only used alone
	:* ∈ imported_names && length(imported_names) > 1 && error("You can only use :* as a unique imported name")
	# If we just have an import module statement we skip it as that is done already
	ex.head === :import && mod_path == [:module] && isempty(imported_names) && return nothing
	# Now we change the name from :module to :_PackageModule_
	mod_path[1] = :_PackageModule_
	# If it's just importing a package, we have to simply bring that package into scope
	if isempty(imported_names) && ex.head == :import
		return :(import $(:.).$(mod_path[1:end-1]...): $(mod_path[end]))
	end
	# In all other cases we need to access the specific imported module
	_mod = _PackageModule_
	for field in mod_path[2:end]
		_mod = getfield(_mod, field)
	end
	if isempty(imported_names) && ex.head == :using
		# We are using the module so we just import all the exported names
		names = filterednames(_mod; all=false)
		# We create the import expression
		mod_name = Expr(:., :., mod_path...)
		names_expr = map(x -> Expr(:., x), names)
		arg = Expr(:(:), mod_name, names_expr...)
		return Expr(:import, arg)
	end
	if first(imported_names) == :*
		# We import all of the variables in the module, including non exported names
		names = filterednames(_mod; all=true)
		# We create the import expression
		mod_name = Expr(:., :., mod_path...)
		names_expr = map(x -> Expr(:., x), names)
		arg = Expr(:(:), mod_name, names_expr...)
		return Expr(:import, arg)
	end
	# If we reached here we have a number of specified imports, so we just stick to those
	mod_name = Expr(:., :., mod_path...)
	names_expr = ex.args[1].args[2:end]
	arg = Expr(:(:), mod_name, names_expr...)
	return Expr(:import, arg)
end

# ╔═╡ 78dd77b4-a16d-49f2-8905-1a86793e9a57
md"""
# Macro
"""

# ╔═╡ 717c123f-1d35-4499-8047-593bec35a57e
md"""
## @removeexpr
"""

# ╔═╡ b8d33d27-8830-41df-b900-6339fb13bf5d
macro removeexpr(ex)
	ex = if is_notebook_local(__source__.file)
		:($_remove_expr_var_name = $ex)
	else
		nothing
	end
	esc(ex)
end

# ╔═╡ 5b9e791d-0be0-4bf3-a7e4-2a06e88bcc40
# ╠═╡ skip_as_script = true
#=╠═╡
@removeexpr [
	:(using MacroTools),
	:(using Requires),
]
  ╠═╡ =#

# ╔═╡ 942a8ae5-c861-4078-8340-85eabfba60f9
md"""
## @fromparent
"""

# ╔═╡ 8ebd991e-e4b1-478c-9648-9c164954f167
function fromparent(ex, calling_file, _module)
	is_notebook_local(calling_file) || return nothing
	ex isa Expr || error("You have to call this macro with an import statement or a begin-end block of import statements")
	# We create a dummy module to use
	isempty(module_path) && push!(module_path, Core.eval(_module, :(module $(gensym(:fromparent)) end)))
	# Construct the basic block where the module is import under name _PackageModule_. The module is only parsed if _PackageModule_ is not already defined in the calling module
	block, _PackageModule_ = load_module(calling_file, _module)
	# We extract the parse dict
	dict = _PackageModule_._fromparent_dict_
	if Meta.isexpr(ex, [:import, :using])
		# Single statement
		push!(block.args, parseinput_simple(ex, _PackageModule_))
	elseif ex.head == :block
		for arg in ex.args
			arg isa LineNumberNode && continue
			push!(block.args, parseinput_simple(arg, _PackageModule_))
	end
	else
		error("You have to call this macro with an import statement or a begin-end block of import statements")
	end
	return block
end

# ╔═╡ a757df08-31a3-462c-96b1-6db481704d4a
macro fromparent(ex)
	calling_file = String(__source__.file)
	esc(fromparent(ex, calling_file, __module__))
end

# ╔═╡ 1f2efdc0-6afd-4645-b186-93d46287e160
md"""
# Tests
"""

# ╔═╡ 1bd7847d-68c1-4140-9ab6-1151e73a9d52
# ╠═╡ skip_as_script = true
#=╠═╡
let
	target = "/home/amengali/Repos/github/mine/PlutoDevMacros/notebooks/mapexpr.jl"
	dict = get_parent_data(target)
	dict["Expr to Remove"] = [
		:(using Requires)
		LineNumberNode(13, "/home/amengali/Repos/github/mine/PlutoDevMacros/src/PlutoDevMacros.jl")
	]
	dict["Stop After Line"] = LineNumberNode(15, "/home/amengali/Repos/github/mine/PlutoDevMacros/src/PlutoDevMacros.jl")
	_mod = @__MODULE__
	ex, data = extract_module_expression(dict, _mod);
	keepat!(module_path, 1)
	eval_in_module(Expr(:toplevel, LineNumberNode(1, :TOP), ex))
end
  ╠═╡ =#

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
HypertextLiteral = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
LoggingExtras = "e6f89c97-d47a-5376-807f-9c37f3926c36"
MacroTools = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
PlutoExtras = "ed5d0301-4775-4676-b788-cf71e66ff8ed"
TOML = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[compat]
BenchmarkTools = "~1.3.2"
HypertextLiteral = "~0.9.4"
LoggingExtras = "~1.0.0"
MacroTools = "~0.5.10"
PlutoExtras = "~0.7.3"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.9.0-rc1"
manifest_format = "2.0"
project_hash = "401e2a5e5bc8fa181f2f881fd8d193629736e0cf"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "8eaf9f1b4921132a4cff3f36a1d9ba923b14a481"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.4"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "d9a9701b899b30332bbcb3e1679c41cce81fb0e8"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.3.2"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "eb7f0f8307f71fac7c606984ea5fb2817275d6e4"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.4"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.0.2+0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "c47c5fa4c5308f27ccaac35504858d8914e102f9"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.4"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "f7be53659ab06ddc986428d3a9dcc95f6fa6705a"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.2"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "3c837543ddb02250ef42f4738347454f95079d4e"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.3"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.3"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "7.84.0+0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.10.2+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.LoggingExtras]]
deps = ["Dates", "Logging"]
git-tree-sha1 = "cedb76b37bc5a6c702ade66be44f831fa23c681e"
uuid = "e6f89c97-d47a-5376-807f-9c37f3926c36"
version = "1.0.0"

[[deps.MIMEs]]
git-tree-sha1 = "65f28ad4b594aebe22157d6fac869786a255b7eb"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "0.1.4"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "42324d08725e200c23d4dfb549e0d5d89dede2d2"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.10"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.10.11"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.21+4"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.Parsers]]
deps = ["Dates", "SnoopPrecompile"]
git-tree-sha1 = "478ac6c952fddd4399e71d4779797c538d0ff2bf"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.5.8"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.9.0"

[[deps.PlutoDevMacros]]
deps = ["HypertextLiteral", "InteractiveUtils", "MacroTools", "Markdown", "Random", "Requires"]
git-tree-sha1 = "fa04003441d7c80b4812bd7f9678f721498259e7"
uuid = "a0499f29-c39b-4c5c-807c-88074221b949"
version = "0.5.0"

[[deps.PlutoExtras]]
deps = ["AbstractPlutoDingetjes", "HypertextLiteral", "InteractiveUtils", "Markdown", "OrderedCollections", "PlutoDevMacros", "PlutoUI", "REPL"]
git-tree-sha1 = "3a05ee8f9b1a17fc3b406d37c087d88ef3437886"
uuid = "ed5d0301-4775-4676-b788-cf71e66ff8ed"
version = "0.7.3"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "5bb5129fdd62a2bbbe17c2756932259acf467386"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.50"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "47e5f437cc0e7ef2ce8406ce1e7e24d44915f88d"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.3.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.SnoopPrecompile]]
deps = ["Preferences"]
git-tree-sha1 = "e760a70afdcd461cf01a575947738d359234665c"
uuid = "66db9d55-30c0-4569-8b51-7e840670fc0c"
version = "1.0.3"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.9.0"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "Pkg", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "5.10.1+6"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.Tricks]]
git-tree-sha1 = "6bac775f2d42a611cdfcd1fb217ee719630c4175"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.6"

[[deps.URIs]]
git-tree-sha1 = "074f993b0ca030848b897beff716d93aca60f06a"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.4.2"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.4.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.48.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+0"
"""

# ╔═╡ Cell order:
# ╠═982cd9c4-c32b-11ed-2e41-ff955d3dc55f
# ╠═fbbcf94e-0cfe-4b18-8fd2-2706b6d55fd9
# ╠═59f5445b-6295-49ab-8e58-8a55fa5b100f
# ╟─9f71009b-141b-43aa-ae71-6748ccc61b6d
# ╠═46126b08-73e4-4134-af04-81d4796406e2
# ╠═8233fa3c-9ba9-4c2e-a20c-0bfc60373c37
# ╠═c3969684-8f43-42ca-96f8-a4937fa7f920
# ╠═983c2ecd-df26-4fcf-9d58-7712e2adf276
# ╟─a10949ca-75e7-416e-85c7-1259a9743f1f
# ╟─dfcee900-e383-4aae-ba9e-593f4a7979cc
# ╠═8cb1d823-85fc-4871-ae48-3c1fe0d8fe12
# ╠═57935d8e-6e11-466f-b4cb-b7353fa3335b
# ╠═87211218-8085-4885-90e8-aeb3cbf5c0d1
# ╟─68a8033c-fe13-4060-8c71-672d3782098b
# ╠═ca76678d-6105-4186-bdef-876c69339a2d
# ╟─64ae6575-0f8a-4efa-aabf-81688bb27878
# ╠═11e8f78a-c271-43ee-95f9-ee4c00d727c4
# ╟─81f0fccd-d175-4fa4-ae52-33607c4f0545
# ╠═7bd53128-672e-4d59-a667-6a1d20be3c92
# ╠═1939ea58-0fe3-4884-ab12-b31a59cf5d68
# ╠═2fe2579c-83e9-41cb-8f92-9da30a40185f
# ╟─103c6cd7-b8a2-4f94-9f34-192cd75e6d00
# ╟─b29ee2bd-da26-436b-bed6-cb49519ec3a9
# ╠═4727093d-93b0-4b3f-bcf9-906017e29587
# ╠═98fd5870-bd55-4e41-9538-ef5938458549
# ╠═99f041bb-1857-4b27-9d14-07e4cf0768c6
# ╠═2d4c6a8a-0324-4c42-9b87-a665c124fc78
# ╠═c7369a67-cb15-4d56-b146-1c796fff5c81
# ╟─ef468c27-ae88-460a-b788-8a2fc4b76941
# ╠═fc21f785-76cd-40bb-bbe0-d2d807bcc971
# ╠═ebc1ad90-90a7-4d0c-8f55-221cca2885fa
# ╠═e2a21d36-46c5-4da0-a075-655f61887ea7
# ╠═028aa527-0394-4370-9dad-b7feb098b137
# ╠═bdc074af-9536-4965-832a-96fe4c31b9f0
# ╠═f688d00f-80e8-44ba-83b4-8b8f6dbdf084
# ╠═eab2c973-8dbd-43fd-b2da-61893e64b46e
# ╠═03d4bce0-4c94-4a89-95f7-3619c2e50831
# ╠═beef92a2-83fe-438a-8a2d-a0aa6fbdf478
# ╠═8de2c0ad-ebd8-4827-9f27-c2c2efd24f21
# ╠═77e627f9-e1d8-4758-bfd0-611397306a2d
# ╠═bcbab5be-8896-436d-92ab-dc18cceabe7f
# ╠═5d153399-8226-4890-a9ed-0d7b452a8c20
# ╠═c6c8a7f5-32d5-46af-ba36-d5a56cf92aaa
# ╠═e992d999-1318-4393-9108-4108838ecd26
# ╠═575e85f1-3ea1-4d7d-aab0-09a326a5ea7f
# ╠═40bbfd2c-ffa8-407c-86d3-c5a3091d419f
# ╠═b0c5d79b-e00b-4cdc-b9c6-8cfe38d16979
# ╠═f95e4942-50c4-451e-bd88-3cf12a62e3fa
# ╠═c18c8f42-728a-4afc-b44f-9d989aac1188
# ╠═220d5e24-d288-4d65-aec2-9eb53a721361
# ╠═1144610f-0a45-4883-be37-d42a314f664a
# ╠═0e9b21e4-8ec6-44bf-b06c-5bc9ec58a668
# ╠═42ce51c2-42a0-4fe2-b524-e34678923b38
# ╠═73962d0d-844e-423c-82ac-8cc8b959a7c4
# ╠═81cd6445-3e7f-4230-8b8d-846e9c1da4e8
# ╟─8b93d94e-07db-42c9-b4b6-f3691bedf960
# ╟─b09f91a4-0d31-4bfa-a08f-80d8de424d92
# ╠═9df8ec58-b145-45b8-991e-e654f1a7e055
# ╟─0d4f9c34-f783-470b-b2a0-916a9630b744
# ╠═ce4640f6-eef4-41c9-a484-d14c376a69ef
# ╟─b3854ee1-ae7e-4ee3-a683-abda26e0fefd
# ╠═1fafe21c-1d98-4f62-ad34-2bee849e644b
# ╟─01ae4ab1-17ff-4972-acb3-c98a8596522d
# ╟─dbb8d64f-0d58-439f-9e26-e6683b817cd5
# ╟─1ed28b37-23ee-42cf-b6ca-0b2d941c6546
# ╠═16a1dd66-7548-4076-9db5-ed171cdca0b3
# ╟─78dd77b4-a16d-49f2-8905-1a86793e9a57
# ╟─717c123f-1d35-4499-8047-593bec35a57e
# ╠═b8d33d27-8830-41df-b900-6339fb13bf5d
# ╠═5b9e791d-0be0-4bf3-a7e4-2a06e88bcc40
# ╟─942a8ae5-c861-4078-8340-85eabfba60f9
# ╠═8ebd991e-e4b1-478c-9648-9c164954f167
# ╠═a757df08-31a3-462c-96b1-6db481704d4a
# ╟─1f2efdc0-6afd-4645-b186-93d46287e160
# ╠═1bd7847d-68c1-4140-9ab6-1151e73a9d52
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
