### A Pluto.jl notebook ###
# v0.19.27

#> custom_attrs = ["hide-enabled"]

using Markdown
using InteractiveUtils

# ╔═╡ d0e6a2b2-1e5d-11ee-177a-5f0a92dd83f5
begin
	plutodevmacros_project= Base.current_project(normpath(@__DIR__, "../..")) 
	# pushfirst!(LOAD_PATH, parent_project) # This contains Revise
	pushfirst!(LOAD_PATH, plutodevmacros_project) # This loads the PlutoDevMacros environment, so we can do import with the latest version
	try
		# Base.eval(Main, :(import Revise))
		Base.eval(Main, :(import PlutoDevMacros))
	finally
		popfirst!(LOAD_PATH) # Remove plutodevmacros env
		# popfirst!(LOAD_PATH) # Remove parent_env
	end
	# using Main.Revise
	using Main.PlutoDevMacros
	using Main.PlutoDevMacros.Script
	using Main.PlutoDevMacros.HypertextLiteral
end

# ╔═╡ 8325847e-fd7e-42ef-84c7-a30c6467183e
using PlutoUI

# ╔═╡ c924a590-a189-4ca2-abef-2b7dca80fe11
md"""
# Packages
"""

# ╔═╡ 13d2cf9a-2fce-47f9-a851-6dd80d130b63
TableOfContents()

# ╔═╡ 9daf72fd-dff2-4096-bf23-5b7fa8afe008
md"""
# Load package
"""

# ╔═╡ d013da3e-8a23-4594-9d15-4eadca921a7a
md"""
# Tests
"""

# ╔═╡ 201323b9-8caf-4acb-904e-b76d16e5ffb1
md"""
## HTLScriptPart
"""

# ╔═╡ adf46403-ec6b-4278-ae65-5747f319dc96
asd = (@htl """
<script>
	let out = html`<div></div>`
	console.log('first script')
</script>
""") |> HTLScriptPart

# ╔═╡ 73932307-b68c-453a-a7e6-8ba5d8bd8334
lol = (@htl """
<script>
	let a = Math.random()
	out.innerText = a
	console.log('second script')
	return out
</script>
""") |> HTLScriptPart

# ╔═╡ 5895351c-9edd-4790-a262-b28731a3ab97
@htl """
<script>
	$asd
	$lol
</script>
"""

# ╔═╡ d508ea5d-cc5d-44d1-a1b0-8ae6c18bf954
[asd,lol]

# ╔═╡ 723490e1-ae51-4e0f-a69f-2572a823973a
@htl """
<script>
	$([asd, lol])
</script>
"""

# ╔═╡ d7a6a1b2-5bb5-4743-b6d2-9f11208711b4
md"""
## HTLBypass
"""

# ╔═╡ a29fb2ee-f71b-411c-a427-e79bde9f9687
bpclass = "magic";

# ╔═╡ f61d937b-e6a8-4f77-b253-f13dc2e8bc16
bplol = @htl """
<div class=$bpclass>
	MAGIC
</div>
"""

# ╔═╡ d10026e7-5736-4555-aa8b-adb769280dbe
bpasd = HTLBypass(@htl """
<div>This is $bplol</div>
""")

# ╔═╡ e95076b9-a4bb-4a94-8b29-ae2b33bfc47a
Script.formatted_js(bpasd)

# ╔═╡ d49ca300-2dd2-48b3-a27e-fab90b61de7e
@htl """
<script>
	let out = html`$bpasd`
	console.log(out)
	return out
</script>
"""

# ╔═╡ 453ee62b-d1b4-4bad-aafa-cba13559b698
md"""
## HTLScript
"""

# ╔═╡ 14d239b3-1402-4ae4-a620-8de9c191a20e
s = HTLScript("console.log('asd')")

# ╔═╡ 4774accb-a3f7-4cee-9e9e-da1a413eb5a0
HTLScript(s)

# ╔═╡ b5464d21-dc4d-4be1-83fa-a4c351015944
combine_scripts([(s for _ in 1:4)..., "console.log('lol')"];id=missing)

