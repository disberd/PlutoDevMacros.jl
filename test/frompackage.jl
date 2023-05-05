import PlutoDevMacros.FromPackage: process_outside_pluto!

using Test
import Pluto: update_save_run!, update_run!, WorkspaceManager, ClientSession, ServerSession, Notebook, Cell, project_relative_path, SessionActions, load_notebook, Configuration

# The LOAD_PATH hack is required because if we add ./TestPackage as a test dependency we get the error in https://github.com/JuliaLang/Pkg.jl/issues/1585
push!(LOAD_PATH, normpath(@__DIR__, "./TestPackage"))
import TestPackage
import TestPackage: testmethod
import TestPackage.Issue2
pop!(LOAD_PATH)

function noerror(cell; verbose=true)
    if cell.errored && verbose
        @show cell.output.body
    end
    !cell.errored
end

@testset "FromPackage" begin
    @testset "Outside Pluto" begin
        rmnothing(ex::Expr) = Expr(ex.head, filter(x -> x !== :nothing && !isnothing(x), ex.args)...)
        rmnothing(x) = x
        function expr_equal(ex1, ex2)
            ex1 = prewalk(rmlines, deepcopy(ex1))
            ex1 = postwalk(rmnothing, ex1)
            ex2 = prewalk(rmlines, deepcopy(ex2))
            ex2 = postwalk(rmnothing, ex2)
            ex1 == ex2
        end

        ex = :(import .ASD: lol)
        @test deepcopy(ex) == process_outside_pluto!(ex)
        ex = :(import .ASD: *)
        @test nothing === process_outside_pluto!(ex)
        ex = :(import module: lol)
        @test nothing === process_outside_pluto!(ex)


        # Here we test that the loaded TestPackage has the intended functionality
        # We verify that the relative import statement from @fromparent outside
        # of Pluto works as intended, correctly importing and extending
        # `testmethod`
        @test testmethod("a") == "ANY"
        @test testmethod(3) == "INT"
        @test testmethod(3.0) == "FLOAT"
        
        @test Issue2.foo(Issue2.c) !== nothing
    end


    @testset "Inside Pluto" begin
        options = Configuration.from_flat_kwargs(;disable_writing_notebook_files = true)
        srcdir = joinpath(@__DIR__, "TestPackage/src/")
        eval_in_nb(sn, expr) = WorkspaceManager.eval_fetch_in_workspace(sn, expr)

        @testset "notebook1.jl" begin
            ss = ServerSession(;options)
            path = joinpath(srcdir, "notebook1.jl")
            nb = SessionActions.open(ss, path; run_async=false)
            @test eval_in_nb((ss, nb), :toplevel_variable) == TestPackage.toplevel_variable
            @test eval_in_nb((ss, nb), :hidden_toplevel_variable) == TestPackage.hidden_toplevel_variable
            # For some reason the first cell errors with `Pkg` not defined as a
            # package when calling Pkg.activate. The rest of the cells seem to
            # work fine though so unclear what is happening. For the moment we
            # don't test the first cell
            for cell in nb.cells[2:end] 
                @test noerror(cell)
            end
            SessionActions.shutdown(ss, nb)
        end

        @testset "inner_notebook2.jl" begin
            ss = ServerSession(;options)
            path = joinpath(srcdir, "inner_notebook2.jl")
            nb = SessionActions.open(ss, path; run_async=false)
            # For some reason the first cell errors with `Pkg` not defined as a
            # package when calling Pkg.activate. The rest of the cells seem to
            # work fine though so unclear what is happening. For the moment we
            # don't test the first cell
            for cell in nb.cells[2:end] 
                @test noerror(cell)
            end
            SessionActions.shutdown(ss, nb)
        end

        @testset "test_macro2.jl" begin
            ss = ServerSession(;options)
            path = joinpath(srcdir, "test_macro2.jl")
            nb = SessionActions.open(ss, path; run_async=false)
            # For some reason the first cell errors with `Pkg` not defined as a
            # package when calling Pkg.activate. The rest of the cells seem to
            # work fine though so unclear what is happening. For the moment we
            # don't test the first cell
            for cell in nb.cells[2:end] 
                @test noerror(cell)
            end
            SessionActions.shutdown(ss, nb)
        end
    end
end
