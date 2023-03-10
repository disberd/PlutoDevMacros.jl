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

# ╔═╡ 7e440c22-c1e0-493e-aa62-a30183f18bae
# ╠═╡ skip_as_script = true
#=╠═╡
begin
	using PlutoExtras
	using BenchmarkTools
end
  ╠═╡ =#

# ╔═╡ 7f164c6d-1b27-4805-ae03-6a82a8390c16
using HypertextLiteral

# ╔═╡ 60aecd17-82c9-4a64-ad99-310e502c5a5e
begin
	using TOML
	using LoggingExtras
end

# ╔═╡ 5722e2db-881f-4ec2-98ec-220654a4e7ae
#=╠═╡
ExtendedTableOfContents(;hide_preamble = false)
  ╠═╡ =#

# ╔═╡ 5f1db2c0-4ab5-4391-a15b-8331f9b649d7
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
	
	return parent_data
end

# ╔═╡ 4e1e0305-7cda-4272-904a-2aa7add72cb5
# ╠═╡ skip_as_script = true
#=╠═╡
data = get_parent_data(@__FILE__)
  ╠═╡ =#

# ╔═╡ 74b3f945-39af-463f-9f0a-ba1c7adc526c
md"""
# Macro
"""

# ╔═╡ 9a3ef442-9905-431a-8e18-f72c9acba5e8
_skip_expr_var_name = :__parent_import_expr_to_remove__

# ╔═╡ 520e5abb-46aa-4dd6-91e5-3b4781e5dbd7
macro skipexpr(ex)
	esc(Expr(:(=), _skip_expr_var_name, ex))
end

# ╔═╡ 10b633a4-14ab-4eff-b503-9841d9ffe175
md"""
## Function
"""

# ╔═╡ d1b36c20-63d0-4105-9418-cdb05645ca99
# ╠═╡ skip_as_script = true
#=╠═╡
@skipexpr [
	:(using MacroTools),
	:(using Requires),
]
  ╠═╡ =#

# ╔═╡ a3102851-32f0-4ddd-97d2-4c6650b94dcd
macro fromparent(ex)
	calling_file = String(__source__.file)
	esc(fromparent(ex, calling_file, __module__))
end

# ╔═╡ 3208acb4-9a54-41e9-910f-d98206dc80a2
export @fromparent, @skipexpr

# ╔═╡ 43783ef3-3d0f-4a70-9b4f-cfbf3e5b1673
# ╠═╡ skip_as_script = true
#=╠═╡
@fromparent import module
  ╠═╡ =#

# ╔═╡ e4175daf-bef5-4d91-9794-85458371d03d
md"""
# Process Functions
"""

# ╔═╡ 09f7ce21-382d-44ba-adaf-15ce787acb65
md"""
## Basic skip/remove
"""

# ╔═╡ 1cab8cea-04b0-4531-89cd-cf8c296ed9a4
_skip(ex) = Expr(:__skip_expr__, ex)

# ╔═╡ 2f0877d4-bdb3-4009-a117-c47de34059b9
_remove(ex) = Expr(:__remove_expr__, ex)

# ╔═╡ 38744425-14e4-4228-99cb-965b96490100
can_skip(ex) = Meta.isexpr(ex, [:__skip_expr__, :__remove_expr__])

# ╔═╡ 30fbe651-9849-40e6-ad44-7d5a1a0e5097
md"""
## parseinput
"""

# ╔═╡ 3756fc1e-b64c-4fe5-bf7b-cc6094fc00a7
# This fuction parse the input and return the path to access the module to import from
function parseinput(ex, dict)
	Meta.isexpr(ex, [:import, :using]) || error("Only import or using statements are supported as input to the `@fromparent` macro")
	# Get the path to access the parent module of the calling function
	parentpath = filter([:_PackageModule_, dict["Module Path"]...]) do name
		return !(name == Symbol(dict["name"]))
	end
	catchall = false
	if Meta.isexpr(ex.args[1], :(:))
		# We have a list of imported names from a module, let's force the import and check if it's a catchall
		ex.head = :import
		modname = ex.args[1]
		# We find how many levels up it goes in the hierarchy
		Meta.isexpr(modname, :(.)) && modname.args[1] == :(.) || error("We are expecting expression of the type `import .NAME: vars...`")
		for arg in modname.args[2:end]
		end
		imported_names = ex.args[2:end]
	else
		name = ex.args[1].args[1]
		length(ex.args) == 1 && name ∈ (:(*), :module) || error("When calling the macro without specifying which variables to import, you can only use `*` or `module` as arguments, you gave $(ex.args)")
		if name == :module
			ex = nothing
		else
			catchall = true
		end
	end
	return ex, parentpath, catchall
