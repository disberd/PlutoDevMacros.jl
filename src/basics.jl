function _cell_data(filesrc::String)
	names = split(filesrc,"#==#")
	if length(names) > 1
		return names
	else
		return names[1], ""
	end
end
_cell_data(file::Symbol) = _cell_data(String(file))
_cell_data(lnn::LineNumberNode) = _cell_data(lnn.file)

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


## Macros ##
"""
	@current_pluto_cell_id()
Returns the cell_id (as a string) of the cell where the macro is called. If not
ran from within the pluto notebook containing the call, returns an empty string
"""
macro current_pluto_cell_id()
	_, cell_id = _cell_data(__source__.file::Symbol |> String)
	return isempty(cell_id) ? "" : string(cell_id)
end

"""
	@current_pluto_notebook_file()
Returns the path of the notebook file of the cell where the macro is called. If
not ran from within the pluto notebook containing the call, returns an empty
string
"""
macro current_pluto_notebook_file()
	nbfile, cell_id = _cell_data(__source__.file::Symbol |> String)
	return isempty(cell_id) ? "" : string(nbfile)
end

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

"""
	only_out_nb(ex)
Opposite of `@only_in_nb`

See also: [`@only_in_nb`](@ref). [`PlutoHooks.@only_as_script`](@ref).
"""
macro only_out_nb(ex) 
	is_notebook_local(String(__source__.file::Symbol)) ? nothing : esc(ex) 
end

"""
	@addmethod func(args...;kwargs...) = body
	@addmethod function func(args...;kwargs...) 
		body
	end
This simple macro modifies a function definition expression (only when called
from a Pluto notebook) to prepend the name of the module defining the function
(here called `DefiningModule`) to the method definition.

So the code
```julia
@addmethod func(args...;kwargs...) = something
```
is simply translated to
```julia
DefiningModule.func(args...;kwargs...) = something
```
when called from a Pluto notebook, and to:
```julia
func(args...;kwargs...) = something
```
when called outside of Pluto.

This is useful to avoid multiple definition errors inside Pluto but has the
caveat that defining a method with `@addmethod` does not trigger a reactive run
of all cells that call the modified function.
This also mean that when removing the cell with the `@addmethod` call, the
actual method added to the `DefiningModule` will not be automatically erased by
Pluto and will still accessible until it is not overwritten with another method
with the same signature. 

This is easy to fix in the case of adding methods to
modules loaded with `@frompackage`/`@fromparent` as reloading the module is
sufficient to remove the hanging method.

See this video for an example:

![Link to Video](https://user-images.githubusercontent.com/12846528/236472989-da86a311-4501-4966-9f0b-1298bbd9d53b.mp4)

See also: [`@frompackage`](@ref), [`@fromparent`](@ref)
"""
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