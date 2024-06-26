@testitem "Indirect Extension" begin
    include(joinpath(@__DIR__, "with_pluto_helpers.jl"))
    ss = ServerSession(; options)
    path = joinpath(indirect_path, "test_extension.jl")
    nb = SessionActions.open(ss, path; run_async=false)
    @test eval_in_nb((ss, nb), :method_present) === true
    for cell in nb.cells
        @test noerror(cell)
    end
    SessionActions.shutdown(ss, nb)
end

@testitem "Direct Extensions" begin
    # Include the setup
    include(joinpath(@__DIR__, "with_pluto_helpers.jl"))
    env_path = joinpath(direct_path, "notebook_env")
    dev_package_in_proj(env_path)
    instantiate_from_path(env_path)
    # Do the rest
    ss = ServerSession(; options)
    path = joinpath(direct_path, "test_extension.jl")
    nb = SessionActions.open(ss, path; run_async=false)
    @test eval_in_nb((ss, nb), :standard_extension_output) === "Standard Extension works!"
    @test eval_in_nb((ss, nb), :weird_extension_output) === "Weird Extension name works!"
    @test eval_in_nb((ss, nb), :(p isa PlutoPlot)) === true
    for cell in nb.cells
        @test noerror(cell)
    end
    SessionActions.shutdown(ss, nb)
end
