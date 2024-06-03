import PlutoDevMacros.FromPackage: process_outside_pluto!, load_module_in_caller, modname_path, parseinput, get_package_data, @fromparent, _combined, process_skiplines!, get_temp_module, LineNumberRange, parse_skipline, extract_module_expression, _inrange, filterednames, reconstruct_import_expr, extract_import_args, extract_raw_str, @frompackage, update_stored_module, get_target_module, frompackage, FromPackage, can_import_in_caller, overwrite_imported_symbols
using Test

import Pkg

# FromPackage.default_pkg_io[] = Pkg.stderr_f()

TestPackage_path = normpath(@__DIR__, "../TestPackage")
# The LOAD_PATH hack is required because if we add ./TestPackage as a test dependency we get the error in https://github.com/JuliaLang/Pkg.jl/issues/1585
push!(LOAD_PATH, TestPackage_path)
import TestPackage
import TestPackage: testmethod
import TestPackage.Issue2
pop!(LOAD_PATH)

# We point at the helpers file inside the TestPackage module, we stuff up to the first include
outpackage_target = TestPackage_path
inpackage_target = joinpath(outpackage_target, "src/inner_notebook2.jl")
# We simulate a caller from a notebook by appending a fake cell-id
outpluto_caller = joinpath(TestPackage_path, "src")
inpluto_caller = join([outpluto_caller, "#==#", "00000000-0000-0000-0000-000000000000"])

current_project = Base.active_project()
try
    @testset "Errors" begin
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
                write(
                    io,
                    """
          module INCOMPLETE
          a = 1
          """
                )
            end
            if VERSION < v"1.10"
                @test_throws "did not generate a valid `module`" extract_module_expression(path)
            else
                @test_throws Base.Meta.ParseError extract_module_expression(path)
            end
        end
    end
finally
    Pkg.activate(current_project)
end

# Test the macroexpand part
@test nothing === Core.eval(@__MODULE__, :(@macroexpand @frompackage $(inpackage_target) import *))
@test_throws "No project was found" Core.eval(@__MODULE__, :(@macroexpand @frompackage "/asd/lol" import TOML))
@testset "raw_str" begin
    str, valid = extract_raw_str("asd")
    @test valid
    @test str == "asd"
    str, valid = extract_raw_str(:(raw"asd\lol"))
    @test valid
    @test str == "asd\\lol"
    @test_throws "Only `AbstractStrings`" Core.eval(Main, :(@frompackage 3 + 2 import *))
    cd(dirname(inpackage_target)) do
        @test Core.eval(@__MODULE__, :(@frompackage raw".." import *)) === nothing
    end
end

@testset "Outside Pluto" begin
    dict = get_package_data(outpackage_target)
    valid(ex) = nothing !== process_outside_pluto!(deepcopy(ex), dict)
    invalid(ex) = nothing === process_outside_pluto!(deepcopy(ex), dict)

    @test valid(:(import .ASD: lol))
    @test invalid(:(import .ASD: *))
    @test invalid(:(import TestPackage: lol)) # PlutoDevMacros is the name of the inpackage_target package, we don't allow that
    @test invalid(:(import *)) # Outside of pluto the catchall is removed

    @test valid(:(import >.BenchmarkTools)) # This is a direct dependency
    @test valid(:(import >.InteractiveUtils)) # This is a direct dependency and a stdlib
    @test invalid(:(import >.JSON)) # This is an indirect dependency, from HypertextLiteral
    @test invalid(:(import >.Statistics)) # This is an stdlib, but on in the proj
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

