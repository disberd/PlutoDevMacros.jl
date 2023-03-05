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
	parent_data["Nested Level"] = -1
	
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

# ╔═╡ f0ae8c36-875a-412e-8d84-e8d0aeb7b12f


# ╔═╡ 9a3ef442-9905-431a-8e18-f72c9acba5e8
_skip_expr_var_name = :__parent_import_expr_to_remove__

# ╔═╡ 520e5abb-46aa-4dd6-91e5-3b4781e5dbd7
macro skipexpr(ex)
	esc(Expr(:(=), _skip_expr_var_name, ex))
end

# ╔═╡ 0176659b-20bf-403b-8d7d-b34b6c32d9b7
@skipexpr [
	:(using MacroTools),
	:(using Requires),
]

# ╔═╡ 9fe8c054-07c0-43ab-8560-f90ce69e88d4
macro gesure(ex)
	dump(ex)
end

# ╔═╡ e4175daf-bef5-4d91-9794-85458371d03d
md"""
# Process Functions
"""

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
	# If we are inside a module, we also only focus on the block of instructions within the module
	# Meta.isexpr(ast, :module) ? ast.args[3] : ast
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
	ex.head == :macro && ex.args[1] == :(bind(def, element)) && return nothing, false
	ex.head == :(=) && ex.args[1] ∈ (:PLUTO_PROJECT_TOML_CONTENTS, :PLUTO_MANIFEST_TOML_CONTENTS) && return nothing, false
	isbind(ex) && return Expr(:throw_error, :bind), false
	return ex, false
end

# ╔═╡ eedf9fb4-3371-4c98-8d97-3d925ccf3cc0
md"""
## Remove Custom Exprs
"""

# ╔═╡ 47e76b6f-8440-49b9-8aca-015a706da947
function remove_custom_exprs(ex, dict)
	exprs = dict["Expr to Remove"]
	newex = ex ∈ exprs ? nothing : ex
	return newex, false
end

# ╔═╡ 08816d5b-7f26-46bf-9b0b-c20e195cf326
md"""
## Skip Expr/quote
"""

# ╔═╡ 8385962e-8397-4e5b-be98-86a4398c455d
function is_Expr_call(ex)
	ex.head == :call && ex.args[1] == :Expr && return true
	ex.head == :quote && return true
	return false
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

# ╔═╡ 4ec1a33e-c409-4047-853c-722a058768c9
md"""
## Process ast
"""

# ╔═╡ 88717267-8057-4cd7-b04a-04936c2a3a9f
md"""
## Throw errors
"""

# ╔═╡ 182a1acb-93d2-4401-b05a-ed78358b1555
throw_error(ln::LineNumberNode, ::Val{:bind}) = error("A call to @bind was found in the imported notebook around $ln, please consider disabling the cell defining the bind from the file")

# ╔═╡ 98779ff3-46d6-4ae5-98d6-bd5f7ae96504
md"""
## clearn args
"""

# ╔═╡ 6a270c77-5f32-496c-8dcb-361e7039b311
function clean_args!(newargs)
	last_invalid = false
	error_type = :none
	for i ∈ reverse(eachindex(newargs))
		arg = newargs[i]
		if Meta.isexpr(arg, :throw_error)
			error_type = arg.args[1]
		elseif arg isa Nothing
			last_invalid = true
		elseif arg isa LineNumberNode
			error_type != :none && throw_error(arg, Val(error_type))
			# If last arg was nothing, we delete this
			if last_invalid
				newargs[i] = nothing
			else
				last_invalid = true
			end
		elseif Meta.isexpr(arg, :let) && length(arg.args) == 1
			# We deleted the second block in the let expression, we have to put it back
			pushfirst!(arg.args, Expr(:block))
		elseif Meta.isexpr(arg, :processed_toplevel)
			# We add all its args here
			splice!(newargs, i, arg.args)
			last_invalid = false
		# elseif Meta.isexpr(arg, :module) && length(arg.args) != 3
		# 	newargs[i] = nothing
		# 	last_invalid = true
		else
			last_invalid = false
		end
	end
	filter!(!isnothing, newargs)
end

# ╔═╡ 93a422c6-2948-434f-81bf-f4c74dc16e0f
function process_ast(ex, dict)
	ex isa Expr || return ex, false
	is_Expr_call(ex) && return ex, false
	nest_level = dict["Nested Level"]
	if Meta.isexpr(ex, :module)
		level = dict["Nested Level"] += 1
		dict["Parent Module"] = (;name = ex.args[2], level)
	end
	target_found = false
	for f in (remove_custom_exprs, remove_pluto_exprs, extract_packages, process_include)
		ex, target_found = f(ex, dict)
		ex isa Nothing && return nothing, target_found
	end
	if (ex.head == :processed_toplevel)
		# ex.head = :toplevel
		return ex, target_found
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
	dict["Nested Level"] = nest_level
	return (isempty(newargs) ? nothing : Expr(ex.head, newargs...), target_found)
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

