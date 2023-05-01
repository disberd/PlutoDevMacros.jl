### A Pluto.jl notebook ###
# v0.19.24

using Markdown
using InteractiveUtils

# ╔═╡ f32cb55a-cf6d-40cd-8d5a-81445a685b53
import MacroTools: shortdef

# ╔═╡ 887893a3-0f17-47c4-ae40-3459fbf2a4f4
md"""
# Exports
"""

# ╔═╡ 03bea6d7-c397-4a25-a5ff-af370e171f49
md"""
# Functions
"""

# ╔═╡ 047bc2be-35bc-45e4-bca8-75beeda57057
function _cell_data(filesrc::String)
	names = split(filesrc,"#==#")
	if length(names) > 1
		return names
	else
		return names[1], ""
	end
end

# ╔═╡ 356a8eb0-4f70-11ec-3ca7-efdefb29fe4f
"""
	is_notebook_local(filesrc::AbstractString)::Bool
Returns `true` if Pluto is loaded and if the `filesrc` points to the currently running Pluto cell_id

To be fed the result of `@__FILE__` (or `__source__.file` used inside macros) as `filesrc`.\\
This works because the `@__FILE__` information contains the name of the Pluto notebook followed the string `#==#` and by the cell UUID in case this is called directly in a notebook (and not included from outside)
"""
function is_notebook_local(filesrc)::Bool
	# If this is ran from the notebook it is defined in Pluto, the output of __source__.file or @__FILE__ is split into filepath and cell_id with a #==# separator
	file, cell_id = _cell_data(filesrc)
	return isempty(cell_id) ? false : true
end

# ╔═╡ fa0cf8bd-f783-44cb-9f32-115531adb7d4
"""
	plutodump(x::Union{Symbol, Expr}; maxdepth = 8)
Dumps a symbol or expression directly as text on the pluto cell output instead of in the stdout

See also: [`Meta.dump`](@ref)
"""
function plutodump(x::Union{Symbol, Expr}; maxdepth = 8)
	i = IOBuffer()
	Meta.dump(i, x; maxdepth)
	String(take!(i)) |> Text
end

# ╔═╡ 17f796de-e2db-41a8-9120-509ca54be657
"""
	@current_pluto_cell_id()
Returns the cell_id (as a string) of the cell where the macro is called. If not ran from within the pluto notebook containing the call, returns an empty string
"""
macro current_pluto_cell_id()
	_, cell_id = _cell_data(__source__.file::Symbol |> String)
	return isempty(cell_id) ? "" : cell_id
end

# ╔═╡ 4786625f-39d9-47f7-9f19-2410a91d52db
"""
	@current_pluto_notebook_file()
Returns the path of the notebook file of the cell where the macro is called. If not ran from within the pluto notebook containing the call, returns an empty string
"""
macro current_pluto_notebook_file()
	nbfile, cell_id = _cell_data(__source__.file::Symbol |> String)
	return isempty(cell_id) ? "" : nbfile
end

# ╔═╡ a79573ae-60d7-4e40-a4c3-3662f48adcf8
function is_notebook_local()
	cell_id = try
		Main.PlutoRunner.currently_running_cell_id[]
	catch e
		return false
	end
	caller = stacktrace()[2] # We get the function calling this function
	calling_file = caller.file |> string
	return endswith(calling_file, string(cell_id))
end

# ╔═╡ 35728756-c270-4455-9131-1636614f2466
"""
	only_in_nb(ex)
Executes the expression `ex` only if the macro is called from a running Pluto instance and ran directly from the source notebook file.

This is more strict than `PlutoHooks.@skip_as_script` as including a notebook with `@skip_as_script ex` from another notebook would still execute `ex`.\\
`@only_in_nb ex` instead only evaluates `ex` if the calling notebook is the original source notebook file.

See also: [`@only_out_nb`](@ref). [`PlutoHooks.@skip_as_script`](@ref).
"""
macro only_in_nb(ex) 
	is_notebook_local(String(__source__.file::Symbol)) ? esc(ex) : nothing 