end

# ╔═╡ df992d64-4990-4d51-a6bd-831844371617
# ╠═╡ skip_as_script = true
#=╠═╡
module GESURE
	a(x) = 3+x
	module MADONNA
		import ..GESURE: a
		b = a(50)
	end
end
  ╠═╡ =#

# ╔═╡ cbf5c05a-e0ed-46a4-9533-d7dad5434402
#=╠═╡
GESURE.MADONNA.b
  ╠═╡ =#

# ╔═╡ 76dbf4fd-8c4d-4af2-ac17-efb5b51aae76
md"""
## Extract File AST
"""

# ╔═╡ ccbd8186-c075-4321-9289-e0b320f338ba
# ╠═╡ skip_as_script = true
#=╠═╡
let
	code = read("/home/amengali/Repos/github/mine/PlutoDevMacros/notebooks/basics.jl", String)
	ast = Meta.parseall(code)
	ast.args
end
  ╠═╡ =#

# ╔═╡ 061aecc5-b893-4866-8f2a-605e1dcfffec
function extract_file_ast(filename)
	code = read(filename, String)
	ast = Meta.parseall(code; filename)
	@assert Meta.isexpr(ast, :toplevel)
	ast
end

# ╔═╡ 54508213-9956-4a94-ac5b-9a9be6ea8959
md"""
## getfirst
"""

# ╔═╡ 5fbbed80-6235-4d9d-b3ca-fac179e80568
function getfirst(p, itr)
    for el in itr
        p(el) && return el
    end
    return nothing
end

# ╔═╡ 0bc1743a-b672-4310-8198-bcc754b30fc4
md"""
## Remove Pluto exprs
"""

# ╔═╡ 6160fd21-6fe8-40fb-89fe-f86a1b945099
function isbind(ex)
	ex isa Expr || return false
	ex.head == :(=) && return isbind(ex.args[2])
	ex.head == :macrocall && ex.args[1] == Symbol("@bind") && return true
	return false
end

# ╔═╡ b66e9c72-00d9-4af5-9f27-02c0c9aff5e6
# ╠═╡ skip_as_script = true
#=╠═╡
isbind(:(a = @bind a LOL))
  ╠═╡ =#

# ╔═╡ 8b1f3a72-2d3f-4546-8f2b-4ae13bb6a2a9
function remove_pluto_exprs(ex, dict)
	# ex.head == :macro && ex.args[1] == :(bind(def, element)) && return nothing, false
	ex.head == :(=) && ex.args[1] ∈ (:PLUTO_PROJECT_TOML_CONTENTS, :PLUTO_MANIFEST_TOML_CONTENTS) && return _remove(ex), false
	# isbind(ex) && return Expr(:throw_error, :bind), false
	return ex, false
end

# ╔═╡ eedf9fb4-3371-4c98-8d97-3d925ccf3cc0
md"""
## Remove Custom Exprs
"""

# ╔═╡ 47e76b6f-8440-49b9-8aca-015a706da947
function remove_custom_exprs(ex, dict)
	exprs = dict["Expr to Remove"]
	newex = ex ∈ exprs ? _remove(ex) : ex
	return newex, false
end

# ╔═╡ 08816d5b-7f26-46bf-9b0b-c20e195cf326
md"""
## Skip basic exprs
"""

