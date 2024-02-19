import PlutoDevMacros.FromPackage: process_outside_pluto!, load_module_in_caller, modname_path, fromparent_module, parseinput, get_package_data, @fromparent, _combined, process_skiplines!, get_temp_module, LineNumberRange, parse_skipline, package_dependencies, extract_module_expression
import Pkg

using Test

# The LOAD_PATH hack is required because if we add ./TestPackage as a test dependency we get the error in https://github.com/JuliaLang/Pkg.jl/issues/1585
push!(LOAD_PATH, normpath(@__DIR__, "../TestPackage"))
import TestPackage
import TestPackage: testmethod
import TestPackage.Issue2
pop!(LOAD_PATH)

# We point at the helpers file inside the FromPackage submodule, we only load the constants in the Loaded submodule
outpackage_target = abspath(@__DIR__,"../..")
inpackage_target = joinpath(outpackage_target, "src/frompackage/helpers.jl")
# We simulate a caller from a notebook by appending a fake cell-id
outpluto_caller = abspath(@__DIR__,"../..")
inpluto_caller = join([outpluto_caller, "#==#", "00000000-0000-0000-0000-000000000000"])

@testset "Errors" begin
    @test_throws "No parent project" mktempdir() do tmpdir
            package_dependencies(tmpdir)
    end
    @test_throws "No project" mktempdir() do tmpdir
            get_package_data(tmpdir)
    end 
    @test_throws "is not a package" mktempdir() do tmpdir
        cd(tmpdir) do 
            Pkg.activate(".")
            Pkg.add("TOML")
            get_package_data(".")
        end
    end

    mktemp() do path, io
        open(path, "w") do io
            write(io, """
            module INCOMPLETE
            a = 1
            """)
        end
        if VERSION < v"1.10"
            @test_throws "did not generate a valid `module`" extract_module_expression(path)
        else
            @test_throws Base.Meta.ParseError extract_module_expression(path)
        end
    end
end

@testset "Outside Pluto" begin
    dict = get_package_data(inpackage_target)
    valid(ex) = nothing !== process_outside_pluto!(deepcopy(ex), dict)
    invalid(ex) = nothing === process_outside_pluto!(deepcopy(ex), dict)

    @test valid(:(import .ASD: lol))
    @test invalid(:(import .ASD: *))
    @test invalid(:(import PlutoDevMacros: lol)) # PlutoDevMacros is the name of the inpackage_target package, we don't allow that
    @test invalid(:(import *))

    @test valid(:(import >.HypertextLiteral)) # This is a direct dependency
    @test valid(:(import >.Random)) # This is a direct dependency and a stdlib
    @test invalid(:(import >.Tricks)) # This is an indirect dependency, from HypertextLiteral
    @test invalid(:(import >.Base64)) # This is an stdlib, but on in the proj
    @test invalid(:(import >.DataFrames)) # This is not a dependency


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
        @testset "target included in Package" begin
            dict = load_module_in_caller(inpackage_target, Main)
            f(ex) = parseinput(deepcopy(ex), dict)


            parent_path = modname_path(fromparent_module[])
            # FromDeps imports
            ex = :(using >.MacroTools)

            MacroTools = get_temp_module().PlutoDevMacros._DirectDeps_.MacroTools

            mod_path = Expr(:., vcat(parent_path, [:PlutoDevMacros, :_DirectDeps_, :MacroTools])...)
            exported_names = map(x -> Expr(:., x), names(MacroTools))
            expected = Expr(:import, Expr(:(:), mod_path, exported_names...))
            @test expected == f(ex) # This should work as MacroTools is a deps of PlutoDevMacros

            ex = :(using >.MacroTools: *)
            @test_throws "catch-all" f(ex)

            ex = :(using DataFrames)
            @test_throws "import expression is not supported" f(ex)

            # FromPackage imports
            ex = :(import PlutoDevMacros)
            expected = :(import $(parent_path...).PlutoDevMacros)
            @test expected == f(ex) # This works because PlutoDevMacros is the name of the loaded package

            ex = :(import PackageModule.PlutoCombineHTL)
            expected = :(import $(parent_path...).PlutoDevMacros.PlutoCombineHTL)
            @test expected == f(ex)

            ex = :(using PackageModule.PlutoCombineHTL)
            expected = :(import $(parent_path...).PlutoDevMacros.PlutoCombineHTL: PlutoCombineHTL, formatted_code, make_html, make_node, make_script)
            @test expected == f(ex)

            # Relative imports
            ex = :(import ..PlutoCombineHTL)
            expected = :(import $(parent_path...).PlutoDevMacros.PlutoCombineHTL)
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
        @testset "target not included in Package" begin
            dict = load_module_in_caller(inpluto_caller, Main)
            f(ex) = parseinput(deepcopy(ex), dict)
            parent_path = modname_path(fromparent_module[])

            ex = :(import PackageModule.PlutoCombineHTL)
            expected = :(import $(parent_path...).PlutoDevMacros.PlutoCombineHTL)
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
end

