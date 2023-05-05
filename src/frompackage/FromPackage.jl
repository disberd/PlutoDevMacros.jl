module FromPackage
    import ..PlutoDevMacros: @addmethod
    using HypertextLiteral
    export @fromparent, @addmethod, @frompackage


    include("helpers.jl")
    include("code_parsing.jl")
    include("loading.jl")
    include("input_parsing.jl")
    include("macro.jl")
end