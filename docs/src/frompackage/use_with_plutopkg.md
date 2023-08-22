# Use with PlutoPkg

The macro evaluates the code of the local `target` package within the Pluto notebook workspace. For this to work, the notebook needs to have access to all the packages that are loaded within the `target` package.

Normally, this is achieved by either:
- Adding the dependencies directly to the notebook environment
- Activating the environment of the local package within the notebook

The first option risk polluting the notebook environment with a lot of packages that are not directly used within the notebook, while the second option deactivate the integrate PlutoPkg which handles package dependencies.

To address these issues, the macro currently adds the `target` package environment to the [`LOAD_PATH`](https://docs.julialang.org/en/v1/manual/code-loading/#code-loading) during package code evaluation in the notebook workspace.

This approach gives the flexibility of loading arbitrary local package code without requiring to modify the notebook environment itself.
!!! note
    For this to work, the environment of the local `target` package needs to be instantiated. The macro will actually errors if this is not the case.

The macro tries to catch all possible exceptions that are thrown either during macro compilation or during the resulting expression evaluation (using a try catch) to correctly clean `LOAD_PATH` after the macro is executed.

This approach may cause issues in case the notebook and the package environment share some dependencies at different version. In this case, the one that was loaded first is the actual version used within the notebook (and within the Package module when loaded in the notebook).

The macro adds the local package environment at the second position in the
LOAD_PATH (so after the notebook environment). This should minimize the potential
issues as the notebook environment is parsed first to find the packages.
This does not prevent the case when a package (for example DataFrames) that is only used by the loaded package, is also added to the notebook after the target Package has been loaded. 
In this case, the version of DataFrames used by the notebook will be the version loaded by Package, and not the one installed in the notebook environment.
Upon restarting the notebook, the situation will flip. Since now DataFrames is in the notebook environment, the notebook version will be loaded both in the notebook and in the Package module, potentially causing issues with the PackageCode if it was depending on a different version of DataFrames.

**Due to the issues just mentioned, use the macro knowing that it might break if you want to use the Pluto PkgManager without manually adding all depending packages to the notebook environment**.