shouldskip(p::HTLScriptPart) = p.buffer.size === 0
shouldskip(::Missing) = true
shouldskip(x::Any) = false
shouldskip(x::HTLScript) = shouldskip(x.body) && shouldskip(x.invalidation)

haslisteners(s::HTLScriptPart) = s.addedEventListeners
haslisteners(s::HTLScript) = haslisteners(s.body)
haslisteners(ms::HTLMultiScript) = any(haslisteners, ms.scripts)

"""
	combine_scripts(v; id = missing)
Creates a single [`HTLScript`](@ref) element by combining multiple inputs contained in the iterable object `v`.

The generated combined output has its fields `body` and `invalidation` that are the concatenation of all the `body` and `invalidation` fields (respectively) of the elements of `v`. Elements of `v` that are not of type `HTLScript` are converted (using the `HTLScript` constructor) prior to concatenation.

When a custom `id` is provided as kwarg, the final script id will be `id`, otherwise it is computed depending on the `id` fields of the elements of `v`.

See also: [`HTLScript`](@ref)

# Examples:
The following code:
```julia
let
	a = HTLScript("console.log('asd')")
	b = HTLScript(@htl("<script>console.log('boh')</script>"), "console.log('lol')")
	script = combine_scripts([a,b];id='test')
	out = @htl("\$script")
end
```
is equivalent to writing directly
```julia
@htl \"\"\"
<script id='test'>
	console.log('asd')
	console.log('boh')
	
	invalidation.then(() => {
		console.log('lol')
	})
</script>
\"\"\"
```
"""
function combine_scripts(v; id = missing)
	out = _convert_combine(v;id)
end


const ValidInputs = Union{HTLScript, AbstractString, IOBuffer, HTLScriptPart}

_convert_combine(h; id) = _combine(Iterators.map(x -> x isa HTLScript ? x : HTLScript(x), h); id)
_convert_combine(h::Vararg{ValidInputs};id) = _convert_combine(h;id)

_combine(h::Vararg{HTLScript};id) = _combine(h;id)

function _combine(h;id)
	body = IOBuffer()
	invalidation = IOBuffer()
	_id = missing
	f(x, y) = if !shouldskip(y)
		if x.size !== 0 
			write(x, '\n')
		end
		buf = y.buffer
		seekstart(buf)
		write(x, buf)
	end
	for el in h
		@assert el isa HTLScript "Only element of type HTLScript can be combined together"
		f(body, el.body)
		f(invalidation, el.invalidation)
		if ismissing(id)
			!ismissing(_id) && !ismissing(el.id) && _id != el.id && error("You cannot combine HTLScript elements with different assigned ids")
			_id = coalesce(_id, el.id)
		end
	end
	HTLScript(;
		body = shouldskip(body) ? missing : HTLScriptPart(body),
		invalidation = shouldskip(invalidation) ? missing : HTLScriptPart(invalidation),
		id = ismissing(id) ? _id : id
	)	
end

## Make Script ##
function make_script(h::HTLScript, addListeners::Bool = h.body.addedEventListeners; pluto = true)
	id = coalesce(h.id, h._id)
    s = combine_scripts([
        addListeners ? _events_listeners_preamble : HTLScript("")
        h
        addListeners ? _events_listeners_postamble : HTLScript("")
    ])
	contents = [
		s.body
		pluto && !shouldskip(s.invalidation) ?
		HTLScriptPart(@htl("""
		<script>
			invalidation.then(() => {	
				$(s.invalidation)
			})
		</script>
		""")) : HTLScriptPart("")
	]
	@htl("""
		<script id='$id'>
			$(contents)
		</script>
	""")
end