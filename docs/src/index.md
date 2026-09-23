```@raw html
---
layout: home

hero:
  name: PlutoDevMacros.jl
  text: Develop a Julia package from a Pluto notebook
  tagline: Load the code of your package into a notebook, change it, and click reload to test the change.
  actions:
    - theme: brand
      text: First tutorial
      link: /tutorials/first_package/
    - theme: alt
      text: Reference
      link: /reference/frompackage/
    - theme: alt
      text: View on GitHub
      link: https://github.com/disberd/PlutoDevMacros.jl

features:
  - icon: 🔄
    title: Reload button
    details: "`@fromparent` loads the target package and shows a button that loads it again after you change the code."
    link: /tutorials/first_package/
  - icon: 📦
    title: Import syntax
    details: Import all names with `import *`, or import specific names, submodules, and dependencies.
    link: /reference/frompackage/
  - icon: 🧩
    title: Package extensions
    details: The extensions of the target package load when the notebook loads their trigger packages.
    link: /tutorials/package_extension/
  - icon: ⚙️
    title: Settings
    details: Resolve or instantiate the environment of the target package, and show log messages about each load step.
    link: /reference/frompackage/
  - icon: 📓
    title: Notebook-only code
    details: "`@only_in_nb` and `@only_out_nb` run code only inside or only outside the notebook."
    link: /reference/other_exports/
  - icon: ➕
    title: Add methods
    details: "`@addmethod` adds methods to functions of the target package from a notebook cell."
    link: /reference/other_exports/
---
```

## Quickstart

Put a Pluto notebook in the folder of your package and run this code in a cell:

```julia
using PlutoDevMacros

@fromparent import *
```

The cell loads your package and imports all its names into the notebook. Click
the reload button in the top-right corner of the notebook after you change the
code of the package.

<!-- The GIF of the reload button goes here. -->
