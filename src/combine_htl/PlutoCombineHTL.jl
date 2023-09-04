module PlutoCombineHTL

using Random
using HypertextLiteral
using Markdown
using AbstractPlutoDingetjes: is_inside_pluto

export ScriptContent, HTLBypass, DualScript, combine_scripts, make_script

include("typedef.jl")
include("js_events.jl")
include("helpers.jl")
# include("combine.jl")
include("show.jl")

end