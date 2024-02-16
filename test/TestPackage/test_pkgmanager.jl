### A Pluto.jl notebook ###
# v0.19.36

using Markdown
using InteractiveUtils

# ╔═╡ 071ec1a4-eda6-11ed-3a1b-c1347c9fafa5
begin
	plutodevmacros_project= Base.current_project(normpath(@__DIR__, "../..")) 
	# pushfirst!(LOAD_PATH, parent_project) # This contains Revise
	pushfirst!(LOAD_PATH, plutodevmacros_project) # This loads the PlutoDevMacros environment, so we can do import with the latest version
	try
		# Base.eval(Main, :(import Revise))
		Base.eval(Main, :(import PlutoDevMacros))
	finally
		popfirst!(LOAD_PATH) # Remove plutodevmacros env
		# popfirst!(LOAD_PATH) # Remove parent_env
	end
	# using Main.Revise
	using Main.PlutoDevMacros
end

# ╔═╡ e12b4f7a-0d4a-4fa2-a850-faa6cb626795
@fromparent begin
	import PackageModule: toplevel_variable
	import ^.Issue2: GreatStructure
	import >.TOML
	using >.BenchmarkTools
end

# ╔═╡ d341f653-e1d0-4fbf-b83f-fccaa383cfa8
isdefined(@__MODULE__, :toplevel_variable) || error("toplevel_variable should be defined")

# ╔═╡ f2aebf0c-b135-4735-89d2-716d9983d42c
GreatStructure isa DataType || error("GreatStructure should be defined (and a Type)")

# ╔═╡ 3decbd80-c1bc-4d00-b89e-7f3ddaa07683
isdefined(@__MODULE__, Symbol("@benchmark")) || error("@benchmark should be available as BenchmarkTools should have been loaded as dependency by @fromparent")

# ╔═╡ Cell order:
# ╠═071ec1a4-eda6-11ed-3a1b-c1347c9fafa5
# ╠═e12b4f7a-0d4a-4fa2-a850-faa6cb626795
# ╠═d341f653-e1d0-4fbf-b83f-fccaa383cfa8
# ╠═f2aebf0c-b135-4735-89d2-716d9983d42c
# ╠═3decbd80-c1bc-4d00-b89e-7f3ddaa07683
