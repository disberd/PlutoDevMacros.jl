### A Pluto.jl notebook ###
# v0.19.25

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

# ╔═╡ 661e0d86-9675-4c24-a898-5ffee2e32029
begin
	using MacroTools
end

# ╔═╡ e3d5c718-d98c-4d53-8fc9-911be34c9f2d
# ╠═╡ skip_as_script = true
#=╠═╡
begin
	using BenchmarkTools
	import PlutoDevMacros
end
  ╠═╡ =#

# ╔═╡ 47c42d27-88f1-4a27-bda9-54a2439b09a1
# ╠═╡ skip_as_script = true
#=╠═╡
include("basics.jl")
  ╠═╡ =#

# ╔═╡ 5089d8dd-6587-4172-9ffd-13cf43e8c341
# ╠═╡ skip_as_script = true
#=╠═╡
md"""
## Main Functions
"""
  ╠═╡ =#

# ╔═╡ b87d12be-a37b-4202-9426-3eef14d8253c
function ingredients(path::String)
	# this is from the Julia source code (evalfile in base/loading.jl)
	# but with the modification that it returns the module instead of the last object
	name = Symbol("#plutoinclude_",basename(path))
	m = Module(name)
	Core.eval(m,
        Expr(:toplevel,
             :(eval(x) = $(Expr(:core, :eval))($name, x)),
             :(include(x) = $(Expr(:top, :include))($name, x)),
             :(include(mapexpr::Function, x) = $(Expr(:top, :include))(mapexpr, $name, x)),
			 :(using PlutoDevMacros: @plutoinclude), # This is needed for nested @plutoinclude calls
             :(include($path))))
	m
end

# ╔═╡ 57efc195-6a2f-4ad3-94fd-53e884838789
# ╠═╡ skip_as_script = true
#=╠═╡
md"""
# Other Ingredients Helpers
"""
  ╠═╡ =#

# ╔═╡ aa28b5d8-e0d7-4b97-9220-b61a0c5f4fc4
html_reload_button() = html"""
<div class="plutoinclude_banner">
	Reload @pluto_include
</div>
<script>
	const cell = currentScript.closest('pluto-cell')

	const onClick = (e) => {
		console.log(e)
		if (e.ctrlKey) {
			history.pushState({},'')			
			cell.scrollIntoView({
				behavior: 'smooth',
				block: 'center',				
			})
		} else {
			cell.querySelector('button.runcell').click()
		}
	}
	const banner = cell.querySelector(".plutoinclude_banner")

	banner.addEventListener('click',onClick)
	invalidation.then(() => banner.removeEventListener('click',onClick))
</script>
<style>
	.plutoinclude_banner {
	    height: 20px;
	    position: fixed;
	    top: 40px;
		right: 10px;
	    margin-top: 5px;
	    padding-right: 5px;
	    z-index: 200;
		background: #ffffff;
	    padding: 5px 8px;
	    border: 3px solid #e3e3e3;
	    border-radius: 12px;
	    height: 35px;
	    font-family: "Segoe UI Emoji", "Roboto Mono", monospace;
	    font-size: 0.75rem;
	}
	.plutoinclude_banner:hover {
	    font-weight: 800;
		cursor: pointer;
	}
	body.disable_ui .plutoinclude_banner {
		display: none;
	}
	main 
</style>
"""

# ╔═╡ 98b1fa0d-fad1-4c4f-88a0-9452d492c4cb
function include_expr(from::Module,kwargstrs::String...; to::Module)
	modname = Symbol("#plutoincluded_module")
	ex = Expr(:block, :(const $modname = $from))
	kwargs = (Symbol(s) => true for s ∈ kwargstrs if s ∈ ("all","imported"))
	varnames = names(from;kwargs...)
	# Remove the symbols that start with a '#' (still to check what is the impact)
	filter!(!Base.isgensym,varnames)
	# Symbols to always exclude from imports
	exclude_names = (
			nameof(from),
			:eval,
			:include,
			Symbol("@bind"),
			Symbol("@plutoinclude"), # Since we included this in the module
		)
	for s ∈ varnames
		if s ∉ exclude_names
			if getfield(from,s) isa Function
				# _copymethods!(ex, s; to, from, importedlist = varnames, fromname = modname)
				ret_types = Base.return_types(getfield(from,s))
				candidate_type = ret_types[1]
				# Get the eventual docstring
				docstring = Base.doc(Base.Docs.Binding(from, s))
				if all(x -> x === candidate_type, ret_types) && Base.isconcretetype(candidate_type)
					push!(ex.args, :(@doc ($docstring) $s(args...; kwargs...)::$candidate_type = $modname.$s(args...; kwargs...)))
				else
					push!(ex.args, :(@doc ($docstring) $s(args...; kwargs...) = $modname.$s(args...; kwargs...)))
				end
			else
				push!(ex.args,:(const $s = $modname.$s))
			end
		end
	end
	# Add the html to re-run the cell
	push!(ex.args,:($(html_reload_button())))
	ex
