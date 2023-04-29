### A Pluto.jl notebook ###
# v0.17.2

# using Markdown
# using InteractiveUtils

# ╔═╡ ea96e5d7-7bc0-45cf-8bf1-4acfaf5507c9
# ╠═╡ skip_as_script = true
#=╠═╡
include("basics.jl")
  ╠═╡ =#

# ╔═╡ 0ba0aae0-5c29-449a-81db-a389baddf0dc
# ╠═╡ skip_as_script = true
#=╠═╡
#using PlutoDevMacros
  ╠═╡ =#

# ╔═╡ 2307b8e6-6308-4902-9921-135b85273f65
# ╠═╡ skip_as_script = true
#=╠═╡
import WhereTraits
  ╠═╡ =#

# ╔═╡ 9b6c7d3b-b70a-4cd4-9a77-f9b8d8501b9e
import MacroTools

# ╔═╡ 4495c328-5bff-41ec-97f3-2422ee8c7339
function _plutotraits(ex::Expr)
	if ex.head === :block && length(ex.args) == 2
		return _plutotraits(ex.args[2])
	elseif ex.head === :macrocall && ex.args[1] isa GlobalRef && ex.args[1].name === Symbol("@doc")
		ex.args[end], fname = _plutotraits(ex.args[end])
		return ex, fname
	else
		# We try to see if this expression is a function definition
		defdict = MacroTools.splitdef(ex)
		# If we reach this point, the expression is a funcdef or splitdef would error
		# Extract the linenumbernode from the definition
		body = defdict[:body]
		ln = body.args[1]
		# If the second arg is also a linenumbernode, remove the first on
		if body.args[2] isa LineNumberNode
			popfirst!(body.args)
		end
		# Add the call to traits
		# ex = Expr(:macrocall, Expr(:(.),:WhereTraits,QuoteNode(Symbol("@traits"))), ln, ex)
		ex = :(WhereTraits.@traits $(ex))
		# Change the line
		ex.args[2] = ln
		# push!(ex.args, ln, ex)
		return ex, defdict[:name]
	end
	error("The provided expression was not of the valid type")
end

# ╔═╡ b810a742-dda2-4bd0-b9d3-8b0b5ee7356c
"""
	@plutotraits f(args...;kwargs...) where {wargs..} = body...
Macro that allows to use the `WhereTraits.@traits` macro inside Pluto notebooks.

When ran inside a notebook, this reconstructs the expression `expr` one would get by calling
`WhereTraits.@traits f(args...;kwargs...) where {wargs..} = body...` but evaluates it in the top-level of the current workspace/module (using `Core.eval(__module__,Expr(:toplevel, expr))`).\\
This is needed to avoid Pluto's internal expression explorer throwing an error if multiple functions with the same name but different conditions are defined with `@traits` in separate cells.

The usual Pluto workaround of wrapping multiple definitions in a begin ... end does not work with @traits as every call to the @traits macro has to be executed at the top level.\\
This has the side-effect that function calls within the notebook are not re-computed automatically if the definition with `@plutotraits` is changed within the notebook.

When called outside of Pluto (or included in Pluto from another notebook using `@plutoinclude`), the macro simply resorts to calling directly the `Where.@traits` expression without resorting to the `Core.eval` call within the macro body.

See [`WhereTraits.@traits`](@ref) or [`https://github.com/schlichtanders/WhereTraits.jl`](https://github.com/schlichtanders/WhereTraits.jl) for understanding how to use the underlying `@traits` macro.
"""
macro plutotraits(expr)
	# Meta.dump(expr)
	ex, fname = try
		_plutotraits(expr)
	catch e
		# error("The macro only supports a single call to the `@traits` macro with optional docstrings (wrapped in a begin...end block))")
		error(e)
	end
	if is_notebook_local(String(__source__.file))
		Core.eval(__module__, Expr(:toplevel, ex))
		esc(fname)
	else
		esc(ex)
	end
end

# ╔═╡ 8f354575-6ca2-4f0f-9880-f50d785de8f9
export @plutotraits

# ╔═╡ d6e472a7-bbd3-4f18-aa27-7289e6c23eab
# ╠═╡ skip_as_script = true
#=╠═╡
@plutotraits begin
	"Test Documentation"
	g(a) where {iseven(a)} = "EVEN"
end
  ╠═╡ =#

