module FromPackage
    import ..PlutoDevMacros: @addmethod, _cell_data
    using HypertextLiteral
    import Pkg
    import TOML

    export @fromparent, @addmethod, @frompackage

    include("types.jl")
    include("envcachegroup.jl")
    include("helpers.jl")
    include("code_parsing.jl")
    include("loading.jl")
    include("input_parsing.jl")
    include("macro.jl")

    # Here we will store modules from Base.loaded_modules that are explicitly requested inside `@frompackage` or that are needed to load extensions of the `@frompackage` target
    module LoadedModules end
end