end

# ╔═╡ fb6ce0fb-bae4-4120-9f33-4edcd36c3c2e
"""
	only_out_nb(ex)
Opposite of `@only_in_nb`

See also: [`@only_in_nb`](@ref). [`PlutoHooks.@only_as_script`](@ref).
"""
macro only_out_nb(ex) 
	is_notebook_local(String(__source__.file::Symbol)) ? nothing : esc(ex) 
end

# ╔═╡ ee668600-5010-4718-a8b5-0016a4118486
macro addmethod(ex)
	if is_notebook_local(String(__source__.file::Symbol))
		def = shortdef(ex)
		fname = def.args[1].args[1]
		# Switch it to (::typeof(fname))
		def.args[1].args[1] = :(::typeof($fname))
		esc(def)
	else
		esc(ex)
	end
end

# ╔═╡ fd5f3b92-a1ac-449c-aafd-d29783152da3
export @only_in_nb, @only_out_nb, plutodump, @current_pluto_cell_id, @current_pluto_notebook_file, @addmethod

# ╔═╡ e3296a1c-9d38-4363-b275-42738d1ebae7
# ╠═╡ skip_as_script = true
#=╠═╡
asd(x::Int) = 3
  ╠═╡ =#

# ╔═╡ 5808997c-0da3-4d1d-8b9a-b0e8965ce4a8
#=╠═╡
@addmethod asd(x::Float64) = 4.0
  ╠═╡ =#

# ╔═╡ 65603c9c-5b1b-4cd0-9db2-7216520d1c36
#=╠═╡
@addmethod asd(x::String) = "LOL" * string(asd(1))
  ╠═╡ =#

# ╔═╡ 53f8ca75-67f1-47c5-9c1e-a3747b376c3a
#=╠═╡
asd(3.0)
  ╠═╡ =#

# ╔═╡ b4351ff1-65eb-45d8-9262-6811fc0884f1
#=╠═╡
asd("ASD")
  ╠═╡ =#

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
MacroTools = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"

[compat]
MacroTools = "~0.5.10"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.9.0-rc2"
manifest_format = "2.0"
project_hash = "12baccd4e76911866d4f70f7337d171b47d17cd9"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "42324d08725e200c23d4dfb549e0d5d89dede2d2"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.10"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
"""

# ╔═╡ Cell order:
# ╠═f32cb55a-cf6d-40cd-8d5a-81445a685b53
# ╟─887893a3-0f17-47c4-ae40-3459fbf2a4f4
# ╠═fd5f3b92-a1ac-449c-aafd-d29783152da3
# ╟─03bea6d7-c397-4a25-a5ff-af370e171f49
# ╠═047bc2be-35bc-45e4-bca8-75beeda57057
# ╠═356a8eb0-4f70-11ec-3ca7-efdefb29fe4f
# ╠═35728756-c270-4455-9131-1636614f2466
# ╠═fb6ce0fb-bae4-4120-9f33-4edcd36c3c2e
# ╠═fa0cf8bd-f783-44cb-9f32-115531adb7d4
# ╠═17f796de-e2db-41a8-9120-509ca54be657
# ╠═4786625f-39d9-47f7-9f19-2410a91d52db
# ╠═a79573ae-60d7-4e40-a4c3-3662f48adcf8
# ╠═ee668600-5010-4718-a8b5-0016a4118486
# ╠═e3296a1c-9d38-4363-b275-42738d1ebae7
# ╠═5808997c-0da3-4d1d-8b9a-b0e8965ce4a8
# ╠═65603c9c-5b1b-4cd0-9db2-7216520d1c36
# ╠═53f8ca75-67f1-47c5-9c1e-a3747b376c3a
# ╠═b4351ff1-65eb-45d8-9262-6811fc0884f1
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
