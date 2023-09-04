module PlutoDevMacros

using MacroTools
using HypertextLiteral

# export @only_in_nb, @only_out_nb, include_mapexpr, @skip_as_script
# export notebook_to_source

# This are from basics.jl
export @only_in_nb, @only_out_nb, plutodump, @current_pluto_cell_id,
@current_pluto_notebook_file, @addmethod

include("basics.jl")
include("combine_htl/PlutoCombineHTL.jl")
include("html_helpers.jl")

include("frompackage/FromPackage.jl")
using .FromPackage
export @fromparent, @frompackage

include("../notebooks/mapexpr.jl") # hasexpr, default_exprlist, include_mapexpr
include("../notebooks/plutoinclude_macro.jl") # hasexpr, default_exprlist, include_mapexpr
# include("../notebooks/pluto_traits.jl") # This defines and exports the @plutotraits macro

# function __init__()
#     if isdefined(Main, :PlutoRunner)
#         @info @htl("""
#         <script>
#             console.log('This is a script that is ran inside Pluto when loading PlutoDevMacros')
#             const current_log = currentScript.closest('pluto-log-dot-positioner')
#             const logs = current_log.parentElement
#             if (logs.children.length > 1) {
#                 current_log.style.display = "none"
#             } else {
#                 logs.parentElement.style.display = "none"
#             }
#         </script>""")
#         @info "GESU"
#     else
        
#     end
# end

end # module
