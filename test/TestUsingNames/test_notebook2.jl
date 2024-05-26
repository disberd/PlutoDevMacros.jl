### A Pluto.jl notebook ###
# v0.19.42

using Markdown
using InteractiveUtils

# ╔═╡ 4f8def86-f90b-4f74-ac47-93fe6e437cee
# ╠═╡ skip_as_script = true
#=╠═╡
begin
	test_project = Base.current_project(normpath(@__DIR__, ".."))
	notebook_project = Base.active_project()
	plutodevmacros_project= Base.current_project(normpath(@__DIR__, "../..")) 
	Base.eval(Main, quote # instantiate the parent env, mostly for CI
		import Pkg
		Pkg.activate($test_project)
		Pkg.instantiate()
		Pkg.activate($notebook_project)
	end)
	pushfirst!(LOAD_PATH, test_project) # This contains Revise
	pushfirst!(LOAD_PATH, plutodevmacros_project) # This loads the PlutoDevMacros environment, so we can do import with the latest version
	try
		Base.eval(Main, :(import Revise))
		Base.eval(Main, :(import PlutoDevMacros))
	finally
		popfirst!(LOAD_PATH) # Remove plutodevmacros env
		popfirst!(LOAD_PATH) # Remove parent_env
	end
	using Main.Revise
	using Main.PlutoDevMacros
end
  ╠═╡ =#

# ╔═╡ ac3d261a-86c9-453f-9d86-23a8f30ca583
#=╠═╡
@fromparent import *
  ╠═╡ =#

# ╔═╡ dd3f662f-e2ce-422d-a91a-487a4da359cc
# ╠═╡ skip_as_script = true
#=╠═╡
isdefined(@__MODULE__, :base64encode) || error("base64encode from Base64 should be defined")
  ╠═╡ =#

# ╔═╡ Cell order:
# ╠═4f8def86-f90b-4f74-ac47-93fe6e437cee
# ╠═ac3d261a-86c9-453f-9d86-23a8f30ca583
# ╠═dd3f662f-e2ce-422d-a91a-487a4da359cc
