import Base: stacktrace, catch_backtrace

function wrap_parse_error(e)
    # Just return the error if we are not in 1.10 or is not a ParseError
    VERSION >= v"1.10" && e isa Base.Meta.ParseError && hasproperty(e, :detail) || return e
    # Extract the filename and line of the parseerror
    (; source, diagnostics) = e.detail
    byte_index = first(diagnostics) |> Base.JuliaSyntax.first_byte
    line = Base.JuliaSyntax.source_line(source, byte_index)
    file = source.filename
    # We wrap this in a LoadError as if we `included` the file containnig the error
    return LoadError(file, line, e)
end

## @frompackage
function frompackage(ex, target_file, caller_module; macroname, cell_id, extra_args)
    p = FromPackageController(target_file, caller_module; cell_id)
    p.cell_id !== nothing || return process_outside_pluto(p, ex)
    parse_options!(p, ex, extra_args)
    populate_manifest_deps!(p)
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
            $html_reload_button($p)
        catch e
            # We also send the reload button as an @info log, so that we can use the cell output to format the error nicely
            @info $html_reload_button($p; err = true)
            rethrow()
        end
    end |> flatten
    return out
end

function _combined(ex, target, calling_file, caller_module; macroname, extra_args)
    # Enforce absolute path to handle different OSs
    calling_file = abspath(calling_file)
    _, cell_id = _cell_data(calling_file)
    notebook_local = !isempty(cell_id)
    # Get the target file
    target_file = extract_target_path(target, caller_module; calling_file, notebook_local)
    out = try
        frompackage(ex, target_file, caller_module; macroname, cell_id, extra_args)
    catch e
        # If we are outside of pluto we simply rethrow
        notebook_local || rethrow()
        out = Expr(:block)
        # We send a log to maintain the reload button
        @info html_reload_button(cell_id; name = macroname, err=true)
        # Wrap ParseError in LoadError (see https://github.com/disberd/PlutoDevMacros.jl/issues/30)
        we = wrap_parse_error(e)
        bt = stacktrace(catch_backtrace())
        # Outputting the CaptureException as last statement allows pretty printing of errors inside Pluto
        push!(out.args, :(CapturedException($we, $bt)))
        out
    end
    return out
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
macro frompackage(target::Union{AbstractString,Expr,Symbol}, ex, extra_args...)
    calling_file = String(__source__.file)
    out = _combined(ex, target, calling_file, __module__; macroname="@frompackage", extra_args)
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
macro fromparent(ex, extra_args...)
    calling_file = String(__source__.file)
    out = _combined(ex, calling_file, calling_file, __module__; macroname="@fromparent", extra_args)
    esc(out)
end
