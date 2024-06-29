module TestDirectExtension

using PlotlyExtensionsHelper
using HypertextLiteral

export to_extend, plot_this

to_extend(x) = "Generic Method"
function plot_this end

end # module TestDirectExtension
