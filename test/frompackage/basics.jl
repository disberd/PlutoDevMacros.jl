@testitem "Project/Manifest" begin
    include(joinpath(@__DIR__, "basics_helpers.jl"))
    tmpdir = mktempdir()
    # We test parsing the project of the test folder
    test_proj = Base.current_project(@__DIR__)
    pd = ProjectData(test_proj)
    @test pd.uuid |> isnothing
    @test pd.name |> isnothing
    @test pd.version |> isnothing

    @test "Revise" in keys(pd.deps)
    @test "TestItemRunner" in keys(pd.deps)

    # We test parsing of the Manifest
    md = generate_manifest_deps(test_proj)

    @test "Revise" in values(md)
    @test "TestItemRunner" in values(md)
    # Indirect Dependencies
    @test "CodeTracking" in values(md)
    @test "p7zip_jll" in values(md)

    # We try to copy the proj to a temp dir
    copied_proj = joinpath(tmpdir, basename(test_proj))
    cp(test_proj, copied_proj)
    # Without a manifest it will throw
    @test_throws "A manifest could not be found" generate_manifest_deps(copied_proj)
    instantiate_from_path(copied_proj)
    # After instantiating, the manifest is correctly parsed and equivalent to the original one
    md2 = generate_manifest_deps(copied_proj)
    @test md2 == md

    # We test that pointing to a folder without a project throws
    @test_throws "No project was found" FromPackageController(homedir(), @__MODULE__)
end

@testitem "extract_target_path" begin
    include(joinpath(@__DIR__, "basics_helpers.jl"))
    calling_file = @__FILE__
    m = @__MODULE__
    # Test that an invalid file throws
    @test_throws "does not seem to be a valid path" extract_target_path("asd", m; calling_file)
    # We test that it create abspath based on the dir of the calling file
    @test extract_target_path(basename(@__FILE__), m; calling_file) === @__FILE__
    # We test that this also works with an expression, if inside pluto
    basepath = basename(@__FILE__)
    @test extract_target_path(:basepath, m; calling_file, notebook_local=true) === @__FILE__
    # We test that also an expression works
    @test extract_target_path(:(basename($(@__FILE__))), m; calling_file, notebook_local=true) === @__FILE__
    # Test that this instead throws an error outside of pluto as at macro expansion we don't know symbols
    @test_throws "the path must be provided as" extract_target_path(:basepath, m; calling_file, notebook_local=false) === @__FILE__
end

@testitem "Outside Pluto" begin
    include(joinpath(@__DIR__, "basics_helpers.jl"))
    controller = FromPackageController(outpackage_target, @__MODULE__)
    valid(ex) = any(x -> Meta.isexpr(x, (:using, :import)), process_outside_pluto(controller, ex).args)
    invalid(ex) = !valid(ex)

    @test valid(:(import .ASD: lol))
    @test invalid(:(import .ASD: *))
    @test invalid(:(import TestPackage: lol)) # We only allow relative imports or imports from direct deps (always starting with >.)
    @test invalid(:(import *)) # Outside of pluto the catchall is removed

    @test valid(:(import >.BenchmarkTools)) # This is a direct dependency
    @test valid(:(import >.InteractiveUtils)) # This is a direct dependency and a stdlib
    @test invalid(:(import >.JSON)) # This is an indirect dependency, from HypertextLiteral
    @test invalid(:(import >.Statistics)) # This is an stdlib, but on in the proj
    @test invalid(:(import >.DataFrames)) # This is not a dependency

    f_compare(ex_out, ex_in) = compare_exprs(ex_out, process_outside_pluto(controller, ex_in))

    # We test some some specific imports
    ex_out = quote
        import BenchmarkTools as BT
    end
    ex_in = :(import >.BenchmarkTools as BT)
    @test f_compare(ex_out, ex_in)

    ex_out = quote
        using BenchmarkTools
        using Markdown
    end
    ex_in = :(using >.BenchmarkTools, >.Markdown)
    @test f_compare(ex_out, ex_in)

    # MacroTools is an indirect dep so it's discarded
    ex_out = quote
        using BenchmarkTools
    end
    ex_in = :(using >.BenchmarkTools, >.MacroTools)
    @test f_compare(ex_out, ex_in)

    ex_out = quote
        import BenchmarkTools as BT
        import .ASD as LOL
    end
    ex_in = :(import >.BenchmarkTools as BT, .ASD as LOL)
    @test f_compare(ex_out, ex_in)

    ex_out = quote
        using BenchmarkTools
        import .ASD: boh as lol
    end
    ex_in = quote
        using >.BenchmarkTools
        import .ASD: boh as lol
    end
    @test f_compare(ex_out, ex_in)

    ex_out = quote end
    ex_in = quote
        import *
        using >.CodeTracking # Interactive dependency
    end
    @test f_compare(ex_out, ex_in)
