### A Pluto.jl notebook ###
# v0.19.42

using Markdown
using InteractiveUtils

# ╔═╡ f90b0ae3-0e16-4b83-8546-23d4450812b2
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

# ╔═╡ 8aa0221b-8f13-4ee8-8cc6-a19fdce2468b
using PlutoDevMacros

# ╔═╡ e1c8bbbd-da6f-4550-9f2c-30337d4962ad
@fromparent begin
	import ..TestPackage: testmethod
	using >.BenchmarkTools # This is a direct dependency of the package
end

# ╔═╡ c83b0017-bb5e-48bd-96e6-5192b6151233
BenchmarkTools isa Module || error("It should be defined")

# ╔═╡ d5c73062-b20a-459f-8165-550e0f07375a
isdefined(@__MODULE__, Symbol("@benchmark")) || error("It should be defined")

# ╔═╡ c30c2104-9fb1-4afd-a119-6da9d50ae2b6
testmethod(3)

# ╔═╡ 596410f6-81b7-48ae-a761-e5cca4a996ba
# To add methods to function import with @fromparent, you need to use the @addmethod macro.
@addmethod function testmethod(x::Int) 
	"INT"
end

# ╔═╡ a1430424-c9b8-4517-9105-c4daa72fdeea
testmethod(3)

# ╔═╡ Cell order:
# ╠═f90b0ae3-0e16-4b83-8546-23d4450812b2
# ╠═8aa0221b-8f13-4ee8-8cc6-a19fdce2468b
# ╠═e1c8bbbd-da6f-4550-9f2c-30337d4962ad
# ╠═c83b0017-bb5e-48bd-96e6-5192b6151233
# ╠═d5c73062-b20a-459f-8165-550e0f07375a
# ╠═c30c2104-9fb1-4afd-a119-6da9d50ae2b6
# ╠═596410f6-81b7-48ae-a761-e5cca4a996ba
# ╠═a1430424-c9b8-4517-9105-c4daa72fdeea
