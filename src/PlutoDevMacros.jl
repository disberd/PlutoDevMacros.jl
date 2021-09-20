module PlutoDevMacros

using MacroTools

export @only_in_nb, @only_out_nb, include_mapexpr

function is_notebook_local(filesrc)
	if isdefined(Main,:PlutoRunner)
		# Try to see if the last 36 character of the source file are a UUID (Pluto cells have their cell_id appended to the file_source)
		cell_id = tryparse(Base.UUID,last(filesrc,36))
		cell_id !== nothing && cell_id === Main.PlutoRunner.currently_running_cell_id[] && return true
	end
	return false
end

macro only_in_nb(ex) is_notebook_local(String(__source__.file::Symbol)) ? esc(ex) : nothing end
macro only_out_nb(ex) is_notebook_local(String(__source__.file::Symbol)) ? nothing : esc(ex) end


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

end # module
