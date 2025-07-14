
@testitem "notebook1.jl" begin
    # Include the setup
    include(joinpath(@__DIR__, "with_pluto_helpers.jl"))
    srcdir = joinpath(@__DIR__, "../TestPackage/src/")
    # We add PlutoDevMacros as dev dependency to TestPackage
    dev_package_in_proj(srcdir)
    instantiate_from_path(srcdir)
    eval_with_load_path(:(import TestPackage), testpackage_path)
    # Do the tests
    ss = ServerSession(; options)
    path = joinpath(srcdir, "notebook1.jl")
    nb = SessionActions.open(ss, path; run_async=false)
    @test eval_in_nb((ss, nb), :toplevel_variable) == TestPackage.toplevel_variable
    @test eval_in_nb((ss, nb), :hidden_toplevel_variable) == TestPackage.hidden_toplevel_variable
    # We test that __init__ was not ran, as this file will only contain the module before the __init__ function is defined
    @test eval_in_nb((ss, nb), :(TEST_INIT[])) == 0
    for cell in nb.cells
        @test noerror(cell)
    end
    SessionActions.shutdown(ss, nb)
end

@testitem "inner_notebook2.jl" begin
    # Include the setup
    include(joinpath(@__DIR__, "with_pluto_helpers.jl"))
    srcdir = joinpath(@__DIR__, "../TestPackage/src/")
    # We add PlutoDevMacros as dev dependency to TestPackage
    dev_package_in_proj(srcdir)
    instantiate_from_path(srcdir)
    # Do the tests
    ss = ServerSession(; options)
    path = joinpath(srcdir, "inner_notebook2.jl")
    nb = SessionActions.open(ss, path; run_async=false)
    for cell in nb.cells
        @test noerror(cell)
    end
    eval_in_nb((ss, nb), :(BenchmarkTools isa Module))
    SessionActions.shutdown(ss, nb)
end

@testitem "test_macro2.jl" begin
    # Include the setup
    include(joinpath(@__DIR__, "with_pluto_helpers.jl"))
    srcdir = joinpath(@__DIR__, "../TestPackage/src/")
    # We add PlutoDevMacros as dev dependency to TestPackage
    dev_package_in_proj(srcdir)
    instantiate_from_path(srcdir)
    # Do the tests
    ss = ServerSession(; options)
    path = joinpath(srcdir, "test_macro2.jl")
    nb = SessionActions.open(ss, path; run_async=false)
    for cell in nb.cells
        @test noerror(cell)
    end
    SessionActions.shutdown(ss, nb)
end

@testitem "TestPackage/import_as.jl" begin
    # Include the setup
    include(joinpath(@__DIR__, "with_pluto_helpers.jl"))
    srcdir = joinpath(@__DIR__, "../TestPackage/src/")
    # We add PlutoDevMacros as dev dependency to TestPackage
    dev_package_in_proj(srcdir)
    instantiate_from_path(srcdir)
    # Do the tests
    ss = ServerSession(; options)
    path = joinpath(srcdir, "import_as.jl")
    nb = SessionActions.open(ss, path; run_async=false)
    for cell in nb.cells
        @test noerror(cell)
    end
    SessionActions.shutdown(ss, nb)
end

@testitem "TestPackage/out_notebook.jl" begin
    # Include the setup
    include(joinpath(@__DIR__, "with_pluto_helpers.jl"))
    srcdir = joinpath(@__DIR__, "../TestPackage/src/")
    # We add PlutoDevMacros as dev dependency to TestPackage
    dev_package_in_proj(srcdir)
    instantiate_from_path(srcdir)
    # Do the tests
    ss = ServerSession(; options)
    path = abspath(srcdir, "../out_notebook.jl")
    nb = SessionActions.open(ss, path; run_async=false)
    for cell in nb.cells[1:end-1] # The last cell contains an error on purpose
        @test noerror(cell)
    end
    SessionActions.shutdown(ss, nb)
end

@testitem "test_pkgmanager.jl" begin
    # Include the setup
    include(joinpath(@__DIR__, "with_pluto_helpers.jl"))
    srcdir = joinpath(@__DIR__, "../TestPackage/src/")
    # We add PlutoDevMacros as dev dependency to TestPackage
    dev_package_in_proj(srcdir)
    instantiate_from_path(srcdir)
    # Do the tests
    ss = ServerSession(; options)
    path = abspath(srcdir, "../test_pkgmanager.jl")
    nb = SessionActions.open(ss, path; run_async=false)
    for cell in nb.cells
        @test noerror(cell)
    end
    SessionActions.shutdown(ss, nb)
end

