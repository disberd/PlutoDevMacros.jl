# Find loading problems

When the target package does not load, the `@fromparent` cell shows the
error. The reload button stays in the top-right corner of the notebook and
gets a red border. Fix the code of the package, save the file, and click the
reload button.

The cells that use names from the target package show `UndefVarError` until
the `@fromparent` cell runs without an error. Fix the error in the
`@fromparent` cell first.

## Read the error

For a syntax error in the code of the target package, the cell shows a
`LoadError` with the file and the line of the error:

```
LoadError: ParseError:
# Error @ /path/to/MyPkg/src/MyPkg.jl:11:35
```

For other errors, the cell shows the error message and the stack trace.

Hold the Ctrl key and click the reload button to scroll to the `@fromparent`
cell.

## Show the load steps

Add `verbose = true` to the `@fromparent` cell:

```julia
@fromparent import * verbose = true
```

The cell then shows log messages about the load steps. These are some of
them:

- `Adding .../MyPkg/Project.toml to end of LOAD_PATH`
- `Instantiating Manifest as explicitly requested`, with the
  `manifest = :instantiate` setting
- `Loading code of extension MyPkgExampleExt for package MyPkg`

With the `manifest` setting, `verbose = true` also shows the output of the
package manager.

## Fix common errors

This table lists errors that `@fromparent` shows and their usual cause.

| Error message starts with | Cause | Fix |
|:--------------------------|:------|:----|
| `A manifest could not be found` | The target package has no manifest. | [Instantiate the environment](instantiate_environment.md). |
| `No project was found starting from` | No folder above the notebook contains a `Project.toml`. | Save the notebook inside the folder of the target package. |
| `@frompackage can only be called with a Package as target` | The `Project.toml` has no `name` and `uuid`. | Add them, or point the macro to the folder of a package. |
| `The package with name ... could not be found as a dependency` | A `>.` statement names a package that the target package does not depend on. | Add the dependency, or load the package without `>.`. |
| `The provided extra arguments at the end of the macro call are not in a supported format` | A setting has a wrong name or type. | See the settings table in the [`@frompackage`](@ref) reference. |
| `Multiple definitions for` | Two cells define the same name, or the notebook has two `@fromparent` cells. | [Handle names that the notebook defines already](import_names.md#Handle-names-that-the-notebook-defines-already). |
