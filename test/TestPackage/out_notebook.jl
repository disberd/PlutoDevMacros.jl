### A Pluto.jl notebook ###
# v0.19.25

using Markdown
using InteractiveUtils

# ╔═╡ 931a8c2c-ed76-11ed-3721-396dae146ad4
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

# ╔═╡ bd0d177f-ab66-493d-89a6-a9faca81cd11
using PlutoDevMacros.FromPackage

# ╔═╡ ca13553c-d246-437a-9962-2a2045c7dd12
@fromparent begin
	import TestPackage
	@skiplines begin
		"11" # Skip line 11 in the main file TestPackage.jl. This does not load module Inner
		"test_macro2.jl" # This skips the whole file test_macro2.jl
		"22-23" # This skips from line 21 to 22 in the main file, including extrema. This translates to module SpecificImport being empty
		"test_macro1.jl:28-10000" # This skips parts of test_macro1.jl
	end
end

# ╔═╡ 09d5606d-d68e-4610-ae11-f3712e2d6aa2
# This module does not exist as it was removed because we skip line 11
!isdefined(TestPackage, :Inner) || error("This is unexpected")

# ╔═╡ 16a4e5e1-bde4-45a6-8777-ee4c7aa3d8f2
isdefined(TestPackage, :Issue2) || error("This is unexpected")

# ╔═╡ bdb4c4e3-84dd-4795-b272-eadcb0b56fb8
# This is not defined because we skipped test_macro2.jl
!isdefined(TestPackage.Issue2, :GreatStructure) || error("This is unexpected")

# ╔═╡ 71c1f0f3-79d9-4358-8032-9f7dee73836b
# This is not defined because we skipped test_macro1.jl from line 28
isdefined(TestPackage.Issue2, :CoolStruct) || error("This is unexpected")

# ╔═╡ 705ad7ec-b73c-48d5-b6d8-43833115cdf3
# This is not defined because we skipped test_macro1.jl from line 28
!isdefined(TestPackage.Issue2, :NotThatCoolStruct) || error("This is unexpected")

# ╔═╡ c231c321-b89f-4f1a-8a60-5eb03c098fa1
isdefined(TestPackage, :SpecificImport) || error("This is unexpected")

# ╔═╡ 3e83aab4-5feb-4f3f-9dc1-2da208bcd599
# Not defined because we removed line 22 and 23, so SpecificImport is an empty module
!isdefined(TestPackage.SpecificImport, :inner_variable1) || error("This is unexpected")

# ╔═╡ Cell order:
# ╠═931a8c2c-ed76-11ed-3721-396dae146ad4
# ╠═bd0d177f-ab66-493d-89a6-a9faca81cd11
# ╠═ca13553c-d246-437a-9962-2a2045c7dd12
# ╠═09d5606d-d68e-4610-ae11-f3712e2d6aa2
# ╠═16a4e5e1-bde4-45a6-8777-ee4c7aa3d8f2
# ╠═bdb4c4e3-84dd-4795-b272-eadcb0b56fb8
# ╠═71c1f0f3-79d9-4358-8032-9f7dee73836b
# ╠═705ad7ec-b73c-48d5-b6d8-43833115cdf3
# ╠═c231c321-b89f-4f1a-8a60-5eb03c098fa1
# ╠═3e83aab4-5feb-4f3f-9dc1-2da208bcd599
