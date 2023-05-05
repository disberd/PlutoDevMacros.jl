### A Pluto.jl notebook ###
# v0.19.25

using Markdown
using InteractiveUtils

# ╔═╡ 414ea677-fc22-42d1-b28c-36d0666f466e
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

# ╔═╡ d8bb9b0c-b777-4b92-aab4-688358059f6d
using PlutoDevMacros.FromPackage

# ╔═╡ da3cb2df-c686-45ed-abad-d4556c253ffa
# When using PackageModule as name of the package to use or import from, `PackageModule` is substituted with the acutal module of the package targeted by @frompackage/@fromparent and loaded within the notebook.
# Similarly, ParentModule as name is substituted to the name of module that in the loaded package is including the target/current file. If the current file is not included within the package a statement referring to ParentModule is invalid and will throw an error.
# PackageModule and ParentModule can point to the same module in case the file is not part of a submodule of the package module.
@fromparent begin
	using PackageModule # This just loads the exported names from TestPackage, which is only toplevel_variable
	import ParentModule: inner_variable1 # This only imports `inner_variable` from the module containing the current file, which is the SpecificImport module
end

# ╔═╡ b03c28ca-9ad3-4ca0-a025-d0ca7799a6b2
# This cell will not error outside of Pluto (when executing the code of this notebook that is included in TestPackage) because inner_variable2 is visible outside of Pluto 
inner_variable2

# ╔═╡ ea26eaf9-bc34-4d53-b3af-641fec5039dd
# ╠═╡ skip_as_script = true
#=╠═╡
# This is skipped_as_script because toplevel_variable is not visible outside of Pluto, as import statements that are not using relative module paths are discarded by @frompackage/@fromparent outside of Pluto
toplevel_variable + inner_variable1
  ╠═╡ =#

# ╔═╡ Cell order:
# ╠═414ea677-fc22-42d1-b28c-36d0666f466e
# ╠═d8bb9b0c-b777-4b92-aab4-688358059f6d
# ╠═da3cb2df-c686-45ed-abad-d4556c253ffa
# ╠═b03c28ca-9ad3-4ca0-a025-d0ca7799a6b2
# ╠═ea26eaf9-bc34-4d53-b3af-641fec5039dd
