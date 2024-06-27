import Base: stacktrace, catch_backtrace

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

function frompackage(ex, target_file, caller_module; macroname, cell_id)
    p = FromPackageController(target_file, caller_module; cell_id)
	p.cell_id !== nothing || return process_outside_pluto(p, ex)
    load_module!(p)
    args = extract_input_args(ex)
    for (i, arg) in enumerate(args)
        arg isa Expr || continue
        args[i] = process_input_expr(p, arg)
    end
	text = "Reload $macroname"
	out = quote
		# We put the cell id variable
		$PREV_CONTROLLER_NAME = $p
		try
			$(args...)
			# We add the reload button as last expression so it's sent to the cell output
			$html_reload_button($cell_id; text = $text)
		catch e
			# We also send the reload button as an @info log, so that we can use the cell output to format the error nicely
			@info $html_reload_button($cell_id; text = $text)
			rethrow()
		end
	end |> flatten
	return out
end

function _combined(ex, target, calling_file, caller_module; macroname)
	# Enforce absolute path to handle different OSs
	calling_file = abspath(calling_file)
	_, cell_id = _cell_data(calling_file)
    notebook_local = !isempty(cell_id)
    # Get the target file
	target_file = extract_target_path(target, caller_module; calling_file, notebook_local)
	out = try
		frompackage(ex, target_file, caller_module; macroname, cell_id)
	catch e
		# If we are outside of pluto we simply rethrow
		notebook_local || rethrow()
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

This macro takes a local Package (derived from the `target` path, which can be
an `AbstractString` or a `@raw_str`), loads it as a submodule of the current
Pluto workspace and then process the various import/using statements inside
`import_block` to extract varables/functions from the local Package into the
notebook workspace.

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
macro frompackage(target::Union{AbstractString, Expr, Symbol}, ex)
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
