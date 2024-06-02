import PlutoDevMacros.FromPackage: FromPackage, add_loadpath, process_settings!, get_setting, get_active, get_project_file
using Test

TestPackage_path = normpath(@__DIR__, "../TestPackage")
# We point at the helpers file inside the TestPackage module, we stuff up to the first include
target = TestPackage_path

# We test that the prefix is there in the temp env
@test startswith(FromPackage.default_ecg() |> get_active |> get_project_file |> dirname |> basename, "frompackage_")

@testset "Get Setting" begin
    @test_throws "is not a valid setting" get_setting(:asdfasdf)
    key = :SHOULD_PREPEND_LOAD_PATH
    current = getproperty(FromPackage, key)[]
    @test get_setting(key) === current

    getproperty(FromPackage, key)[] = !current
    @test get_setting(key) === !current

    getproperty(FromPackage, key)[] = current
    @test get_setting(key) === current
    # Test with dict
    d = Dict("Custom Settings" => Dict(key => !current))
    @test get_setting(d, key) === !current
end

@testset "Parsing" begin
    ex = :(@settings a = 1)
    # Nothing done without block, as that is anyhow not supported
    @test ex === process_settings!(ex, Dict())
    # Test that settings are removed if in a block
    ex = quote $ex end
    d = Dict()
    new_ex = process_settings!(deepcopy(ex), d) |> Base.remove_linenums!
    @test isempty(new_ex.args)
    @test haskey(d, "Custom Settings")
    @test d["Custom Settings"][:a] == 1

    # We check illegal expressions
    ex = quote
        @settings a = 1 b = rand()
    end
    @test_throws "Only primitive" process_settings!(deepcopy(ex), Dict())
    ex = quote
        @settings a = 1 b c
    end
    @test_throws "Only `var = value`" process_settings!(deepcopy(ex), Dict())

    # Test the begin end synthax
    ex = quote
        @settings begin
            a = 1
            b = 2
        end
    end
    d = Dict()
    new_ex = process_settings!(deepcopy(ex), d) |> Base.remove_linenums!
    @test isempty(new_ex.args)
    @test haskey(d, "Custom Settings")
    @test d["Custom Settings"][:a] == 1
    @test d["Custom Settings"][:b] == 2
end

@testset "SHOULD_PREPEND_LOAD_PATH" begin
    proj_file = FromPackage.default_ecg() |> get_active |> get_project_file
    # Remove the custom envs from the load path
    filter!(LOAD_PATH) do proj
        !startswith(proj |> dirname |> basename, "frompackage_")
    end
    @info LOAD_PATH
    l = length(LOAD_PATH)
    @test proj_file ∉ LOAD_PATH
    add_loadpath(proj_file; should_prepend = false)
    @test length(LOAD_PATH) == l+1
    add_loadpath(proj_file; should_prepend = false)
    @test length(LOAD_PATH) == l+1
    @test LOAD_PATH[end] == proj_file
    LOAD_PATH[end] == proj_file && pop!(LOAD_PATH)

    # Prepend
    add_loadpath(proj_file; should_prepend = true)
    @test LOAD_PATH[1] == proj_file
    LOAD_PATH[1] == proj_file && popfirst!(LOAD_PATH)
end