end

@testitem "Include using names" begin
    include(joinpath(@__DIR__, "basics_helpers.jl"))
    target_dir = abspath(@__DIR__, "../TestUsingNames/")
    instantiate_from_path(target_dir)
    caller_module = Core.eval(@__MODULE__, :(module $(gensym(:TestUsingNames)) end))
    function f(target; caller_module = caller_module)
        cell_id = Base.UUID(0)
        target_file = joinpath(target_dir, target * "#==#$cell_id")
        controller = FromPackageController(target_file, caller_module; cell_id)
        # Load the module
        load_module!(controller)
        return controller
    end
    function has_symbol(symbol, ex::Expr)
        imported_symbol(ia::ImportAs) = something(ia.as, last(ia.original))
        block = MacroTools.prettify(ex) |> MacroTools.block
        any(block.args) do arg
            any(iterate_imports(arg)) do mwn
                any(mwn.imported) do ia
                    imported_symbol(ia) === symbol
                end
            end
        end
    end
    # Test1 - test1.jl
    target = "src/test1.jl"
    controller = f(target)
    valid(ex) = any(x -> Meta.isexpr(x, (:using, :import)), process_outside_pluto(controller, ex).args)
    invalid(ex) = !valid(ex)
    # Test that this only works with catchall
    @test_throws "The provided input expression is not supported." process_input_expr(controller, :(@include_using import Downloads))
    # Test that even with the @exclude_using macro in front the expression is filtered out outside Pluo
    @test invalid(:(@exclude_using import *))
    # Test that the names are extracted correctly
    ex = process_input_expr(controller, :(import *))
    @test has_symbol(:domath, ex)
    ex = process_input_expr(controller, :(@exclude_using import *))
    @test !has_symbol(:domath, ex)

    # Test2 - test2.jl
    target = "src/test2.jl"
    controller = f(target)
    # Test that the names are extracted correctly
    ex = process_input_expr(controller, :(import *)) |> MacroTools.prettify
    @test has_symbol(:test1, ex) # test1 is exported by Module Test1
    @test has_symbol(:base64encode, ex) # test1 is exported by Module Base64
    ex = process_input_expr(controller, :(@exclude_using import *))
    @test !has_symbol(:test1, ex)
    @test !has_symbol(:base64encode, ex)

    # Test3 - test3.jl
    target = "src/test3.jl"
    controller = f(target)
    # Test that the names are extracted correctly, :top_level_func is exported by TestUsingNames
    ex = process_input_expr(controller, :(import *)) |> MacroTools.prettify
    @test has_symbol(:top_level_func, ex)
    ex = process_input_expr(controller, :(@exclude_using import *))
    @test !has_symbol(:top_level_func, ex)

    # Test from a file outside the package
    target = ""
    controller = f(target)
    # # Test that the names are extracted correctly, :base64encode is exported by Base64
    ex = process_input_expr(controller, :(import *)) |> MacroTools.prettify
    @test has_symbol(:base64encode, ex)
    ex = process_input_expr(controller, :(@exclude_using import *))
    @test !has_symbol(:base64encode, ex)

    # We test the new skipping capabilities of `filterednames`
    # We save the module associated to the controller
    controller = f("")
    target_mod = get_temp_module(controller)
    m = Module(gensym())
    # We create a function in the new module
    m.top_level_func = target_mod.top_level_func
    # We test that :top_level_func will not be imported because it's already in the caller module
    @test :top_level_func ∉ filterednames(f(""; caller_module = m), target_mod)
    # If we put a controller with the :top_level_func name inside the `imported_names` field as previous controller in the caller module, it will instead be imported as it was in the list of previously imported names
    push!(controller.imported_names, :top_level_func)
    Core.eval(m, :($PREV_CONTROLLER_NAME = $controller))
    @test :top_level_func ∈ filterednames(f(""; caller_module = m), target_mod)
