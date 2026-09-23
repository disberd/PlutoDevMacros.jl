@testitem "MyPkg notebooks" begin
    include(joinpath(@__DIR__, "with_pluto_helpers.jl"))
    import Pluto
    # Work on a copy, so the test can edit the package and the notebook environments
    mypkg_path = temp_copy_without_manifests(normpath(@__DIR__, "../../docs/examples/MyPkg"))
    instantiate_from_path(mypkg_path)
    notebook_path(name) = joinpath(mypkg_path, "notebooks", name)
    # The notebooks get PlutoDevMacros from the registry. Use the local version instead.
    for name in ("first_steps.jl", "extension.jl")
        Pluto.activate_notebook_environment(notebook_path(name)) do
            Pkg.compat("PlutoDevMacros", nothing)
            Pkg.develop(PackageSpec(; path = current_package_path()))
        end
    end
    find_cell(nb, code) = only(filter(c -> c.code == code, nb.cells))
    # Apply the `old => new` replacement to the file at `path`, then click the reload button
    function edit_and_reload(ss, nb, path, change::Pair)
        write(path, replace(read(path, String), change))
        update_run!(ss, nb, only(filter(c -> startswith(c.code, "@fromparent"), nb.cells)))
    end
    output_text(cell) = string(cell.output.body)

    ss = ServerSession(; options)

    nb = SessionActions.open(ss, notebook_path("first_steps.jl"); run_async = false)
    for cell in nb.cells
        @test noerror(cell)
    end
    @test contains(output_text(find_cell(nb, "greet(name)")), "Hi, Pluto!")
    @test eval_in_nb((ss, nb), :(distance(p))) == 7.0
    edit_and_reload(ss, nb, joinpath(mypkg_path, "src", "MyPkg.jl"), "Hi, " => "Hey, ")
    for cell in nb.cells
        @test noerror(cell)
    end
    @test contains(output_text(find_cell(nb, "greet(name)")), "Hey, Pluto!")
    SessionActions.shutdown(ss, nb)

    nb = SessionActions.open(ss, notebook_path("extension.jl"); run_async = false)
    for cell in nb.cells
        @test noerror(cell)
    end
    shout_cell = find_cell(nb, "shout(\"Pluto\")")
    @test contains(output_text(shout_cell), "HELLO, PLUTO!")
    edit_and_reload(ss, nb, joinpath(mypkg_path, "ext", "MyPkgExampleExt.jl"), "\"!\"" => "\"!!\"")
    for cell in nb.cells
        @test noerror(cell)
    end
    @test contains(output_text(shout_cell), "HELLO, PLUTO!!")
    SessionActions.shutdown(ss, nb)
end
