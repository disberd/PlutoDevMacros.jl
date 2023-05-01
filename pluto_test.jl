### A Pluto.jl notebook ###
# v0.19.22

using Markdown
using InteractiveUtils

# ╔═╡ 7fca1ea8-c30a-11ed-01d0-8737b110ab7a
begin
	import Pkg
	Pkg.activate(Base.current_project())
	using Revise
	using LoggingExtras
end

# ╔═╡ 657425b7-fb50-4257-a610-bd7f27f1c783
begin
	using PlutoDevMacros
	using PlutoDevMacros: is_notebook_local
	import PlutoDevMacros.FromParent: @fromparent, @removeexpr
end

# ╔═╡ 4c982250-edde-4a7f-91c9-f82cbbae8e7a
@removeexpr [
	:(using Requires),
	:(using MacroTools),
]

# ╔═╡ e59536cc-7f49-4210-bf28-dd2484321fbd
names(PlutoDevMacros.FromParent._MODULE_;all=true)

# ╔═╡ ffb54854-e3d7-4dc4-99b8-5c443e7ba9ef
@fromparent begin
	import module.Script: *
end

# ╔═╡ b20e5c96-0470-49a9-bae7-e535dd4e312b
asd(x::Int) = 3

# ╔═╡ 47ff421f-1bd4-4bfd-811c-8582d59876b0
@addmethod function is_notebook_local(x,y)
	"ASD"
end

# ╔═╡ ed684f08-ae0f-493d-8334-74b07694333f
is_notebook_local(3,4)

# ╔═╡ 5d8f3bd5-59be-47b8-a35f-e08cea01d6cf
asd(3.0)

# ╔═╡ Cell order:
# ╠═7fca1ea8-c30a-11ed-01d0-8737b110ab7a
# ╠═657425b7-fb50-4257-a610-bd7f27f1c783
# ╠═4c982250-edde-4a7f-91c9-f82cbbae8e7a
# ╠═e59536cc-7f49-4210-bf28-dd2484321fbd
# ╠═ffb54854-e3d7-4dc4-99b8-5c443e7ba9ef
# ╠═b20e5c96-0470-49a9-bae7-e535dd4e312b
# ╠═47ff421f-1bd4-4bfd-811c-8582d59876b0
# ╠═ed684f08-ae0f-493d-8334-74b07694333f
# ╠═5d8f3bd5-59be-47b8-a35f-e08cea01d6cf
