@testitem "Project/Manifest" begin
    include(joinpath(@__DIR__, "basics_helpers.jl"))
    # We test parsing the project of the TestUsingNames folder
    target_dir = abspath(@__DIR__, "../TestUsingNames/")
    # We delete the manifest if it exists
    delete_manifest(target_dir)
    # We test that by default it throws since there is no manifest
    controller = FromPackageController(target_dir, @__MODULE__; cell_id = Base.UUID(0))
    @test controller.options.manifest ∉ (:instantiate, :resolve)
    pd = controller.project
    @test pd.uuid === Base.UUID("ad5af708-d1e5-4d28-9e91-6798178ddbab")
    @test pd.name === "TestUsingNames"
    @test pd.version === v"0.1.0"

    @test "Example" in keys(pd.deps)
    @test "Revise" in keys(pd.deps)

    # We test parsing of the Manifest
    @test_throws "A manifest could not be found" populate_manifest_deps!(controller)
    controller.options.verbose = true
    controller.options.manifest = :resolve
    populate_manifest_deps!(controller)
    @test isfile(joinpath(target_dir, "Manifest.toml"))
    delete_manifest(target_dir)
    @test !isfile(joinpath(target_dir, "Manifest.toml"))
    controller.options.manifest = :instantiate
    populate_manifest_deps!(controller)
    @test isfile(joinpath(target_dir, "Manifest.toml"))

    md = controller.manifest_deps

    @test "Example" in values(md)
    @test "InteractiveUtils" in values(md)
    # Indirect Dependencies
    @test "CodeTracking" in values(md)

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
    function f(target; caller_module=caller_module)
        cell_id = Base.UUID(0)
        target_file = joinpath(target_dir, target * "#==#$cell_id")
        controller = FromPackageController(target_file, caller_module; cell_id)
        # Load the module
        load_module!(controller)
        return controller
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
    Core.eval(m, :(top_level_func = $(target_mod.top_level_func)))
    # We test that :top_level_func will not be imported because it's already in the caller module
    @test :top_level_func ∉ filterednames(f(""; caller_module=m), target_mod)
    # If we put a controller with the :top_level_func name inside the `imported_names` field as previous controller in the caller module, it will instead be imported as it was in the list of previously imported names
    push!(controller.imported_names, :top_level_func)
    Core.eval(m, :($PREV_CONTROLLER_NAME = $controller))
    @test :top_level_func ∈ filterednames(f(""; caller_module=m), target_mod)
end


@testitem "target in package" begin
    include(joinpath(@__DIR__, "basics_helpers.jl"))
    cell_id = Base.UUID(0)
    caller_module = Core.eval(@__MODULE__, :(module $(gensym(:InPackage)) end))
    controller = FromPackageController(inpackage_target, caller_module; cell_id)
    populate_manifest_deps!(controller)
    load_module!(controller)
    f(ex; alias=false) = MacroTools.prettify(process_input_expr(controller, ex); alias)


    # FromDeps imports
    ex = :(using >.BenchmarkTools)
    expected_parent_path = fullname(get_loaded_modules_mod())
    mwn = ModuleWithNames(f(ex))
    # We remove the last name which is the unique name
    modname_path = copy(mwn.modname.original)
    unique_name = pop!(modname_path)
    @test compare_modname(modname_path, expected_parent_path)
    @test unique_name === unique_module_name(Base.UUID("6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"), "BenchmarkTools")



    ex = :(using >.BenchmarkTools: *)
    @test_throws "catch-all" f(ex)

    ex = :(using DataFrames)
    @test_throws "The provided import statement is not a valid input" f(ex)

    # Test indirect import
    ex = f(:(using >.JSON))
    # We now test that Tricks is loaded in DepsImports
    @test has_symbol(:json, ex)

    # We test that trying to load a package that is not a dependency throws an error saying so
    @test_throws "The package with name DataFrames could not" f(:(using >.DataFrames))

    # FromPackage imports
    ex = :(import TestPackage)
    mwn = f(ex) |> ModuleWithNames
    # This works because TestPackage is the name of the loaded package
    @test compare_modname(mwn, fullname(get_temp_module(controller)))

    ex = :(import PackageModule.SUBINIT)
    mwn = f(ex) |> ModuleWithNames
    @test compare_modname(mwn, [fullname(get_temp_module(controller))..., :SUBINIT])

    out_ex = f(:(using PackageModule.SUBINIT))
    @test has_symbol(:SUBINIT, out_ex)

    # # Relative imports
    ex = f(:(import ..SUBINIT))
    mwn = ex |> ModuleWithNames
    @test compare_modname(mwn, [fullname(get_temp_module(controller))..., :SUBINIT])

    ex = :(import ..NonExistant)
    @test_throws "The module `NonExistant` could not be found" f(ex) # It can't find the module

    # FromParent import
    ex = :(@exclude_using import *)
    parent_path = fullname(get_temp_module(controller))
    expected = :(import $(parent_path...).Inner: Inner, testmethod)
    @test expected == f(ex)

    ex = :(@exclude_using import ParentModule: *)
    @test expected == f(ex)

    ex = :(import ParentModule: testmethod)
    expected = :(import $(parent_path...).Inner: testmethod)
    @test expected == f(ex)

    ex = :(using ParentModule)
    expected = :(import $(parent_path...).Inner: Inner)
    @test expected == f(ex)
