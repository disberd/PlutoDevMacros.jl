### A Pluto.jl notebook ###
# v0.19.42

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

# ╔═╡ da2f67c7-530e-4e65-8876-06588a5f4411
# ╠═╡ skip_as_script = true
#=╠═╡
this_file = relpath(split(@__FILE__,"#==#")[1], dirname(dirname(dirname(@__DIR__))))
  ╠═╡ =#

# ╔═╡ ca13553c-d246-437a-9962-2a2045c7dd12
@fromparent begin
	import TestPackage
	@skiplines begin
		"22" # Skip line in the main file TestPackage.jl which defines module Inner
		"test_macro2.jl" # This skips the whole file test_macro2.jl
		"33-34" # This skips lines in the main file, which are the 2 include statements of the inner SpecificImport module
		"test_macro1.jl:::28-10000" # This skips parts of test_macro1.jl
	end
end

# ╔═╡ 09d5606d-d68e-4610-ae11-f3712e2d6aa2
# This module does not exist as it was removed because we skip line 13
!isdefined(TestPackage, :Inner) || error("Module Inner should not be defined as we skipped the line defining it")

# ╔═╡ 16a4e5e1-bde4-45a6-8777-ee4c7aa3d8f2
isdefined(TestPackage, :Issue2) || error("TestPackage should have the Issue2 module")

# ╔═╡ bdb4c4e3-84dd-4795-b272-eadcb0b56fb8
# This is not defined because we skipped test_macro2.jl
!isdefined(TestPackage.Issue2, :GreatStructure) || error("GreatStructure should not be defined as it is inside file test_macro2.jl that we skipped")

# ╔═╡ 71c1f0f3-79d9-4358-8032-9f7dee73836b
isdefined(TestPackage.Issue2, :CoolStruct) || error("CoolStruct2 inside module Issue2 should be defined")

# ╔═╡ 705ad7ec-b73c-48d5-b6d8-43833115cdf3
# This is not defined because we skipped test_macro1.jl from line 28
!isdefined(TestPackage.Issue2, :NotThatCoolStruct) || error("NotThatCoolStruct should not be defined as we should have skipped everything after line 28 in test_macro1.jl")

# ╔═╡ c231c321-b89f-4f1a-8a60-5eb03c098fa1
isdefined(TestPackage, :SpecificImport) || error("The module SpecificImport was not found, it should be there but empty")

# ╔═╡ 3e83aab4-5feb-4f3f-9dc1-2da208bcd599
# Not defined because we removed line 24 and 25, so SpecificImport is an empty module
!isdefined(TestPackage.SpecificImport, :inner_variable1) || error("SpecificImport should not have execute include statements at lines 24 and 25")

# ╔═╡ 06408ada-f0b7-4057-9177-a79baf2fa9cf
isdefined(TestPackage, :TEST_INIT) && TestPackage.TEST_INIT[] == 5 || error("The execution of the __init__ function did not seem to happen")

# ╔═╡ e37034a1-398c-45ad-803c-4b78e3388464
isdefined(TestPackage.SUBINIT, :TEST_SUBINIT) && TestPackage.SUBINIT.TEST_SUBINIT[] == 15 || error("The execution of the __init__ function in the submodule did not seem to happen")

# ╔═╡ 14a547ce-f48a-4f19-88f5-b2ca499fc087
(FromPackage.issamepath(pkgdir(TestPackage), @__DIR__)) || error("`pkgdir(TestPackage)` did not return the correct path, it seems like registering as root module failed")

# ╔═╡ Cell order:
# ╠═931a8c2c-ed76-11ed-3721-396dae146ad4
# ╠═bd0d177f-ab66-493d-89a6-a9faca81cd11
# ╠═da2f67c7-530e-4e65-8876-06588a5f4411
# ╠═ca13553c-d246-437a-9962-2a2045c7dd12
# ╠═09d5606d-d68e-4610-ae11-f3712e2d6aa2
# ╠═16a4e5e1-bde4-45a6-8777-ee4c7aa3d8f2
# ╠═bdb4c4e3-84dd-4795-b272-eadcb0b56fb8
# ╠═71c1f0f3-79d9-4358-8032-9f7dee73836b
# ╠═705ad7ec-b73c-48d5-b6d8-43833115cdf3
# ╠═c231c321-b89f-4f1a-8a60-5eb03c098fa1
# ╠═3e83aab4-5feb-4f3f-9dc1-2da208bcd599
# ╠═06408ada-f0b7-4057-9177-a79baf2fa9cf
# ╠═e37034a1-398c-45ad-803c-4b78e3388464
# ╠═14a547ce-f48a-4f19-88f5-b2ca499fc087
