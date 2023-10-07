using Test
using PlutoDevMacros.PlutoCombineHTL.WithTypes
using PlutoDevMacros.PlutoCombineHTL: LOCAL_MODULE_URL
using PlutoDevMacros.HypertextLiteral
using PlutoDevMacros.PlutoCombineHTL: shouldskip, children, print_html,
script_id, inner_node, plutodefault, haslisteners, is_inside_pluto, hasreturn,
add_pluto_compat, hasinvalidation, displaylocation, returned_element, to_string,
formatted_contents
import PlutoDevMacros

import Pluto: update_save_run!, update_run!, WorkspaceManager, ClientSession,
ServerSession, Notebook, Cell, project_relative_path, SessionActions,
load_notebook, Configuration

@testset "make_script" begin
    ds = make_script("test")
    @test make_script(ds) === ds
    @test ds isa DualScript
    @test inner_node(ds, InsidePluto()).body == inner_node(ds, OutsidePluto()).body
    @test ds.inside_pluto.body.content === "test"
    ds = make_script("lol"; id = "asdfasdf")
    @test script_id(ds, InsidePluto()) === "asdfasdf"
    @test script_id(ds, OutsidePluto()) === "asdfasdf"
    ds2 = make_script(
        make_script(:pluto; body = "lol", id = "asdfasdf"),
        make_script(:normal; body = "lol", id = "different"),
    )
    @test ds.inside_pluto == ds2.inside_pluto
    @test ds.outside_pluto != ds2.outside_pluto

    @test shouldskip(ScriptContent()) === true
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
    @test shouldskip(ds, InsidePluto()) && shouldskip(ds, OutsidePluto()) # The script is empty because with `@htl` we only get the content between the first <script> tag.
    ds = make_script(;invalidation = "lol")
    @test shouldskip(ds, InsidePluto()) === false
    ds = make_script(;invalidation = @htl("<script>lol</script>"))
    @test !shouldskip(ds, InsidePluto())
    @test shouldskip(ds, OutsidePluto())
    @test shouldskip(ds.inside_pluto.body)
    @test ds.inside_pluto.invalidation.content === "lol"

    ps = PlutoScript("asd", "lol")
    @test PlutoScript(ps) === ps
    @test ps.body.content === "asd"
    @test ps.invalidation.content === "lol"
    @test shouldskip(ps, InsidePluto()) === false
    @test shouldskip(ps, OutsidePluto()) === true

    ns = NormalScript("lol")
    @test NormalScript(ns) === ns
    @test_throws "You can't construct" NormalScript(ps).body

    let ds = DualScript(ps)
        @test ds.inside_pluto === ps
        @test shouldskip(ds, OutsidePluto())
    end
    let ds = DualScript(ns)
        @test ds.outside_pluto === ns
        @test shouldskip(ds, InsidePluto())
    end

    cs = make_script([
        "asd",
        "lol",
    ])
    @test hasreturn(cs, InsideAndOutsidePluto()) === false
    @test hasinvalidation(cs) === false
    @test add_pluto_compat(cs) === true
    @test cs isa CombinedScripts
    @test CombinedScripts(cs) === cs
    @test make_script(cs) === cs
    @test children(CombinedScripts(ds)) == children(make_script([ds]))

    @test isempty(children(make_script([PlutoScript("asd")]))) === false
    @test isempty(children(make_script([NormalScript("asd")]))) === false

    make_script(ShowWithPrintHTML(cs)) === cs
    @test_throws "only valid if `T <: Script`" make_script(ShowWithPrintHTML("asd"))

    # Now we test that constructing a CombinedScripts with a return in not the last script or more returns errors.
    ds1 = make_script(PlutoScript(;returned_element = "asd"))
    ds2 = make_script("asd")

    @test_throws "More than one return" make_script([
        ds1,
        ds2,
        ds1,
    ])
    ds3 = make_script(PlutoScript(;returned_element = "asd"), NormalScript(;returned_element = "boh"))
    cs = make_script([
        ds2,
        ds3
        ]; returned_element = "lol"
    )
    @test returned_element(cs, InsidePluto()) === "lol"
    @test returned_element(cs, OutsidePluto()) === "lol"
    @test returned_element(ds3, InsidePluto()) === "asd"
    @test returned_element(ds3, OutsidePluto()) === "boh"

    @test make_script(:outside, ds2) === ds2.outside_pluto
    @test make_script(:Inside, ds2) === ds2.inside_pluto
