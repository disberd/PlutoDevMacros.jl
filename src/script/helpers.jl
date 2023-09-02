shouldskip(p::HTLScriptPart) = p.buffer.size === 0
shouldskip(::Missing) = true
shouldskip(x::Any) = false
shouldskip(x::HTLScript) = shouldskip(x.body) && shouldskip(x.invalidation)
shouldskip(ms::HTLMultiScript) = isempty(ms.scripts)

haslisteners(s::HTLScriptPart) = s.addedEventListeners
haslisteners(s::HTLScript) = haslisteners(s.body)
haslisteners(ms::HTLMultiScript) = any(haslisteners, ms.scripts)

script_id(s::HTLScript) = coalesce(s.id, randstring(6))
function script_id(v::Vector{HTLScript})
    for s in v
        s.id isa String && return s.id
    end
    return randstring(6)
end
script_id(ms::HTLMultiScript) = script_id(ms.scripts)

make_sc