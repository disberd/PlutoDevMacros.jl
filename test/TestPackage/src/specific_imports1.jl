### A Pluto.jl notebook ###
# v0.19.42

using Markdown
using InteractiveUtils

# ╔═╡ 414ea677-fc22-42d1-b28c-36d0666f466e
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

# ╔═╡ d8bb9b0c-b777-4b92-aab4-688358059f6d
using PlutoDevMacros

# ╔═╡ da3cb2df-c686-45ed-abad-d4556c253ffa
# When using PackageModule as name of the package to use or import from, `PackageModule` is substituted with the acutal module of the package targeted by @frompackage/@fromparent and loaded within the notebook.
@fromparent import PackageModule: hidden_toplevel_variable

# ╔═╡ b03c28ca-9ad3-4ca0-a025-d0ca7799a6b2
# ╠═╡ skip_as_script = true
#=╠═╡
hidden_toplevel_variable
  ╠═╡ =#

# ╔═╡ ea26eaf9-bc34-4d53-b3af-641fec5039dd
# Outside of Pluto, these variables are defined inside the module containing this notebook, which is called SpecificImport
begin
	inner_variable1 = 100
	inner_variable2 = 200
end

# ╔═╡ Cell order:
# ╠═414ea677-fc22-42d1-b28c-36d0666f466e
# ╠═d8bb9b0c-b777-4b92-aab4-688358059f6d
# ╠═da3cb2df-c686-45ed-abad-d4556c253ffa
# ╠═b03c28ca-9ad3-4ca0-a025-d0ca7799a6b2
# ╠═ea26eaf9-bc34-4d53-b3af-641fec5039dd
