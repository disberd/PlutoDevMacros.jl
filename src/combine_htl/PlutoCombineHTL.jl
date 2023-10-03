module PlutoCombineHTL

using Random
using HypertextLiteral
using HypertextLiteral: Result, Bypass, Reprint, Render
using Markdown
using AbstractPlutoDingetjes: is_inside_pluto
using DocStringExtensions

export make_node, make_html, make_script, formatted_code

const LOCAL_MODULE_URL = Ref("https://cdn.jsdelivr.net/gh/disberd/PlutoDevMacros@$(pkgversion(@__MODULE__))/src/combine_htl/pluto_compat.js")

include("typedef.jl")
include("constructors.jl")
include("js_events.jl")
include("helpers.jl")
# include("combine.jl")
include("show.jl")
# include("docstrings.jl")

module WithTypes
    _ex_names = (
        :PlutoCombineHTL,
        :make_node, :make_html, :make_script, :formatted_code,
        :ScriptContent,
        :Node, :DualNode, :CombinedNodes, :PlutoNode, :NormalNode,
        :Script, :DualScript, :CombinedScripts, :PlutoScript, :NormalScript,
        :SingleDisplayLocation, :DisplayLocation, :InsidePluto, :OutsidePluto, :InsideAndOutsidePluto,
        :ShowWithPrintHTML, :AbstractHTML
    )
    for n in _ex_names
        eval(:(import ..PlutoCombineHTL: $n))
        eval(:(export $n))
    end
end

end