end

@testset "make_node" begin
    dn = make_node()
    @test dn isa DualNode
    @test shouldskip(dn, InsidePluto()) && shouldskip(dn, OutsidePluto())

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
    @test make_node(cn) === cn

    @test PlutoNode(dn.inside_pluto) === dn.inside_pluto
    @test PlutoNode(@htl("")).empty === true

    nn = NormalNode("lol")
    dn = DualNode(nn)
    @test inner_node(dn, OutsidePluto()) === nn
    @test shouldskip(dn, InsidePluto())

    pn = PlutoNode("asd")
    dn = DualNode(pn)
    @test inner_node(dn, InsidePluto()) === pn
    @test shouldskip(dn, OutsidePluto())
    @test shouldskip(dn, InsidePluto()) === false


    dn = DualNode("asd", "lol")
    @test inner_node(dn, InsidePluto()) == pn
    @test inner_node(dn, OutsidePluto()) == nn

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
        pn = inner_node(dn, InsidePluto())
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

    @test make_node(:pluto, "asd") === PlutoNode("asd")
    @test make_node(:outside; content = "lol") === NormalNode("lol")
    @test make_node(:both, "asd", "lol") === DualNode("asd", "lol")
    @test make_node(:both, "asd", "lol") === make_node("asd", "lol")
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

    for l in (InsidePluto(), OutsidePluto())
        @test haslisteners(make_script("asd"), l) === false
    end
    s = "addScriptEventListeners('lol')"
    @test haslisteners(make_script(s, "asd"), InsidePluto()) === true
    @test haslisteners(make_script(s, "asd"), OutsidePluto()) === false
    @test haslisteners(missing) === false

    @test_throws "can not identify a display location" displaylocation(:not_exist)

    @test hasreturn(make_script("asd","lol"), InsidePluto()) === false
    @test hasreturn(make_script("asd","lol"), OutsidePluto()) === false
    ds = make_script(PlutoScript(; returned_element = "asd"),"lol")
    @test shouldskip(ds.inside_pluto) === false
    @test hasreturn(ds, InsidePluto()) === true
    @test hasreturn(ds, OutsidePluto()) === false
    @test hasreturn(make_script(NormalScript(;returned_element = "lol")), OutsidePluto()) === true
    @test hasreturn(make_script(NormalScript(;returned_element = "lol")), InsidePluto()) === false

    cs = make_script([
        "asd",
        "lol",
    ])
    cn = make_node([
        "asd",
        "lol",
    ])
    # Test getproperty
    @test cs.children === children(cs)
    @test cn.children === children(cn)

    # We test the abstract type constructors
    @test Script(InsideAndOutsidePluto()) === DualScript
    @test Script(InsidePluto()) === PlutoScript
    @test Script(OutsidePluto()) === NormalScript

    @test Node(InsideAndOutsidePluto()) === DualNode
    @test Node(InsidePluto()) === PlutoNode
    @test Node(OutsidePluto()) === NormalNode

    ps = PlutoScript("asd")
    ns = NormalScript("asd")
    ds = make_script(ps,ns)
    @test DualScript("asd") == ds
    @test_throws "can't construct" PlutoScript(ns)
    @test_throws "can't construct" NormalScript(ps)

    @test PlutoScript(ds) === ps
    @test NormalScript(ds) === ns

    for D in (InsidePluto, OutsidePluto, InsideAndOutsidePluto)
        @test plutodefault(D) === plutodefault(D())
        @test displaylocation(D()) === D()
    end
    io = IOBuffer()
    swp1 = ShowWithPrintHTML(make_node("asd"); display_type = :pluto)
    swp2 = ShowWithPrintHTML(make_node("asd"); display_type = :both) # :both is the default
    @test plutodefault(io, swp1) === plutodefault(swp1)
    @test plutodefault(io, swp2) === is_inside_pluto(io) !== plutodefault(swp1)
end

