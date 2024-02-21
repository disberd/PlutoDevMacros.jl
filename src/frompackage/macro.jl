import Base: stacktrace, catch_backtrace

_id_name(cell_id) = Symbol(:_fromparent_cell_id_, cell_id)

function is_call_unique(cell_id, caller_module)
	current_id = macro_cell[]
	current_id == cell_id && return true
	# If we get here we have a potential multiple call
	id_name = _id_name(current_id)
	return if isdefined(caller_module, id_name) 
		false
	else
		# We have the update the cell reference
		macro_cell[] = cell_id
		true
	end
end

function wrap_parse_error(e)
	# Just return the error if we are not in 1.10 or is not a ParseError
	VERSION >= v"1.10" && e isa Base.Meta.ParseError && hasproperty(e, :detail) || return e
	# Extract the filename and line of the parseerror
	(;source, diagnostics) = e.detail
	byte_index = first(diagnostics) |> Base.JuliaSyntax.first_byte
	line = Base.JuliaSyntax.source_line(source, byte_index)
	file = source.filename
	# We wrap this in a LoadError as if we `included` the file containnig the error
	return LoadError(file, line, e)
end

function is_macroexpand(trace, cell_id)
	for _ ∈ eachindex(trace)
		# We go throught the stack until we find the call to :macroexpand
		frame = popfirst!(trace)
		frame.func == :macroexpand && break
	end
	length(trace) < 1 && return false
	caller_frame = popfirst!(trace)
	file, id = _cell_data(String(caller_frame.file))
	if id == cell_id
		# @info "@macroexpand call"
		return true
	end
	return false
end

## @frompackage

function frompackage(ex, target_file, caller, caller_module; macroname)
	is_notebook_local(caller) || return process_outside_pluto!(ex, get_package_data(target_file))
	_, cell_id = _cell_data(caller)
	maybe_update_envcache(Base.active_project(), ENVS; notebook = true)
	proj_file = Base.current_project(target_file)
	id_name = _id_name(cell_id)
	ex isa Expr || error("You have to call this macro with an import statement or a begin-end block of import statements")
	# Try to load the module of the target package in the calling workspace and return the dict with extracted paramteres
	dict = if is_call_unique(cell_id, caller_module)
		dict = get_package_data(target_file)
		# We try to extract eventual lines to skip
		process_skiplines!(ex, dict)
		load_module_in_caller(dict, caller_module)
	else
		error("Multiple Calls: The $macroname is already present in cell with id $(macro_cell[]), you can only have one call-site per notebook")
	end
	args = []
	# We extract the parse dict
	ex_args = if Meta.isexpr(ex, [:import, :using])
		[ex]
	elseif Meta.isexpr(ex, :block)
		ex.args
	else
		error("You have to call this macro with an import statement or a begin-end block of import statements")
	end
	# We now process/parse all the import/using statements
	for arg in ex_args
		arg isa LineNumberNode && continue
		push!(args, parseinput(arg, dict))
	end
	# Now we add the call to maybe load the package extensions
	push!(args, :($load_package_extensions($dict, @__MODULE__)))
	# Check if we are inside a direct macroexpand code, and clean the LOAD_PATH if we do as we won't be executing the retured expression
	is_macroexpand(stacktrace(), cell_id) && clean_loadpath(proj_file)
	# We wrap the import expressions inside a try-catch, as those also correctly work from there.
	# This also allow us to be able to catch the error in case something happens during loading and be able to gracefully clean the work space
	text = "Reload $macroname"
	out = quote
		# We put the cell id variable
		$id_name = true
		try
			$(args...)
			# We add the reload button as last expression so it's sent to the cell output
			$html_reload_button($cell_id; text = $text)
		catch e
			# We also send the reload button as an @info log, so that we can use the cell output to format the error nicely
			@info $html_reload_button($cell_id; text = $text)
			rethrow()
		end
	end
	return out
end

function _combined(ex, target, calling_file, caller_module; macroname)
	# Enforce absolute path to handle different OSs
	target = abspath(target)
	calling_file = abspath(calling_file)
	_, cell_id = _cell_data(calling_file)
	proj_file = Base.current_project(target)
	out = try
		frompackage(ex, target, calling_file, caller_module; macroname)
	catch e
		# If we are outside of pluto we simply rethrow
		is_notebook_local(calling_file) || rethrow()
		out = Expr(:block)
		if !(e isa ErrorException && startswith(e.msg, "Multiple Calls: The"))
			text = "Reload $macroname"
			# We send a log to maintain the reload button
			@info html_reload_button(cell_id; text, err = true)
		end
		# Wrap ParseError in LoadError (see https://github.com/disberd/PlutoDevMacros.jl/issues/30)
		we = wrap_parse_error(e)
		# If we are at macroexpand, simply rethrow here, ohterwise output the expression with the error
		is_macroexpand(stacktrace(), cell_id) && throw(we)
		bt = stacktrace(catch_backtrace())
		# Outputting the CaptureException as last statement allows pretty printing of errors inside Pluto
		push!(out.args,	:(CapturedException($we, $bt)))
		out
	end
	out
end

"""
	@frompackage target import_block

This macro takes a local Package (derived from the `target` path), loads it as
a submodule of the current Pluto workspace and then process the various
import/using statements inside `import_block` to extract varables/functions from
the local Package into the notebook workspace.

Its main use is allowing to load a local package under development within a
running Pluto notebook in order to facilitate prototyping and testing.

The following julia code inside a Pluto notebook cell:
```julia
@frompackage local_package_path begin
	import ^: *
	using >.LocalDependency
end
```
takes the main module definition code for the package located at
`local_package_path`, creates the corresponding module in the notebook workspace
and imports all of the names defined within (That is what the `import ^:*`
statement does).

Additionally, it loads the package called `LocalDependency` (must be a
dependency of the local package) as if the `using LocalDependency` code was used
within the notebook, but without adding `LocalDependency` to the notebook environment.

See the package [documentation](https://disberd.github.io/PlutoDevMacros.jl/dev/frompackage/introduction/#Introduction) for more details.

See also: [`@fromparent`](@ref)
"""
macro frompackage(target::String, ex)
	calling_file = String(__source__.file)
	out = _combined(ex, target, calling_file, __module__; macroname = "@frompackage")
	esc(out)
end

"""
This macro is equivalent to [`@frompackage`](@ref) but assumes the calling file as the `target` argument. So the code 
```
@fromparent import_block
``` 
is equivalent to
```
@frompackage @__FILE__ import_block
```

Refer to the [`@frompackage`](@ref) docstring and the package
[documentation](https://disberd.github.io/PlutoDevMacros.jl/dev/frompackage/introduction/#Introduction)
for understanding its use.
See also: [`@addmethod`](@ref)
"""
macro fromparent(ex)
	calling_file = String(__source__.file)
	out = _combined(ex, calling_file, calling_file, __module__; macroname = "@fromparent")
	esc(out)
end
