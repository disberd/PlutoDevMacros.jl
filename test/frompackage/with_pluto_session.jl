using Test
import Pluto: update_save_run!, update_run!, WorkspaceManager, ClientSession, ServerSession, Notebook, Cell, project_relative_path, SessionActions, load_notebook, Configuration

include(joinpath(@__DIR__, "helpers.jl"))

instantiate_and_import(:(import TestPackage), normpath(@__DIR__, "../TestPackage"))

function noerror(cell; verbose=true)
    if cell.errored && verbose
        @show cell.output.body
    end
    !cell.errored
end


options = Configuration.from_flat_kwargs(; disable_writing_notebook_files=true, workspace_use_distributed_stdlib = true)
srcdir = joinpath(@__DIR__, "../TestPackage/src/")
eval_in_nb(sn, expr) = WorkspaceManager.eval_fetch_in_workspace(sn, expr)

@testset "notebook1.jl" begin
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

@testset "inner_notebook2.jl" begin
    ss = ServerSession(; options)
    path = joinpath(srcdir, "inner_notebook2.jl")
    nb = SessionActions.open(ss, path; run_async=false)
    for cell in nb.cells
        @test noerror(cell)
    end
    eval_in_nb((ss, nb), :(BenchmarkTools isa Module))
    SessionActions.shutdown(ss, nb)
end

@testset "test_macro2.jl" begin
    ss = ServerSession(; options)
    path = joinpath(srcdir, "test_macro2.jl")
    nb = SessionActions.open(ss, path; run_async=false)
    for cell in nb.cells
        @test noerror(cell)
    end
    SessionActions.shutdown(ss, nb)
end

# @testset "out_notebook.jl" begin
#     ss = ServerSession(; options)
#     path = abspath(srcdir, "../out_notebook.jl")
#     nb = SessionActions.open(ss, path; run_async=false)
#     for cell in nb.cells
#         @test noerror(cell)
#     end
#     SessionActions.shutdown(ss, nb)
# end

@testset "test_pkgmanager.jl" begin
    ss = ServerSession(; options)
    path = abspath(srcdir, "../test_pkgmanager.jl")
    nb = SessionActions.open(ss, path; run_async=false)
    for cell in nb.cells
        @test noerror(cell)
    end
    SessionActions.shutdown(ss, nb)
end

# We test the ParseError (issue 30)
srcdir = joinpath(@__DIR__, "../TestParseError/src/")
@testset "test_parse_error.jl" begin
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

# We test dev dependencies with relative path (issue 30)
srcdir = joinpath(@__DIR__, "../TestDevDependency/src/")
@testset "test_dev_dependency.jl" begin
    ss = ServerSession(; options)
    path = abspath(srcdir, "../test_notebook.jl")
    nb = SessionActions.open(ss, path; run_async=false)
    for cell in nb.cells
        @test noerror(cell)
    end
    SessionActions.shutdown(ss, nb)
end

# We test @exclude_using (issue 11)
srcdir = joinpath(@__DIR__, "../TestUsingNames/src/")
@testset "Using Names" begin
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