### A Pluto.jl notebook ###
# v0.17.1

using Markdown
using InteractiveUtils

# ╔═╡ bb26cad0-4720-11ec-20c0-6538c8fcc18f
#=╠═╡ notebook_exclusive
begin
	import Pkg
	Pkg.activate("..")
end
  ╠═╡ notebook_exclusive =#

# ╔═╡ 82ace475-cc8d-4f3d-84bd-91a49c141648
using PlutoDevMacros

# ╔═╡ 8c251cd4-3050-4809-80a3-07e9aab558ab
struct TestStruct1 end

# ╔═╡ 8145c16e-0a16-4e8b-a073-8e1774273bb4
asd(x::Int) = "INT"

# ╔═╡ 354605a3-297e-4647-b4cf-f0aea4987f9e
asd(::TestStruct1) = "TESTSTRUCT1"

# ╔═╡ Cell order:
# ╠═bb26cad0-4720-11ec-20c0-6538c8fcc18f
# ╠═82ace475-cc8d-4f3d-84bd-91a49c141648
# ╠═8c251cd4-3050-4809-80a3-07e9aab558ab
# ╠═8145c16e-0a16-4e8b-a073-8e1774273bb4
# ╠═354605a3-297e-4647-b4cf-f0aea4987f9e
