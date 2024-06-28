import PlutoDevMacros.FromPackage: FromPackage, @fromparent, load_module!, FromPackageController, generate_manifest_deps, ProjectData, @frompackage, extract_target_path, is_notebook_local, process_outside_pluto, process_input_expr, iterate_imports, ImportAs, get_temp_module, PREV_CONTROLLER_NAME, filterednames, ModuleWithNames, JustModules, get_loaded_modules_mod, unique_module_name, extract_nested_module, get_dep_from_loaded_modules, extract_input_args
import MacroTools

function compare_exprs(ex1, ex2)
    ex1 = MacroTools.prettify(ex1)
    ex2 = MacroTools.prettify(ex2)
    equal = ex1 == ex2
    equal || @error "The expression are not equivalent" ex1 ex2
end

# Function to extract the name of the imported symbol
imported_symbol(ia::ImportAs) = something(ia.as, last(ia.original))
# Function to check if an expression contain an explict imported symbol with the provided name
function has_symbol(symbol, ex::Expr)
    block = MacroTools.prettify(ex) |> MacroTools.block
    any(block.args) do arg
        any(iterate_imports(arg)) do mwn
            any(mwn.imported) do ia
                imported_symbol(ia) === symbol
            end
        end
    end
end

function compare_modname(m1, m2)
    Tuple(m1) == Tuple(m2)
end
function compare_modname(mwn::ModuleWithNames, m2; skip_last = 0)
    m1 = mwn.modname.original[1:end-skip_last]
    compare_modname(m1, m2)
end

include(joinpath(@__DIR__, "helpers.jl"))
TestPackage_path = normpath(@__DIR__, "../TestPackage")

dev_package_in_proj(TestPackage_path)
# instantiate_from_path(TestPackage_path)
# Also instantiate the test env
instantiate_from_path(TestPackage_path |> dirname)

# We point at the helpers file inside the TestPackage module, we stuff up to the first include
outpackage_target = TestPackage_path
inpackage_target = joinpath(outpackage_target, "src/inner_notebook2.jl")
outpluto_caller = joinpath(TestPackage_path, "src")
# We simulate a caller from a notebook by appending a fake cell-id
cell_id = Base.UUID(0)
inpluto_caller = join([outpluto_caller, "#==#", string(cell_id)])