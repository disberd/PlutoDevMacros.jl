module FromPackage
    import ..PlutoDevMacros: @addmethod, _cell_data, is_notebook_local
    import ..PlutoDevMacros: hide_this_log, simple_html_cat
    import Pkg
    import TOML
    using MacroTools: postwalk, flatten, MacroTools, isdef, longdef
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