### A Pluto.jl notebook ###
# v0.19.43

using Markdown
using InteractiveUtils

# ╔═╡ f08451b0-5666-4132-9c7e-a7d37c7d0c5a
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

# ╔═╡ 1a327f54-0bb4-4206-9070-e02d24c7861c
using PlutoDevMacros

# ╔═╡ d483e6a9-262a-4346-91d2-68bf342c5ef9
@fromparent begin
	# CodeTracking is an indirect dependency
	import >.CodeTracking as CT, >.TOML as TML
	using >.TOML: tryparse as tp
end

# ╔═╡ e2707562-9e31-4d4d-bc61-8af24911de9a
tp === TML.tryparse || error("Import as from TOML did not work as expected")

# ╔═╡ 74384ece-10c5-4b1a-bfcb-3c83eceb0447
# ╠═╡ skip_as_script = true
#=╠═╡
# This cell is commented outside of the notebook as CT will not be imported oustide of the notebook since it's an indirect dependency
nameof(CT) === :CodeTracking || error("import of CodeTracking with different name did not work")
  ╠═╡ =#

# ╔═╡ Cell order:
# ╠═f08451b0-5666-4132-9c7e-a7d37c7d0c5a
# ╠═1a327f54-0bb4-4206-9070-e02d24c7861c
# ╠═d483e6a9-262a-4346-91d2-68bf342c5ef9
# ╠═e2707562-9e31-4d4d-bc61-8af24911de9a
# ╠═74384ece-10c5-4b1a-bfcb-3c83eceb0447
