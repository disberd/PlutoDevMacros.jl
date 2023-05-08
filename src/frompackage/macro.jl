import Base: stacktrace, catch_backtrace

_id_name(cell_id) = Symbol(:_fromparent_cell_id_, cell_id)

function is_call_unique(cell_id, _module)
	current_id = macro_cell[]
	current_id == cell_id && return true
	# If we get here we have a potential multiple call
	id_name = _id_name(current_id)
	return if isdefined(_module, id_name) 
		false
	else
		# We have the update the cell reference
		macro_cell[] = cell_id
		true
	end
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

function frompackage(ex, target_file, caller, _module; macroname)
	is_notebook_local(caller) || return process_outside_pluto!(ex, get_package_data(target_file))
	_, cell_id = _cell_data(caller)
	proj_file = Base.current_project(target_file)
	id_name = _id_name(cell_id)
	ex isa Expr || error("You have to call this macro with an import statement or a begin-end block of import statements")
	# Try to load the module of the target package in the calling workspace and return the dict with extracted paramteres
	dict = if is_call_unique(cell_id, _module)
		mod_exp, dict = extract_module_expression(target_file, _module)
		# We try to extract eventual lines to skip
		process_skiplines!(ex, dict)
		load_module(mod_exp, dict, _module)
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
		finally
			# We add the expression that cleans the load path 
			$clean_loadpath($proj_file)
		end
	end
	return out
end

function _combined(ex, target, calling_file, __module__; macroname)
	# Enforce absolute path to handle different OSs
	target = abspath(target)
	calling_file = abspath(calling_file)
	_, cell_id = _cell_data(calling_file)
	proj_file = Base.current_project(target)
	out = try
		frompackage(ex, target, calling_file, __module__; macroname)
	catch e
		bt = stacktrace(catch_backtrace())
		out = Expr(:block)
		if !(e isa ErrorException && startswith(e.msg, "Multiple Calls: The"))
			text = "Reload $macroname"
			# We send a log to maintain the reload button
			@info html_reload_button(cell_id; text, err = true)
		end
		# We have to also remove the project from the load path
		clean_loadpath(proj_file)
		# If we are at macroexpand, simply rethrow here, ohterwise output the expression with the error
		is_macroexpand(stacktrace(), cell_id) && rethrow()
		# Outputting the CaptureException as last statement allows pretty printing of errors inside Pluto
		push!(out.args,	:(CapturedException($e, $bt)))
		out
	end
	out
end

