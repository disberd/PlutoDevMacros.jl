### A Pluto.jl notebook ###
# v0.17.1

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ f5486f67-7bfc-44e2-91b9-9401d81666da
#=╠═╡ notebook_exclusive
begin
	import Pkg
	Pkg.activate("..")
	using PlutoDevMacros: @skip_as_script, include_mapexpr
end
  ╠═╡ notebook_exclusive =#

# ╔═╡ fcbd82ae-c04d-4f87-bbb7-5f73bdbf8bd0
html"""
<h1>Disclaimer</h1>
The code in this notebook is made to be viewed with a fork of Pluto that provides functionality to make cells exclusive to the notebook (meaning that they are commented out in the .jl file).
<br>
This is a custom feature I use to clean up notebooks and only execute the relevant cells of a notebook when this is included from normal julia (I use notebooks as building blocks for packages)
<br>
<br>
This is heavily inspired by the cell disabling that exists in Pluto and the source code to save notebook exclusivity on the file is copied/adapted from <a href="https://github.com/fonsp/Pluto.jl/pull/1209">pull request #1209.</a>
The actual modifications to achieve this functionalities
are shown <a href="https://github.com/disberd/Pluto.jl/compare/master@%7B2021-08-05%7D...disberd:notebook-exclusive-cells@%7B2021-08-05%7D">here</a>
<br>
<br>
When opening this notebook without that functionality, all cells after the macro and functions definition are <i>notebook_exclusive</i> and are thus surrounded by block comments.
<br>
<br>
To try out the <i>exclusive</i> parts of the notebook, press this <button>button</button> toggle between commenting in or out the cells by removing (or adding) the leading and trailing block comments from the cells that are marked as <i>notebook_exclusive</i>.
<br>
You will then have to use <i>Ctrl-S</i> to execute all modified cells (where the block comments were removed)
<br>
<br>
<b>You still need to use at least version 0.17 of Pluto as the @ingredients macro only works properly with the macro analysis functionality that was added in that version (PlutoHooks)</b>
<br>
<br>
<b>The automatic reload of the macro when re-executing the cell is broken with CM6 so the whole cell should add/delete empty spaces after the macro before re-executing</b>

<script>
/* Get the button */
const but = currentScript.closest('.raw-html-wrapper').querySelector('button')


const exclusive_pre =  "#=╠═╡ notebook_exclusive"
const exclusive_post = "  ╠═╡ notebook_exclusive =#"

/* Define the function to identify if a cell is wrapped in notebook_exclusive comments */
const is_notebook_exclusive = cell => {
	if (cell.hasAttribute('notebook_exclusive')) return true
	const cm = cell.querySelector('pluto-input .CodeMirror').CodeMirror
	const arr = cm.getValue().split('\n')
	const pre = arr.shift()
	if (pre !== exclusive_pre)  return false/* return if the preamble is not found */
	const post = arr.pop()
	if (post !== exclusive_post)  return false/* return if the preamble is not found */
	cell.setAttribute('notebook_exclusive','')
	return true
}

// Check for each cell if it is exclusive, and if it is, toggle the related attribute and remove the comment blocks
const onClick = () => {
// 	Get all the cells in the notebook
	const cells = document.querySelectorAll('pluto-cell')
	cells.forEach(cell => {
	if (!is_notebook_exclusive(cell)) return false
	
	const cm = cell.querySelector('pluto-input .CodeMirror').CodeMirror
	const arr = cm.getValue().split('\n')
	if (arr[0] === exclusive_pre) {
// 		The comments must be removed
// 		Remove the first line
		arr.shift()
// 		Remove the last line
		arr.pop()
// 		Rejoin the array and change the editor text
	} else {
// 		The comments must be inserted
		arr.unshift(exclusive_pre)
		arr.push(exclusive_post)
	}
	cm.setValue(arr.join('\n'))
})}

but.addEventListener('click',onClick)
	invalidation.then(() => but.removeEventListener('click',onClick))	
</script>
"""

