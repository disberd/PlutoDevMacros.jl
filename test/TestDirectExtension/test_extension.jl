### A Pluto.jl notebook ###
# v0.19.43

using Markdown
using InteractiveUtils

# ╔═╡ c2b18f94-b49d-4b4e-a485-85072cb797bf
begin
	import Pkg
	Pkg.activate(joinpath(@__DIR__, "notebook_env"))
	using Revise
end

# ╔═╡ abccfc80-afaf-4c54-b300-c0c893de3848
begin
	using PlutoDevMacros
	using PlutoPlotly
	using Example
end

# ╔═╡ 90ca1f01-cbad-496a-b3e2-7dc7231ed101
@fromparent using PackageModule

# ╔═╡ 675230da-e628-4059-b44d-6137a4dd4987
standard_extension_output = to_extend(plot(rand(4)).Plot)

# ╔═╡ 8e7563ce-d2ba-4356-93e4-70ebe0f2be87
weird_extension_output = to_extend(Example)

# ╔═╡ 8d561235-2003-4446-bd64-b7f235d653a4
standard_extension_output === "Standard Extension works!" || error("PlotlyBase extension did not load")

# ╔═╡ 6f258d3c-7c09-4009-ad8d-001dbd451ad2
weird_extension_output === "Weird Extension name works!" || error("Example extension did not load")

# ╔═╡ da703251-1f4a-4fa1-ba08-720bceb2ada6
p = plot_this()

# ╔═╡ 1e143a84-1a79-448b-a7ff-189ef167870d
to_extend((hello, p.Plot)) === "Dual Deps Extension works!" || error("dual deps extension failed")

# ╔═╡ Cell order:
# ╠═c2b18f94-b49d-4b4e-a485-85072cb797bf
# ╠═abccfc80-afaf-4c54-b300-c0c893de3848
# ╠═90ca1f01-cbad-496a-b3e2-7dc7231ed101
# ╠═675230da-e628-4059-b44d-6137a4dd4987
# ╠═8e7563ce-d2ba-4356-93e4-70ebe0f2be87
# ╠═8d561235-2003-4446-bd64-b7f235d653a4
# ╠═6f258d3c-7c09-4009-ad8d-001dbd451ad2
# ╠═1e143a84-1a79-448b-a7ff-189ef167870d
# ╠═da703251-1f4a-4fa1-ba08-720bceb2ada6
