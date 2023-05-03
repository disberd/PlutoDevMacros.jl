using Test
using PlutoDevMacros
push!(LOAD_PATH, normpath(@__DIR__, "./TestPackage"))
using TestPackage
pop!(LOAD_PATH)

include("frompackage.jl")