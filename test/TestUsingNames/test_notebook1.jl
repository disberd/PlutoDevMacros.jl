### A Pluto.jl notebook ###
# v0.19.42

using Markdown
using InteractiveUtils

# ╔═╡ bb3dd7a0-19fc-11ef-093c-a938acaf0cf5
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

# ╔═╡ 23a1bdef-5c31-4c90-a7f5-1f5a806d3d2e
#=╠═╡
@fromparent @exclude_using import *
  ╠═╡ =#

# ╔═╡ e4f436ed-27e9-4d19-98bd-c2b3021cf8bd
# ╠═╡ skip_as_script = true
#=╠═╡
!isdefined(@__MODULE__, :base64encode) || error("base64encode from Base64 should not be defined")
  ╠═╡ =#

# ╔═╡ Cell order:
# ╠═bb3dd7a0-19fc-11ef-093c-a938acaf0cf5
# ╠═23a1bdef-5c31-4c90-a7f5-1f5a806d3d2e
# ╠═e4f436ed-27e9-4d19-98bd-c2b3021cf8bd
