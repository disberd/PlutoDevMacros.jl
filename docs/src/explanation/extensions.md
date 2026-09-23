# How package extensions load

A package extension of the target package loads as soon as the notebook
loads all its trigger packages. The extension also loads again after each
click on the reload button. PlutoDevMacros handles two kinds of extensions in
different ways:

- A direct extension is an extension of the target package itself. The
  `[extensions]` section of the `Project.toml` of the target package lists
  it.
- An indirect extension is an extension of a dependency of the target
  package.

This page uses the `MyPkg` package and its extension `MyPkgExampleExt` from
the tutorial
[Develop a package extension in a notebook](../tutorials/package_extension.md).

## Direct extensions

Julia loads the extensions of the packages that it loaded itself. Julia did
not load the `MyPkg` module that `@fromparent` makes in the notebook, so
Julia does not load its extensions. PlutoDevMacros loads them instead.

PlutoDevMacros adds a function to `Base.package_callbacks`. Julia calls the
functions in this list each time it loads a package in the notebook process.
The function of PlutoDevMacros then checks each extension of the target
package. When Julia loaded all the trigger packages of an extension, the
function evaluates the extension code. The macro does the same check at the
end of each load of the target package. So when the notebook loaded the
trigger packages before, the extension loads together with the target
package.

The extension code is in `ext/MyPkgExampleExt.jl` or in
`ext/MyPkgExampleExt/MyPkgExampleExt.jl`. PlutoDevMacros evaluates it in a new
module in the same way as the code of the target package. Inside the
extension code, `using MyPkg` points to the `MyPkg` module that `@fromparent`
loaded, and `using Example` points to the loaded trigger package.

A trigger package counts as loaded when any code in the notebook process
loaded it. A plain `using Example` in a notebook cell is the usual case. A
different package that depends on `Example` also loads it.

Each load of the target package makes a new `MyPkg` module. The extensions
of the previous module do not apply to it, so PlutoDevMacros loads the
extensions again for the new module. This is why the tutorial shows the
`Loading code of extension` message again after a click on the reload
button.

## Indirect extensions

The dependencies of the target package are normal Julia packages, and Julia
loads them. Julia also loads their extensions with its own mechanism. When
the notebook loads the trigger packages of such an extension, Julia loads the
extension. PlutoDevMacros does nothing for these extensions.

A click on the reload button does not load a dependency again, so its
extensions also do not load again.
