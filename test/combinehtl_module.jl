using Test
using PlutoDevMacros.PlutoCombineHTL.WithTypes
using PlutoDevMacros.HypertextLiteral
using PlutoDevMacros.PlutoCombineHTL: shouldskip, children, print_html,
script_id, inner_node, ShowWithPrintHTML, plutodefault, haslisteners, is_inside_pluto, hasreturn
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

    @test isempty(children(make_script([PlutoScript("asd")]))) === false
    @test isempty(children(make_script([NormalScript("asd")]))) === false

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
    @test PlutoNode(@htl("")).empty === true

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
    
    @test compare_content(make_node(HTML("asd")), make_node("asd"))
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

    
    @test isempty(children(make_node([PlutoNode("asd")]))) === false
    @test isempty(children(make_node([NormalNode("asd")]))) === false
end

@testset "Other Helpers" begin
    @test shouldskip(3) === false
    s = make_html(PlutoScript())
    @test s isa ShowWithPrintHTML
    @test make_html(s) === s
    for T in (HypertextLiteral.Render, HypertextLiteral.Bypass)
        @test shouldskip(T("lol")) === false
        @test shouldskip(T("")) === true
    end

    @test haslisteners(make_script("asd")) === false
    s = "addScriptEventListeners('lol')"
    @test haslisteners(make_script(s, "asd"); pluto = true) === true
    @test haslisteners(make_script(s, "asd"); pluto = false) === false

    @test hasreturn(make_script("asd","lol"); pluto = true) === false
    @test hasreturn(make_script("asd","lol"); pluto = false) === false
    @test hasreturn(make_script("return asd","lol"); pluto = true) === true
    @test hasreturn(make_script("return asd","lol"); pluto = false) === false
    @test hasreturn(make_script("asd","return lol"); pluto = false) === true

    @test hasreturn(true)(make_script([
        "lol"
        "return asd"
    ]))

    @test_throws "not in the last" hasreturn(true)(make_script([
        "return asd"
        "lol"
    ]))
    @test_throws "multiple scripts with a return" hasreturn(true)(make_script([
        "return asd"
        "return lol"
    ]))
end

@testset "Show methods" begin
    function to_string(n, mime; pluto = missing, useshow = false)
        io = IOBuffer()
        f = if mime isa MIME"text/javascript"
            x -> show(io, mime, x; pluto = pluto === missing ? plutodefault(x) : pluto)
        else
            if useshow
                x -> show(io, mime, x; pluto = pluto === missing ? is_inside_pluto(x) : pluto)
            else
                x -> print_html(io, x; pluto = pluto === missing ? plutodefault(x) : pluto)
            end
        end
        f(n)
        String(take!(io))
    end

    ps = PlutoScript("asd")
    s = to_string(ps, MIME"text/javascript"())
    hs = to_string(ps, MIME"text/html"())
    @test contains(s, "AUTOMATICALLY ADDED") === false
    @test contains(hs, r"<script id='\w+'") === true

    ds = DualScript("addScriptEventListeners('lol')", "magic"; id = "custom_id")
    s_in = to_string(ds, MIME"text/javascript"(); pluto = true)
    s_out = to_string(ds, MIME"text/javascript"(); pluto = false)
    @test contains(s_in, "AUTOMATICALLY ADDED") === true
    @test contains(s_out, "AUTOMATICALLY ADDED") === false
    hs_in = to_string(ds, MIME"text/html"(); pluto = true)
    hs_out = to_string(ds, MIME"text/html"(); pluto = false)
    @test contains(hs_in, "<script id='custom_id'>") === true
    @test contains(hs_out, "<script type='module' id='custom_id'>") === true

    # Test error with print_script
    @test_throws "Interpolation of `Script` subtypes is not allowed" HypertextLiteral.print_script(IOBuffer(), ds)

    # Show outside Pluto
    # PlutoScript should be empty when shown out of Pluto
    n = PlutoScript("asd")
    s_in = to_string(n, MIME"text/html"(); pluto = true, useshow = true)
    s_out = to_string(n, MIME"text/html"(); pluto = false, useshow = true)
    @test contains(s_in, r"markdown.*code class.*language-html.*script id")
    @test contains(s_in, "script id") === true
    @test isempty(s_out)

    # ScriptContent should just show as repr outside of Pluto
    n = ScriptContent("asd")
    s_in = to_string(n, MIME"text/html"(); pluto = true, useshow = true)
    s_out = to_string(n, MIME"text/html"(); pluto = false, useshow = true)
    @test contains(s_in, r"markdown.*code class.*language-js") # This is language-js
    @test contains(s_in, "script id") === false
    @test s_out === repr(n)

    # ScriptContent should just show as repr outside of Pluto
    n = DualScript("asd", "lol"; id = "asd")
    s_in = to_string(n, MIME"text/html"(); pluto = true, useshow = true)
    s_out = to_string(n, MIME"text/html"(); pluto = false, useshow = true)
    @test contains(s_in, r"markdown.*code class.*language-html")
    @test contains(s_in, "script id") === true
    @test s_out === "<script type='module' id='asd'>\nlol\n</script>\n"

    # PlutoScript should be empty when shown out of Pluto
    n = NormalNode("asd")
    s_in = to_string(n, MIME"text/html"(); pluto = true, useshow = true)
    s_out = to_string(n, MIME"text/html"(); pluto = false, useshow = true)
    @test contains(s_in, r"markdown.*code class.*language-html")
    @test contains(s_in, "script id") === false
    @test s_out === "asd\n"
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