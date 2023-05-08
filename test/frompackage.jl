import PlutoDevMacros.FromPackage: process_outside_pluto!, load_module, modname_path, fromparent_module, parseinput, get_package_data

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

# We point at the helpers file inside the FromPackage submodule, we only load the constants in the Loaded submodule
target = "../src/frompackage/helpers.jl"
# We simulate a caller from a notebook by appending a fake cell-id
caller = join([ @__FILE__, "#==#", "00000000-0000-0000-0000-000000000000" ])
@testset "FromPackage" begin
    @testset "Outside Pluto" begin
        dict = get_package_data(target)
        valid(ex) = ex == process_outside_pluto!(deepcopy(ex), dict)
        invalid(ex) = nothing === process_outside_pluto!(deepcopy(ex), dict)

        @test valid(:(import .ASD: lol))
        @test invalid(:(import .ASD: *))
        @test invalid(:(import PlutoDevMacros: lol)) # PlutoDevMacros is the name of the target package, we don't allow that
        @test invalid(:(import *))

        @test valid(:(import HypertextLiteral)) # This is a direct dependency
        @test valid(:(import Random)) # This is a direct dependency and a stdlib
        @test invalid(:(import Tricks)) # This is an indirect dependency, from HypertextLiteral
        @test invalid(:(import Base64)) # This is an stdlib, but on in the proj
        @test invalid(:(import DataFrames)) # This is not a dependency


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
        @testset "Input Parsing" begin
            @testset "Target included in Package" begin
                dict = load_module(target, Main)
                f(ex) = parseinput(deepcopy(ex), dict)

                parent_path = modname_path(fromparent_module[])
                # FromDeps imports
                ex = :(using MacroTools)
                @test ex == f(ex) # This should work as MacroTools is a deps of PlutoDevMacros

                ex = :(using MacroTools: *)
                @test_throws "catch-all" f(ex) 

                ex = :(using DataFrames)
                @test_throws "import expression is not supported" f(ex) 

                # FromPackage imports
                ex = :(import PlutoDevMacros)
                expected = :(import $(parent_path...).PlutoDevMacros)
                @test expected == f(ex) # This works because PlutoDevMacros is the name of the loaded package

                ex = :(import PackageModule.Script)
                expected = :(import $(parent_path...).PlutoDevMacros.Script)
                @test expected == f(ex)

                ex = :(using PackageModule.Script)
                expected = :(import $(parent_path...).PlutoDevMacros.Script: HTLBypass, HTLScript, HTLScriptPart, Script, combine_scripts)
                @test expected == f(ex)

                # Relative imports
                ex = :(import ..Script)
                expected = :(import $(parent_path...).PlutoDevMacros.Script)
                @test expected == f(ex) # This should work as Script is a valid sibling module of FromPackage

                ex = :(import ..NonExistant)
                @test_throws UndefVarError f(ex) # It can't find the module

                # FromParent import
                ex = :(import *)
                expected = :(import $(parent_path...).PlutoDevMacros.FromPackage: @addmethod, @frompackage, @fromparent, FromPackage, _cell_data)
                @test expected == f(ex)

                ex = :(import ParentModule: *)
                @test expected == f(ex)

                ex = :(import ParentModule: _cell_data)
                expected = :(import $(parent_path...).PlutoDevMacros.FromPackage: _cell_data)
                @test expected == f(ex)

                ex = :(using ParentModule)
                expected = :(import $(parent_path...).PlutoDevMacros.FromPackage: @addmethod, @frompackage, @fromparent, FromPackage)
                @test expected == f(ex)
            end
            @testset "Target not included in Package" begin
                dict = load_module(caller, Main)
                f(ex) = parseinput(deepcopy(ex), dict)
                parent_path = modname_path(fromparent_module[])

                ex = :(import PackageModule.Script)
                expected = :(import $(parent_path...).PlutoDevMacros.Script)
                @test expected == f(ex)

                # FromParent import
                ex = :(import *)
                @test_throws "The current file was not found" f(ex)

                ex = :(import ParentModule: *)
                @test_throws "The current file was not found" f(ex)

                ex = :(import ParentModule: _cell_data)
                @test_throws "The current file was not found" f(ex)
            end
        end

        @testset "With Pluto Session" begin
            options = Configuration.from_flat_kwargs(;disable_writing_notebook_files = true)
            srcdir = joinpath(@__DIR__, "TestPackage/src/")
            eval_in_nb(sn, expr) = WorkspaceManager.eval_fetch_in_workspace(sn, expr)

            @testset "notebook1.jl" begin
                ss = ServerSession(;options)
                path = joinpath(srcdir, "notebook1.jl")
                nb = SessionActions.open(ss, path; run_async=false)
                @test eval_in_nb((ss, nb), :toplevel_variable) == TestPackage.toplevel_variable
                @test eval_in_nb((ss, nb), :hidden_toplevel_variable) == TestPackage.hidden_toplevel_variable
                for cell in nb.cells 
                    @test noerror(cell)
                end
                SessionActions.shutdown(ss, nb)
            end

            @testset "inner_notebook2.jl" begin
                ss = ServerSession(;options)
                path = joinpath(srcdir, "inner_notebook2.jl")
                nb = SessionActions.open(ss, path; run_async=false)
                for cell in nb.cells 
                    @test noerror(cell)
                end
                eval_in_nb((ss,nb), :(BenchmarkTools isa Module))
                SessionActions.shutdown(ss, nb)
            end

            @testset "test_macro2.jl" begin
                ss = ServerSession(;options)
                path = joinpath(srcdir, "test_macro2.jl")
                nb = SessionActions.open(ss, path; run_async=false)
                for cell in nb.cells
                    @test noerror(cell)
                end
                SessionActions.shutdown(ss, nb)
            end
        end
    end
end