@testset "Show methods" begin
    ps = PlutoScript("asd")
    s = to_string(ps, MIME"text/javascript"())
    hs = to_string(ps, MIME"text/html"())
    @test contains(s, r"JS Listeners .* PlutoDevMacros") === false # No listeners helpers should be added
    @test contains(hs, r"<script id='\w+'") === true

    ds = DualScript("addScriptEventListeners('lol')", "magic"; id = "custom_id")
    s_in = to_string(ds, MIME"text/javascript"(); pluto = true)
    s_out = to_string(ds, MIME"text/javascript"(); pluto = false)
    @test contains(s_in, r"JS Listeners .* PlutoDevMacros") === true
    @test contains(s_out, r"JS Listeners .* PlutoDevMacros") === false # The listeners where only added in Pluto
    hs_in = to_string(ds, MIME"text/html"(); pluto = true)
    hs_out = to_string(ds, MIME"text/html"(); pluto = false)
    @test contains(hs_in, "<script id='custom_id'>") === true
    @test contains(hs_out, "<script id='custom_id'>") === true

    # Test error with print_script
    @test_throws "Interpolation of `Script` subtypes is not allowed" HypertextLiteral.print_script(IOBuffer(), ds)
    # Test error with show javascript ShowWithPrintHTML
    @test_throws "not supposed to be shown with mime 'text/javascript'" show(IOBuffer(), MIME"text/javascript"(), make_html("asd"))


    # Show outside Pluto
    # PlutoScript should be empty when shown out of Pluto
    n = PlutoScript("asd")
    s_in = to_string(n, MIME"text/html"(); pluto = true)
    s_out = to_string(n, MIME"text/html"(); pluto = false)
    @test contains(s_in, "script id='") === true
    @test isempty(s_out)
    @test contains(string(formatted_code(n)), "```html\n<script id='")

    # ScriptContent should just show as repr outside of Pluto
    sc = ScriptContent("asd")
    s_in = formatted_code(sc; pluto = true) |> string
    s_out = formatted_code(sc; pluto = false) |> string
    @test contains(s_in, "```js\nasd\n") # This is language-js
    @test s_out === s_in # The pluto kwarg is ignored for script content when shown to text/html

    # DualScript
    n = DualScript("asd", "lol"; id = "asd")
    s_in = to_string(n, MIME"text/html"(); pluto = true)
    s_out = to_string(n, MIME"text/html"(); pluto = false)
    @test contains(s_in, "script id='asd'") === true
    @test contains(s_out, "script id='asd'") === true
    @test contains(string(formatted_code(n; pluto=true)), "```html\n<script id='asd'")
    @test add_pluto_compat(n) === true
    @test contains(s_out, LOCAL_MODULE_URL[])
    @test contains(s_out, "async (currentScript) =>") # Opening async outside Pluto
    @test contains(s_out, "})(document.currentScript)") # Closing and calling async outside Pluto
    # Test when Pluto compat is false
    n = DualScript(n; add_pluto_compat = false)
    @test add_pluto_compat(n) === false
    s_out = to_string(n, MIME"text/html"(); pluto = false)
    @test contains(s_out, LOCAL_MODULE_URL[]) === false
    # Test the return
    n = DualScript(PlutoScript(;returned_element = "asd"), NormalScript(;returned_element = "lol"))
    s_in = to_string(n, MIME"text/html"(); pluto = true)
    s_out = to_string(n, MIME"text/html"(); pluto = false)
    @test contains(s_in, "return asd")
    @test contains(s_out, "currentScript.insertAdjacentElement('beforebegin', lol)")

    # NormalNode should be empty when shown out of Pluto
    n = NormalNode("asd")
    s_in = to_string(n, MIME"text/html"(); pluto = true)
    s_out = to_string(n, MIME"text/html"(); pluto = false)
    @test isempty(s_in) === true
    @test s_out === "asd\n"

    ds = DualScript("addScriptEventListeners(asd)", "lol"; id = "asd") # Forcing same id is necessary for equality
    for mime in (MIME"text/javascript"(), MIME"text/html"())
        @test formatted_code(mime)(ds) == formatted_code(ds, mime)
    end
    @test formatted_contents()(ds) == formatted_code(ds; only_contents = true)
    mime = MIME"text/html"()
    for l in (InsidePluto(), OutsidePluto())
        @test formatted_contents(l)(ds) != formatted_code(l; only_contents = false)
    end

    @test formatted_code(ds) == formatted_code(ds, MIME"text/html"())
    sc = ScriptContent("asd")
    @test formatted_code(sc) == formatted_code(sc, MIME"text/javascript"())
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