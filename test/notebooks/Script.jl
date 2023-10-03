### A Pluto.jl notebook ###
# v0.19.29

#> custom_attrs = ["hide-enabled"]

using Markdown
using InteractiveUtils

# ╔═╡ d0e6a2b2-1e5d-11ee-177a-5f0a92dd83f5
begin
	test_project= Base.current_project(@__DIR__)
	plutodevmacros_project= Base.current_project(normpath(@__DIR__, "../..")) 
	pushfirst!(LOAD_PATH, test_project) # This contains Revise
	pushfirst!(LOAD_PATH, plutodevmacros_project) # This loads the PlutoDevMacros environment, so we can do import with the latest version
	try
		Base.eval(Main, :(import Revise))
		Base.eval(Main, :(import PlutoDevMacros))
	finally
		popfirst!(LOAD_PATH) # Remove plutodevmacros env
		popfirst!(LOAD_PATH) # Remove parent_env
	end
	using Main.Revise
	using Main.PlutoDevMacros
	using Main.PlutoDevMacros.PlutoCombineHTL.WithTypes
	using Main.PlutoDevMacros.HypertextLiteral
end

# ╔═╡ 8325847e-fd7e-42ef-84c7-a30c6467183e
using PlutoUI

# ╔═╡ 65bff575-5dcb-4d81-b357-2b2f8bfd43d7
using PlutoVSCodeDebugger

# ╔═╡ c924a590-a189-4ca2-abef-2b7dca80fe11
md"""
# Packages
"""

# ╔═╡ ede9b8dd-104f-4d5c-a134-f1fc67a1b9c7
import .PlutoCombineHTL: print_html

# ╔═╡ 13d2cf9a-2fce-47f9-a851-6dd80d130b63
TableOfContents()

# ╔═╡ 7a8c6eb4-cc33-41c3-9e1a-d8e07954fef9
# This is just to test that the html_reload_button generates the button correctly
PlutoDevMacros.FromPackage.html_reload_button("asd")

# ╔═╡ 01368463-0f95-4ced-abb1-6c8800ca2524
md"""
All outputs of type `ScriptContent`, `Script` or `Node` where `Script <: Node` are shown in Pluto by default as formatted code (using Markdown).
To actually generate and show in the pluto-output their corresponding HTML code you have to either interpolate them inside `@htl` or call the `make_html` function on them.
"""

# ╔═╡ c862e547-3b62-4218-b06e-0e84d05d6587
@connect_vscode begin
end

# ╔═╡ d115c2b6-f92d-4609-94a9-59391c160645
md"""
# Scripts 
"""

# ╔═╡ 201323b9-8caf-4acb-904e-b76d16e5ffb1
md"""
## ScriptContent
"""

# ╔═╡ f1bde184-7487-4745-8c47-0df407da6813
md"""
The ScriptContent type wraps javascript content of a script, and can be used to compose a script with multiple `ScriptContent` elements
"""

# ╔═╡ adf46403-ec6b-4278-ae65-5747f319dc96
simple_sc = """
	let out = html`<div>ASD</div>`
	console.log('first script')
	return out
""" |> ScriptContent

# ╔═╡ 0a1e9af6-6b32-49c6-9cf6-8cf7f594f109
md"""
### @htl constructor
"""

# ╔═╡ f2fde939-638a-4b69-94ee-d32aff03879e
md"""
Objects of `ScriptContent` type can also be generated using outputs of the `@htl` macro as input. In this case, the constructor performs some additional check and only accepts objects of type `HypertextLiteral.Result` that are containing at least one `<script>` tag element.

The content used for generating the `ScriptContent` is the text contained within the first `<script>` tag found. 
"""

# ╔═╡ 05941b74-00f1-4937-9a1d-d01e6e1a776f
# They can also be created starting form a String
ScriptContent("asd") === ScriptContent(@htl("<script>asd</script>")) || error("Something went wrong")

