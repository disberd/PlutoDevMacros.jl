# Package Extensions

The `@frompackage` macro supports [package extensions](https://pkgdocs.julialang.org/v1.9/creating-packages/#Conditional-loading-of-code-in-packages-(Extensions)) defined within the packages loaded by the macro within the [`import_block`](@ref)

We specify two possible types of extensions within the context of `@frompackage`:
- **Direct Extensions**: These are extensions that are defined directly within the local `target` package loaded by the macro
- **Indirect Extensions**: These are extensions that are not defined by the `target` package directly, but by one of its dependencies.

## Direct Extensions
An example of a scenario with Direct Extensions is the one of the `TestDirectExtension` package found in the [test/TestDirectExtension](https://github.com/disberd/PlutoDevMacros.jl/tree/master/test/TestDirectExtension) folder and whose Project.toml is replicated below:

```toml
name = "TestDirectExtension"
uuid = "f446dfe5-66ce-4684-9abf-53561df9f9a0"
authors = ["Alberto Mengali <disberd@gmail.com>"]
version = "0.1.0"

[deps]
Revise = "295af30f-e4ad-537b-8983-00126c2a3abe"

[weakdeps]
PlutoPlotly = "8e989ff0-3d88-8e9f-f020-2b208a939ff0"
Example = "7876af07-990d-54b4-ab0e-23690620f79a"

[extensions]
PlutoPlotlyExt = "PlutoPlotly"
Magic = "Example"
```

We can see that this package defines two extensions `PlutoPlotlyExt` and `Magic` that depend on the `PlutoPlotly` and `Example` packages respectively.

When the `TestDirectExtension` module is loaded within a Pluto notebook using the `@frompackage` or `@fromparent` macro, the module is not associated to a package UUID so julia does not know that the `Magic` extension has to be loaded whenever the `Example` package is loaded into the notebook.

To still support loading the extension code in this situation, the macro will *eval* the `Magic` module definition within the `TestDirectExtension` module if the `Example` package is defined within the notebook environment.
This allows prototyping and testing package extensions during their development exploiting the `@frompackage` macro.

Check the relevant example notebook located at [test/TestDirectExtension/test_extension.jl](https://github.com/disberd/PlutoDevMacros.jl/blob/master/test/TestDirectExtension/test_extension.jl) for more clarity.


## Indirect Extensions
Indirect extensions are mostly handled correctly by julia directly, but some issues may arise when a package added to the notebook environment triggers the load of an extension of a package loaded as a [direct dependency](@ref "Imports from Direct dependencies") within the [`import_block`](@ref).

If the notebook package triggering the extension is loaded **after** the direct dependency has already been loaded by the `@frompackage` macro, an extension compilation error is generated because the direct dependency is not in the `LOAD_PATH` (See the [Use with PlutoPkg](@ref) section)

The way to solve this issue is to simply reload the local code by using the re-executing the cell containing the macro call. This will trigger a call to `Base.retry_load_extensions`.