# Clean the given expression by removing `nothing` and LineNumberNodes
function clean_expr(ex)
    ex = deepcopy(ex)
    ex isa LineNumberNode && return nothing
    ex isa Expr || return ex
    Meta.isexpr(ex, :block) || return ex
    args = filter(!isnothing, map(clean_expr, ex.args))
    return Expr(:block, args...)
end

@testset "Skip Lines" begin
    @testset "Parsing" begin
        function iseq(lr1::LineNumberRange, lr2::LineNumberRange)
            lr1.first == lr2.first && lr1.last == lr2.last
        end

        srcdir = abspath(@__DIR__,"../../src")
        f(path) = abspath(srcdir,path)
        mainfile = f("PlutoDevMacros.jl")

        p = "frompackage/helpers.jl"
        @test iseq(parse_skipline("$(f(p)):::3-5", mainfile), LineNumberRange(f(p),3,5))
        @test iseq(parse_skipline("$(f(p)):::3", mainfile), LineNumberRange(f(p),3,3))
        @test iseq(parse_skipline("$(f(p))", mainfile), LineNumberRange(f(p),1,10^6))
        @test iseq(parse_skipline("3-5", mainfile), LineNumberRange(mainfile,3,5))
        @test iseq(parse_skipline("5", mainfile), LineNumberRange(mainfile,5,5))
    end
    @testset "Outside Pluto" begin
        # Outside of Pluto the @skiplines macro is simply removed from the exp
        f(ex) = _combined(ex, inpackage_target, outpluto_caller, Main; macroname = "@frompackage") |> clean_expr
        ex = quote
            import DataFrames
            import >.HypertextLiteral
            @skiplines begin
                "frompackage/FromPackage.jl:8-100"
            end
        end
        out_ex = quote
            import HypertextLiteral
        end
        @test clean_expr(out_ex) == f(ex)
    end
    @testset "Inside Pluto" begin
        dict = get_package_data(outpackage_target)
        ex = quote
            import >.HypertextLiteral
            @skiplines begin
                "frompackage/FromPackage.jl:::8-100" # We are skipping from line 8, so we only load helpers.jl
            end
        end
        process_skiplines!(ex, dict)
        load_module_in_caller(dict, Main)
        _m = get_temp_module().PlutoDevMacros.FromPackage

        @test isdefined(_m, :_cell_data) # This is directly at the top of the module
        @test isdefined(_m, :macro_cell) # this variable is defined inside helpers.jl
        @test !isdefined(_m, :extract_file_ast) # This is defined inside code_parsing.jl, which should be skipped as it's line FromPackage.jl:8

        # Now we test providing lines as abs path
        dict = get_package_data(outpackage_target)
        fullpath = abspath(@__DIR__, "../../src/frompackage/FromPackage.jl")
        ex = quote
            import >.HypertextLiteral
            @skiplines begin
                $("$(fullpath):::9-100") # We are skipping from line 9
            end
        end
        process_skiplines!(ex, dict)
        load_module_in_caller(dict, Main)
        _m = get_temp_module().PlutoDevMacros.FromPackage

        @test isdefined(_m, :_cell_data) # This is directly at the top of the module
        @test isdefined(_m, :macro_cell) # this variable is defined inside helpers.jl
        @test isdefined(_m, :extract_file_ast) # This is defined inside code_parsing.jl
        @test !isdefined(_m, :load_module_in_caller) # This is defined inside loading.jl, which should be skipped as it's line FromPackage.jl:9
    end
end