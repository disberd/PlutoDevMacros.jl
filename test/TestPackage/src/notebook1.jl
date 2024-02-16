### A Pluto.jl notebook ###
# v0.19.36

using Markdown
using InteractiveUtils

# ╔═╡ 8de53a58-e6ab-11ed-1db7-ef087d78eaef
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

# ╔═╡ 22f0a6a4-907b-4389-b6b7-1f175289c69b
using PlutoDevMacros.FromPackage

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

# ╔═╡ Cell order:
# ╠═8de53a58-e6ab-11ed-1db7-ef087d78eaef
# ╠═22f0a6a4-907b-4389-b6b7-1f175289c69b
# ╠═cf9f785b-f8f5-4d1b-9a48-ca5983843ba4
# ╠═9a8ae7e2-d3c4-4cf2-876e-bcde84741540
# ╠═c9997396-bd93-41f1-8c3c-d13c7c6c5c3e
