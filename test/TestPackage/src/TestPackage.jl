module TestPackage

import PlutoDevMacros
export toplevel_variable

toplevel_variable = 15
hidden_toplevel_variable = 10

include("notebook1.jl")

module Inner
    include("inner_notebook1.jl")
    include("inner_notebook2.jl")
end

module Issue2
    include("test_macro1.jl")
    include("test_macro2.jl")
end

module SpecificImport
    include("specific_imports1.jl")
    include("specific_imports2.jl")
end

end # module TestPackage