# ╔═╡ 8385962e-8397-4e5b-be98-86a4398c455d
# Check if the provided Expr is internally generating another Expr (like a quote)
function skip_basic_exprs(ex, dict)
	# We skip everything that is not an expr
	ex isa Expr || return (_skip(ex), false)
	# We skip Expr/quote inside the Expr
	ex.head == :call && ex.args[1] == :Expr && return (_skip(ex), false)
	ex.head == :quote && return (_skip(ex), false)
	# We leave the rest untouched
	return (ex, false)
end	

# ╔═╡ 2178c9bf-6128-40f8-9050-492e22cf55e7
md"""
## Extract Package Names
"""

# ╔═╡ 96768bc9-f233-44e1-b833-7a39acaf111e
function extract_packages(ex, dict)
	ex.head ∈ (:using, :import) || return ex, false
	arg = ex.args[1]
	arg = arg.head == :(:) ? arg.args[1] : arg
	arg.head == :(.) || error("Something unexpected happened")
	# If the import or using is of the type `import .NAME: something` we ignore it as it's not a package but a local module
	arg.args[1] == :(.) && return ex, false
	skip_names = (:Main, :Core, :Base)
	mod_name = getfirst(x -> x ∉ skip_names, arg.args)
	mod_name isa Nothing && return ex, false
	package_set = get!(dict, "discovered packages", Set{Symbol}())
	push!(package_set, mod_name)
	return ex, false
end

# ╔═╡ 5d1d9139-b5fa-4b82-a9fa-f025de82012b
md"""
## Process include
"""

# ╔═╡ 26c97491-f315-4a9c-a93d-603c4e1a21f9
md"""
## update module path
"""

# ╔═╡ ca1ea13c-ecee-4517-9176-679ec9f4e585
function update_module_path(ex, dict)
	Meta.isexpr(ex, :module) || return (ex, false)
	path = dict["Module Path"]
	module_name = ex.args[2]
	
	if isempty(path) || first(path) != module_name 
		# Add the current module to the path
		pushfirst!(path, module_name)
	else
		# Remove the current module from the path
		popfirst!(path)
	end

	return ex, false
end

# ╔═╡ 4ec1a33e-c409-4047-853c-722a058768c9
md"""
## Process ast
"""

# ╔═╡ 3553578a-aac1-452c-bea2-5c1917f61cd3
function can_remove_args(ex)
	Meta.isexpr(ex, [:parameters, :return]) && return false
	return true
end

# ╔═╡ 98779ff3-46d6-4ae5-98d6-bd5f7ae96504
md"""
## clearn args
"""

# ╔═╡ 6a270c77-5f32-496c-8dcb-361e7039b311
function clean_args!(newargs)
	last_invalid = 0
	for i ∈ reverse(eachindex(newargs))
		arg = newargs[i]
		if Meta.isexpr(arg, :__skip_expr__)
			# We remove the wrapper
			newargs[i] = arg.args[1]
		elseif Meta.isexpr(arg, :__remove_expr__)
			deleteat!(newargs, i)
			last_invalid = i
		elseif arg isa LineNumberNode
			last_invalid == i+i && deleteat!(newargs, i)
			last_invalid = i
		end
	end
end

# ╔═╡ 93a422c6-2948-434f-81bf-f4c74dc16e0f
function process_ast(ex, dict)
	# We try to add the module to the path
	update_module_path(ex, dict)
	target_found = false
	for f in (skip_basic_exprs, remove_custom_exprs, remove_pluto_exprs, extract_packages, process_include)
		ex, target_found = f(ex, dict)
		can_skip(ex) && return ex, target_found
	end
	# Process all arguments
	last_idx = 0
	newargs = ex.args
	for (i,arg) in enumerate(newargs)
		newarg, target_found = process_ast(arg, dict)
		newargs[i] = newarg
		if target_found
			last_idx = i
			break
		end
	end
	if target_found && last_idx > 0 && last_idx != lastindex(newargs)
		newargs = newargs[1:last_idx]
	end
	# Remove the linunumbernodes that are directly before another nothing or LinuNumberNode
	clean_args!(newargs)

	
	# We try to remove the module from the path
	update_module_path(ex, dict)
	return (Expr(ex.head, newargs...), target_found)
