### A Pluto.jl notebook ###
# v0.19.39

using Markdown
using InteractiveUtils

# ╔═╡ d4f2f0ca-c463-4318-8fe8-ad41ae9ca998
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

# ╔═╡ 03c088e9-257c-4e76-a13e-d14366b6f96c
@fromparent begin
	import ^: *
end

# ╔═╡ Cell order:
# ╠═d4f2f0ca-c463-4318-8fe8-ad41ae9ca998
# ╠═03c088e9-257c-4e76-a13e-d14366b6f96c
