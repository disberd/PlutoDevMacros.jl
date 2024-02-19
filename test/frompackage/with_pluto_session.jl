using Test
import Pluto: update_save_run!, update_run!, WorkspaceManager, ClientSession, ServerSession, Notebook, Cell, project_relative_path, SessionActions, load_notebook, Configuration

include("helpers.jl")

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

@testset "out_notebook.jl" begin
    ss = ServerSession(; options)
    path = abspath(srcdir, "../out_notebook.jl")
    nb = SessionActions.open(ss, path; run_async=false)
    for cell in nb.cells
        @test noerror(cell)
    end
    SessionActions.shutdown(ss, nb)
end

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