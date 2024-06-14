### A Pluto.jl notebook ###
# v0.19.42

using Markdown
using InteractiveUtils

# ╔═╡ 85628a8b-b883-4374-918d-e080f4ab7d2e
# ╠═╡ skip_as_script = true
#=╠═╡
begin
	import Pkg
	Pkg.activate(Base.current_project(@__FILE__))
	# Revise is only used for internal testing during development to update the
	# changes to PlutoDevMacros
	using Revise
end
  ╠═╡ =#

# ╔═╡ 9fd3e305-b493-46a5-8d4d-2d3712d9b23a
using PlutoDevMacros.FromPackage

# ╔═╡ 52ad0f6c-a01a-4c9d-a176-64d9872aa3c1
@fromparent import *

# ╔═╡ 7f231b93-521d-4378-8094-763245eb5e43
struct GreatStructure <: CrazyType
	s :: String
end

# ╔═╡ ebd09585-3edf-4167-9724-47a16ce4b596
@addmethod foo(g::GreatStructure) = "What a great structure! $(g.s)"

# ╔═╡ 2b245479-cce8-4e57-9261-42e2c926312b
gs = [GreatStructure("$c") for c ∈ ('a':'c')]

# ╔═╡ 0735dc02-2b60-4fa6-bb8d-98729ad01d27
c = CoolStruct(gs)

# ╔═╡ 62546e81-98fe-49c0-8022-8b28389b24ba
foo(c) # This doesn't breaks anymore! See https://github.com/disberd/PlutoDevMacros.jl/issues/2 for details

# ╔═╡ Cell order:
# ╠═85628a8b-b883-4374-918d-e080f4ab7d2e
# ╠═9fd3e305-b493-46a5-8d4d-2d3712d9b23a
# ╠═52ad0f6c-a01a-4c9d-a176-64d9872aa3c1
# ╠═7f231b93-521d-4378-8094-763245eb5e43
# ╠═ebd09585-3edf-4167-9724-47a16ce4b596
# ╠═2b245479-cce8-4e57-9261-42e2c926312b
# ╠═0735dc02-2b60-4fa6-bb8d-98729ad01d27
# ╠═62546e81-98fe-49c0-8022-8b28389b24ba
