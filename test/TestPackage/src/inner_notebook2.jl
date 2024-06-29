### A Pluto.jl notebook ###
# v0.19.43

using Markdown
using InteractiveUtils

# ╔═╡ 5fe1bfc9-9622-4266-8efa-d4032b42d847
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

# ╔═╡ 2a3b9920-8fa7-4e20-aee9-71a93d589b70
using PlutoDevMacros

# ╔═╡ d9d182c7-abc8-4097-97da-459e351e01ba
@fromparent begin
	import *
	using >.BenchmarkTools
end

# ╔═╡ eaf576ed-ea38-4bb8-b2c8-4ba6ea6b2ac9
@addmethod testmethod(x::Float64) = "FLOAT"

# ╔═╡ 3cb7f11d-8829-409c-b3c8-9359a5da0763
testmethod("a") == "ANY" || error("Something went wrong")

# ╔═╡ b91a7413-534f-442b-bc55-a61244938820
testmethod(3) == "INT" || error("Something went wrong")

# ╔═╡ 88b26633-0760-428e-868a-1b799076189c
testmethod(3.0) == "FLOAT" || error("Something went wrong")

# ╔═╡ Cell order:
# ╠═5fe1bfc9-9622-4266-8efa-d4032b42d847
# ╠═2a3b9920-8fa7-4e20-aee9-71a93d589b70
# ╠═d9d182c7-abc8-4097-97da-459e351e01ba
# ╠═eaf576ed-ea38-4bb8-b2c8-4ba6ea6b2ac9
# ╠═3cb7f11d-8829-409c-b3c8-9359a5da0763
# ╠═b91a7413-534f-442b-bc55-a61244938820
# ╠═88b26633-0760-428e-868a-1b799076189c
