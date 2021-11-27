### A Pluto.jl notebook ###
# v0.17.2

# using Markdown
# using InteractiveUtils

# ╔═╡ ab7fc0f6-d065-4c03-aeb5-64a49214399e
const default_exprlist = [Symbol("@md_str"), Symbol("@benchmark"), :(using Markdown), :PLUTO_MANIFEST_TOML_CONTENTS, :PLUTO_PROJECT_TOML_CONTENTS]

# ╔═╡ 2ac5f3c6-96f8-4f24-8022-1f0470672383
#=╠═╡ notebook_exclusive
"""
    hasexpr(expr, exprlist)

Simple expression match; will return `true` if one of the exprs listed in `exprlist` can
be found inside `expr`. Checking for macrocalls can be done by including the `Symbol` of the macro among the expression list

```julia
hasexpr(:(@benchmark 3+2), Symbol("@benchmark")) == true
```
"""
function hasexpr(ex, exprlist::AbstractVector)
  result = false
  MacroTools.postwalk(ex) do y
    if y in exprlist
      result = true
    end
    return y
  end
  return result
end
  ╠═╡ notebook_exclusive =#

# ╔═╡ 1663bd40-4a0c-42cd-b716-4583d0a1bb66
# Fallback for when a single element is provided
hasexpr(ex,exprlist) = hasexpr(ex,[exprlist])

# ╔═╡ b42062a6-5bca-4c47-835c-caaeee1ceac6
"""
	include_mapexpr([exprlist])::Function 
Returns a function that can be used as first argument (`mapexpr`) of [`include`](@ref) calls
to avoid including some of the expressions inside a Pluto notebook.

When applied to an expression `ex`, the output function traverse `ex` recursively and
returns `nothing` if `ex ∈ exprlist` and `ex` otherwise.

The expression walk is performed with [`MacroTools.postwalk`](@ref) so for example the name
of macros can be used to filter out nested expr which contains the macro call.

When called without arguments, the value of `exprlist` defaults to a vector containing some
filtering entries for Pluto notebooks:

	default_exprlist = $default_exprlist

```julia
include_mapexpr()(:(md"asd")) == nothing
include_mapexpr()(:(3 + 2)) == :(3+2)
include_mapexpr([3])(:(3 + 2)) == nothing
```
"""
include_mapexpr(exprlist=default_exprlist) = ex -> hasexpr(ex,exprlist) ? nothing : ex

# ╔═╡ b0f0df45-ed36-454a-9a9d-215f8c23836a
export include_mapexpr

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
# ╠═ab7fc0f6-d065-4c03-aeb5-64a49214399e
# ╠═b0f0df45-ed36-454a-9a9d-215f8c23836a
# ╠═2ac5f3c6-96f8-4f24-8022-1f0470672383
# ╠═1663bd40-4a0c-42cd-b716-4583d0a1bb66
# ╠═b42062a6-5bca-4c47-835c-caaeee1ceac6
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
