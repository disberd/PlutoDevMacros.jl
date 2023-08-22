# Skipping Package Parts
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

## Example

For an example consider the source file of the `TestPackage` module defined at [test/TestPackage/src/TestPackage.jl](https://github.com/disberd/PlutoDevMacros.jl/blob/f7b2bbf3a89ca677ab1765a2d4fcb3a1600d66f6/test/TestPackage/src/TestPackage.jl), whose contents are shown below:

![image](https://user-images.githubusercontent.com/12846528/236829189-dc30414a-d936-4a63-831b-963664249558.png)

The notebook called `out_notebook.jl` located in the main folder of `TestPackage` gives an example of how to use the new functionality.

The following call to `@fromparent` is used to import the `TestPackage` in the notebook's workspace while removing some of the code that is present in the original source of `TestPackage`:
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

![image](https://user-images.githubusercontent.com/12846528/236832303-eb2fdc0f-08fd-47e7-9c1d-35f1f1b637fd.png)