end

# ╔═╡ 872bd88e-dded-4789-85ef-145f16003351
"""
	@plutoinclude path nameskwargs...
	@plutoinclude modname=path namekwargs...

This macro is used to include external julia files inside a pluto notebook and is inspired by the discussion on [this Pluto issue](https://github.com/fonsp/Pluto.jl/issues/1101).

It requires Pluto >= v0.17.0 and includes and external file, taking care of putting in the caller namespace all varnames that are tagged with `export varname` inside the included file.

The macro relies on the use of [`names`](@ref) to get the variable names to be exported, and support providing the names of the keyword arguments of `names` to be set to true as additional strings 

When called from outside Pluto, it simply returns nothing
"""
macro plutoinclude(ex,kwargstrs...)
	path = ex isa String ? ex : Base.eval(__module__,ex)
	if is_notebook_local(__source__.file::Symbol |> String)
		# If this is called directly from the notebook, do the hack to export the various variables from the module
		m = ingredients(path)
		esc(include_expr(m,kwargstrs...; to = __module__))
	elseif first(nameof(__module__) |> String, 13) == "#plutoinclude"
		# We are in a chained plutoinclude, simply include the subfile	
		:(include($path)) |> esc
	else
		# We are not in the notebook and not in a chained include, so do nothing
		nothing
	end
end

# ╔═╡ 748b8eab-2f3d-4afd-bfb4-fee3240d391b
export @plutoinclude

# ╔═╡ 1f291bd2-9ab1-4fd2-bf50-49253726058f
# ╠═╡ skip_as_script = true
#=╠═╡
md"""
## Example Use
"""
  ╠═╡ =#

# ╔═╡ cf0d13ea-7562-4b8c-b7e6-fb2f1de119a7
# ╠═╡ skip_as_script = true
#=╠═╡
md"""
The cells below assume to also have the test notebook `ingredients_include_test.jl` from PlutoUtils in the same folder, download it and put it in the same folder in case you didn't already
"""
  ╠═╡ =#

# ╔═╡ bd3b021f-db44-4aa1-97b2-04002f76aeff
# ╠═╡ skip_as_script = true
#=╠═╡
notebook_path = "./plutoinclude_test.jl"
  ╠═╡ =#

# ╔═╡ 0e3eb73f-091a-4683-8ccb-592b8ccb1bee
# ╠═╡ skip_as_script = true
#=╠═╡
md"""
Try changing the content of the included notebook by removing some exported variables and re-execute (**using Shift-Enter**) the cell below containing the @plutoinclude call to see that variables are correctly updated.

You can also try leaving some variable unexported and still export all that is defined in the notebook by using 
```julia
@plutoinclude notebook_path "all"
```

Finally, you can also assign the full imported module in a specific variable by doing
```julia
@plutoinclude varname = notebook_path
```
"""
  ╠═╡ =#

# ╔═╡ d2ac4955-d2a0-48b5-afcb-32baa59ade21
# ╠═╡ skip_as_script = true
#=╠═╡
@plutoinclude notebook_path "all"
  ╠═╡ =#

# ╔═╡ 0d1f5079-a886-4a07-9e99-d73e0b8a2eec
# ╠═╡ skip_as_script = true
#=╠═╡
@macroexpand @plutoinclude notebook_path "all"
  ╠═╡ =#

# ╔═╡ 50759ca2-45ca-4005-9182-058a5cb68359
# ╠═╡ skip_as_script = true
#=╠═╡
const mm = ingredients(notebook_path)
  ╠═╡ =#

# ╔═╡ 4cec781b-c6d7-4fd7-bbe3-f7db0f973698
# ╠═╡ skip_as_script = true
#=╠═╡
a
  ╠═╡ =#

# ╔═╡ a7e7123f-0e7a-4771-9b9b-d0da97fefcef
# ╠═╡ skip_as_script = true
#=╠═╡
b
  ╠═╡ =#