@testset "Include using names" begin
    target_dir = abspath(@__DIR__, "../TestUsingNames/")
    caller_module = Core.eval(Main, :(module $(gensym(:TestUsingNames)) end))
    function f(target)
        target_file = joinpath(target_dir, target * "#==#00000000-0000-0000-0000-000000000000")
        dict = get_package_data(target_file)
        # Load the module
        load_module_in_caller(dict, caller_module)
        return dict
    end
    function has_symbol(symbol, ex::Expr)
        _, args = extract_import_args(ex)
        for ex in args
            name = ex.args[1]
            name === symbol && return true
        end
        return false
    end
    # Test1 - test1.jl
    target = "src/test1.jl"
    dict = f(target)
    invalid(ex) = nothing === process_outside_pluto!(deepcopy(ex), dict)
    # Test that this only works with catchall
    @test_throws "You can only use @exclude_using" parseinput(:(@exclude_using import Downloads), dict; caller_module)
    # Test that it throws with ill-formed expression
    @test_throws "You can only use @exclude_using" parseinput(:(@exclude_using), dict; caller_module)
    # Test the deprecation warning
    @test_logs (:warn, r"Use `@exclude_using`") parseinput(:(@include_using import *), dict; caller_module)
    # Test unsupported expression
    @test_throws "The provided input expression is not supported" parseinput(:(@asd import *), dict; caller_module)

    # Test that even with the @exclude_using macro in front the expression is filtered out outside Pluo
    @test invalid(:(@exclude_using import *))
    # Test that the names are extracted correctly
    ex = parseinput(:(import *), dict; caller_module)
    @test has_symbol(:domath, ex)
    ex = parseinput(:(@exclude_using import *), dict; caller_module)
    @test !has_symbol(:domath, ex)

    # Test2 - test2.jl
    target = "src/test2.jl"
    dict = f(target)
    # Test that the names are extracted correctly
    ex = parseinput(:(import *), dict; caller_module)
    @test has_symbol(:test1, ex) # test1 is exported by Module Test1
    @test has_symbol(:base64encode, ex) # test1 is exported by Module Base64
    ex = parseinput(:(@exclude_using import *), dict; caller_module)
    @test !has_symbol(:test1, ex)
    @test !has_symbol(:base64encode, ex)

    # Test3 - test3.jl
    target = "src/test3.jl"
    dict = f(target)
    # Test that the names are extracted correctly, :top_level_func is exported by TestUsingNames
    ex = parseinput(:(import *), dict; caller_module)
    @test has_symbol(:top_level_func, ex)
    ex = parseinput(:(@exclude_using import *), dict; caller_module)
    @test !has_symbol(:top_level_func, ex)

    # Test from a file outside the package
    target = ""
    dict = f(target)
    # Test that the names are extracted correctly, :base64encode is exported by Base64
    ex = parseinput(:(import *), dict; caller_module)
    @test has_symbol(:base64encode, ex)
    ex = parseinput(:(@exclude_using import *), dict; caller_module)
    @test !has_symbol(:base64encode, ex)

    # We test the new skipping capabilities of `filterednames`
    # We save the loaded module in the created_modules variable
    target_mod = update_stored_module(dict)
    m = Module(gensym())
    m.top_level_func = target_mod.top_level_func
    @test :top_level_func ∉ filterednames(target_mod; caller_module =  m)
    # We test that it will be imported in a new module without clash
    @test :top_level_func ∈ filterednames(target_mod; caller_module =  Module(gensym()))
    # We test that it will also be imported with clash if the name was explicitly imported before. It will still throw as there is already a variable with that name defined in the caller but the filterins should not exclude it
    overwrite_imported_symbols([:top_level_func])
    @test :top_level_func ∈ filterednames(target_mod; caller_module = m)

    # We test the warning if we are trying to overwrite something we didn't put
    overwrite_imported_symbols([])
    @test_logs (:warn, r"is already present in the caller module") filterednames(target_mod; caller_module = m)
end


