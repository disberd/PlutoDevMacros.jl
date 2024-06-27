import PlutoDevMacros.FromPackage: FromPackage, @fromparent, load_module!, FromPackageController, generate_manifest_deps, ProjectData, @frompackage, extract_target_path, is_notebook_local, process_outside_pluto
import MacroTools

function compare_exprs(ex1, ex2)
    ex1 = MacroTools.prettify(ex1)
    ex2 = MacroTools.prettify(ex2)
    equal = ex1 == ex2
    equal || @error "The expression are not equivalent" ex1 ex2
end

include(joinpath(@__DIR__, "helpers.jl"))
TestPackage_path = normpath(@__DIR__, "../TestPackage")

# We point at the helpers file inside the TestPackage module, we stuff up to the first include
outpackage_target = TestPackage_path
inpackage_target = joinpath(outpackage_target, "src/inner_notebook2.jl")
outpluto_caller = joinpath(TestPackage_path, "src")
# We simulate a caller from a notebook by appending a fake cell-id
inpluto_caller = join([outpluto_caller, "#==#", "00000000-0000-0000-0000-000000000000"])