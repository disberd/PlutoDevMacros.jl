import Base: catch_backtrace

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
        # `CapturedException` expects the raw backtrace; Julia 1.13 errors on processed `StackFrame`s
        bt = catch_backtrace()
        # Outputting the CaptureException as last statement allows pretty printing of errors inside Pluto
        push!(out.args, :(CapturedException($we, $bt)))
        out
    end
    return out
end

"""
    @frompackage target import_block [option = value ...]

Load the target package into the Pluto notebook and run the import statements
of `import_block` against it.

The target package is the package of the first `Project.toml` in the folder of
`target` or in one of its parent folders. `target` is a path to a file or a
folder. A relative path starts from the folder of the notebook file. Outside of
a notebook, `target` must be a `String` or a `raw"..."` string. Inside a
notebook, `target` can be any expression that returns a path, for example
`@__FILE__`.

Each call parses and evaluates the code of the target package again, as a
submodule of the notebook workspace. The macro also shows a reload button in
the cell output. Click it to load the target package again after you change
its code.

Use [`@fromparent`](@ref) when the notebook file is inside the folder of the
target package. `@fromparent import_block` is the short form of
`@frompackage @__FILE__ import_block`.

This cell loads the package in the folder `path/to/MyPkg`, imports all its
names, and loads `LocalDependency`, a dependency of `MyPkg`:

```julia
@frompackage "path/to/MyPkg" begin
    import ^: *
    using >.LocalDependency
end
```

`LocalDependency` does not have to be in the notebook environment.

# Import syntax

`import_block` is one `import` or `using` statement, or a `begin ... end` block
of statements. The first name of the module path selects the source module:

| Syntax | Source | Example |
|:-------|:-------|:--------|
| `PackageModule` or `^` | The top module of the target package. | `import ^: func` |
| The name of the target package | The top module of the target package. | `using MyPkg.SubModule` |
| `ParentModule` or `<` | The module that `include`s the `target` file. | `import <: func` |
| `.` (relative import) | A path relative to the module that `include`s the `target` file. | `import ..Sibling: func` |
| `>.` | A dependency of the target package, direct or indirect. | `using >.JSON` |
| `*` (catch-all) | `ParentModule` if the target package `include`s the `target` file, otherwise `PackageModule`. | `import *` |

Some rules apply to these statements:

- `ParentModule`, `<`, and relative imports work only when the target package
  `include`s the `target` file.
- A catch-all import `import Module: *` imports all the names that `Module`
  defines or imports. It also imports the names that `using` statements inside
  `Module` bring into scope. You cannot use `*` with `>.` or with a list of
  other names.
- Put `@exclude_using` before a catch-all import to leave out the names from
  `using` statements, for example `@exclude_using import *`.
- A statement without a list of names (`import *`, `using ^.SubModule`, or
  `import ^.SubModule`) does not import a name that the notebook defines
  already. The macro skips these names and does not show a warning. A statement
  with a list of names, as `import ^: func`, imports all the names in the list.
- One statement can contain more than one module, for example
  `using >.JSON, >.Markdown`.

Outside of Pluto, the macro keeps only relative imports without `*` and
`>.` imports of direct dependencies. It removes all other statements. For
example, `import >.JSON` becomes `import JSON` when `JSON` is a direct
dependency of the target package.

# Settings

Put settings after `import_block` in the form `name = value`:

```julia
@fromparent import * verbose = true manifest = :instantiate
```

| Setting | Default | Effect |
|:--------|:--------|:-------|
| `manifest::Symbol` | `:none` | `:none` uses the manifest in the environment of the target package and gives an error if there is no manifest. `:resolve` runs `Pkg.resolve` on that environment first. `:instantiate` runs `Pkg.instantiate` on it first. |
| `rootmodule::Bool` | `false` | `true` registers the loaded module as a root module, so it behaves more like a module loaded with `using MyPkg`. This setting uses Julia internals. |
| `verbose::Bool` | `false` | `true` shows log messages about the load steps, for example changes to `LOAD_PATH` and loaded extensions. |

See also: [`@fromparent`](@ref)
"""
macro frompackage(target::Union{AbstractString,Expr,Symbol}, ex, extra_args...)
    calling_file = String(__source__.file)
    out = _combined(ex, target, calling_file, __module__; macroname="@frompackage", extra_args)
    esc(out)
end

"""
    @fromparent import_block [option = value ...]

Short form of [`@frompackage`](@ref) that uses the calling file as `target`.
These two calls are equal:

```julia
@fromparent import_block
@frompackage @__FILE__ import_block
```

The target package is the package that contains the notebook file. The
[`@frompackage`](@ref) docstring describes the import syntax and the settings.

See also: [`@addmethod`](@ref)
"""
macro fromparent(ex, extra_args...)
    calling_file = String(__source__.file)
    out = _combined(ex, calling_file, calling_file, __module__; macroname="@fromparent", extra_args)
    esc(out)
end
