### A Pluto.jl notebook ###
# v0.20.13

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
using PlutoDevMacros

# ╔═╡ ca13553c-d246-437a-9962-2a2045c7dd12
@fromparent begin
	import TestPackage
end

# ╔═╡ 9cab38df-9ba5-4f6a-b568-b8699d44e0d4
md"""
## Basic Tests
"""

# ╔═╡ 16a4e5e1-bde4-45a6-8777-ee4c7aa3d8f2
isdefined(TestPackage, :Issue2) || error("TestPackage should have the Issue2 module")

# ╔═╡ 71c1f0f3-79d9-4358-8032-9f7dee73836b
isdefined(TestPackage.Issue2, :CoolStruct) || error("CoolStruct2 inside module Issue2 should be defined")

# ╔═╡ c231c321-b89f-4f1a-8a60-5eb03c098fa1
isdefined(TestPackage, :SpecificImport) || error("The module SpecificImport was not found, it should be there but empty")

# ╔═╡ 06408ada-f0b7-4057-9177-a79baf2fa9cf
isdefined(TestPackage, :TEST_INIT) && TestPackage.TEST_INIT[] == 5 || error("The execution of the __init__ function did not seem to happen")

# ╔═╡ e37034a1-398c-45ad-803c-4b78e3388464
isdefined(TestPackage.SUBINIT, :TEST_SUBINIT) && TestPackage.SUBINIT.TEST_SUBINIT[] == 15 || error("The execution of the __init__ function in the submodule did not seem to happen")

# ╔═╡ 4a72716e-13a5-4914-a02f-8df4d590091f
md"""
## ImportAs Tests
This tests that import statements with `x as y` work
"""

# ╔═╡ 8642825b-d05c-407b-84ad-958a83a92953
!isdefined(TestPackage.ImportAsStatements, :CT) || error("The CT module should not be defined inside the ImportAsStatements submodule")

# ╔═╡ 081f71cb-8512-4b66-9f64-80a7c3fa8a71
let
	m = TestPackage.ImportAsStatements
	isdefined(m, :tp) & isdefined(m, :TML) || error("`tp` and `TML` should be defined inside the ImportAsStatements module")
end

# ╔═╡ 5c9a13c3-78b1-45a6-b9d9-67983e4fb927
md"""
## map expr tests
This tests that using custom `mapexpr` function within include statements in the package works
"""

# ╔═╡ c3691cc1-9cfb-460e-b94a-15c9357b0892
TestPackage.MapExpr.should_be_100 == 100 || error("The custom application of mapexpr in `include` did not work")

# ╔═╡ 83b8c9bb-c831-48cd-8d5d-0c9b8691d35c
TestPackage.MapExpr.should_not_be_15 !== 15 || error("The custom application of mapexpr in `include` did not work.\nVariable `should_not_be_15` is 15")

# ╔═╡ a298f325-85ef-4b48-a15c-67080515dd8d
!isdefined(TestPackage.MapExpr, :var_to_delete) || error("The custom application of mapexpr in `include` did not work")

# ╔═╡ 79a035c0-9138-4b47-87ab-1ce5e4b9a4d4
md"""
## Prettify Output
This tests that the types and function defined in the target package do not show the full module names which includes various temp modules
!!! note
	These tests can not be assessed outside of the browser as the _beautifying_ function is in javascript.
"""

# ╔═╡ 53dcca38-0014-4b0c-9a5c-f8cf6779a16f
TestPackage.PrettyPrint

# ╔═╡ 12e174cd-b431-4df9-80bc-e7e8974eee71
methods(TestPackage.PrettyPrint.some_function)

# ╔═╡ 783ae9cf-05a4-40c9-814d-c359bde6c668
TestPackage.testmethod |> methods

# ╔═╡ 0fd4ad04-b7cd-4055-aec4-e5c2612ebef2
let
	M = TestPackage.PrettyPrint
	M.some_function(M.SomeType())
end

# ╔═╡ Cell order:
# ╠═931a8c2c-ed76-11ed-3721-396dae146ad4
# ╠═bd0d177f-ab66-493d-89a6-a9faca81cd11
# ╠═ca13553c-d246-437a-9962-2a2045c7dd12
# ╟─9cab38df-9ba5-4f6a-b568-b8699d44e0d4
# ╠═16a4e5e1-bde4-45a6-8777-ee4c7aa3d8f2
# ╠═71c1f0f3-79d9-4358-8032-9f7dee73836b
# ╠═c231c321-b89f-4f1a-8a60-5eb03c098fa1
# ╠═06408ada-f0b7-4057-9177-a79baf2fa9cf
# ╠═e37034a1-398c-45ad-803c-4b78e3388464
# ╟─4a72716e-13a5-4914-a02f-8df4d590091f
# ╠═8642825b-d05c-407b-84ad-958a83a92953
# ╠═081f71cb-8512-4b66-9f64-80a7c3fa8a71
# ╟─5c9a13c3-78b1-45a6-b9d9-67983e4fb927
# ╠═c3691cc1-9cfb-460e-b94a-15c9357b0892
# ╠═83b8c9bb-c831-48cd-8d5d-0c9b8691d35c
# ╠═a298f325-85ef-4b48-a15c-67080515dd8d
# ╟─79a035c0-9138-4b47-87ab-1ce5e4b9a4d4
# ╠═53dcca38-0014-4b0c-9a5c-f8cf6779a16f
# ╠═12e174cd-b431-4df9-80bc-e7e8974eee71
# ╠═783ae9cf-05a4-40c9-814d-c359bde6c668
# ╠═0fd4ad04-b7cd-4055-aec4-e5c2612ebef2
