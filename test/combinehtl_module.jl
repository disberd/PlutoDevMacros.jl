using Test
using PlutoDevMacros.HypertextLiteral
using PlutoDevMacros.PlutoCombineHTL.WithTypes
using PlutoDevMacros.PlutoCombineHTL: shouldskip, children, print_html, script_id, inner_node, ShowWithPrintHTML, plutodefault
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
    ds = make_script("lol"; id = "asdfasdf")
    @test script_id(ds; pluto=true) === "asdfasdf"
    @test script_id(ds; pluto=false) === "asdfasdf"
    ds2 = DualScript("lol"; id = script_id(ds))
    @test inner_node(ds; pluto=true) == inner_node(ds2; pluto = true)
    @test inner_node(ds; pluto=false) != inner_node(ds2; pluto = false) # The normal in ds2 has missing id

    @test shouldskip(ScriptContent())
    @test ScriptContent(nothing) === missing
    @test ScriptContent(missing) === missing
    sc = ScriptContent("addScriptEventListeners('lol')")
    @test sc.addedEventListeners === true
    sc = ScriptContent("console.log('lol')")
    @test sc.addedEventListeners === false


    @test_logs (:warn, r"No <script> tag was found") make_script(;invalidation = @htl("lol"))
    @test_logs (:warn, r"More than one <script> tag was found") make_script(@htl("""
    <script id='lol'>asd</script>
    <script class='asd'></script>
    """))
    @test_logs (:warn, r"The provided input also contained contents outside") make_script(@htl("""
    <script id='lol'>asd</script>
    magic
    """))
    @test_throws "No closing </script>" make_script(@htl("<script>asd"))
    ds = make_script(;invalidation = @htl("lol"))
    @test shouldskip(ds;both=true) # The script is empty because with `@htl` we only get the content between the first <script> tag.
    ds = make_script(;invalidation = "lol")
    @test shouldskip(ds;both=true) === false
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

    make_script(ShowWithPrintHTML(cs)) === cs
    @test_throws "only valid if `T <: Script`" make_script(ShowWithPrintHTML("asd"))
end

@testset "make_node" begin
    dn = make_node()
    @test dn isa DualNode
    @test shouldskip(dn) === true

    s = make_script("asd")
    dn = make_node("asd")
    @test make_node(s) === s
    @test dn != s
    @test make_node(dn) === dn
    cn = make_node([
        "asd",
        "",
        "lol"
    ])
    @test cn isa CombinedNodes
    @test length(children(cn)) === 2 # We skipped the second empty element

    @test PlutoNode(dn.inside_pluto) === dn.inside_pluto

    nn = NormalNode("lol")
    dn = DualNode(nn)
    @test inner_node(dn; pluto=false) === nn
    @test shouldskip(inner_node(dn; pluto = true))

    pn = PlutoNode("asd")
    dn = DualNode(pn)
    @test inner_node(dn; pluto=true) === pn
    @test shouldskip(inner_node(dn; pluto = false))


    dn = DualNode("asd", "lol")
    @test inner_node(dn; pluto=true) == pn
    @test inner_node(dn; pluto=false) == nn

    function compare_content(n1, n2; pluto = missing)
        io1 = IOBuffer()
        io2 = IOBuffer()
        print_html(io1, n1; pluto = pluto === missing ? plutodefault(n1) : pluto)
        print_html(io2, n2; pluto = pluto === missing ? plutodefault(n2) : pluto)
        String(take!(io1)) == String(take!(io2))
    end
    
    @test compare_content(NormalNode("asd"), NormalNode(ShowWithPrintHTML("asd")))
    @test compare_content(PlutoNode("asd"), NormalNode("asd"))
    @test compare_content(PlutoNode("asd"), NormalNode("asd"); pluto = true) === false
    @test compare_content(PlutoNode("asd"), NormalNode("asd"); pluto = false) === false

    function test_stripping(inp, expected)
        dn = make_node(inp)
        pn = inner_node(dn; pluto=true)
        io = IOBuffer()
        print_html(io, pn)
        s = String(take!(io))
        s === expected
    end

    @test test_stripping("\n\n  a\n\n","  a\n") # Only leading newlines (\r or \n) are removed
    @test test_stripping("\n\na  \n\n","a\n") # Only leading newlines (\r or \n) are removed
    @test test_stripping(@htl("lol"), "lol\n")
    @test test_stripping(@htl("
    lol
    
    "), "    lol\n") # lol is right offset by 4 spaces
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