@testset "Inside Pluto" begin
    @testset "Input Parsing" begin
        @testset "target included in Package" begin
            caller_module = Module(gensym())
            dict = load_module_in_caller(inpackage_target, caller_module)
            f(ex) = parseinput(deepcopy(ex), dict; caller_module)


            parent_path = modname_path(get_temp_module())
            # FromDeps imports
            ex = :(using >.BenchmarkTools)

            LoadedModules = get_temp_module()._LoadedModules_
            direct_dep_name = :BenchmarkTools
            direct_deps_module = getfield(LoadedModules, direct_dep_name)

            mod_path = Expr(:., vcat(parent_path, [:_LoadedModules_, direct_dep_name])...)
            exported_names = map(x -> Expr(:., x), names(direct_deps_module))
            expected = Expr(:import, Expr(:(:), mod_path, exported_names...))
            @test expected == f(ex) # This should work as MacroTools is a deps of PlutoDevMacros

            ex = :(using >.$(direct_dep_name): *)
            @test_throws "catch-all" f(ex)

            ex = :(using DataFrames)
            @test_throws "import expression is not supported" f(ex)

            # Test indirect import
            indirect_id = Base.PkgId(Base.UUID("682c06a0-de6a-54ab-a142-c8b1cf79cde6"), "JSON")
            # This will load Tricks inside _DepsImports_
            _ex = f(:(using >.JSON))
            # We now test that Tricks is loaded in DepsImports
            @test LoadedModules.JSON === Base.maybe_root_module(indirect_id)

            # We test that trying to load a package that is not a dependency throws an error saying so
            @test_throws "The package DataFrames was not" f(:(using >.DataFrames))

            # FromPackage imports
            ex = :(import TestPackage)
            expected = :(import $(parent_path...).TestPackage)
            @test expected == f(ex) # This works because TestPackage is the name of the loaded package

            ex = :(import PackageModule.SUBINIT)
            expected = :(import $(parent_path...).TestPackage.SUBINIT)
            @test expected == f(ex)

            ex = :(using PackageModule.SUBINIT)
            expected = :(import $(parent_path...).TestPackage.SUBINIT: SUBINIT) # This does not export anything
            @test expected == f(ex)

            # Relative imports
            ex = :(import ..SUBINIT)
            expected = :(import $(parent_path...).TestPackage.SUBINIT)
            @test expected == f(ex) # This should work as Script is a valid sibling module of FromPackage

            ex = :(import ..NonExistant)
            @test_throws UndefVarError f(ex) # It can't find the module

            # FromParent import
            ex = :(@exclude_using import *)
            expected = :(import $(parent_path...).TestPackage.Inner: Inner, testmethod)
            @test expected == f(ex)

            ex = :(@exclude_using import ParentModule: *)
            @test expected == f(ex)

            ex = :(import ParentModule: testmethod)
            expected = :(import $(parent_path...).TestPackage.Inner: testmethod)
            @test expected == f(ex)

            ex = :(using ParentModule)
            expected = :(import $(parent_path...).TestPackage.Inner: Inner)
            @test expected == f(ex)
        end
        @testset "target not included in Package" begin
            caller_module = Module(gensym())
            dict = load_module_in_caller(inpluto_caller, caller_module)
            f(ex) = parseinput(deepcopy(ex), dict; caller_module)
            parent_path = modname_path(get_temp_module())

            ex = :(import PackageModule.Issue2)
            expected = :(import $(parent_path...).TestPackage.Issue2)
            @test expected == f(ex)

            ex = :(@exclude_using import *)
            expected = let _mod = get_temp_module().TestPackage
                imported_names = filterednames(_mod; all=true, imported=true, caller_module)
                importednames_exprs = map(n -> Expr(:., n), imported_names)
                modname_expr = Expr(:., vcat(parent_path, :TestPackage)...)
                reconstruct_import_expr(modname_expr, importednames_exprs)
            end
            @test expected == f(ex)

            # FromParent import
            ex = :(import ParentModule: *)
            @test_throws "The current file was not found" f(ex)

            ex = :(import ParentModule: hidden_toplevel_variable)
            @test_throws "The current file was not found" f(ex)
        end
    end
end