end

# ╔═╡ d2944e2d-3f3f-4482-a052-5ea147f193d9
function extract_module_expression(filename, _module)
	data = get_parent_data(filename)
	# We check if there are specific expressions that we want to avoid
	get!(data, "Expr to Remove") do
		if isdefined(_module, _skip_expr_var_name)
			Core.eval(_module, _skip_expr_var_name)
		else
			Expr[]
		end
	end
	
	ast = extract_file_ast(data["file"])
	logger = EarlyFilteredLogger(current_logger()) do log
		log.level > Logging.Debug ? true : false
	end
	ex, found = let
	# ex, found = with_logger(logger) do
		process_ast(ast, data)
	end
	mod_exp = getfirst(x -> Meta.isexpr(x, :module), ex.args)
	mod_exp, data
end

# ╔═╡ 7948ab6f-ee62-4c41-a2c0-74f1c25a87ce
# ╠═╡ skip_as_script = true
#=╠═╡
extract_module_expression(@__FILE__, @__MODULE__)[2]
  ╠═╡ =#

# ╔═╡ 61871032-7ab7-4066-983c-04d3acdd954d
function maybe_load_module(calling_file, _module)
	# We try to see if the module was already created in this workspace
	packagemodule = let
		out = nothing
		for sym in names(_module; all=true)
			startswith(String(sym), "##packagemodule") || continue
			out = getproperty(_module, sym)
			break
		end
		out
	end
	# if Base.isdefined(_module, :_PackageModule_)
	if !(packagemodule isa Nothing)
		return Expr(:block), packagemodule
	else
		mod_exp, dict = extract_module_expression(calling_file, _module)
		asd = if length(split(calling_file, "#==#")) == 1
			# This is not a notebook
		else
			# This is a notebook, so we check the dependencies
			proj_file = Core.eval(_module, :(Base.active_project()))
			notebook_project = TOML.parsefile(proj_file)
			notebook_deps =  Set(map(Symbol, keys(notebook_project["deps"]) |> collect))
			missing_packages = setdiff(dict["discovered packages"], notebook_deps, Set([:Markdown, :Random, :InteractiveUtils]))
			if !isempty(missing_packages)
				error("""The following packages are used in the parent module but are not currently imported in this notebook's environment:
				$(collect(missing_packages))
				Consider adding those in a cell with:
				`import $(join(collect(missing_packages),", "))`
				""")
			end
			# We create the module with a gensym name
			s = gensym(:packagemodule)
			mod_exp.args[2] = s
			__module = Core.eval(_module, mod_exp)
			__module._fromparent_dict_ = dict
			block = quote
				_PackageModule_ = $__module
			end
			return block, __module
		end
	end
end

# ╔═╡ bc89433c-1fad-4653-8e98-2ab98360529f
function process_include(ex, dict)
	ex.head === :call && ex.args[1] == :include || return ex, false
	filename = ex.args[2]
	if !(filename isa String) 
		@warn "Only calls to include which are given direct strings are supported, instead $ex was found as expression"
		return ex, false
	end
	srcdir = joinpath(dict["dir"], "src")
	fullpath = startswith(filename, srcdir) ? filename : normpath(joinpath(srcdir, filename))
	is_target = fullpath == dict["target"]
	if is_target
		return nothing, true
	else
		# We directly process the include and return the processed expression
		ast = extract_file_ast(fullpath)
		newex, found = process_ast(ast, dict)
		return _skip(newex), found
	end
end

# ╔═╡ 3db3a103-26f2-4b63-8be0-226ec5df4cc9
md"""
## filterednames
"""

# ╔═╡ 0225f847-a8bf-45c0-b208-71d8547f0d3d
function filterednames(m::Module)
	excluded = (:eval, :include, :_fromparent_dict_, nameof(m))
	filter(names(m;all=true)) do s
		Base.isgensym(s) && return false
		s in excluded && return false
		return true
	end
end

