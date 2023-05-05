### A Pluto.jl notebook ###
# v0.19.24

using Markdown
using InteractiveUtils

# ╔═╡ 5fe1bfc9-9622-4266-8efa-d4032b42d847
# ╠═╡ skip_as_script = true
#=╠═╡
begin
	import Pkg
	Pkg.activate(Base.current_project(@__FILE__))
	using Revise
end
  ╠═╡ =#

# ╔═╡ 2a354c8d-a896-4822-ba5b-bf2406b232aa
using PlutoDevMacros.FromPackage

# ╔═╡ d9d182c7-abc8-4097-97da-459e351e01ba
@fromparent import *

# ╔═╡ eaf576ed-ea38-4bb8-b2c8-4ba6ea6b2ac9
@addmethod testmethod(x::Float64) = "FLOAT"

# ╔═╡ 3cb7f11d-8829-409c-b3c8-9359a5da0763
testmethod("a")

# ╔═╡ b91a7413-534f-442b-bc55-a61244938820
testmethod(3)

# ╔═╡ 88b26633-0760-428e-868a-1b799076189c
testmethod(3.0)

# ╔═╡ Cell order:
# ╠═5fe1bfc9-9622-4266-8efa-d4032b42d847
# ╠═2a354c8d-a896-4822-ba5b-bf2406b232aa
# ╠═d9d182c7-abc8-4097-97da-459e351e01ba
# ╠═eaf576ed-ea38-4bb8-b2c8-4ba6ea6b2ac9
# ╠═3cb7f11d-8829-409c-b3c8-9359a5da0763
# ╠═b91a7413-534f-442b-bc55-a61244938820
# ╠═88b26633-0760-428e-868a-1b799076189c