# ╔═╡ fbe39d75-01e8-4f3a-8e65-f260a039365e
md"""
When using the `@htl` macro to construct a `ScriptContent` element, some warning are printed if the content of the `@htl` macro either does not contain a <script> tag or contains more than the <script> tag
"""

# ╔═╡ 4c41b737-c392-455e-b6d8-98931f88d467
# This generates an empty content with no warning
ScriptContent(@htl(""))

# ╔═╡ 6879d22c-f01c-424f-bc37-eb42062e49db
# This generates a warning because some extra content was present but is discarded
ScriptContent(@htl("asd
<script id='lol'>
asd
</script>"))

# ╔═╡ 55044c8e-3f70-4a55-ad9f-7514d44a7211
# This generates a warning because no script tag was found despite its input being non-empty
ScriptContent(@htl("asd"))

# ╔═╡ a9bc9479-722d-4564-9cb9-560f7b0f4ffb
# This generates a warning because two script tags are found
ScriptContent(@htl("<script>asd</script>lol<script>boh</script>"))

# ╔═╡ da343b23-1ee0-44f9-9341-2c337f0de333
# This cell will throw an error because you have to always provide the closing </script> tag in the constructor when using @htl
try
	ScriptContent(@htl("<script>asd"))
	false
catch e
	contains(e.msg, "No closing </script>") || rethrow()
end

# ╔═╡ 57929023-813c-42ab-acdd-8a8f9033c11a
md"""
### Display/Interpolation
"""

# ╔═╡ 8d9dd998-c3d0-435c-a709-ee42c586c230
md"""
`ScriptContent` objects can only be _materialized_ as scripts by performing a direct interpolation within the <script> tag of the `@htl` macro. Using `make_html` will not work. Alternatively one can also wrap the ScriptContent inside a `Script` element before calling `make_html` as will be shown later 
"""

# ╔═╡ c2aa06c6-3d34-4793-afa6-2e5a7c8b920a
# Here we interpolate this inside `@htl` to create the script
@htl("<script>$simple_sc</script>")

# ╔═╡ 720f431c-00d6-418a-a33c-d440070a7363
# make_html will simply re-show the formatted HTML code
make_html(simple_sc)

# ╔═╡ 3362ad99-d10c-4312-84ae-e3876ad1787f
md"""
A Vector of `ScriptContent` can also be directly interpolated inside the <script> tags within the `@htl` macro.
"""

# ╔═╡ 318a9af6-a7e9-449d-8299-db4b6ab11fea
@htl("""
<script>
$([
	ScriptContent("let dv = html`<div>LOL</div>`") # This creates the div
	ScriptContent("currentScript.insertAdjacentElement('beforebegin',dv)") # This puts the previous div before the currentScript
	ScriptContent("return html`<div>ASD`") # This returns a new div, which is put after the previous one. Return statements should not be contained inside ScriptContents directly but provided with the returned_element keyword when constructing a Script.
])
</script>
""")

# ╔═╡ cc621eb7-b977-4ee8-9fbf-600a6f2bcfd2
md"""
## SingleScript
"""

# ╔═╡ 02f7b708-1f21-4533-bc3c-de4573d0a14b
md"""
There are two subyptes of `InOrOutScript <: Script`. They are:
- `PlutoScript`
- `NormalScript`
These are elements representing scripts that are exclusive to either be shown in Pluto or outside of Pluto.

The PlutoScript internally contains two `ScriptContent` fields, one for the normal script body, and one for the invalidation part of the script that takes place when a cell is removed/re-run.\
Check the JavaScript sample Pluto notebook for more details on the `invalidation` stage of Pluto cells.

`SinglScript` objects can be constructed either with `ScriptContent` objects directly or with inputs that are supported by the `ScriptContent` constructor (i.e. `String` and `HypertextLiteral.Result` containing a <script> tag)
"""

# ╔═╡ 1e2d7cc9-45d8-4aca-806b-76f1e50986b0
md"""
### PlutoScript
"""

# ╔═╡ 73932307-b68c-453a-a7e6-8ba5d8bd8334
# When showing a Script object, the <script> tag is included
PlutoScript(simple_sc) |> formatted_code

# ╔═╡ d866e092-f24b-4553-971f-c1f74f3a1c1a
# Can also be constructed with Strings
ps = PlutoScript("   console.log('asd')", "   console.log('lol')"; id = "my_id") |>
formatted_code

# ╔═╡ 3dfb8184-2fce-4296-9c47-f0a034e99f73
PlutoScript("return html`<div>MAGIC`")

# ╔═╡ 7f70ce43-567b-47aa-856e-bb41ee00fcc4
md"""
### NormalScript
"""

# ╔═╡ 07db9619-2cfe-4796-a083-f571f6c30721
md"""
NormalScript will not show the formatted code as normal output in Pluto, but will transform into an empty script when actually shown with `make_html` inside Pluto.

In order to maximize code reuse between the Pluto and Normal scripts, some JS packages are loaded and made available in NormalScript objects' generated HTML by default.
These are the packages that are also automatically loaded inside Pluto and are available when executing cell code and include:
- the [Observable Standard Library](https://github.com/observablehq/stdlib) 
- the [Lodash](https://lodash.com/) package.
Similarly to what happens in Pluto, the `currentScript` variable is also associated to the script being executed.

While `currentScript` is always bound, the package loading/inclusion is controlled by a `Bool` field of the `NormalScript` structure and it can be overridden by calling the script constructor with the `add_pluto_compat = false` keyword argument.
"""

# ╔═╡ ebd5e071-e151-43d6-806e-ca6582c0046b
ns = NormalScript("return html`<div>MAGIC`")

# ╔═╡ 22589abd-63f4-46de-9fed-b673a72a449f
# The MAGIC word is not appearing like for the PlutoScript because we are showing inside Pluto
make_html(ns)

# ╔═╡ 0b129e2a-842f-44cd-9d5e-61f7090ab63d
md"""
### JS Listeners
"""

# ╔═╡ bdac5c70-2114-4f2b-9a0b-14ff172a1559
md"""
`Script` objects can also be constructed with a convenience function to attach JS listeners to objects that are automatically removed upon cell invalidation.

To use this functionality, it is sufficient to add a call to the `addScriptEventListeners` inside the script content.

See below the actually generated HTML when this keyword is added to the contents of a Script:
"""

# ╔═╡ d508ea5d-cc5d-44d1-a1b0-8ae6c18bf954
begin
	ps_js = PlutoScript("""
		let dv = html`<div>ASDLOL`
		let active = false
		addScriptEventListeners(dv, {
			'click': (e) => {
				console.log(e)
				active = !active
				if (active) {
					dv.style = "border: solid 2px red;"
				} else {
					dv.style = ""
				}
			}
		})
	"""; returned_element = "dv") # To avoid having a return statement within the script that will stop the rest of the content. Returned elements name should be given as a separated keyword argument.
	formatted_code(ps_js)
end

# ╔═╡ a87c1d5f-1160-477b-9de9-432f1b742e3f
# One can also just show the content without the scripts parts added by PlutoDevMacros
ps_js |> formatted_code(;only_contents = true)

# ╔═╡ a4004826-ee3d-451f-a944-dff8d0787481
md"""
And here is the generated script which will create a div which changes its border color upon click
"""

# ╔═╡ 5ec6e1a4-ece4-4cdf-81f5-fe0d1c9c39b9
ps_js

# ╔═╡ f8e10efd-f29d-431b-bbc7-ae4c0608e4d6
md"""
## DualScript
"""

# ╔═╡ c30afe44-ac82-4f80-82d2-ba89677f49b0
ScriptContent(@htl("""
<script>
asd
</script>
"""); context_pairs = [:pluto => true])

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
PlutoVSCodeDebugger = "560812a8-17ff-4261-aab5-f8f600b273e2"

[compat]
PlutoUI = "~0.7.52"
PlutoVSCodeDebugger = "~0.2.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.10.0-beta2"
manifest_format = "2.0"
project_hash = "2a231071dd4c3eaebeebc799c8f5832c9f4ce78a"

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

[[deps.PlutoVSCodeDebugger]]
deps = ["AbstractPlutoDingetjes", "InteractiveUtils", "Markdown", "REPL"]
git-tree-sha1 = "888128e4c890f15b1a0eb847bfd54cf987a6bc77"
uuid = "560812a8-17ff-4261-aab5-f8f600b273e2"
version = "0.2.0"

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
# ╠═ede9b8dd-104f-4d5c-a134-f1fc67a1b9c7
# ╠═8325847e-fd7e-42ef-84c7-a30c6467183e
# ╠═13d2cf9a-2fce-47f9-a851-6dd80d130b63
# ╠═7a8c6eb4-cc33-41c3-9e1a-d8e07954fef9
# ╟─01368463-0f95-4ced-abb1-6c8800ca2524
# ╠═65bff575-5dcb-4d81-b357-2b2f8bfd43d7
# ╠═c862e547-3b62-4218-b06e-0e84d05d6587
# ╟─d115c2b6-f92d-4609-94a9-59391c160645
# ╟─201323b9-8caf-4acb-904e-b76d16e5ffb1
# ╟─f1bde184-7487-4745-8c47-0df407da6813
# ╠═adf46403-ec6b-4278-ae65-5747f319dc96
# ╟─0a1e9af6-6b32-49c6-9cf6-8cf7f594f109
# ╟─f2fde939-638a-4b69-94ee-d32aff03879e
# ╠═05941b74-00f1-4937-9a1d-d01e6e1a776f
# ╟─fbe39d75-01e8-4f3a-8e65-f260a039365e
# ╠═4c41b737-c392-455e-b6d8-98931f88d467
# ╠═6879d22c-f01c-424f-bc37-eb42062e49db
# ╠═55044c8e-3f70-4a55-ad9f-7514d44a7211
# ╠═a9bc9479-722d-4564-9cb9-560f7b0f4ffb
# ╠═da343b23-1ee0-44f9-9341-2c337f0de333
# ╟─57929023-813c-42ab-acdd-8a8f9033c11a
# ╟─8d9dd998-c3d0-435c-a709-ee42c586c230
# ╠═c2aa06c6-3d34-4793-afa6-2e5a7c8b920a
# ╠═720f431c-00d6-418a-a33c-d440070a7363
# ╟─3362ad99-d10c-4312-84ae-e3876ad1787f
# ╠═318a9af6-a7e9-449d-8299-db4b6ab11fea
# ╟─cc621eb7-b977-4ee8-9fbf-600a6f2bcfd2
# ╟─02f7b708-1f21-4533-bc3c-de4573d0a14b
# ╟─1e2d7cc9-45d8-4aca-806b-76f1e50986b0
# ╠═73932307-b68c-453a-a7e6-8ba5d8bd8334
# ╠═d866e092-f24b-4553-971f-c1f74f3a1c1a
# ╠═3dfb8184-2fce-4296-9c47-f0a034e99f73
# ╟─7f70ce43-567b-47aa-856e-bb41ee00fcc4
# ╟─07db9619-2cfe-4796-a083-f571f6c30721
# ╠═ebd5e071-e151-43d6-806e-ca6582c0046b
# ╠═22589abd-63f4-46de-9fed-b673a72a449f
# ╟─0b129e2a-842f-44cd-9d5e-61f7090ab63d
# ╟─bdac5c70-2114-4f2b-9a0b-14ff172a1559
# ╠═d508ea5d-cc5d-44d1-a1b0-8ae6c18bf954
# ╠═a87c1d5f-1160-477b-9de9-432f1b742e3f
# ╟─a4004826-ee3d-451f-a944-dff8d0787481
# ╠═5ec6e1a4-ece4-4cdf-81f5-fe0d1c9c39b9
# ╟─f8e10efd-f29d-431b-bbc7-ae4c0608e4d6
# ╠═c30afe44-ac82-4f80-82d2-ba89677f49b0
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
