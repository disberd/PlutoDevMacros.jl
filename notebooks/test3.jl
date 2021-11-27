### A Pluto.jl notebook ###
# v0.17.2

# using Markdown
# using InteractiveUtils

# ╔═╡ a1e38635-d1cb-4184-8e77-dab98a057e4c
#=╠═╡ notebook_exclusive
begin
	import Pkg
	Pkg.activate("..")
end
  ╠═╡ notebook_exclusive =#

# ╔═╡ 24ee155b-af1a-4915-a23b-3ff16e7ba844
begin
	using Revise
	using PlutoDevMacros
end

# ╔═╡ fa2b4748-4ec4-475a-a255-40b16cee11be
#=╠═╡ notebook_exclusive
using BenchmarkTools
  ╠═╡ notebook_exclusive =#

# ╔═╡ c5a1f2f0-c2b8-4ff7-b33c-467495b2317c
@plutoinclude "test2.jl" "all"

# ╔═╡ 7f9edbbe-2f8d-4b94-8199-6debf0143cca
#=╠═╡ notebook_exclusive
struct TestStruct3 end
  ╠═╡ notebook_exclusive =#

# ╔═╡ 25c3a29c-3a29-4de6-b66b-aaeb7c788d29
#=╠═╡ notebook_exclusive
asd(::TestStruct3) = "TESTSTRUCT3"
  ╠═╡ notebook_exclusive =#

# ╔═╡ 6630b18d-b98b-49b8-a416-e793a1d3b474
#=╠═╡ notebook_exclusive
asd(1)
  ╠═╡ notebook_exclusive =#

# ╔═╡ 0542d7f4-4104-4884-b79e-d94d3fd3041c
#=╠═╡ notebook_exclusive
asd(1.0)
  ╠═╡ notebook_exclusive =#

# ╔═╡ 25924828-2ec2-4df0-8afd-3bcb6e3aad28
#=╠═╡ notebook_exclusive
asd(TestStruct1())
  ╠═╡ notebook_exclusive =#

# ╔═╡ c0448179-1dac-4c61-9fb3-5b2c14f44f30
#=╠═╡ notebook_exclusive
asd(TestStruct2())
  ╠═╡ notebook_exclusive =#

# ╔═╡ 0d7ab7ce-1ce5-4249-b8de-8aeed5bec07e
#=╠═╡ notebook_exclusive
asd(TestStruct3())
  ╠═╡ notebook_exclusive =#

# ╔═╡ 720caf23-72de-4161-a7b0-0a10d690f0c3
#=╠═╡ notebook_exclusive
asd(TestStruct2())
  ╠═╡ notebook_exclusive =#

# ╔═╡ 26b39429-5766-45a5-a173-ad632c31718c
#=╠═╡ notebook_exclusive
@benchmark asd(TestStruct1())
  ╠═╡ notebook_exclusive =#

# ╔═╡ Cell order:
# ╠═a1e38635-d1cb-4184-8e77-dab98a057e4c
# ╠═24ee155b-af1a-4915-a23b-3ff16e7ba844
# ╠═fa2b4748-4ec4-475a-a255-40b16cee11be
# ╠═c5a1f2f0-c2b8-4ff7-b33c-467495b2317c
# ╠═6630b18d-b98b-49b8-a416-e793a1d3b474
# ╠═0542d7f4-4104-4884-b79e-d94d3fd3041c
# ╠═25924828-2ec2-4df0-8afd-3bcb6e3aad28
# ╠═c0448179-1dac-4c61-9fb3-5b2c14f44f30
# ╠═7f9edbbe-2f8d-4b94-8199-6debf0143cca
# ╠═25c3a29c-3a29-4de6-b66b-aaeb7c788d29
# ╠═0d7ab7ce-1ce5-4249-b8de-8aeed5bec07e
# ╠═720caf23-72de-4161-a7b0-0a10d690f0c3
# ╠═26b39429-5766-45a5-a173-ad632c31718c