# ╔═╡ 5089d8dd-6587-4172-9ffd-13cf43e8c341
#=╠═╡ notebook_exclusive
md"""
## Main Functions
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ e3e5510d-d1aa-442f-8d51-e42fe942f295
#=╠═╡ notebook_exclusive
@__FILE__
  ╠═╡ notebook_exclusive =#

# ╔═╡ 4a10255c-3a99-4939-ac29-65ef13b2c252
#=╠═╡ notebook_exclusive
md"""
### called from notebook 
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ a6f31a58-18ad-44d2-a6a2-f46e970f195a
#=╠═╡ notebook_exclusive
Main.PlutoRunner.cell_results.keys
  ╠═╡ notebook_exclusive =#

# ╔═╡ f41c1fa8-bd01-443c-bdeb-c49e5ff7127c
"""
	_called_from_notebook(filesrc::AbstractString)

Given the result of `@__FILE__` (or `string(__source__.file)` from a macro), check whether the macro was called directly from a Pluto notebook.

This works because the `@__FILE__` information contains the name of the Pluto notebook followed by the cell UUID in case this is called directly in a notebook (and not included from outside)
"""
function _called_from_notebook(filesrc)
	if isdefined(Main,:PlutoRunner)
		cell_id = tryparse(Base.UUID,last(filesrc,36))
		println("cell_id = $cell_id")
		println("currently_running = $(Main.PlutoRunner.currently_running_cell_id[])")
		cell_id !== nothing && cell_id === Main.PlutoRunner.currently_running_cell_id[] && return true
	end
	return false
end

# ╔═╡ b87d12be-a37b-4202-9426-3eef14d8253c
function ingredients(path::String,exprmap::Function=include_mapexpr())
	# this is from the Julia source code (evalfile in base/loading.jl)
	# but with the modification that it returns the module instead of the last object
	name = Symbol(basename(path))
	m = Module(name)
	Core.eval(m,
        Expr(:toplevel,
             :(eval(x) = $(Expr(:core, :eval))($name, x)),
             :(include(x) = $(Expr(:top, :include))($name, x)),
             :(include(mapexpr::Function, x) = $(Expr(:top, :include))(mapexpr, $name, x)),
			 :(using PlutoDevMacros: @ingredients, @skip_as_script), # This is needed for nested @ingredients calls
             :(include($exprmap,$path))))
	m
end

# ╔═╡ 98b1fa0d-fad1-4c4f-88a0-9452d492c4cb
function include_expr(m::Module,kwargstrs::String...)
	ex = Expr(:block)
	kwargs = (Symbol(s) => true for s ∈ kwargstrs if s ∈ ("all","imported"))
	varnames = names(m;kwargs...)
	# Remove the symbols that start with a '#' (still to check what is the impact)
	filter!(x -> first(String(x)) !== '#',varnames)
	# Symbols to always exclude from imports
	exclude_names = (
			nameof(m),
			:eval,
			:include,
			Symbol("@bind"),
			Symbol("@ingredients"), # Since we included this in the module
			Symbol("@skip_as_script"), # Since we included this in the module
		)
	name = repr(m) |> Symbol
	# push!(ex.args,:($m))
	for s ∈ varnames
		if s ∉ exclude_names
			push!(ex.args,:($(esc(s)) = $(getfield(m,s))))
		end
	end
	ex
end

# ╔═╡ 872bd88e-dded-4789-85ef-145f16003351
"""
	@ingredients path nameskwargs...
	@ingredients modname=path namekwargs...

This macro is used to include external julia files inside a pluto notebook and is inspired by the discussion on [this Pluto issue](https://github.com/fonsp/Pluto.jl/issues/1101).

It requires Pluto >= v0.17.0 and includes and external file, taking care of putting in the caller namespace all varnames that are tagged with `export varname` inside the included file.

The macro relies on the use of [`names`](@ref) to get the variable names to be exported, and support providing the names of the keyword arguments of `names` to be set to true as additional strings 

When called from outside Pluto, it simply returns nothing
"""
macro ingredients(ex,kwargstrs...)
	path = ex isa String ? ex : Base.eval(__module__,ex)
	@skip_as_script begin
		m = ingredients(path)
		include_expr(m,kwargstrs...)
	end
end

# ╔═╡ 63e2bd00-63b8-43f9-b8d3-b5d336744f3a
export @ingredients, ingredients

