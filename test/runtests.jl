using TestItemRunner

@testitem "Aqua" begin
    using Aqua
    using PlutoDevMacros
    Aqua.test_all(PlutoDevMacros)
end

@testitem "Basics" begin include("basics.jl") end
include("frompackage/with_pluto_session.jl")
include("frompackage/pluto_package_extensions.jl")

@run_package_tests verbose=true