# Reconstruct import without explicit names
@test reconstruct_import_expr(Expr(:., :ParentModule, :TestPackage), []) == :(import ParentModule.TestPackage)

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
    # Some coverage
    ln = LineNumberNode(3, Symbol(@__FILE__))
    lnr = LineNumberRange(ln)
    @test lnr.first == lnr.last
    @test _inrange(ln, ln)
    @testset "Parsing" begin
        function iseq(lr1::LineNumberRange, lr2::LineNumberRange)
            lr1.first == lr2.first && lr1.last == lr2.last
        end

        srcdir = abspath(@__DIR__, "../../src")
        f(path) = abspath(srcdir, path)
        mainfile = f("PlutoDevMacros.jl")

        p = "frompackage/helpers.jl"
        @test iseq(parse_skipline("$(f(p)):::3-5", mainfile), LineNumberRange(f(p), 3, 5))
        @test iseq(parse_skipline("$(f(p)):::3", mainfile), LineNumberRange(f(p), 3, 3))
        @test iseq(parse_skipline("$(f(p))", mainfile), LineNumberRange(f(p), 1, 10^6))
        @test iseq(parse_skipline("3-5", mainfile), LineNumberRange(mainfile, 3, 5))
        @test iseq(parse_skipline("5", mainfile), LineNumberRange(mainfile, 5, 5))
    end
    @testset "Outside Pluto" begin
        # Outside of Pluto the @skiplines macro is simply removed from the exp
        f(ex) = _combined(ex, inpackage_target, outpluto_caller, Main; macroname="@frompackage") |> clean_expr
        ex = quote
            import DataFrames
            import >.BenchmarkTools
            @skiplines begin
                "TestPacakge.jl:8-100"
            end
        end
        out_ex = quote
            import BenchmarkTools
        end
        @test clean_expr(out_ex) == f(ex)
    end
    @testset "Inside Pluto" begin
        dict = get_package_data(outpackage_target)
        ex = quote
            import >.BenchmarkTools
            @skiplines begin
                "TestPackage.jl:::21-100" # We are skipping from line 21, so we only load up to the notebook1.jl
            end
        end
        process_skiplines!(ex, dict)
        load_module_in_caller(dict, Main)
        _m = get_temp_module().TestPackage

        @test isdefined(_m, :hidden_toplevel_variable) # This is directly at the top of the module
        @test isdefined(_m, :testmethod) # this variable is defined inside notebook1.jl
        @test !isdefined(_m, :Inner) # This is defined after line 20

        # Now we test providing lines as abs path
        dict = get_package_data(outpackage_target)
        fullpath = abspath(TestPackage_path, "src/TestPackage.jl")
        skip_str = "$(fullpath):::26-100"
        ex = quote
            import >.HypertextLiteral
            @skiplines $(skip_str) # We are skipping from line 26
        end
        process_skiplines!(ex, dict)
        load_module_in_caller(dict, Main)
        _m = get_temp_module().TestPackage

        @test isdefined(_m, :hidden_toplevel_variable) # This is directly at the top of the module
        @test isdefined(_m, :testmethod) # this variable is defined inside notebook1.jl
        @test isdefined(_m, :Inner) # This is defined at line 22-25
        @test !isdefined(_m, :Issue2) # This is defined at lines 27-30, which should be skipped
    end
end

# This tests macroexpand and the multiple calls error
@testset "Macroexpand" begin
        id1 = "4dc0e7fa-6ddc-48ba-867d-8e74d7e6e373"
        id2 = "5288e998-6b66-4d46-ab8d-4aa3159c0982"
        file_path = joinpath(TestPackage_path, "test_macroexpand.jl")
        inpluto_path(id) = join([file_path, "#==#", id])
        # Create the fake module
        m = Core.eval(Main, :(module $(gensym(:MacroExpand)) end))
        # Load the macro in the module
        m.var"@fromparent" = var"@fromparent"
        # We simulate a call from cell 1 with the normal macro
        fromparent_call_ex = Expr(:macrocall, Symbol("@fromparent"), LineNumberNode(36, Symbol(inpluto_path(id1))), :(import *))
        # Run the macro
        Core.eval(m, fromparent_call_ex);
        # Check that the dummy variable generated by the macro is defined in the module
        @test isdefined(m, FromPackage._id_name(id1))
        # We try calling the macro from another cell and test that it throws
        error_ex = Expr(:macrocall, Symbol("@fromparent"), LineNumberNode(41, Symbol(inpluto_path(id2))), :(import *))
        macroexpand_ex = Expr(:macrocall, Symbol("@macroexpand"), LineNumberNode(41, Symbol(inpluto_path(id2))), error_ex)
        # We test that this thorws a CapturedException
        out = Core.eval(m, error_ex)
        @test out isa CapturedException
        # We test that Multiple Calls is in the error exception message
        @test contains(out.ex.msg, "Multiple Calls")
        if VERSION >= v"1.10" # This seems to not work in 1.9, not sure why now
            # We try macroexpand, which should directly rethrow without the CaptureException
            @test_throws "Multiple Calls" Core.eval(m, macroexpand_ex)
        end
end

# This test is just for 100% coverage by checking that absolute path includes are respected
mktempdir() do tmpdir
    cd(tmpdir) do
        included_file = joinpath(tmpdir, "random_include.jl") |> abspath
        open(included_file, "w") do io
            write(io, "a = 15")
        end
        # We generate a dummy package folder
        Pkg.generate("RandomPackage")
        pkgdir = joinpath(tmpdir, "RandomPackage")
        open(joinpath(pkgdir, "src", "RandomPackage.jl"), "w") do io
            println(io, "module RandomPackage")
            println(io, "include(raw\"$included_file\")")
            println(io, "end")
        end
        dict = get_package_data(pkgdir)
        load_module_in_caller(dict, Main)
        m = get_target_module(dict)
        @test isdefined(m, :a)
    end
end