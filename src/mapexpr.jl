const default_exprlist = [Symbol("@md_str"), Symbol("@benchmark"), :(using Markdown), :PLUTO_MANIFEST_TOML_CONTENTS, :PLUTO_PROJECT_TOML_CONTENTS]

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

# Fallback for when a single element is provided
hasexpr(ex,exprlist) = hasexpr(ex,[exprlist])

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