### A Pluto.jl notebook ###
# v0.19.42

using Markdown
using InteractiveUtils

# ╔═╡ 9ff61650-18ef-11ef-165b-13081b75c35f
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

# ╔═╡ e9f7421b-9ed0-4f4d-b458-689b301dad5c
@fromparent begin
	using *
	using >.TestPackage
	using >.TestDirectExtension
end

# ╔═╡ 4b493e7f-78d5-4005-b7c8-630dca053e6b
TestPackage isa Module || error("TestPackage not loaded correctly")

# ╔═╡ Cell order:
# ╠═9ff61650-18ef-11ef-165b-13081b75c35f
# ╠═e9f7421b-9ed0-4f4d-b458-689b301dad5c
# ╠═4b493e7f-78d5-4005-b7c8-630dca053e6b
