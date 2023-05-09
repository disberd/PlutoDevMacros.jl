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
    include("test_macro1.jl") # Defines NotThatCoolStruct at line 28
    include("test_macro2.jl") # Defines GreatStructure
end

module SpecificImport
    include("specific_imports1.jl") # Defines inner_variable1
    include("specific_imports2.jl")
end

end # module TestPackage
