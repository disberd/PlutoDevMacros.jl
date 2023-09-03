# Basics
shouldskip(p::ScriptContent) = p.buffer.size === 0
shouldskip(::Missing) = true
shouldskip(x::Any) = false

shouldskip(x::PlutoScript; kwargs...) = shouldskip(x.body) && shouldskip(x.invalidation)
shouldskip(x::NormalScript; kwargs...) = shouldskip(x.body)
# Returning a Function
shouldskip(pluto::Bool) = x -> shouldskip(x; pluto)
# Dual Script
function shouldskip(ds::DualScript; pluto = true, both = false)
    if both
        shouldskip(ds.inside_pluto) && shouldskip(ds.outside_pluto)
    else
        shouldskip(inner_script(ds; pluto))
    end
end
shouldskip(ms::CombinedScripts; pluto = true) = all(shouldskip(pluto), ms.scripts)

show_as_module(ns::NormalScript) =  ns.show_as_module
show_as_module(ds::DualScript) = show_as_module(ds.outside_pluto)
show_as_module(cs::CombinedScripts) = any(show_as_module, cs.scripts)

haslisteners(s::ScriptContent) = s.addedEventListeners
haslisteners(s::SingleScript) = haslisteners(s.body)
# Returning a Function
haslisteners(pluto::Bool) = x -> haslisteners(x; pluto)
function haslisteners(ds::DualScript; pluto = true, both = false)
    if both
        haslisteners(ds.inside_pluto) && haslisteners(ds.outside_pluto)
    else
        haslisteners(inner_script(ds; pluto))
    end
end
haslisteners(ms::CombinedScripts; pluto) = any(haslisteners(pluto), ms.scripts)

script_id(s::SingleScript; kwargs...) = coalesce(s.id, randstring(6))
script_id(ds::DualScript; pluto = true) = script_id(inner_script(ds; pluto))
function script_id(cs::CombinedScripts; pluto = true)
    for ds in cs.scripts
        s = inner_script(ds; pluto)
        s.id isa String && return s.id
    end
    return randstring(6)
end

inner_script(ds::DualScript; pluto) = pluto ? ds.inside_pluto : ds.outside_pluto