end


# @testitem "Inside Pluto" begin

#     include(joinpath(@__DIR__, "basics_helpers.jl"))
#     # Import TestPath in this testitem
#     eval_with_load_path(:(import TestPackage: TestPackage, testmethod, Issue2), TestPackage_path)

#     @testset "Input Parsing" begin
#         @testset "target included in Package" begin
#             caller_module = Module(gensym())
#             dict = load_module_in_caller(inpackage_target, caller_module)
#             f(ex) = parseinput(deepcopy(ex), dict; caller_module)


#             parent_path = temp_module_path() |> collect
#             # FromDeps imports
#             ex = :(using >.BenchmarkTools)

#             LoadedModules = get_temp_module()._LoadedModules_
#             direct_dep_name = :BenchmarkTools
#             direct_deps_module = getfield(LoadedModules, direct_dep_name)

#             mod_path = Expr(:., vcat(parent_path, [:_LoadedModules_, direct_dep_name])...)
#             exported_names = map(x -> Expr(:., x), names(direct_deps_module))
#             expected = Expr(:import, Expr(:(:), mod_path, exported_names...))
#             @test expected == f(ex) # This should work as MacroTools is a deps of PlutoDevMacros

#             ex = :(using >.$(direct_dep_name): *)
#             @test_throws "catch-all" f(ex)

#             ex = :(using DataFrames)
#             @test_throws "import expression is not supported" f(ex)

#             # Test indirect import
#             indirect_id = Base.PkgId(Base.UUID("682c06a0-de6a-54ab-a142-c8b1cf79cde6"), "JSON")
#             # This will load Tricks inside _DepsImports_
#             _ex = f(:(using >.JSON))
#             # We now test that Tricks is loaded in DepsImports
#             @test LoadedModules.JSON === Base.maybe_root_module(indirect_id)

#             # We test that trying to load a package that is not a dependency throws an error saying so
#             @test_throws "The package DataFrames was not" f(:(using >.DataFrames))

#             # FromPackage imports
#             ex = :(import TestPackage)
#             expected = :(import $(parent_path...).TestPackage)
#             @test expected == f(ex) # This works because TestPackage is the name of the loaded package

#             ex = :(import PackageModule.SUBINIT)
#             expected = :(import $(parent_path...).TestPackage.SUBINIT)
#             @test expected == f(ex)

#             ex = :(using PackageModule.SUBINIT)
#             expected = :(import $(parent_path...).TestPackage.SUBINIT: SUBINIT) # This does not export anything
#             @test expected == f(ex)

#             # Relative imports
#             ex = :(import ..SUBINIT)
#             expected = :(import $(parent_path...).TestPackage.SUBINIT)
#             @test expected == f(ex) # This should work as Script is a valid sibling module of FromPackage

#             ex = :(import ..NonExistant)
#             @test_throws UndefVarError f(ex) # It can't find the module

#             # FromParent import
#             ex = :(@exclude_using import *)
#             expected = :(import $(parent_path...).TestPackage.Inner: Inner, testmethod)
#             @test expected == f(ex)

#             ex = :(@exclude_using import ParentModule: *)
#             @test expected == f(ex)

#             ex = :(import ParentModule: testmethod)
#             expected = :(import $(parent_path...).TestPackage.Inner: testmethod)
#             @test expected == f(ex)

#             ex = :(using ParentModule)
#             expected = :(import $(parent_path...).TestPackage.Inner: Inner)
#             @test expected == f(ex)
#         end
#         @testset "target not included in Package" begin
#             caller_module = Module(gensym())
#             dict = load_module_in_caller(inpluto_caller, caller_module)
#             f(ex) = parseinput(deepcopy(ex), dict; caller_module)
#             parent_path = temp_module_path() |> collect

