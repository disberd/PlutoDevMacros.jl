import PlutoDevMacros
using MacroTools: postwalk
import PlutoDevMacros.FromParent: process_ast, extract_module_expression, skip_basic_exprs, get_parent_data, fromparent, @fromparent
target = "/home/amengali/Repos/github/mine/PlutoDevMacros/notebooks/fromparent.jl#==#8ebd991e-e4b1-478c-9648-9c164954f167"


dict = get_parent_data(target)
dict["Expr to Remove"] = [
    LineNumberNode(12, Symbol("/home/amengali/Repos/github/mine/PlutoDevMacros/src/PlutoDevMacros.jl")),
]
dict["Stop After Line"] = LineNumberNode(60, Symbol("/home/amengali/Repos/github/mine/PlutoDevMacros/notebooks/basics.jl"))

# @run process_ast(:(module DIO
# include("/home/amengali/.julia/pluto_notebooks/gesure.jl")
# end), dict)

@macroexpand @fromparent begin
    import .ASD: *
end

PlutoDevMacros.FromParent.fromparent_module
PlutoDevMacros.FromParent.fromparent_module[].PlutoRunner |> names
_mod = @__MODULE__
fromparent(:(begin
import ..Script
end), target, _mod)
generated_mod = Main.var"##fromparent#292".PlutoDevMacros
generated_mod.PlutoRunner
@run fromparent(:(import module), target, _mod)
ex, data = extract_module_expression(dict, _mod);
ex
data["Last Parsed Line"]

check_args(ex1, ex2) = map(ex1.args, ex2.args) do a,b
    a == b
end

ex2, found = FromParent.process_ast(deepcopy(ex), dict)
a, b = ex.args[end], ex2.args[end]
a,b = Base.remove_linenums!.((a,b))
a,b = a.args[end], b.args[end]
check_args(a,b)

ex = :(function asd(;params=(;)) end)
dump(Base.remove_linenums!(ex))
ex2, found = process_ast(deepcopy(ex), dict)
dump(ex2)


PlutoDevMacros.FromParent.process_outside_pluto(quote
import module
import *
import .Parent
import .Parent: *
import .Parent: a, b
end)