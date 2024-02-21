module FromPackage
    import ..PlutoDevMacros: @addmethod, _cell_data
    using HypertextLiteral
    export @fromparent, @addmethod, @frompackage

    include("types.jl")
    include("helpers.jl")
    include("code_parsing.jl")
    include("loading.jl")
    include("input_parsing.jl")
    include("macro.jl")
end