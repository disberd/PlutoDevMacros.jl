module TestPackage

import PlutoDevMacros
export toplevel_variable

const TEST_INIT = Ref{Int}(0)

toplevel_variable = 15
hidden_toplevel_variable = 10

module SUBINIT
    const TEST_SUBINIT = Ref{Int}(0)
    function __init__()
        TEST_SUBINIT[] = 15
    end
end

using .TestPackage.SUBINIT: TEST_SUBINIT

include("notebook1.jl")

module Inner
    include("inner_notebook1.jl")
    include("inner_notebook2.jl")
end

module Issue2
    include("test_macro1.jl") # Defines NotThatCoolStruct at line 28
    include("test_macro2.jl") # Defines GreatStructure
end

module SpecificImport
    include("specific_imports1.jl") # Defines inner_variable1
    include("specific_imports2.jl")
end

module ImportAsStatements
    include("import_as.jl")
end

module PrettyPrint
    function some_function end
    struct SomeType end
end

module MapExpr
    import PlutoDevMacros.FromPackage: RemoveThisExpr
    import PlutoDevMacros.FromPackage.MacroTools: postwalk
    # This apply mapexpr to all the args of an expression and remove all of the arguments that are of type RemoveThisExpr after mapping.
    # If not args are left, simply returns RemoveThisExpr, otherwise reconstruct the resulting expression
    function map_and_clean_expr(ex::Expr, mapexpr = identity)
        @nospecialize
        new_args = map(mapexpr, ex.args)
        filter!(x -> !isa(x, RemoveThisExpr), new_args)
        # If we still have args, or if the head is a block, we return the modified haed. We have this special case for a block for tests mostly
        !isempty(new_args) | (ex.head === :block) && return Expr(ex.head, new_args...)
        # If we get here we just return RemoveThisExpr
        return RemoveThisExpr()
    end
    function mapexpr(ex)
        ex isa Expr || return ex
        Meta.isexpr(ex, :(=)) || return map_and_clean_expr(ex)
        args = deepcopy(ex.args)
        varname = first(args)
        varname === :var_to_delete && return RemoveThisExpr()
        if varname === :should_be_100
            args[2] = 100
            return Expr(:(=), args...)
        end
        return ex
    end
    include(ex -> postwalk(mapexpr, ex), "test_mapexpr.jl")
end

function __init__()
    TEST_INIT[] = 5
end

end # module TestPackage
