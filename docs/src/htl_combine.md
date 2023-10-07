```@example
using PlutoDevMacros.PlutoCombineHTL
PlutoCombineHTL.LOCAL_MODULE_URL[] = "https://cdn.jsdelivr.net/gh/disberd/PlutoDevMacros@expand_Script/src/combine_htl/pluto_compat.js"
make_script("let asd = html`<div>MAGIC`"; returned_element = "asd")
```