end
@testitem "target not in package" begin
    include(joinpath(@__DIR__, "basics_helpers.jl"))
    cell_id = Base.UUID(0)
    caller_module = Core.eval(@__MODULE__, :(module $(gensym(:NotInPackage)) end))
    controller = FromPackageController(outpackage_target, caller_module; cell_id)
    load_module!(controller)
    f(ex; alias=false) = MacroTools.prettify(process_input_expr(controller, ex); alias)

    parent_path = fullname(get_temp_module(controller))

    ex = :(import PackageModule.Issue2)
    expected = :(import $(parent_path...).Issue2: Issue2)
    @test expected == f(ex)

    ex = f(:(@exclude_using import *))
    mwn = ModuleWithNames(ex)
    # Test that the module path is correct
    @test compare_modname(mwn, parent_path)
    # We test that non-exported names of TestPackage are in the explicitly imported names
    @test has_symbol(:hidden_toplevel_variable, ex)
    # We test that the names coming from `using` statements within the target package are not re-exported
    @test !has_symbol(:TEST_SUBINIT, ex)

    # We now include usings
    ex = f(:(import *))
    # We also test that also symbols visible in the target package due to `using` statements are re-exported
    @test has_symbol(:TEST_SUBINIT, ex)
    @test has_symbol(Symbol("@code_lowered"), ex)
    @test has_symbol(Symbol("@md_str"), ex)


    # We test that you can't call the parent module or relative imports when not included
    ex = :(import ParentModule: *)
    @test_throws "You can't import from the Parent Module" f(ex)

    ex = :(import ..LOL)
    @test_throws "You can't use relative imports" f(ex)
end

@testitem "Errors" begin
    include(joinpath(@__DIR__, "basics_helpers.jl"))
    cell_id = Base.UUID(0)
    caller_module = Core.eval(@__MODULE__, :(module $(gensym(:NotInPackage)) end))
    controller = FromPackageController(outpackage_target, caller_module; cell_id)
    load_module!(controller)

    # Test that an error is thrown if the dependency could not be found in deps or weakdeps
    @test_throws "could not be found as a dependency (or weak dependency)" get_dep_from_loaded_modules(controller, :DataFrames; allow_weakdeps = true)

    @test_throws "is not valid for constructing ImportAs" ImportAs(:(1+1))

    @test_throws "or a begin-end block of import statements" extract_input_args(:(1+1))
end

@testitem "Options Parsing" begin
    include(joinpath(@__DIR__, "basics_helpers.jl"))
    # Parse options
    macro dummy(args...)
        caller_module = __module__
        calling_file = @__FILE__
        target = outpackage_target
        target_file = extract_target_path(target, caller_module; calling_file, notebook_local=false)
        p = FromPackageController(target_file, caller_module; cell_id = Base.UUID(0))
        ex = :(import *)
        parse_options!(p, ex, args)
        :($p)
    end
    # Test correct handling
    default = FromPackageOptions()
    p = @dummy verbose = true rootmodule = true manifest = :instantiate
    @test p.options.verbose === true !== default.verbose
    @test p.options.rootmodule === true !== default.rootmodule
    @test p.options.manifest === :instantiate !== default.manifest
    # Manifest with name directly
    p = @dummy manifest = resolve
    @test p.options.manifest === :resolve !== default.manifest
    #
    @test_throws "are not in a supported format" eval(:(@dummy verboses = true))
    @test_throws "are not in a supported format" eval(:(@dummy verbose = 3))
    @test_throws "are not in a supported format" eval(:(@dummy manifest = true))
end