# ╔═╡ 1f291bd2-9ab1-4fd2-bf50-49253726058f
#=╠═╡ notebook_exclusive
md"""
## Example Use
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ cf0d13ea-7562-4b8c-b7e6-fb2f1de119a7
#=╠═╡ notebook_exclusive
md"""
The cells below assume to also have the test notebook `ingredients_include_test.jl` from PlutoUtils in the same folder, download it and put it in the same folder in case you didn't already
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ bd3b021f-db44-4aa1-97b2-04002f76aeff
#=╠═╡ notebook_exclusive
notebook_path = "./ingredients_include_test.jl"
  ╠═╡ notebook_exclusive =#

# ╔═╡ 0e3eb73f-091a-4683-8ccb-592b8ccb1bee
#=╠═╡ notebook_exclusive
md"""
Try changing the content of the included notebook by removing some exported variables and re-execute (**using Shift-Enter**) the cell below containing the @ingredients call to see that variables are correctly updated.

You can also try leaving some variable unexported and still export all that is defined in the notebook by using 
```julia
@ingredients notebook_path "all"
```

Finally, you can also assign the full imported module in a specific variable by doing
```julia
@ingredients varname = notebook_path
```
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ d2ac4955-d2a0-48b5-afcb-32baa59ade21
#=╠═╡ notebook_exclusive
@ingredients notebook_path
  ╠═╡ notebook_exclusive =#

# ╔═╡ 0d1f5079-a886-4a07-9e99-d73e0b8a2eec
#=╠═╡ notebook_exclusive
@macroexpand @ingredients notebook_path "all"
  ╠═╡ notebook_exclusive =#

# ╔═╡ 4cec781b-c6d7-4fd7-bbe3-f7db0f973698
#=╠═╡ notebook_exclusive
a
  ╠═╡ notebook_exclusive =#

# ╔═╡ a7e7123f-0e7a-4771-9b9b-d0da97fefcef
#=╠═╡ notebook_exclusive
b
  ╠═╡ notebook_exclusive =#

# ╔═╡ 2c41234e-e1b8-4ad8-9134-85cd65a75a2d
#=╠═╡ notebook_exclusive
c
  ╠═╡ notebook_exclusive =#

# ╔═╡ ce2a2025-a6e0-44ab-8631-8d308be734a9
#=╠═╡ notebook_exclusive
d
  ╠═╡ notebook_exclusive =#

# ╔═╡ 584c8631-a2aa-425c-a6cd-99b7df1d857d
#=╠═╡ notebook_exclusive
TestStruct()
  ╠═╡ notebook_exclusive =#

# ╔═╡ Cell order:
# ╠═f5486f67-7bfc-44e2-91b9-9401d81666da
# ╟─fcbd82ae-c04d-4f87-bbb7-5f73bdbf8bd0
# ╟─5089d8dd-6587-4172-9ffd-13cf43e8c341
# ╠═e3e5510d-d1aa-442f-8d51-e42fe942f295
# ╟─4a10255c-3a99-4939-ac29-65ef13b2c252
# ╠═a6f31a58-18ad-44d2-a6a2-f46e970f195a
# ╠═f41c1fa8-bd01-443c-bdeb-c49e5ff7127c
# ╠═b87d12be-a37b-4202-9426-3eef14d8253c
# ╠═98b1fa0d-fad1-4c4f-88a0-9452d492c4cb
# ╠═872bd88e-dded-4789-85ef-145f16003351
# ╠═63e2bd00-63b8-43f9-b8d3-b5d336744f3a
# ╟─1f291bd2-9ab1-4fd2-bf50-49253726058f
# ╟─cf0d13ea-7562-4b8c-b7e6-fb2f1de119a7
# ╠═bd3b021f-db44-4aa1-97b2-04002f76aeff
# ╟─0e3eb73f-091a-4683-8ccb-592b8ccb1bee
# ╠═d2ac4955-d2a0-48b5-afcb-32baa59ade21
# ╠═0d1f5079-a886-4a07-9e99-d73e0b8a2eec
# ╠═4cec781b-c6d7-4fd7-bbe3-f7db0f973698
# ╠═a7e7123f-0e7a-4771-9b9b-d0da97fefcef
# ╠═2c41234e-e1b8-4ad8-9134-85cd65a75a2d
# ╠═ce2a2025-a6e0-44ab-8631-8d308be734a9
# ╠═584c8631-a2aa-425c-a6cd-99b7df1d857d
