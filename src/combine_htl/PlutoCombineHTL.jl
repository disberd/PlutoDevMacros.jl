module PlutoCombineHTL

using Random
using HypertextLiteral
using HypertextLiteral: Result, Bypass, Reprint, Render
using Markdown
using AbstractPlutoDingetjes: is_inside_pluto

export make_node, make_html, make_script, formatted_code

include("typedef.jl")
include("constructors.jl")
include("js_events.jl")
include("helpers.jl")
# include("combine.jl")
include("show.jl")

module WithTypes
    _ex_names = (
        :PlutoCombineHTL,
        :make_node, :make_html, :make_script, :formatted_code,
        :ScriptContent,
        :Node, :DualNode, :CombinedNodes, :PlutoNode, :NormalNode,
        :Script, :DualScript, :CombinedScripts, :PlutoScript, :NormalScript,
    )
    for n in _ex_names
        eval(:(import ..PlutoCombineHTL: $n))
        eval(:(export $n))
    end
end

end