module TestPackage

greet() = print("Hello World!")

export toplevel_variable

toplevel_variable = 15
hidden_toplevel_variable = 10

include("notebook1.jl")

end # module TestPackage
