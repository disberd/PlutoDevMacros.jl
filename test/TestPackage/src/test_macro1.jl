### A Pluto.jl notebook ###
# v0.19.42

using Markdown
using InteractiveUtils

# ╔═╡ e1caf748-e9c4-11ed-037b-8564786d02a4
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

# ╔═╡ e9bf965f-6d89-4df4-9515-6664eec341d7
abstract type CrazyType end

# ╔═╡ baf6004f-4abc-4fd0-ae9e-a05144e955c4
struct CoolStruct <: CrazyType
	v :: Vector{<:CrazyType}
end

# ╔═╡ d88d8173-a3d5-4d00-9372-ffce7ceecac9
struct NotThatCoolStruct <: CrazyType
	x :: Int64
end

# ╔═╡ 1dc784ea-e469-4c91-a202-bcf51e9961b5
foo(c::CrazyType) =	error("This wasn't implemented for $c")

# ╔═╡ 335e2f3d-359f-4f61-ae92-97c75292acd3
foo(n::NotThatCoolStruct) = "Yes! this was implemented: $(n.x)"

# ╔═╡ 1aca5c06-e5cc-4d89-8586-7d98b01ddbec
foo(n::CoolStruct) = foo.(n.v)

# ╔═╡ 1e78971b-fc54-4b58-8a49-603b29864843
# ╠═╡ skip_as_script = true
#=╠═╡
ns = [NotThatCoolStruct(i) for i ∈ (1:3)]
  ╠═╡ =#

# ╔═╡ 51bd6a66-48fe-400d-8f03-ff051895c859
#=╠═╡
cool = CoolStruct(ns)
  ╠═╡ =#

# ╔═╡ 0daf4126-8626-4403-b16a-e55890e21faa
#=╠═╡
foo(ns[1])
  ╠═╡ =#

# ╔═╡ 3786adad-39a4-4766-839b-dd508afc7e47
#=╠═╡
foo(cool)
  ╠═╡ =#

# ╔═╡ Cell order:
# ╠═e1caf748-e9c4-11ed-037b-8564786d02a4
# ╠═e9bf965f-6d89-4df4-9515-6664eec341d7
# ╠═baf6004f-4abc-4fd0-ae9e-a05144e955c4
# ╠═d88d8173-a3d5-4d00-9372-ffce7ceecac9
# ╠═1dc784ea-e469-4c91-a202-bcf51e9961b5
# ╠═335e2f3d-359f-4f61-ae92-97c75292acd3
# ╠═1aca5c06-e5cc-4d89-8586-7d98b01ddbec
# ╠═1e78971b-fc54-4b58-8a49-603b29864843
# ╠═51bd6a66-48fe-400d-8f03-ff051895c859
# ╠═0daf4126-8626-4403-b16a-e55890e21faa
# ╠═3786adad-39a4-4766-839b-dd508afc7e47
