### A Pluto.jl notebook ###
# v0.17.2

# using Markdown
# using InteractiveUtils

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

# ╔═╡ fd5f3b92-a1ac-449c-aafd-d29783152da3
export @only_in_nb, @only_out_nb, plutodump, @current_pluto_cell_id, @current_pluto_notebook_file

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.7.0-rc2"
manifest_format = "2.0"

[deps]
"""

# ╔═╡ Cell order:
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
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
