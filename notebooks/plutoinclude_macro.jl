### A Pluto.jl notebook ###
# v0.17.2

# using Markdown
# using InteractiveUtils

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
	using PlutoDevMacros
end
  ╠═╡ notebook_exclusive =#

# ╔═╡ e3d5c718-d98c-4d53-8fc9-911be34c9f2d
#=╠═╡ notebook_exclusive
using BenchmarkTools
  ╠═╡ notebook_exclusive =#

# ╔═╡ 47c42d27-88f1-4a27-bda9-54a2439b09a1
#=╠═╡ notebook_exclusive
include("basics.jl")
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
<b>You still need to use at least version 0.17 of Pluto as the @plutoinclude macro only works properly with the macro analysis functionality that was added in that version (PlutoHooks)</b>
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

# ╔═╡ b87d12be-a37b-4202-9426-3eef14d8253c
function ingredients(path::String)
	# this is from the Julia source code (evalfile in base/loading.jl)
	# but with the modification that it returns the module instead of the last object
	name = Symbol("#plutoinclude_",basename(path))
	m = Module(name)
	Core.eval(m,
        Expr(:toplevel,
             :(eval(x) = $(Expr(:core, :eval))($name, x)),
             :(include(x) = $(Expr(:top, :include))($name, x)),
             :(include(mapexpr::Function, x) = $(Expr(:top, :include))(mapexpr, $name, x)),
			 :(using PlutoDevMacros: @plutoinclude), # This is needed for nested @plutoinclude calls
             :(include($path))))
	m
end

# ╔═╡ 57efc195-6a2f-4ad3-94fd-53e884838789
#=╠═╡ notebook_exclusive
md"""
# Other Ingredients Helpers
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ aa28b5d8-e0d7-4b97-9220-b61a0c5f4fc4
html_reload_button() = html"""
<div class="plutoinclude_banner">
	Reload @pluto_include
</div>
<script>
	const cell = currentScript.closest('pluto-cell')

	const onClick = (e) => {
		console.log(e)
		if (e.ctrlKey) {
			history.pushState({},'')			
			cell.scrollIntoView({
				behavior: 'smooth',
				block: 'center',				
			})
		} else {
			cell.querySelector('button.runcell').click()
		}
	}
	const banner = cell.querySelector(".plutoinclude_banner")

	banner.addEventListener('click',onClick)
	invalidation.then(() => banner.removeEventListener('click',onClick))
</script>
<style>
	.plutoinclude_banner {
	    height: 20px;
	    position: fixed;
	    top: 40px;
		right: 10px;
	    margin-top: 5px;
	    padding-right: 5px;
	    z-index: 200;
		background: #ffffff;
	    padding: 5px 8px;
	    border: 3px solid #e3e3e3;
	    border-radius: 12px;
	    height: 35px;
	    font-family: "Segoe UI Emoji", "Roboto Mono", monospace;
	    font-size: 0.75rem;
	}
	.plutoinclude_banner:hover {
	    font-weight: 800;
		cursor: pointer;
	}
	body.disable_ui .plutoinclude_banner {
		display: none;
	}
	main 
</style>
"""

# ╔═╡ 98b1fa0d-fad1-4c4f-88a0-9452d492c4cb
function include_expr(from::Module,kwargstrs::String...; to::Module)
	modname = Symbol("#plutoincluded_module")
	ex = Expr(:block, :(const $modname = $from))
	kwargs = (Symbol(s) => true for s ∈ kwargstrs if s ∈ ("all","imported"))
	varnames = names(from;kwargs...)
	# Remove the symbols that start with a '#' (still to check what is the impact)
	filter!(!Base.isgensym,varnames)
	# Symbols to always exclude from imports
	exclude_names = (
			nameof(from),
			:eval,
			:include,
			Symbol("@bind"),
			Symbol("@plutoinclude"), # Since we included this in the module
		)
	for s ∈ varnames
		if s ∉ exclude_names
			if getfield(from,s) isa Function
				# _copymethods!(ex, s; to, from, importedlist = varnames, fromname = modname)
				ret_types = Base.return_types(getfield(from,s))
				candidate_type = ret_types[1]
				if all(x -> x === candidate_type, ret_types) && Base.isconcretetype(candidate_type)
					push!(ex.args, :($s(args...; kwargs...)::$candidate_type = $modname.$s(args...; kwargs...)))
				else
					push!(ex.args, :($s(args...; kwargs...) = $modname.$s(args...; kwargs...)))
				end
			else
				push!(ex.args,:(const $s = $modname.$s))
			end
		end
	end
	# Add the html to re-run the cell
	push!(ex.args,:($(html_reload_button())))
	ex
end

# ╔═╡ 872bd88e-dded-4789-85ef-145f16003351
"""
	@plutoinclude path nameskwargs...
	@plutoinclude modname=path namekwargs...