#             ex = :(import PackageModule.Issue2)
#             expected = :(import $(parent_path...).TestPackage.Issue2)
#             @test expected == f(ex)

#             ex = :(@exclude_using import *)
#             expected = let _mod = get_temp_module().TestPackage
#                 imported_names = filterednames(_mod; all=true, imported=true, caller_module)
#                 importednames_exprs = map(n -> Expr(:., n), imported_names)
#                 modname_expr = Expr(:., vcat(parent_path, :TestPackage)...)
#                 reconstruct_import_expr(modname_expr, importednames_exprs)
#             end
#             @test expected == f(ex)

#             # FromParent import
#             ex = :(import ParentModule: *)
#             @test_throws "The current file was not found" f(ex)

#             ex = :(import ParentModule: hidden_toplevel_variable)
#             @test_throws "The current file was not found" f(ex)
#         end
#     end
# end

# # Reconstruct import without explicit names
# @test reconstruct_import_expr(Expr(:., :ParentModule, :TestPackage), []) == :(import ParentModule.TestPackage)

# # Clean the given expression by removing `nothing` and LineNumberNodes
# function clean_expr(ex)
#     ex = deepcopy(ex)
#     ex isa LineNumberNode && return nothing
#     ex isa Expr || return ex
#     Meta.isexpr(ex, :block) || return ex
#     args = filter(!isnothing, map(clean_expr, ex.args))
#     return Expr(:block, args...)
# end

# # This tests macroexpand and the multiple calls error
# @testset "Macroexpand" begin
#         id1 = "4dc0e7fa-6ddc-48ba-867d-8e74d7e6e373"
#         id2 = "5288e998-6b66-4d46-ab8d-4aa3159c0982"
#         file_path = joinpath(TestPackage_path, "test_macroexpand.jl")
#         inpluto_path(id) = join([file_path, "#==#", id])
#         # Create the fake module
#         m = Core.eval(Main, :(module $(gensym(:MacroExpand)) end))
#         # Load the macro in the module
#         m.var"@fromparent" = var"@fromparent"
#         # We simulate a call from cell 1 with the normal macro
#         fromparent_call_ex = Expr(:macrocall, Symbol("@fromparent"), LineNumberNode(36, Symbol(inpluto_path(id1))), :(import *))
#         # Run the macro
#         Core.eval(m, fromparent_call_ex);
#         # Check that the dummy variable generated by the macro is defined in the module
#         @test isdefined(m, FromPackage._id_name(id1))
#         # We try calling the macro from another cell and test that it throws
#         error_ex = Expr(:macrocall, Symbol("@fromparent"), LineNumberNode(41, Symbol(inpluto_path(id2))), :(import *))
#         macroexpand_ex = Expr(:macrocall, Symbol("@macroexpand"), LineNumberNode(41, Symbol(inpluto_path(id2))), error_ex)
#         # We test that this thorws a CapturedException
#         out = Core.eval(m, error_ex)
#         @test out isa CapturedException
#         # We test that Multiple Calls is in the error exception message
#         @test contains(out.ex.msg, "Multiple Calls")
#         if VERSION >= v"1.10" # This seems to not work in 1.9, not sure why now
#             # We try macroexpand, which should directly rethrow without the CaptureException
#             @test_throws "Multiple Calls" Core.eval(m, macroexpand_ex)
#         end
# end

# # This test is just for 100% coverage by checking that absolute path includes are respected
# mktempdir() do tmpdir
#     cd(tmpdir) do
#         included_file = joinpath(tmpdir, "random_include.jl") |> abspath
#         open(included_file, "w") do io
#             write(io, "a = 15")
#         end
#         # We generate a dummy package folder
#         Pkg.generate("RandomPackage")
#         pkgdir = joinpath(tmpdir, "RandomPackage")
#         open(joinpath(pkgdir, "src", "RandomPackage.jl"), "w") do io
#             println(io, "module RandomPackage")
#             println(io, "include(raw\"$included_file\")")
#             println(io, "end")
#         end
#         dict = get_package_data(pkgdir)
#         load_module_in_caller(dict, Main)
#         m = get_target_module(dict)
#         @test isdefined(m, :a)
#     end
# end