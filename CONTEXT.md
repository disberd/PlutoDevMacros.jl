# PlutoDevMacros

Tools to develop a Julia package from inside a Pluto notebook.

## Language

**Target package**:
The local Julia package that `@frompackage` loads into the notebook.
_Avoid_: local package, parent package, your package

**@fromparent**:
The short form of `@frompackage` whose target package is the one that contains the notebook file.
_Avoid_: using it as a separate feature name in reference docs
