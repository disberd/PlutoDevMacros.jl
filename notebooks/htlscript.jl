### A Pluto.jl notebook ###
# v0.19.14

using Markdown
using InteractiveUtils

# ╔═╡ 3020de32-5b63-11ed-208f-1d2acb775b3b
using HypertextLiteral

# ╔═╡ af424bad-c980-4969-91b7-299d9f029691
md"""
# HTLScript
"""

# ╔═╡ 1aa9e236-eb68-43f5-afcd-1af51b71b34e
"""
	struct HTLScript
This struct is a simple wrapper around HypertextLiteral.Result intended to provide pretty printing and custom interpolation inside the `<script>` tags of the `@htl` macro.

The main use is simply to decouple parts of a script into separate variables and still be able to interpolate them within <script> tags to compose a bigger script.

Compared to simply using strings wrapped in `HypertextLiteral.JavaScript`, this gives the opportunity to exploit the experimental htmlmixed synthax highlighting of code inside cells.

The struct only accepts the output of the @htl macro as an input and expects the macro to only contain a single `<script>` tag block as follows:
```julia
wrapper = HTLScript(@htl(\"\"\"
<script>
code...
</script>
\"\"\"))
```
When interpolating `wrapper` above inside another `@htl` macro as `@htl "<script>\$wrapper</script>"` it would be as equivalent to directly writing `@htl "<script>code...</script>` inside the script. This is clearly only beneficial if multiple `HTLScript` variables are interpolated inside a single <script> block.

On top of the interpolation, an object of type `HTLScript` will show as a markdown javascript code block with the script contents wrapped by the `HTLScript` element.
"""
struct HTLScript
	result::HypertextLiteral.Result
	buffer::IOBuffer
	function HTLScript(r::HypertextLiteral.Result)
		buf = IOBuffer()
		temp = IOBuffer()
		trash = IOBuffer()
		show(temp, r)
		seekstart(temp)
		# This is adapted from readuntil in https://github.com/JuliaLang/julia/blob/f70b5e4767809c7dbc4c6c082aed67a2af4447c2/base/io.jl#L923-L943
		Base.readuntil_vector!(temp, codeunits("<script>"), false, trash)
		Base.readuntil_vector!(temp, codeunits("</script>"), false, buf)
		new(r, buf)
	end
end

# ╔═╡ a80dd217-bd5f-463c-adcd-56722f4f3027
export HTLScript

# ╔═╡ 08495423-6628-4898-8e91-28cdbc7a418c
# ╠═╡ skip_as_script = true
#=╠═╡
asd = (@htl """
<script>
	let out = html`<div></div>`
	console.log('first script')
</script>
""") |> HTLScript
  ╠═╡ =#

# ╔═╡ 25419f8c-9983-4cc4-9bda-f5f734482d7a
# ╠═╡ skip_as_script = true
#=╠═╡
lol = (@htl """
<script>
	let a = Math.random()
	out.innerText = a
	console.log('second script')
	return out
</script>
""") |> HTLScript
  ╠═╡ =#

# ╔═╡ 13c02158-c8e2-40a2-ae05-9d9793a1009d
#=╠═╡
@htl """
<script>
	$asd
	$lol
</script>
"""
  ╠═╡ =#

# ╔═╡ 0febddd9-6143-4b6c-ba64-b5d209c82603
#=╠═╡
[asd,lol]
  ╠═╡ =#

# ╔═╡ 8552047f-192f-493a-8b1a-8d51f32f81ae
#=╠═╡
@htl """
<script>
	$([asd, lol])
</script>
"""
  ╠═╡ =#

# ╔═╡ bb3b8e82-d556-4fbb-82b8-7e585d9d48ca
# Show the formatted code in markdown as output
function Base.show(io::IO, mime::MIME"text/html", s::HTLScript)
	buf = s.buffer
	seekstart(buf)
	codestring = strip(read(buf, String), '\n')
	show(io, mime, Markdown.MD(Markdown.Code("js", codestring)))
end

# ╔═╡ 7486654e-44fc-4fd7-9cc2-4b7b76f89a91
function Base.show(io::IO, mime::MIME"text/html", v::AbstractVector{HTLScript})
	codestring = ""
	foreach(v) do s
		buf = s.buffer
		seekstart(buf)
		codestring *= read(buf, String)
	end
	show(io, mime, Markdown.MD(Markdown.Code("js", strip(codestring, '\n'))))
end

# ╔═╡ ac2b8e3e-1704-48c3-bc1f-9f12010b7e3c
# This is to have a custom printing when inside a <script> tag within @htl 
function Base.show(io::IO, ::MIME"text/javascript", s::HTLScript)
	buf = s.buffer
	seekstart(buf)
	write(io, buf)
end

# ╔═╡ 9efdecea-27b1-4e9e-892f-c5475ebcf9d5
function HypertextLiteral.print_script(io::IO, v::AbstractVector{HTLScript})
	foreach(v) do s
		show(io, MIME"text/javascript"(), s)
	end
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
HypertextLiteral = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"

[compat]
HypertextLiteral = "~0.9.4"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.8.2"
manifest_format = "2.0"
project_hash = "312e4b9e605df01eeae246a2087d05a62416059a"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "c47c5fa4c5308f27ccaac35504858d8914e102f9"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.4"

[[deps.Tricks]]
git-tree-sha1 = "6bac775f2d42a611cdfcd1fb217ee719630c4175"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.6"
"""

# ╔═╡ Cell order:
# ╠═3020de32-5b63-11ed-208f-1d2acb775b3b
# ╠═a80dd217-bd5f-463c-adcd-56722f4f3027
# ╟─af424bad-c980-4969-91b7-299d9f029691
# ╠═1aa9e236-eb68-43f5-afcd-1af51b71b34e
# ╟─08495423-6628-4898-8e91-28cdbc7a418c
# ╟─25419f8c-9983-4cc4-9bda-f5f734482d7a
# ╠═13c02158-c8e2-40a2-ae05-9d9793a1009d
# ╠═0febddd9-6143-4b6c-ba64-b5d209c82603
# ╠═8552047f-192f-493a-8b1a-8d51f32f81ae
# ╠═bb3b8e82-d556-4fbb-82b8-7e585d9d48ca
# ╠═7486654e-44fc-4fd7-9cc2-4b7b76f89a91
# ╠═ac2b8e3e-1704-48c3-bc1f-9f12010b7e3c
# ╠═9efdecea-27b1-4e9e-892f-c5475ebcf9d5
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002

