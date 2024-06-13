module TestDirectExtension

using PlotlyExtensionsHelper
using HypertextLiteral

export to_extend, plot_this

to_extend(x) = "Generic Method"
function plot_this end

begin
    a = 33
    b = 2
    c = 3
end

const TREF = Ref(0)

function __init__()
    TREF[] = 5
end

@kwdef struct LOLOL
    x::Int = 0
end

module ASD
    using PlotlyExtensionsHelper
    const B = Ref(5)
    struct DIO end
    process_dio(::DIO) = "God"
    function __init__()
        B[] = 15
    end
end

module INCLUDE_MODULE
using PlotlyExtensionsHelper
include("test_include.jl")
end

diogesu = 15

end # module TestDirectExtension
