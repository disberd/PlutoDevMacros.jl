
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
	scripts = if ismissing(id) || isnothing(id)
		collect(h)
	else
		s1, rest = Iterators.peel(h)
		[
			HTLScript(s1; id),
			rest...
		]
	end
	return HTLMultiScript(scripts)
end