This macro is used to include external julia files inside a pluto notebook and is inspired by the discussion on [this Pluto issue](https://github.com/fonsp/Pluto.jl/issues/1101).

It requires Pluto >= v0.17.0 and includes and external file, taking care of putting in the caller namespace all varnames that are tagged with `export varname` inside the included file.

The macro relies on the use of [`names`](@ref) to get the variable names to be exported, and support providing the names of the keyword arguments of `names` to be set to true as additional strings 

When called from outside Pluto, it simply returns nothing
"""
macro plutoinclude(ex,kwargstrs...)
	path = ex isa String ? ex : Base.eval(__module__,ex)
	if is_notebook_local(__source__.file::Symbol |> String)
		# If this is called directly from the notebook, do the hack to export the various variables from the module
		m = ingredients(path)
		esc(include_expr(m,kwargstrs...; to = __module__))
	elseif first(nameof(__module__) |> String, 13) == "#plutoinclude"
		# We are in a chained plutoinclude, simply include the subfile	
		:(include($path)) |> esc
	else
		# We are not in the notebook and not in a chained include, so do nothing
		nothing
	end
end

# ╔═╡ 748b8eab-2f3d-4afd-bfb4-fee3240d391b
export @plutoinclude

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
notebook_path = "./plutoinclude_test.jl"
  ╠═╡ notebook_exclusive =#

# ╔═╡ 0e3eb73f-091a-4683-8ccb-592b8ccb1bee
#=╠═╡ notebook_exclusive
md"""
Try changing the content of the included notebook by removing some exported variables and re-execute (**using Shift-Enter**) the cell below containing the @plutoinclude call to see that variables are correctly updated.

You can also try leaving some variable unexported and still export all that is defined in the notebook by using 
```julia
@plutoinclude notebook_path "all"
```

Finally, you can also assign the full imported module in a specific variable by doing
```julia
@plutoinclude varname = notebook_path
```
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ d2ac4955-d2a0-48b5-afcb-32baa59ade21
#=╠═╡ notebook_exclusive
@plutoinclude notebook_path "all"
  ╠═╡ notebook_exclusive =#

# ╔═╡ 0d1f5079-a886-4a07-9e99-d73e0b8a2eec
#=╠═╡ notebook_exclusive
@macroexpand @plutoinclude notebook_path "all"
  ╠═╡ notebook_exclusive =#

# ╔═╡ 61924e22-f052-43a5-84b1-5512d222af26
#=╠═╡ notebook_exclusive
@benchmark asd(TestStruct())
  ╠═╡ notebook_exclusive =#

# ╔═╡ 50759ca2-45ca-4005-9182-058a5cb68359
#=╠═╡ notebook_exclusive
const mm = ingredients(notebook_path)
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

# ╔═╡ d8be6b4c-a02b-43ec-b176-de6f64fefd87
#=╠═╡ notebook_exclusive
# Extending the method
asd(s::String) = "STRING"
  ╠═╡ notebook_exclusive =#

# ╔═╡ 8090dd72-a47b-4d9d-85df-ceb0c1bcedf5
#=╠═╡ notebook_exclusive
asd(3)
  ╠═╡ notebook_exclusive =#

# ╔═╡ d1fbe484-dcd0-456e-8ec1-c68acd708a08
#=╠═╡ notebook_exclusive
asd(TestStruct())
  ╠═╡ notebook_exclusive =#

# ╔═╡ 8df0f262-faf2-4f99-98e2-6b2a47e5ca31
#=╠═╡ notebook_exclusive
asd(TestStruct(),3,4)
  ╠═╡ notebook_exclusive =#

# ╔═╡ 1754fdcf-de3d-4d49-a2f0-9e3f4aa3498e
#=╠═╡ notebook_exclusive
asd("S")
  ╠═╡ notebook_exclusive =#

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
PlutoDevMacros = "a0499f29-c39b-4c5c-807c-88074221b949"

[compat]
BenchmarkTools = "~1.2.0"
PlutoDevMacros = "~0.3.6"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.7.0-rc2"
manifest_format = "2.0"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "61adeb0823084487000600ef8b1c00cc2474cd47"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.2.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "8076680b162ada2a031f707ac7b4953e30667a37"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.2"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "3d3e902b31198a27340d0bf00d6ac452866021cf"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.9"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"

[[deps.Parsers]]
deps = ["Dates"]
git-tree-sha1 = "ae4bbcadb2906ccc085cf52ac286dc1377dceccc"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.1.2"

[[deps.PlutoDevMacros]]
deps = ["MacroTools", "PlutoHooks"]
git-tree-sha1 = "5d6d3c0f37bd5a635e0795943e33fc863b430035"
uuid = "a0499f29-c39b-4c5c-807c-88074221b949"
version = "0.3.6"

[[deps.PlutoHooks]]
deps = ["FileWatching", "InteractiveUtils", "Markdown", "UUIDs"]
git-tree-sha1 = "f297787f7d7507dada25f6769fe3f08f6b9b8b12"
uuid = "0ff47ea0-7a50-410d-8455-4348d5de0774"
version = "0.0.3"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
"""

# ╔═╡ Cell order:
# ╠═f5486f67-7bfc-44e2-91b9-9401d81666da
# ╠═e3d5c718-d98c-4d53-8fc9-911be34c9f2d
# ╠═748b8eab-2f3d-4afd-bfb4-fee3240d391b
# ╠═47c42d27-88f1-4a27-bda9-54a2439b09a1
# ╟─fcbd82ae-c04d-4f87-bbb7-5f73bdbf8bd0
# ╟─5089d8dd-6587-4172-9ffd-13cf43e8c341
# ╠═b87d12be-a37b-4202-9426-3eef14d8253c
# ╟─57efc195-6a2f-4ad3-94fd-53e884838789
# ╠═98b1fa0d-fad1-4c4f-88a0-9452d492c4cb
# ╠═872bd88e-dded-4789-85ef-145f16003351
# ╠═aa28b5d8-e0d7-4b97-9220-b61a0c5f4fc4
# ╟─1f291bd2-9ab1-4fd2-bf50-49253726058f
# ╟─cf0d13ea-7562-4b8c-b7e6-fb2f1de119a7
# ╠═bd3b021f-db44-4aa1-97b2-04002f76aeff
# ╟─0e3eb73f-091a-4683-8ccb-592b8ccb1bee
# ╠═d2ac4955-d2a0-48b5-afcb-32baa59ade21
# ╠═0d1f5079-a886-4a07-9e99-d73e0b8a2eec
# ╠═8090dd72-a47b-4d9d-85df-ceb0c1bcedf5
# ╠═61924e22-f052-43a5-84b1-5512d222af26
# ╠═50759ca2-45ca-4005-9182-058a5cb68359
# ╠═4cec781b-c6d7-4fd7-bbe3-f7db0f973698
# ╠═a7e7123f-0e7a-4771-9b9b-d0da97fefcef
# ╠═2c41234e-e1b8-4ad8-9134-85cd65a75a2d
# ╠═ce2a2025-a6e0-44ab-8631-8d308be734a9
# ╠═d1fbe484-dcd0-456e-8ec1-c68acd708a08
# ╠═8df0f262-faf2-4f99-98e2-6b2a47e5ca31
# ╠═d8be6b4c-a02b-43ec-b176-de6f64fefd87
# ╠═1754fdcf-de3d-4d49-a2f0-9e3f4aa3498e
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
