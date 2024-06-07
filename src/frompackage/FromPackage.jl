module FromPackage
    import ..PlutoDevMacros: @addmethod, _cell_data
    import Pkg
    import TOML
    using Pkg.Types: EnvCache, write_project, Context, read_project, read_manifest, write_manifest,  Manifest, Project, PackageEntry
    using MacroTools: postwalk, flatten
    using JuliaInterpreter: ExprSplitter


    export @fromparent, @addmethod, @frompackage

    include("types.jl")
    include("settings.jl")
    include("envcachegroup.jl")
    include("helpers.jl")
    include("code_parsing.jl")
    include("loading.jl")
    include("input_parsing.jl")
    include("macro.jl")
    include("new_funcs.jl")
end