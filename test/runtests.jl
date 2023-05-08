using SafeTestsets

@safetestset "@frompackage: basics" begin include("frompackage/basics.jl") end
# @safetestset "@frompackage: with Pluto Session" begin include("frompackage/with_pluto_session.jl") end
