### A Pluto.jl notebook ###
# v0.19.25

using Markdown
using InteractiveUtils

# ╔═╡ 22f0a6a4-907b-4389-b6b7-1f175289c69b
using PlutoDevMacros.FromPackage

# ╔═╡ 8de53a58-e6ab-11ed-1db7-ef087d78eaef
# ╠═╡ skip_as_script = true
#=╠═╡
# begin
# 	import Pkg
# 	Pkg.activate(Base.current_project(@__FILE__))
# 	using Revise
# end
  ╠═╡ =#

# ╔═╡ cf9f785b-f8f5-4d1b-9a48-ca5983843ba4
@fromparent begin
	import * # This import both exported and unexported names from the parent module up to the location where this file was included.
end

# ╔═╡ 9a8ae7e2-d3c4-4cf2-876e-bcde84741540
# We have also visibility on `hidden_toplevel_variable` as was import in this notebook via the catchall *
toplevel_variable + hidden_toplevel_variable

# ╔═╡ c9997396-bd93-41f1-8c3c-d13c7c6c5c3e
# We define a method
testmethod(x) = "ANY"

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
PlutoDevMacros = "a0499f29-c39b-4c5c-807c-88074221b949"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

[[Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "c47c5fa4c5308f27ccaac35504858d8914e102f9"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.4"

[[InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[LoggingExtras]]
deps = ["Dates", "Logging"]
git-tree-sha1 = "cedb76b37bc5a6c702ade66be44f831fa23c681e"
uuid = "e6f89c97-d47a-5376-807f-9c37f3926c36"
version = "1.0.0"

[[MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "42324d08725e200c23d4dfb549e0d5d89dede2d2"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.10"

[[Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[PlutoDevMacros]]
deps = ["HypertextLiteral", "InteractiveUtils", "LoggingExtras", "MacroTools", "Markdown", "Random", "Requires", "TOML"]
git-tree-sha1 = "680e7349a454185b7ae41d9997e5fcbd0c05264f"
repo-rev = "7b80509"
repo-url = "https://github.com/disberd/PlutoDevMacros.jl"
uuid = "a0499f29-c39b-4c5c-807c-88074221b949"
version = "0.5.0"

[[Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[Tricks]]
git-tree-sha1 = "aadb748be58b492045b4f56166b5188aa63ce549"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.7"

[[UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"
"""

# ╔═╡ Cell order:
# ╠═8de53a58-e6ab-11ed-1db7-ef087d78eaef
# ╠═22f0a6a4-907b-4389-b6b7-1f175289c69b
# ╠═cf9f785b-f8f5-4d1b-9a48-ca5983843ba4
# ╠═9a8ae7e2-d3c4-4cf2-876e-bcde84741540
# ╠═c9997396-bd93-41f1-8c3c-d13c7c6c5c3e
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