# ╔═╡ 2c41234e-e1b8-4ad8-9134-85cd65a75a2d
# ╠═╡ skip_as_script = true
#=╠═╡
c
  ╠═╡ =#

# ╔═╡ ce2a2025-a6e0-44ab-8631-8d308be734a9
# ╠═╡ skip_as_script = true
#=╠═╡
d
  ╠═╡ =#

# ╔═╡ d8be6b4c-a02b-43ec-b176-de6f64fefd87
# ╠═╡ skip_as_script = true
#=╠═╡
# Extending the method
asd(s::String) = "STRING"
  ╠═╡ =#

# ╔═╡ 8090dd72-a47b-4d9d-85df-ceb0c1bcedf5
# ╠═╡ skip_as_script = true
#=╠═╡
asd(3)
  ╠═╡ =#

# ╔═╡ 61924e22-f052-43a5-84b1-5512d222af26
# ╠═╡ skip_as_script = true
#=╠═╡
@benchmark asd(TestStruct())
  ╠═╡ =#

# ╔═╡ d1fbe484-dcd0-456e-8ec1-c68acd708a08
# ╠═╡ skip_as_script = true
#=╠═╡
asd(TestStruct())
  ╠═╡ =#

# ╔═╡ 8df0f262-faf2-4f99-98e2-6b2a47e5ca31
# ╠═╡ skip_as_script = true
#=╠═╡
asd(TestStruct(),3,4)
  ╠═╡ =#

# ╔═╡ 1754fdcf-de3d-4d49-a2f0-9e3f4aa3498e
# ╠═╡ skip_as_script = true
#=╠═╡
asd("S")
  ╠═╡ =#

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
MacroTools = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
PlutoDevMacros = "a0499f29-c39b-4c5c-807c-88074221b949"

[compat]
BenchmarkTools = "~1.3.2"
MacroTools = "~0.5.10"
PlutoDevMacros = "~0.5.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.9.0-rc3"
manifest_format = "2.0"
project_hash = "b329ce92ad28a8475022c6a7c95009120252febc"

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

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "c47c5fa4c5308f27ccaac35504858d8914e102f9"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.4"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

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

[[deps.Tricks]]
git-tree-sha1 = "aadb748be58b492045b4f56166b5188aa63ce549"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.7"

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
version = "5.7.0+0"

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
# ╠═661e0d86-9675-4c24-a898-5ffee2e32029
# ╠═e3d5c718-d98c-4d53-8fc9-911be34c9f2d
# ╠═748b8eab-2f3d-4afd-bfb4-fee3240d391b
# ╠═47c42d27-88f1-4a27-bda9-54a2439b09a1
# ╟─5089d8dd-6587-4172-9ffd-13cf43e8c341
# ╠═b87d12be-a37b-4202-9426-3eef14d8253c
# ╟─57efc195-6a2f-4ad3-94fd-53e884838789
# ╠═98b1fa0d-fad1-4c4f-88a0-9452d492c4cb
# ╠═872bd88e-dded-4789-85ef-145f16003351
# ╠═aa28b5d8-e0d7-4b97-9220-b61a0c5f4fc4
# ╟─1f291bd2-9ab1-4fd2-bf50-49253726058f
# ╟─cf0d13ea-7562-4b8c-b7e6-fb2f1de119a7
# ╠═bd3b021f-db44-4aa1-97b2-04002f76aeff
# ╟─0e3eb73f-091a-4683-8ccb-592b8ccb1bee
# ╠═d2ac4955-d2a0-48b5-afcb-32baa59ade21
# ╠═0d1f5079-a886-4a07-9e99-d73e0b8a2eec
# ╠═8090dd72-a47b-4d9d-85df-ceb0c1bcedf5
# ╠═61924e22-f052-43a5-84b1-5512d222af26
# ╠═50759ca2-45ca-4005-9182-058a5cb68359
# ╠═4cec781b-c6d7-4fd7-bbe3-f7db0f973698
# ╠═a7e7123f-0e7a-4771-9b9b-d0da97fefcef
# ╠═2c41234e-e1b8-4ad8-9134-85cd65a75a2d
# ╠═ce2a2025-a6e0-44ab-8631-8d308be734a9
# ╠═d1fbe484-dcd0-456e-8ec1-c68acd708a08
# ╠═8df0f262-faf2-4f99-98e2-6b2a47e5ca31
# ╠═d8be6b4c-a02b-43ec-b176-de6f64fefd87
# ╠═1754fdcf-de3d-4d49-a2f0-9e3f4aa3498e
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