@testitem "test_parse_error.jl" begin
    # Include the setup
    include(joinpath(@__DIR__, "with_pluto_helpers.jl"))
    # We test the ParseError (issue 30)
    srcdir = joinpath(@__DIR__, "../TestParseError/src/")
    instantiate_from_path(srcdir)
    # Do the tests
    ss = ServerSession(; options)
    path = abspath(srcdir, "../parseerror_notebook.jl")
    nb = SessionActions.open(ss, path; run_async=false)
    cell = nb.cells[2]
    @test cell.errored
    msg = cell.output.body[:msg]
    if VERSION < v"1.10"
        @test startswith(msg, "syntax: incomplete:")
    else
        @test startswith(msg, "LoadError: ParseError:")
    end
    SessionActions.shutdown(ss, nb)
end

@testitem "test_dev_dependency.jl" begin
    # Include the setup
    include(joinpath(@__DIR__, "with_pluto_helpers.jl"))
    # We test dev dependencies with relative path (issue 30)
    srcdir = joinpath(@__DIR__, "../TestDevDependency/src/")
    # We add TestPackage as dev dependency
    dev_package_in_proj(srcdir, testpackage_path)

    # Do the tests
    ss = ServerSession(; options)
    path = abspath(srcdir, "../test_notebook.jl")
    nb = SessionActions.open(ss, path; run_async=false)
    for cell in nb.cells
        @test noerror(cell)
    end
    SessionActions.shutdown(ss, nb)
end

@testitem "Using Names" begin
    # Include the setup
    include(joinpath(@__DIR__, "with_pluto_helpers.jl"))
    # We test @exclude_using (issue 11)
    srcdir = joinpath(@__DIR__, "../TestUsingNames/src/")
    instantiate_from_path(srcdir)
    # Do the tests
    ss = ServerSession(; options)
    for filename in ["test_notebook1.jl", "test_notebook2.jl"]
        path = abspath(srcdir, "..", filename)
        nb = SessionActions.open(ss, path; run_async=false)
        # We test that no errors are present
        for cell in nb.cells
            @test noerror(cell)
        end
        # We extract the rand_variable value
        first_value = eval_in_nb((ss, nb), :rand_variable)
        # We rerun the second cell, containing the `@fromparent` call
        update_run!(ss, nb, nb.cells[2])
        # We check again that no errors arose
        for cell in nb.cells
            @test noerror(cell)
        end
        # We check that the rand_variable value changed
        second_value = eval_in_nb((ss, nb), :rand_variable)
        @test first_value != second_value
        SessionActions.shutdown(ss, nb)
    end
end

@testitem "TestInception" begin
    # Include the setup
    include(joinpath(@__DIR__, "with_pluto_helpers.jl"))
    # We test @exclude_using (issue 11)
    target_dir = joinpath(@__DIR__, "../TestInception")
    # We delete the manifest if it exists as we are testing the instantiation happens correctly
    delete_manifest(target_dir)
    # Do the tests
    ss = ServerSession(; options)
    path = abspath(target_dir, "inception_notebook.jl")
    nb = SessionActions.open(ss, path; run_async=false);
    # We test that no errors are present
    for cell in nb.cells
        @test noerror(cell)
    end
    function has_log_msg(cell, needle)
        any(cell.logs) do dict
            msg = dict["msg"] |> first
            contains(msg, needle)
        end
    end
    # We check that the manifest has been created from the cell, and the messages has been logged in the 3rd cell (which is the one calling @fromparent)
    @test has_log_msg(nb.cells[3], r"Instantiating Manifest")
    # We check that the cell importing SimplePlutoInclude has logs for loading the SingleExtension
    @test has_log_msg(nb.cells[10], "Loading code of extension SingleExtension")
    # We check that the cell importing Example has logs for loading the DualExtension
    @test has_log_msg(nb.cells[13], "Loading code of extension DualExtension")
    # We extract the rand_variable value
    first_value = eval_in_nb((ss, nb), :random_variable)
    # We rerun the second cell, containing the `PDM.@frompackage` call, which reload PlutoDevMacros itself
    update_run!(ss, nb, nb.cells[2])
    # We check again that no errors arose
    for cell in nb.cells
        @test noerror(cell)
    end
    # We check that warning of replacing rootmodule and deleting mirror_package_callback from previous workspace are present in cell 3
    @test has_log_msg(nb.cells[3], "Replacing module")
    @test has_log_msg(nb.cells[3], "Deleting previous version of package_callback function")
    # We also have the messages for reloading the extension in this cell now
    @test has_log_msg(nb.cells[3], "Loading code of extension SingleExtension")
    @test has_log_msg(nb.cells[3], "Loading code of extension DualExtension")
    # We check that the rand_variable value changed
    second_value = eval_in_nb((ss, nb), :random_variable)
    @test first_value != second_value
    # We now try to 
    SessionActions.shutdown(ss, nb)
end