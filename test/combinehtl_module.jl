using Test
using PlutoDevMacros.HypertextLiteral
using PlutoDevMacros.PlutoCombineHTL.WithTypes
using PlutoDevMacros.PlutoCombineHTL: shouldskip, children, print_html
import PlutoDevMacros

import Pluto: update_save_run!, update_run!, WorkspaceManager, ClientSession,
ServerSession, Notebook, Cell, project_relative_path, SessionActions,
load_notebook, Configuration

@testset "make_script" begin
    ds = make_script("test")
    @test make_script(ds) === ds
    @test ds isa DualScript
    @test shouldskip(ds;pluto = false)
    @test ds.inside_pluto.body.content === "test"

    @test shouldskip(ScriptContent())
    @test ScriptContent(nothing) === missing
    @test ScriptContent(missing) === missing

    ds = make_script(;invalidation = @htl("lol"))
    @test shouldskip(ds;both=true) # The script is empty because with `@htl` we only get the content between the first <script> tag.
    ds = make_script(;invalidation = @htl("<script>lol</script>"))
    @test !shouldskip(ds;both=true)
    @test shouldskip(ds;pluto = false)
    @test shouldskip(ds.inside_pluto.body)
    @test ds.inside_pluto.invalidation.content === "lol"

    ps = PlutoScript("asd", "lol")
    @test PlutoScript(ps) === ps
    @test ps.body.content === "asd"
    @test ps.invalidation.content === "lol"

    ns = NormalScript("lol")
    @test NormalScript(ns) === ns
    @test NormalScript(ps).body === ps.body

    DualScript(ps).inside_pluto === ps
    DualScript(ns).outside_pluto === ns

    cs = make_script([
        "asd",
        "lol",
    ])
    @test cs isa CombinedScripts
    @test CombinedScripts(cs) === cs
    @test make_script(cs) === cs
    @test children(CombinedScripts(ds)) == children(make_script([ds]))
end

function noerror(cell; verbose=true)
    if cell.errored && verbose
        @show cell.output.body
    end
    !cell.errored
end


options = Configuration.from_flat_kwargs(; disable_writing_notebook_files=true)
srcdir = normpath(@__DIR__, "./notebooks")
eval_in_nb(sn, expr) = WorkspaceManager.eval_fetch_in_workspace(sn, expr)

# @testset "Script test notebook" begin
#     ss = ServerSession(; options)
#     path = joinpath(srcdir, "Script.jl")
#     nb = SessionActions.open(ss, path; run_async=false)
#     for cell in nb.cells
#         @test noerror(cell)
#     end
#     SessionActions.shutdown(ss, nb)
# end