# PlutoDevMacros

This is a package containing macros/functions to help develop Packages using [Pluto](https://github.com/fonsp/Pluto.jl) notebooks as building blocks

## @plutoinclude macro

`@plutoinclude` is a macro aimed at simplifying the development of packages with multiple connected notebooks as building blocks. 

When creating a package whose functionality is divided into various notebooks that are included in the main package file, `@plutoinclude` can be used inside each notebook to serially chain the code definition from one notebook to the next. Each notebook (except the first one) should contain a `@plutoinclude` call to the one preceding it (in the same order you `include` the notebooks in the main package source).

When called from inside a Pluto notebook, `@plutoinclude` takes care of including all variables and function definitions from _included_ notebook into the _including_ one. If called just with the notebook path, it only include variables and function **explicitly** marked with `export`. The string `"all"` can be given as second argument to the macrocall to import all variables and functions defined in the _included_ notebook into the _including_ one.
Lastly, the macro creates a button on the notebook front-end that can be clicked to trigger a re-computation of the inclusion, modifying the imported variables and definition following a modification of the _included_ notebook.

See the video example below, or check the [plutoinclude_macro](./notebooks/plutoinclude_macro.jl), [plutoinclude_test](./notebooks/plutoinclude_test.jl) for basic usage or [test1](./notebooks/test1.jl), [test2](./notebooks/test2.jl), [test3](./notebooks/test3.jl) for chained inclusion examples:

## `@only_in_nb`, `@only_out_nb`

The exported macro `@only_in_nb` ensures that the content of a cell are only executed when ran from the notebook where they are defined.

Similarly, the macro `@only_out_nb` only executes code in the cell when this is included by calling `include` on the notebook file from another julia file

This is useful especially when you want to create and test a functionality in a standalone notebook in which you would use `import Pkg` and `using` in some cells at the beginning of the notebook, but you don't want to have the code in these cells to be executed when the notebook file is included from somewhere else.

The code was inspired and heavily based on the `@skip_as_script` and `@only_as_script` macros that are found [inside the Pluto main package](https://github.com/fonsp/Pluto.jl/blob/main/src/webserver/Firebasey.jl) and in [PlutoTest](https://github.com/JuliaPluto/PlutoTest.jl).

The need for this separate macros is for two reasons:
- The original Pluto macros are not limiting execution to in or out of the specific notebook, but in or out of a Pluto session (if you `include` a notebook from another notebook, all the `@skip_as_script` macros are executed
- I had an issue making the original Pluto macros work together with @requires from [Requires](https://github.com/JuliaPackaging/Requires.jl) while developing a personal package and this macro seems to solve the issue

# IMPORTANT

The code in this notebook packages is made to be viewed with my [personal fork](https://github.com/disberd/Pluto.jl) of Pluto that provides functionality to make cells exclusive to the notebook (meaning that they are commented out in the .jl file).\
This is a custom feature used to clean up notebooks and only execute the relevant cells of a notebook when this is included from normal julia. This is so much more convenient for developing packages with notebooks as it allows to filter out cells that are only used within the notebook (like benchmarks or plot or markdown) and are pointless or even bothersome when the notebook is included as julia file.

One could use `@skip_as_script` from PlutoHooks or `@only_in_nb` from this package, but it is so much more convenient to just have exclusive cells commented out instead of having to put a macro in front of all of them, especially because then every notebook would require the package defining the macro to be imported before inclusion.

The code used to do this is heavily inspired by the cell disabling that exists in Pluto and the source code to save notebook exclusivity on the file is copied/adapted from Pluto pull request [#1209](https://github.com/fonsp/Pluto.jl/pull/1209).

When opening this notebook without that functionality, all cells after the macro and functions definition are *notebook_exclusive* and are thus surrounded by block comments, like so for a cell with `using BenchmarkTools` as the sole command:
```julia
#=╠═╡ notebook_exclusive
using BenchmarkTools
  ╠═╡ notebook_exclusive =#
```

To correctly see the notebook, you can either:
1. Temporarily add my Pluto fork in a temp env to view the notebook in a parallel Pluto instance by running in a new julia CLI:
```julia
]activate --temp
add https://github.com/disberd/Pluto.jl
```
and then run pluto normally. 
**This is by far the preferred one for viewing the notebooks of this package as removing the exclusive comments from cells with method 2 might break chain inclusion from `@plutoinclude`.**

2. Paste the following html snippet in a Pluto cell and execute it to show a button that will automatically strip all the exclusive comments from cells to try the notebook out: 
```html
html"""
To try out the <i>exclusive</i> parts of the notebook, press this <button>button</button> toggle between commenting in or out the cells by removing (or adding) the leading and trailing block comments from the cells that are marked as <i>notebook_exclusive</i>.
<br>
You will then have to use <i>Ctrl-S</i> to execute all modified cells (where the block comments were removed)
<script>
/* Get the button */
const but = currentScript.closest('.raw-html-wrapper').querySelector('button')


const exclusive_pre =  "#=╠═╡ notebook_exclusive"
const exclusive_post = "  ╠═╡ notebook_exclusive =#"

/* Define the function to identify if a cell is wrapped in notebook_exclusive comments */
const is_notebook_exclusive = cell => {
	if (cell.hasAttribute('notebook_exclusive')) return true
	const cm = cell.querySelector('.cm-editor')?.CodeMirror ?? cell.querySelector('.CodeMirror')?.CodeMirror // Second version is for older pluto
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
	
	const cm = cell.querySelector('.cm-editor')?.CodeMirror ?? cell.querySelector('.CodeMirror')?.CodeMirror // Second version is for older pluto
	const arr = cm.getValue().split('\n')
	if (arr[0] === exclusive_pre) {
// 		The comments must be removed
// 		Remove the first line
		arr.shift()
// 		Remove the last line
		arr.pop()
	} else {
// 		The comments must be inserted
		arr.unshift(exclusive_pre)
		arr.push(exclusive_post)
	}
// 	Rejoin the array and change the editor text
	cm.setValue(arr.join('\n'))
})}

but.addEventListener('click',onClick)
	invalidation.then(() => but.removeEventListener('click',onClick))	
</script>
"""
```
