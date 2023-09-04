# Basics
plutodefault(n::Node{<:InsidePluto}) = true
plutodefault(n::Node{<:OutsidePluto}) = false
plutodefault(n::Node{<:InsideAndOutsidePluto}) = true

children(cs::CombinedScripts) = cs.scripts
children(cn::CombinedNodes) = cn.nodes


shouldskip(p::ScriptContent) = isempty(p.content)
shouldskip(::Missing) = true
shouldskip(x::Any) = false

shouldskip(x::PlutoScript; kwargs...) = shouldskip(x.body) && shouldskip(x.invalidation)
shouldskip(x::NormalScript; kwargs...) = shouldskip(x.body)
shouldskip(n::Node{<:SingleDisplayLocation}) = n.empty
# Returning a Function
shouldskip(pluto::Bool) = x -> shouldskip(x; pluto)
# Dual Script/Node
function shouldskip(ds::Union{DualNode, DualScript}; pluto = plutodefault(ds), both = false)
    if both
        shouldskip(ds.inside_pluto) && shouldskip(ds.outside_pluto)
    else
        shouldskip(inner_node(ds; pluto))
    end
end
shouldskip(c::Union{CombinedNodes, CombinedScripts}; pluto = plutodefault(c)) = all(shouldskip(pluto), children(c))


show_as_module(ns::NormalScript) =  ns.show_as_module
show_as_module(ds::DualScript) = show_as_module(ds.outside_pluto)
show_as_module(cs::CombinedScripts) = any(show_as_module, children(cs))

haslisteners(s::ScriptContent) = s.addedEventListeners
haslisteners(s::SingleScript) = haslisteners(s.body)
# Returning a Function
haslisteners(pluto::Bool) = x -> haslisteners(x; pluto)
function haslisteners(ds::DualScript; pluto = plutodefault(ds), both = false)
    if both
        haslisteners(ds.inside_pluto) && haslisteners(ds.outside_pluto)
    else
        haslisteners(inner_node(ds; pluto))
    end
end
haslisteners(ms::CombinedScripts; pluto) = any(haslisteners(pluto), children(ms))

script_id(s::SingleScript; kwargs...) = coalesce(s.id, randstring(6))
script_id(ds::DualScript; pluto = plutodefault(ds)) = script_id(inner_node(ds; pluto))
function script_id(cs::CombinedScripts; pluto = plutodefault(cs))
    for ds in children(cs)
        s = inner_node(ds; pluto)
        s.id isa String && return s.id
    end
    return randstring(6)
end

inner_node(ds::Union{DualNode, DualScript}; pluto) = pluto ? ds.inside_pluto : ds.outside_pluto

## Make Script ##
make_script(;body = "", invalidation = "", inside = PlutoScript(body, invalidation), outside = "") = DualScript(inside, outside)
make_script(x::Union{SingleScript, DualScript}) = DualScript(x)
make_script(x::CombinedScripts) = x
make_script(body; kwargs...) = make_script(;body, kwargs...)
make_script(v::Vector) = CombinedScripts(v)

## Make Node ##
make_node(;inside = "", outside = "") = DualNode(inside, outside)
make_node(s::Script) = make_script(s)
make_node(n::Node) = n
make_node(i, o = "") = DualNode(i, o)
make_node(v::Vector) = CombinedNodes(v)

make_html(x) = ShowWithPrintHTML(make_node(x))