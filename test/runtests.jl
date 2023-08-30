using SafeTestsets

@safetestset "Script Module" begin include("script_module.jl") end
@safetestset "@frompackage: basics" begin include("frompackage/basics.jl") end
@safetestset "@frompackage: with Pluto Session" begin include("frompackage/with_pluto_session.jl") end
@safetestset "@frompackage: Package Extensions in Pluto" begin include("frompackage/pluto_package_extensions.jl") end