# ╔═╡ a3102851-32f0-4ddd-97d2-4c6650b94dcd
macro parentimport()
	calling_file = String(__source__.file)
	mod_exp, dict = extract_module_expression(calling_file, __module__)
	# We create the module with a gensym name
	s = gensym(:parentimport)
	mod_exp.args[2] = s
	_module = Core.eval(__module__, mod_exp)
	quote
		_ImportedParent_ = $_module
	end |> esc
end

# ╔═╡ 55139837-501b-45b6-a075-7ce8da09fbf7
# ╠═╡ skip_as_script = true
#=╠═╡
@parentimport
  ╠═╡ =#

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
		newex, found = process_ast(Expr(:block, ast.args...), dict)
		return Expr(:processed_toplevel, newex.args...), found
	end
end

# ╔═╡ 0225f847-a8bf-45c0-b208-71d8547f0d3d
function filterednames(m::Module)
	excluded = (:eval, :include)
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
@macroexpand @addmodule begin
	a = 2
	b = 5
end

# ╔═╡ d7266a18-be15-4aab-a299-c39ea98464fb
@addmodule begin
	a = 2
	b = 5
end

# ╔═╡ 134981ec-c43f-4be0-b06e-a881b7a8f8dd
a

# ╔═╡ 2b1a2d33-4f5d-4faf-b755-7383864b85a8
#=╠═╡
filterednames(_ImportedParent_)
  ╠═╡ =#

# ╔═╡ 24322219-40c4-4dec-9a13-0d35b48b4f66
# ╠═╡ skip_as_script = true
#=╠═╡
dump(:(import .GESU: a))
  ╠═╡ =#

# ╔═╡ 134b7f5d-147b-4745-9241-1dd8b4782efa
md"""
## Find include
"""

# ╔═╡ 19c151fc-f43f-4f52-bd5a-706776259a64
function find_include(ast, filename)
	idx = 0
	for (i,ex) in enumerate(ast.args)
		ex isa LineNumberNode && continue
		M
	end
end

# ╔═╡ 06e0d5a8-7dd5-4da2-9f2d-53cd47dbfe50
#=╠═╡
data
  ╠═╡ =#

# ╔═╡ 991bd364-3412-4329-85bc-ed2d513540c7
# ╠═╡ skip_as_script = true
#=╠═╡
let
	data = Dict{String, Any}("dir" => "/home/amengali/Repos/github/mine/PlutoExtras", "target" => "")
	ast = extract_file_ast("/home/amengali/Repos/github/mine/PlutoExtras/src/PlutoExtras.jl")
	ex, _ = process_ast(ast, data)
	data
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

julia_version = "1.9.0-beta4"
manifest_format = "2.0"
project_hash = "1e1c774f94cd5d41eeebd85103603b533a18b27c"

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
version = "2.28.0+0"

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
version = "0.3.21+0"

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
# ╠═f0ae8c36-875a-412e-8d84-e8d0aeb7b12f
# ╠═9a3ef442-9905-431a-8e18-f72c9acba5e8
# ╠═520e5abb-46aa-4dd6-91e5-3b4781e5dbd7
# ╠═0176659b-20bf-403b-8d7d-b34b6c32d9b7
# ╠═d2944e2d-3f3f-4482-a052-5ea147f193d9
# ╠═a3102851-32f0-4ddd-97d2-4c6650b94dcd
# ╠═55139837-501b-45b6-a075-7ce8da09fbf7
# ╠═9fe8c054-07c0-43ab-8560-f90ce69e88d4
# ╠═2b1a2d33-4f5d-4faf-b755-7383864b85a8
# ╟─e4175daf-bef5-4d91-9794-85458371d03d
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
# ╟─4ec1a33e-c409-4047-853c-722a058768c9
# ╠═93a422c6-2948-434f-81bf-f4c74dc16e0f
# ╟─88717267-8057-4cd7-b04a-04936c2a3a9f
# ╠═182a1acb-93d2-4401-b05a-ed78358b1555
# ╟─98779ff3-46d6-4ae5-98d6-bd5f7ae96504
# ╠═6a270c77-5f32-496c-8dcb-361e7039b311
# ╠═7137267a-93c2-410c-a7ad-4217b6bfbafb
# ╠═d7266a18-be15-4aab-a299-c39ea98464fb
# ╠═134981ec-c43f-4be0-b06e-a881b7a8f8dd
# ╠═0225f847-a8bf-45c0-b208-71d8547f0d3d
# ╠═24322219-40c4-4dec-9a13-0d35b48b4f66
# ╟─134b7f5d-147b-4745-9241-1dd8b4782efa
# ╠═19c151fc-f43f-4f52-bd5a-706776259a64
# ╠═06e0d5a8-7dd5-4da2-9f2d-53cd47dbfe50
# ╠═991bd364-3412-4329-85bc-ed2d513540c7
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
