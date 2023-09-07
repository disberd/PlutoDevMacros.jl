# Basics
plutodefault(::Union{InsidePluto, InsideAndOutsidePluto}) = true
plutodefault(::OutsidePluto) = false
plutodefault(::Type{D}) where D <: DisplayLocation = plutodefault(D())
plutodefault(@nospecialize(x::AbstractHTML)) = plutodefault(displaylocation(x))
# Methods that gets IO as first argument and a ShowWithPrintHTML as second.
# These are used to select the correct default for ShowWithPrintHTML
plutodefault(io::IO, @nospecialize(x::ShowWithPrintHTML{InsideAndOutsidePluto})) = is_inside_pluto(io)
plutodefault(::IO, @nospecialize(x::ShowWithPrintHTML)) = plutodefault(x)

displaylocation(d::DisplayLocation) = d
displaylocation(pluto::Bool) = pluto ? InsidePluto() : OutsidePluto()
displaylocation(::AbstractHTML{D}) where D <: DisplayLocation = D()
function displaylocation(s::Symbol)
    if s in (:Pluto, :pluto, :inside, :Inside)
        InsidePluto()
    elseif s in (:Normal, :normal, :outside, :Outside)
        OutsidePluto()
    elseif s in (:both, :Both, :insideandoutside, :InsideAndOutside)
        InsideAndOutsidePluto()
    else
        error("The provided symbol can not identify a display location.
Please use one of the following:
- :Pluto, :pluto or :inside, :Inside to display inside Pluto
- :Normal, :normal or :outside, :Outside to display outside Pluto
- :both, :Both, :InsideAndOutside or :insideandoutside to display both inside and outside Pluto
    ")
    end
end

children(cs::CombinedScripts) = cs.scripts
children(cn::CombinedNodes) = cn.nodes

# We create some common methods for the functions below
for F in (:haslisteners, :hasreturn, :returned_element, :script_id, :shouldskip)
    quote
        $F(l::DisplayLocation) = x -> $F(x, l)
        $F(ds::DualScript, l::SingleDisplayLocation) = $F(inner_node(ds, l))
    end |> eval
end

# shouldskip
shouldskip(s::AbstractString) = isempty(s)
shouldskip(p::ScriptContent) = shouldskip(p.content)
shouldskip(::Missing) = true
shouldskip(@nospecialize(x)) = false

shouldskip(x::PlutoScript) = shouldskip(x.body) && shouldskip(x.invalidation)
shouldskip(x::NormalScript) = shouldskip(x.body)
shouldskip(s::SingleScript, l::SingleDisplayLocation) = displaylocation(s) !== l
shouldskip(n::NonScript{<:SingleDisplayLocation}) = n.empty
# Dual Script/Node
function shouldskip(ds::Dual, ::InsideAndOutsidePluto) 
    i = inner_node(ds, InsidePluto())
    o = inner_node(ds, OutsidePluto())
    shouldskip(i) && shouldskip(o)
end
# Combined
shouldskip(c::Combined, l::DisplayLocation) = all(shouldskip(l), children(c))
shouldskip(s::ShowWithPrintHTML) = shouldskip(s.el)
# HypertextLiteral methods
shouldskip(x::Bypass) = shouldskip(x.content)
shouldskip(x::Render) = shouldskip(x.content)


add_pluto_compat(ns::NormalScript) =  ns.add_pluto_compat
add_pluto_compat(ds::DualScript) = add_pluto_compat(inner_node(ds, OutsidePluto()))
add_pluto_compat(v::Vector{DualScript}) = any(add_pluto_compat, v)
add_pluto_compat(cs::CombinedScripts) = add_pluto_compat(children(cs))

hasinvalidation(s::PlutoScript) = !shouldskip(s.invalidation)
hasinvalidation(ds::DualScript) = hasinvalidation(inner_node(ds, InsidePluto()))
hasinvalidation(v::Vector{DualScript}) = any(hasinvalidation, v)
hasinvalidation(cs::CombinedScripts) = hasinvalidation(children(cs))


haslisteners(::Missing) = false
haslisteners(s::ScriptContent) = s.addedEventListeners
haslisteners(s::SingleScript) = haslisteners(s.body)
haslisteners(cs::CombinedScripts, l::DisplayLocation) = any(haslisteners(l), children(cs))

hasreturn(s::SingleScript) = !shouldskip(s.returned_element)
hasreturn(ds::DualScript, ::InsideAndOutsidePluto) = hasreturn(inner_node(ds, InsidePluto())) || hasreturn(inner_node(ds, OutsidePluto()))
hasreturn(cs::CombinedScripts, l::DisplayLocation) = any(hasreturn(l), children(cs))
    
returned_element(s::SingleScript) = s.returned_element
# We check for duplicate returns in the constructor so we just get the return from the last script
returned_element(cs::CombinedScripts, l::DisplayLocation) = returned_element(last(children(cs)), l)

script_id(s::SingleScript) = coalesce(s.id, randstring(6))
function script_id(cs::CombinedScripts, l::SingleDisplayLocation)
    for ds in children(cs)
        s = inner_node(ds, l)
        s.id isa String && return s.id
    end
    return randstring(6)
end

inner_node(ds::Union{DualNode, DualScript}, ::InsidePluto) = ds.inside_pluto
inner_node(ds::Union{DualNode, DualScript}, ::OutsidePluto) = ds.outside_pluto

## Make Script ##
make_script(; type = :both, kwargs...) = make_script(displaylocation(type); kwargs...)
make_script(type::Symbol, args...; kwargs...) = make_script(displaylocation(type), args...; kwargs...)
# Basic location-based constructors
make_script(::InsideAndOutsidePluto; body = missing, invalidation = missing, inside = PlutoScript(body, invalidation), outside = NormalScript(body), kwargs...) = DualScript(inside, outside; kwargs...)
make_script(l::SingleDisplayLocation; kwargs...) = Script(l)(;kwargs...)
# Take a Script as Second argument
make_script(l::DisplayLocation, x::Union{SingleScript, DualScript}; kwargs...) = Script(l)(x; kwargs...)
# Other with no location
make_script(body; kwargs...) = make_script(;body, kwargs...)
make_script(i, o; kwargs...) = DualScript(i, o; kwargs...)
make_script(x::Script; kwargs...) = DualScript(x; kwargs...)
make_script(x::CombinedScripts) = x
make_script(v::Vector; kwargs...) = CombinedScripts(v; kwargs...)
# From ShowWithPrintHTML
make_script(@nospecialize(s::ShowWithPrintHTML{<:DisplayLocation, <:Script})) = s.el
make_script(@nospecialize(s::ShowWithPrintHTML)) = error("make_script on `ShowWithPrintHTML{T}` types is only valid if `T <: Script`")

## Make Node ##
# only kwargs method
make_node(; type = :both, kwargs...) = make_node(displaylocation(type); kwargs...)
# Symbol + args method
make_node(type::Symbol, args...; kwargs...) = make_node(displaylocation(type), args...; kwargs...)
# Methods with location as first argument and kwargs...
make_node(::InsideAndOutsidePluto; inside = "", outside = "") = DualNode(inside, outside)
make_node(l::SingleDisplayLocation; content = "") = Node(l)(content)
# Methods with location as first argument and args
make_node(::InsideAndOutsidePluto, inside, outside=inside) = DualNode(inside, outside)
make_node(l::SingleDisplayLocation, content, args...) = Node(l)(content, args...)
# Defaults without location
make_node(s::Script) = make_script(s)
make_node(n::Node) = DualNode(n)
make_node(n::CombinedNodes) = n
make_node(i, o) = DualNode(i, o)
make_node(content) = DualNode(content, content)
make_node(v::Vector) = CombinedNodes(v)

## Make HTML ##
make_html(x; kwargs...) = ShowWithPrintHTML(make_node(x); kwargs...)
make_html(@nospecialize(x::ShowWithPrintHTML); kwargs...) = ShowWithPrintHTML(x; kwargs...)


js_module_url(;tag = "expanded_Script") = "https://cdn.jsdelivr.net/gh/disberd/PlutoDevMacros@$tag/src/combine_htl/pluto_compat.js"