"""
	@frompackage target import_block

The macro is basically taking a local Package (derived from `target`), loading
it as a submodule of the current Pluto workspace and then process the various
import/using statements inside `import_block` to extract varables/functions from
the local Package into the notebook.

When changes to the code of the local Package are made, the cell containing the
call to `@frompackage` can be re-executed to reload the most recent version of
the module, allowing to work within Pluto with a workflow similar to Revise,
with the added advantage that some of the limitations of Revise requiring to
restart the Julia session (like redefining structs) are avoided.

The main purpose of this is to be able to create packages starting from Pluto
notebooks as building blocks. While this approach to Package development has its
disadvantages, it can be very convenient to speed up the workflow especially at
the beginning of development thanks to avoiding the need to restart Julia when
redefining structs, and exploiting the reactivity of Pluto to quickly assess
*automagically* that your code update did indeed fix the issues by just having
some cells that depend on your changed functions in a notebook.

While the points mentioned above are achievable within a single pluto notebook
without requiring to use this macro, when notebooks become quite complex,
containing many cells, they start to become quite sluggish or unresponsive, so
it is quite conveniente to be able to split the code into various notebook and
be able to access the functionality defined in other notebooks from a single
cell within a new notebook.

To simply import other notebooks, `@ingredients` from
[PlutoHooks](https://github.com/JuliaPluto/PlutoLinks.jl) or `@plutoinclude`
(which is inspired from `@ingredients`) from this PlutoDevMacros already exist,
but I found that they do have some limitations for what concerns directly using
notebooks as building blocks for a package.

# Arguments
Here are more details on the two arguments expected by the macro

## `target`

`target` has to be a String containing the path (either absolute or relative to
the file calling the macro) that points to a local Package (the path can be to
any file or subfolder within the Package folder) or to a specific file that is
*included* in the Package (so the `target` file appears within the Package
module definition inside an `include` call).  - When `target` is not pointing
directly to a file included in the Package, the full code of the module defining
the Package will be parsed and loaded in the Pluto workspace of the notebook
calling the macro.  - When `target` is actually a file included inside the
Package. The macro will just parse the Package module code up to and excluding
the inclusion of `target` and discard the rest of the code, thus loading inside
Pluto just a reduced part of the package. This is mimicking the behavior of
`include` within a package, such that each `included` file only has visibility
on the code that was loaded _before_ its inclusion. This behavior is also
essential when using this macro from a notebook that is also included in the
target Package, to avoid problems with variable redefinitions within the Pluto
notebook (this is also the original usecase of the macro).

## `import_block` 

The second argument to the macro is supposed to be either a single using/import
statement, or multiple using/import statements wrapped inside a `begin...end`
block.

These statements are used to conveniently select which of the loaded Package
names have te be imported within the notebook.  Most of these import statements
are only relevant when called within Pluto, so `@frompackage` simply avoid
loading the target Package and deletes these import statements **in most cases**
when called oustide of Pluto. There is a specific type of import statement
(relative import) that is relevant and applicable also outside of Pluto, so this
kind of statement is maintained in the macro output even outside of Pluto.

The macro respects the differentiation between `using` and `import` as in normal
Julia, so statements containing `using Module` without any variable name
specifier will import all the exported names of `Module`.

All supported statements also allow the following (catch-all) notation `import
Module: *`, which imports within the notebook all the variables that are created
or imported within `Module`. This is useful when one wants to avoid having
either export everything from the module file directly, or specify all the names
of the module when importing it into the notebook.

**Each import statement can only contain one module**, so statements like
*`import Module1, Module2` are not supported. In case multiple imports are
*needed, use multiple statements within a `begin...end` block.

The type of import statements that are supported by the macro are of 4 Types:
- Relative Imports 
- Imports from the Package module
- Import from the Parent module (or submodule)
- Direct dependency import.

### Relative Imports
Relative imports are the ones where the module name starts with a dot (.). These
are mostly relevant when the loaded module contains multiple submodules and they
are **the only supported statement that is kept also outside of Pluto**.

While _catch-all_ notation is supported also with relative imports (e.g. `import
..SiblingModule: *`), the extraction of all the names from the desired relative
module requires loading and inspecting the full Package module and is thus only
functional inside of Pluto. **This kind of statement is deleted when
@frompackage is called outside of Pluto**.

### Imports from Package module
These are all the import statements that have the name `PackageModule` as the
first identifier, e.g.: - `using PackageModule.SubModule` - `import PackageModule:
varname` - `import PackageModule.SubModule.SubSubModule: *` These statements are
processed by the macro and transformed so that `PackageModule` actually points to
the module that was loaded by the macro.

### Imports from Package module (or submodule)
These statements are similar to the previous (imports from Package module) ones, with two main difference:
- They only work if the `target` file is actually a file that is included in the
loaded Package, giving an error otherwise
- `ParentModule` does not point to the loaded Package, but the module that
contains the line that calls `include(target)`. If `target`  is loaded from the
Package main module, and not from one of its submodules, then `ParentModule` will
point to the same module as `PackageModule`.

#### Catch-All
A special kind parent module import is the form:
```julia
import *
```
which is equivalent to `import FromParent: *`. 

This tries to reproduce within the namespace of the calling notebook, the
namespace that would be visible by the notebook file when it is loaded as part
of the Package module outside of Pluto.

### Imports from Direct dependencies

All import statements whose first module identifier is a direct dependency of
the loaded Package are also supported both inside and outside Pluto. These kind
of statements can not be used in combination with the `catch-all` imported name
(*).

This feature is useful when trying to combine `@frompackage` with the integrated
Pluto PkgManager. In this case, is preferable to keep in the Pluto notebook
environment just the packages that are not also part of the loaded Package
environment, and load the eventual packages that are also direct dependencies of
the loaded Package directly from within the `@frompackage` `import_block`.

Doing so minimizes the risk of having issues caused by versions collision
between dependencies that are shared both by the notebook environment and the
loaded Package environment. Combining the use of `@frompackage` with the Pluto
PkgManager is a very experimental feature that comes with significant caveats.
Please read the [related section](https://github.com/disberd/PlutoDevMacros.jl#use-of-fromparentfrompackage-with-pluto-pkgmanager) on the Package README

## Skipping Package Parts
The macro also allows to specify parts of the source code of the target Package that have to be skipped when loading it within Pluto. This is achieved by adding a statement inside the `import_block` like the following:
```julia
@skiplines lines
```
The `@skiplines` macro is not defined within the package, it's just processed during the parsing of the `@frompackage` macro.

`lines` is expected to either be a single String, or a group of Strings within a `begin ... end` block.
Each string represent a part of a file that has to be skipped, with the following formats being supported:
1. `filpeath:::firstline-lastline`: This specifies that all the lines between `firstline` and `lastline` (extrema included) in the file present at `filepath` must be skipped when loading the Package module
2. `filepath:::line`: Like 1. but a single line is skipped
3. `filepath`: Like 1. but the full file located at `filepath` is ignored when loading the module 
4. `line`: Ignores line number `line` in the Package entry point (i.e. the file at `src/PackageName.jl` in the folder of PackageName)
5. `firstline-lastline`: Like 4., but ignores a range of lines.

In all of the examples above `filepath` can be provided as either an absolute path, or as a relative path **starting from the `src` subfolder of the Package folder**

The functionality of skipping lines is only used when `@frompackage` is called inside Pluto. 
When calling the macro from outside of Pluto, the eventual statement with `@skiplines` is discarded.

### Example

For an example consider the source file of the `TestPackage` defined within the test subfolder with the contents shown below:
![image](https://user-images.githubusercontent.com/12846528/236829189-dc30414a-d936-4a63-831b-963664249558.png)

The notebook locate at gives an example of how to use the new functionality.
Considering the notebook to be located in the main folder of the TestPackage folder, the following call to `@fromparent` is used to import the `TestPackage` in the notebook's workspace while removing some of the code that is present in the original source of `TestPackage`:
```julia
@fromparent begin
	import TestPackage
	@skiplines begin
		"11" # Skip line 11 in the main file TestPackage.jl.
		"test_macro2.jl" # This skips the whole file test_macro2.jl
		"22-23" # This skips from line 21 to 22 in the main file, including extrema.
		"test_macro1.jl:::28-10000" # This skips parts of test_macro1.jl
	end
end
```
The output of the notebook is also pasted here for reference:
![image](https://user-images.githubusercontent.com/12846528/236829732-09853734-3dff-46bb-ad3a-51035126cd83.png)



## Reload Button
The macro, when called within Pluto, also creates a convenient button that can
be used to re-execute the cell calling the macro to reloade the Package code due
to a change. It can also be used to quickly navigate to the position of the cell
containing the macro by using Ctrl+Click. The reload button will change
appearance (getting a red border) when the macrocall encountered an error either
due to incorrect import statement (like if a `FromParent` import is used without
a proper target) or due to an error encountered when loading the package code.

To show a simple example of the macro and of the reload button, consider a
package that has the following definition (reduced from PlutoDevMacros tests):
```julia
module TestPackage

export toplevel_variable

toplevel_variable = 15
hidden_toplevel_variable = 10

module SpecificImport
    include("specific_imports1.jl")
    include("specific_imports2.jl")
end
end
```
The current video show a recording where "specific_imports1.jl" is opened as a
notebook on the left window, and "specific_imports2.jl" is opened on the right
one.

[Link to Video](https://user-images.githubusercontent.com/12846528/236453634-c95aa7b2-61eb-492f-85f5-6539bbb714d5.mp4)

See also: [`@fromparent`](@ref), [`@addmethod`](@ref)
"""
macro frompackage(target::String, ex)
	calling_file = String(__source__.file)
	out = _combined(ex, target, calling_file, __module__; macroname = "@frompackage")
	esc(out)
end

"""
The `@fromparent` macro only accepts the `import_block` as single argument, and
it uses the calling file as the target, so:
```julia
(@fromparent import_block) == (@frompackage @__FILE__ import_block)
```
Refer to the [`@frompackage`](@ref) documentation for understanding its use.
See also: [`@addmethod`](@ref)
"""
macro fromparent(ex)
	calling_file = String(__source__.file)
	out = _combined(ex, calling_file, calling_file, __module__; macroname = "@fromparent")
	esc(out)
end
