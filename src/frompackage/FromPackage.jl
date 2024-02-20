module FromPackage
    import ..PlutoDevMacros: @addmethod, _cell_data
    using HypertextLiteral
    import Pkg
    import Pkg.Types: EnvCache, write_project, Context, read_project, read_manifest
    export @fromparent, @addmethod, @frompackage

    include("types.jl")
    include("helpers.jl")
    include("code_parsing.jl")
    include("loading.jl")
    include("input_parsing.jl")
    include("macro.jl")
end