# ╔═╡ 345119ec-5d5d-41bf-9380-1ae684921061
macro addmodule(ex)
	s = gensym()
	modexpr = :(module $s $ex end)
	m = Core.eval(__module__, modexpr)
	all_names = filterednames(m)
	imports = :(import .GESU)
	imports.args[1] = Expr(:(:), imports.args[1], map(all_names) do name
		Expr(:(.), name)
	end...)
	quote
		GESU = $m
		$imports
	end |> esc
end

# ╔═╡ 7137267a-93c2-410c-a7ad-4217b6bfbafb
# ╠═╡ skip_as_script = true
#=╠═╡
@macroexpand @addmodule begin
	a = 2
	b = 5
end
  ╠═╡ =#

# ╔═╡ d7266a18-be15-4aab-a299-c39ea98464fb
# ╠═╡ skip_as_script = true
#=╠═╡
@addmodule begin
	a = 2
	b = 5
end
  ╠═╡ =#

# ╔═╡ 134981ec-c43f-4be0-b06e-a881b7a8f8dd
#=╠═╡
a
  ╠═╡ =#

# ╔═╡ 30c5de94-b453-454a-a3fd-93b86c45c7f1
function fromparent(ex, calling_file, _module)
	# Construct the basic block where the module is import under name _PackageModule_. The module is only parsed if _PackageModule_ is not already defined in the calling module
	block, _PackageModule_ = maybe_load_module(calling_file, _module)
	# We extract the parse dict
	dict = _PackageModule_._fromparent_dict_
	# We parse the input expr, for now just to verify that the catchall expression is provided, otherwise an error is thrown
	exout, parentpath, catchall = parseinput(ex, dict)

	exout isa Nothing && return block
	parentmodule = _PackageModule_
	for sym ∈ parentpath[2:end]
		parentmodule = getproperty(parentmodule, sym)
	end
	# Extract all names to import
	to_import = filterednames(parentmodule)
	# We create the expression to import all the names
	
	if isempty(to_import)
		@warn "The parent module has no name to import"
	else
		import_expr = Expr(:(:), Expr(:(.), :(.), parentpath...), map(x -> Expr(:(.), x), to_import)...)
		# Add this expr to the block
		push!(block.args, Expr(:import, import_expr))
	end
	return block
end

# ╔═╡ 36601158-bb28-4800-8972-559e822bcabf
# ╠═╡ skip_as_script = true
#=╠═╡
let
	# fromparent(:(import *),"/home/amengali/Repos/github/mine/PlutoExtras/src/latex_equations.jl#==#", @__MODULE__)
	fromparent(:(import *),@__FILE__, @__MODULE__)
