### A Pluto.jl notebook ###
# v0.20.18

using Markdown
using InteractiveUtils

# ╔═╡ 673651f0-bd4d-11f0-ba7f-617f2cec5acd
begin
	# We do a hack to import PlutoDevMacros
	plutodevmacros_proj = Base.current_project("../../..") |> abspath
	push!(LOAD_PATH, plutodevmacros_proj)
	try
		Core.eval(Main, :(import PlutoDevMacros as PDM))
	finally
		pop!(LOAD_PATH)
	end
	PDM = Main.PDM
end

# ╔═╡ 0474d311-5132-4278-babd-0f5bef701dca
PDM.@frompackage ".." begin
	import *
end manifest=instantiate

# ╔═╡ 4cad00d8-e685-4fd4-a3b9-969e08d972da
t = Issue67.MyThing(1)

# ╔═╡ 0c0203b0-f88e-44f3-bdf7-c39c4d0dca80
t2 = Issue67.SubModule.construct_thing(1)

# ╔═╡ f4ffef2c-52e2-4530-b749-749be699e051
t == t2 || error("They should be equivalent")

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.12.1"
manifest_format = "2.0"
project_hash = "71853c6197a6a7f222db0f1978c7cb232b87c5ee"

[deps]
"""

# ╔═╡ Cell order:
# ╠═673651f0-bd4d-11f0-ba7f-617f2cec5acd
# ╠═0474d311-5132-4278-babd-0f5bef701dca
# ╠═4cad00d8-e685-4fd4-a3b9-969e08d972da
# ╠═0c0203b0-f88e-44f3-bdf7-c39c4d0dca80
# ╠═f4ffef2c-52e2-4530-b749-749be699e051
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