# ╔═╡ cc41848a-3fcb-4c65-9a5d-452b3fecdf63
dio = let
	a = HTLScript("console.log('asd1')", "console.log('lol1')", "lol")
	b = HTLScript("console.log('asd2');", "console.log('lol2')", "gesu")
	combine_scripts([a,b]; id = "lol")
end

# ╔═╡ f631b4ea-3ce9-43ac-8a87-dba733deec18
let
	r = @htl "<asd>lol</asd>$dio"
	io = IOBuffer()
	show(io, r)
	String(take!(io))
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"

[compat]
PlutoUI = "~0.7.52"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.10.0-beta2"
manifest_format = "2.0"
project_hash = "f5c06f335ceddc089c816627725c7f55bb23b077"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "91bd53c39b9cbfb5ef4b015e8b582d344532bd0a"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.2.0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "eb7f0f8307f71fac7c606984ea5fb2817275d6e4"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.4"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.0.5+1"

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
git-tree-sha1 = "d75853a0bdbfb1ac815478bacd89cd27b550ace6"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.3"

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
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.0.1+1"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.0+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MIMEs]]
git-tree-sha1 = "65f28ad4b594aebe22157d6fac869786a255b7eb"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "0.1.4"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+1"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2023.1.10"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.23+2"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "716e24b21538abc91f6205fd1d8363f39b442851"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.7.2"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.10.0"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "e47cd150dbe0443c3a3651bc5b9cbd5576ab75b7"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.52"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "03b4c25b43cb84cee5c90aa9b5ea0a78fd848d2f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.0"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "7eb1686b4f04b82f96ed7a4ea5890a4f0c7a09f1"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.10.0"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.9.0"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "Pkg", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.2.0+1"

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
git-tree-sha1 = "aadb748be58b492045b4f56166b5188aa63ce549"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.7"

[[deps.URIs]]
git-tree-sha1 = "b7a5e99f24892b6824a954199a45e9ffcc1c70f0"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.5.0"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.8.0+1"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.52.0+1"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"
"""

# ╔═╡ Cell order:
# ╟─c924a590-a189-4ca2-abef-2b7dca80fe11
# ╠═d0e6a2b2-1e5d-11ee-177a-5f0a92dd83f5
# ╠═8325847e-fd7e-42ef-84c7-a30c6467183e
# ╠═13d2cf9a-2fce-47f9-a851-6dd80d130b63
# ╟─9daf72fd-dff2-4096-bf23-5b7fa8afe008
# ╟─d013da3e-8a23-4594-9d15-4eadca921a7a
# ╟─201323b9-8caf-4acb-904e-b76d16e5ffb1
# ╠═adf46403-ec6b-4278-ae65-5747f319dc96
# ╠═73932307-b68c-453a-a7e6-8ba5d8bd8334
# ╠═5895351c-9edd-4790-a262-b28731a3ab97
# ╠═d508ea5d-cc5d-44d1-a1b0-8ae6c18bf954
# ╠═723490e1-ae51-4e0f-a69f-2572a823973a
# ╠═d7a6a1b2-5bb5-4743-b6d2-9f11208711b4
# ╠═a29fb2ee-f71b-411c-a427-e79bde9f9687
# ╠═f61d937b-e6a8-4f77-b253-f13dc2e8bc16
# ╠═d10026e7-5736-4555-aa8b-adb769280dbe
# ╠═e95076b9-a4bb-4a94-8b29-ae2b33bfc47a
# ╠═d49ca300-2dd2-48b3-a27e-fab90b61de7e
# ╠═453ee62b-d1b4-4bad-aafa-cba13559b698
# ╠═14d239b3-1402-4ae4-a620-8de9c191a20e
# ╠═4774accb-a3f7-4cee-9e9e-da1a413eb5a0
# ╠═b5464d21-dc4d-4be1-83fa-a4c351015944
# ╠═cc41848a-3fcb-4c65-9a5d-452b3fecdf63
# ╠═f631b4ea-3ce9-43ac-8a87-dba733deec18
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
