using SafeTestsets

@safetestset "Aqua" begin
    using Aqua
    using PlutoDevMacros
    Aqua.test_all(PlutoDevMacros)
end

@safetestset "Basics" begin include("basics.jl") end
# @safetestset "@frompackage: basics" begin include("frompackage/basics.jl") end
# @safetestset "@frompackage: settings" begin include("frompackage/settings.jl") end
@safetestset "@frompackage: with Pluto Session" begin include("frompackage/with_pluto_session.jl") end
@safetestset "@frompackage: Package Extensions in Pluto" begin include("frompackage/pluto_package_extensions.jl") end