# ╔═╡ e3c59dc8-6894-487a-ae98-62594fd149ef
# ╠═╡ skip_as_script = true
#=╠═╡
@plutotraits g(a) where {isodd(a)} = "ODD"
  ╠═╡ =#

# ╔═╡ 51bdae6a-7749-4bee-a6d0-b1055fab5ece
# ╠═╡ skip_as_script = true
#=╠═╡
g(2)
  ╠═╡ =#

# ╔═╡ c826aa1b-fd70-452c-9716-3bfc6066e590
# ╠═╡ skip_as_script = true
#=╠═╡
g(1)
  ╠═╡ =#

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
MacroTools = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
WhereTraits = "c9d4e05b-6318-49cb-9b56-e0e2b0ceadd8"

[compat]
MacroTools = "~0.5.9"
WhereTraits = "~1.0.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.7.0-rc2"
manifest_format = "2.0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "dce3e3fea680869eaa0b774b2e8343e9ff442313"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.40.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[deps.ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f74e9d5388b8620b4cee35d4c5a618dd4dc547f4"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.3.0"

[[deps.DataTypesBasic]]
deps = ["Compat"]
git-tree-sha1 = "4cff12742dcd7a8639da323abaf6bd4722abc312"
uuid = "83eed652-29e8-11e9-12da-a7c29d64ffc9"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[deps.ExprParsers]]
deps = ["Compat", "ProxyInterfaces", "SimpleMatch", "StructEquality"]
git-tree-sha1 = "03d3f97dad4bd2b10ca0febca5db6bef5e0b320a"
uuid = "c5caad1f-83bd-4ce8-ac8e-4b29921e994e"
version = "1.1.0"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "3d3e902b31198a27340d0bf00d6ac452866021cf"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.9"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.ProxyInterfaces]]
deps = ["Compat"]
git-tree-sha1 = "d85fef4db37288bd756c71d223e34406055b7414"
uuid = "9b3bf0c4-f070-48bc-ae01-f2584e9c23bc"
version = "1.0.0"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "4036a3bd08ac7e968e27c203d45f5fff15020621"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.1.3"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "Requires"]
git-tree-sha1 = "fca29e68c5062722b5b4435594c3d1ba557072a3"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "0.7.1"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.SimpleMatch]]
deps = ["Compat"]
git-tree-sha1 = "c1cc22bbe259ea4a159e30ff2cf5f01d378262e8"
uuid = "a3ae8450-d22f-11e9-3fe0-77240e25996f"
version = "1.0.0"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.StructEquality]]
deps = ["Compat"]
git-tree-sha1 = "6e951cd0585cbe8f4ceb1cb09d69332b9484fec9"
uuid = "6ec83bb0-ed9f-11e9-3b4c-2b04cb4e219c"
version = "1.1.0"

[[deps.Suppressor]]
git-tree-sha1 = "a819d77f31f83e5792a76081eee1ea6342ab8787"
uuid = "fd094767-a336-5f1f-9728-57cf17d0bbfb"
version = "0.2.0"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.WhereTraits]]
deps = ["Compat", "DataTypesBasic", "ExprParsers", "Markdown", "ProxyInterfaces", "Setfield", "SimpleMatch", "StructEquality", "Suppressor"]
git-tree-sha1 = "cb13380b76dbe6e68c433dcd097aca3325a26470"
uuid = "c9d4e05b-6318-49cb-9b56-e0e2b0ceadd8"
version = "1.0.0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
"""

# ╔═╡ Cell order:
# ╠═0ba0aae0-5c29-449a-81db-a389baddf0dc
# ╠═2307b8e6-6308-4902-9921-135b85273f65
# ╠═9b6c7d3b-b70a-4cd4-9a77-f9b8d8501b9e
# ╠═ea96e5d7-7bc0-45cf-8bf1-4acfaf5507c9
# ╠═8f354575-6ca2-4f0f-9880-f50d785de8f9
# ╠═b810a742-dda2-4bd0-b9d3-8b0b5ee7356c
# ╠═4495c328-5bff-41ec-97f3-2422ee8c7339
# ╠═d6e472a7-bbd3-4f18-aa27-7289e6c23eab
# ╠═e3c59dc8-6894-487a-ae98-62594fd149ef
# ╠═51bdae6a-7749-4bee-a6d0-b1055fab5ece
# ╠═c826aa1b-fd70-452c-9716-3bfc6066e590
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
