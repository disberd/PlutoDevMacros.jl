### A Pluto.jl notebook ###
# v0.17.1

using Markdown
using InteractiveUtils

# ╔═╡ f9eff180-3c4d-49c2-9f4e-e3f425a96966
#=╠═╡ notebook_exclusive
begin
	import Pkg
	Pkg.activate("..")
end
  ╠═╡ notebook_exclusive =#

# ╔═╡ 941fa912-61d4-4847-8bb2-5e83eb31ca34
using PlutoDevMacros

# ╔═╡ e2ac5a43-d683-486b-a2a1-f26f48313c47
@plutoinclude "test1.jl" "all"

# ╔═╡ f3287e4b-c92a-4eef-8b79-78346a55803b
asd(x::Float64) = "FLOAT"

# ╔═╡ 4d8e68cb-910f-4f6c-89cd-2bf2da7b5a70
struct TestStruct2 end

# ╔═╡ 53ec02f7-ca14-41d9-b3b7-757c36f526f7
asd(::TestStruct2) = "TESTSTRUCT2"

# ╔═╡ f5b8ccdd-ad66-4ae4-b3e9-82452464168b
#=╠═╡ notebook_exclusive
asd(3)
  ╠═╡ notebook_exclusive =#

# ╔═╡ Cell order:
# ╠═f9eff180-3c4d-49c2-9f4e-e3f425a96966
# ╠═941fa912-61d4-4847-8bb2-5e83eb31ca34
# ╠═e2ac5a43-d683-486b-a2a1-f26f48313c47
# ╠═f5b8ccdd-ad66-4ae4-b3e9-82452464168b
# ╠═f3287e4b-c92a-4eef-8b79-78346a55803b
# ╠═4d8e68cb-910f-4f6c-89cd-2bf2da7b5a70
# ╠═53ec02f7-ca14-41d9-b3b7-757c36f526f7