end
  ╠═╡ =#

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
HypertextLiteral = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
LoggingExtras = "e6f89c97-d47a-5376-807f-9c37f3926c36"
PlutoExtras = "ed5d0301-4775-4676-b788-cf71e66ff8ed"
TOML = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[compat]
BenchmarkTools = "~1.3.2"
HypertextLiteral = "~0.9.4"
LoggingExtras = "~1.0.0"
PlutoExtras = "~0.7.1"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.9.0-rc1"
manifest_format = "2.0"
project_hash = "c4293f1276b2768ebf1a798ebaa78478b5b935fb"

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
git-tree-sha1 = "6f4fbcd1ad45905a5dee3f4256fabb49aa2110c6"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.5.7"

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
git-tree-sha1 = "096d420f1588d0cebb8020ce3c32d1d7c3420794"
uuid = "ed5d0301-4775-4676-b788-cf71e66ff8ed"
version = "0.7.1"

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
# ╠═7e440c22-c1e0-493e-aa62-a30183f18bae
# ╠═7f164c6d-1b27-4805-ae03-6a82a8390c16
# ╠═60aecd17-82c9-4a64-ad99-310e502c5a5e
# ╠═5722e2db-881f-4ec2-98ec-220654a4e7ae
# ╠═5f1db2c0-4ab5-4391-a15b-8331f9b649d7
# ╠═4e1e0305-7cda-4272-904a-2aa7add72cb5
# ╠═74b3f945-39af-463f-9f0a-ba1c7adc526c
# ╠═345119ec-5d5d-41bf-9380-1ae684921061
# ╠═9a3ef442-9905-431a-8e18-f72c9acba5e8
# ╠═520e5abb-46aa-4dd6-91e5-3b4781e5dbd7
# ╠═d2944e2d-3f3f-4482-a052-5ea147f193d9
# ╠═7948ab6f-ee62-4c41-a2c0-74f1c25a87ce
# ╠═3208acb4-9a54-41e9-910f-d98206dc80a2
# ╠═10b633a4-14ab-4eff-b503-9841d9ffe175
# ╠═d1b36c20-63d0-4105-9418-cdb05645ca99
# ╠═36601158-bb28-4800-8972-559e822bcabf
# ╠═61871032-7ab7-4066-983c-04d3acdd954d
# ╠═30c5de94-b453-454a-a3fd-93b86c45c7f1
# ╠═a3102851-32f0-4ddd-97d2-4c6650b94dcd
# ╠═43783ef3-3d0f-4a70-9b4f-cfbf3e5b1673
# ╟─e4175daf-bef5-4d91-9794-85458371d03d
# ╟─09f7ce21-382d-44ba-adaf-15ce787acb65
# ╠═1cab8cea-04b0-4531-89cd-cf8c296ed9a4
# ╠═2f0877d4-bdb3-4009-a117-c47de34059b9
# ╠═38744425-14e4-4228-99cb-965b96490100
# ╟─30fbe651-9849-40e6-ad44-7d5a1a0e5097
# ╠═3756fc1e-b64c-4fe5-bf7b-cc6094fc00a7
# ╠═df992d64-4990-4d51-a6bd-831844371617
# ╠═cbf5c05a-e0ed-46a4-9533-d7dad5434402
# ╟─76dbf4fd-8c4d-4af2-ac17-efb5b51aae76
# ╠═ccbd8186-c075-4321-9289-e0b320f338ba
# ╠═061aecc5-b893-4866-8f2a-605e1dcfffec
# ╠═54508213-9956-4a94-ac5b-9a9be6ea8959
# ╠═5fbbed80-6235-4d9d-b3ca-fac179e80568
# ╟─0bc1743a-b672-4310-8198-bcc754b30fc4
# ╠═6160fd21-6fe8-40fb-89fe-f86a1b945099
# ╠═b66e9c72-00d9-4af5-9f27-02c0c9aff5e6
# ╠═8b1f3a72-2d3f-4546-8f2b-4ae13bb6a2a9
# ╟─eedf9fb4-3371-4c98-8d97-3d925ccf3cc0
# ╠═47e76b6f-8440-49b9-8aca-015a706da947
# ╠═08816d5b-7f26-46bf-9b0b-c20e195cf326
# ╠═8385962e-8397-4e5b-be98-86a4398c455d
# ╟─2178c9bf-6128-40f8-9050-492e22cf55e7
# ╠═96768bc9-f233-44e1-b833-7a39acaf111e
# ╟─5d1d9139-b5fa-4b82-a9fa-f025de82012b
# ╠═bc89433c-1fad-4653-8e98-2ab98360529f
# ╟─26c97491-f315-4a9c-a93d-603c4e1a21f9
# ╠═ca1ea13c-ecee-4517-9176-679ec9f4e585
# ╟─4ec1a33e-c409-4047-853c-722a058768c9
# ╠═3553578a-aac1-452c-bea2-5c1917f61cd3
# ╠═93a422c6-2948-434f-81bf-f4c74dc16e0f
# ╟─98779ff3-46d6-4ae5-98d6-bd5f7ae96504
# ╠═6a270c77-5f32-496c-8dcb-361e7039b311
# ╠═7137267a-93c2-410c-a7ad-4217b6bfbafb
# ╠═d7266a18-be15-4aab-a299-c39ea98464fb
# ╠═134981ec-c43f-4be0-b06e-a881b7a8f8dd
# ╟─3db3a103-26f2-4b63-8be0-226ec5df4cc9
# ╠═0225f847-a8bf-45c0-b208-71d8547f0d3d
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002