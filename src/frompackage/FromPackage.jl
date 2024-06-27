module FromPackage
    import ..PlutoDevMacros: @addmethod, _cell_data, is_notebook_local
    import Pkg
    import TOML
    using MacroTools: postwalk, flatten
    using JuliaInterpreter: ExprSplitter


    export @fromparent, @addmethod, @frompackage

    include("types.jl")
    include("imports_helpers.jl")
    include("settings.jl")
    include("helpers.jl")
    include("code_parsing.jl")
    include("loading.jl")
    include("input_parsing.jl")
    include("macro.jl")
end