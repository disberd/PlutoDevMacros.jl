module Script

using Random
using HypertextLiteral
using Markdown

export HTLScriptPart, HTLBypass, HTLScript, combine_scripts, make_script

# HTLScriptPart #

## Definition - HTLScriptPart ##

	"""
	struct HTLScriptPart
This struct is a simple wrapper around an `IOBuffer` and is intended to provide
pretty printing of script contents and custom interpolation inside the
`<script>` tags of the `@htl` macro.

It is intended for use within Pluto notebooks to simply decouple parts of a
javascript script into separate variables and still be able to interpolate them
within <script> tags to compose a bigger script.

Compared to simply using strings wrapped in `HypertextLiteral.JavaScript`, this
gives the opportunity to exploit the experimental htmlmixed synthax highlighting
of code inside cells by also accepting `HypertextLiteral.Result` objects during
construction.

The struct can be initialized as follows:
```julia
wrapper = HTLScriptPart(@htl(\"\"\"
<script>
code...
</script>
\"\"\"))
```
When interpolating `wrapper` above inside another `@htl` macro as `@htl
"<script>\$wrapper</script>"` it would be as equivalent to directly writing
`@htl "<script>code...</script>` inside the script. This is clearly only
beneficial if multiple `HTLScriptPart` variables are interpolated inside a
single <script> block.

On top of the interpolation, an object of type `HTLScriptPart` will show its
contents as a formatted javascript code markdown element when shown in Pluto. 

The constructor also accepts either a `String` or `IOBuffer` object for its
initialization instead of a `HypertextLiteral.Result` one.

See also: [`HTLScript`](@ref), [`HTLBypass`](@ref)

Examples:

```julia
let
	asd = HTLScriptPart(@htl \"\"\"
	<script>
		let out = html`<div></div>`
		console.log('first script')
	</script>
	\"\"\")
	lol = HTLScriptPart(@htl \"\"\"
	<script>
		let a = Math.random()
		out.innerText = a
		console.log('second script')
		return out
	</script>
	\"\"\")
	@htl \"\"\"
	<script>
		\$([
			asd,
			lol
		])
	</script>
	\"\"\"
end
```
"""
struct HTLScriptPart
	buffer::IOBuffer
	addedEventListeners::Bool
	show_outside_pluto::Bool
	function HTLScriptPart(buf::IOBuffer, show_outside_pluto::Bool)
		# We check if the code contains calls to the addScriptEventListeners
		checkbuf = IOBuffer()
		seekstart(buf)
		Base.readuntil_vector!(buf, codeunits("addScriptEventListeners("), false, checkbuf)
		# If the previous line didn't find any call to addScriptEventListeners, the size of trash and buf will be the same
		addedEventListeners = !(buf.size === checkbuf.size)
		new(buf, addedEventListeners)
	end		
end
HTLScriptPart(buf::IOBuffer; show_outside_pluto::Bool = true) = HTLScriptPart(buf, show_outside_pluto)
function HTLScriptPart(r::HypertextLiteral.Result; kwargs...)
	buf = IOBuffer()
	temp = IOBuffer()
	trash = IOBuffer()
	show(temp, r)
	seekstart(temp)
	# This is adapted from readuntil in
	# https://github.com/JuliaLang/julia/blob/f70b5e4767809c7dbc4c6c082aed67a2af4447c2/base/io.jl#L923-L943
	Base.readuntil_vector!(temp, codeunits("<script>"), false, trash)
	Base.readuntil_vector!(temp, codeunits("</script>"), false, buf)
	HTLScriptPart(buf; kwargs...)
end
function HTLScriptPart(s::AbstractString; kwargs...)
	buf = IOBuffer()
	write(buf, s)
	HTLScriptPart(buf; kwargs...)
end

shouldskip(p::HTLScriptPart) = p.buffer.size === 0
shouldskip(::Missing) = true
shouldskip(x::Any) = false

## Show methods - HTLScriptPart ##

# This is to have a custom printing when inside a <script> tag within @htl 
function Base.show(io::IO, ::MIME"text/javascript", s::HTLScriptPart)
	buf = s.buffer
	seekstart(buf)
	write(io, buf)
end

function HypertextLiteral.print_script(io::IO, v::Union{AbstractVector{HTLScriptPart}, NTuple{N,HTLScriptPart} where N})
	foreach(v) do s
		shouldskip(s) && return
		show(io, MIME"text/javascript"(), s)
	end
end

# Show the formatted code in markdown as output
function Base.show(io::IO, mime::MIME"text/html", s::HTLScriptPart)
	buf = s.buffer
	seekstart(buf)
	codestring = strip(read(buf, String), '\n')
	show(io, mime, Markdown.MD(Markdown.Code("js", codestring)))
end
function Base.show(io::IO, mime::MIME"text/html", v::Union{AbstractVector{HTLScriptPart}, NTuple{N,HTLScriptPart} where N})
	codestring = ""
	foreach(v) do s
		buf = s.buffer
		seekstart(buf)
		codestring *= read(buf, String)
	end
	show(io, mime, Markdown.MD(Markdown.Code("js", strip(codestring, '\n'))))
end


# HTLBypass #

## Definition - HTLBypass ##
"""
	struct HTLBypass
This struct is a simple wrapper around HypertextLiteral.Result intended to
provide interpolation inside <script> tags as if writing the code that generated
the result directly. 

This is intended for use inside Pluto notebooks to ease variable interpolation
inside html element generated within <script> tags using the `html\`\`` command
that is imported from Observable.

This way, one can generate the intended HTML inside other cells to more easily
see the results and with support of nested @htl interpolation.

The struct only accepts the output of the @htl macro as an input.

On top of the interpolation, an object of type `HTLBypass` will simply show the
wrapped `HypertextLiteral.Result` when shown with `MIME"text/html"`.

See also: [`HTLScriptPart`](@ref), [`HTLScript`](@ref)

Examples:

```julia
let
	bpclass = "magic";
	bplol = @htl \"\"\"
	<div class=\$bpclass>
		MAGIC
	</div>
	\"\"\"
	bpasd = HTLBypass(@htl "
	<div>This is \$bplol</div>
	")
	@htl "<script>let out = html`\$bpasd`;return out</script>"
end
```
"""
struct HTLBypass
	result::HypertextLiteral.Result
	buffer::IOBuffer
	function HTLBypass(r::HypertextLiteral.Result)
		buf = IOBuffer()
		show(buf, r)
		new(r, buf)
	end
end

## Show methods - HTLBypass ##

function Base.show(io::IO, ::MIME"text/javascript", s::HTLBypass)
	buf = s.buffer
	seekstart(buf)
	write(io, buf)
end
function Base.show(io::IO, mime::MIME"text/html", s::HTLBypass)
	show(io, mime, s.result)
end

# General Functions #
function formatted_js(s::Union{HTLScriptPart, HTLBypass})
	buf = s.buffer
	seekstart(buf)
	codestring = strip(read(buf, String), '\n')
	Markdown.MD(Markdown.Code("js", codestring))
end

# HTLScript #

## Definition - HTLScript ##
"""
```julia
Base.@kwdef struct HTLScript
	body::HTLScriptPart
	invalidation::Union{HTLScriptPart, Missing}
	id::Union{Missing, Nothing, String}
end
```
# Fields
- `body::HTLScriptPart` -> The main body of the script
- `invalidation::Union{HTLScriptPart, Missing}` -> The code to be executed inside the invalidation promise. Defaults to `missing`
- `id::Union{Missing, Nothing, String}` -> The id to assign to the script. Defaults to `missing`

# Additional Constructors
	HTLScript(body; kwargs...)
	HTLScript(body, invalidation; kwargs...)

For the body and invalidation fields, the constructor also accepts inputs of
type `String`, `HypertextLiteral.Result` and `IOBuffer`, translating them into
`HTLScriptPart` internally.

	HTLScript(s::HTLScript; kwargs...)
This constructor is used to copy the elements from another HTLScript with the
option of overwriting the fields provided as `kwargs`

# Description

This struct is used to create and compose scripts together with the `@htl` macro
from HypertextLiteral. 

It is intended for use inside Pluto notebooks to ease composition of bigger
scripts via smaller parts.

When an HTLScript is interpolated inside the `@htl` macro, the following code is generated:
```html
<script id=\$id>
\$body

invalidation.then(() => {
	\$invalidation
})
```
If the `id = missing` (default), a random string id is associated to the script.
If `id = nothing`, a script without id is created.

If the `invalidation` field is `missing`, the whole invalidation block is
skipped.

Multiple `HTLScript` elements can be combined together using the
[`combine_script`](@ref) function also exported by this package, allowing to
generate bigger scripts by composing multiple building blocks.

When shown inside the output of Pluto cells, the HTLScript object prints its
containing formatted code as a `Markdown.Code` element.

# Javascript Events Listeners

`HTLScript` provides some simplified way of adding event listeners in javascript
that are automatically removed upon cell invalidation. Scripts created using
`HTLScript` expose an internal javascript function 
```js
addScriptEventListener(element, listeners)
```
which accepts any givent JS `element` to which listeners have to be attached,
and an object of with the following key-values:
```js
{ 
  eventName1: listenerFunction1, 
  eventName2: listenerFunction2,
  ... 
}
```
When generating the script to execute, `HTLScript` automatically adds all the
provided listeners to the provided element, and also takes care of removing all
the listeners upon cell invalidation.

For example, the following julia code:
```julia
let
	script = HTLScript(@htl(\"\"\"
<script>
	addScriptEventListeners(window, { 
		click: function (event) {
			console.log('click: ',event)
		}, 
		keydown: function (event) {
			console.log('keydown: ',event)
		},
	})
</script>
	\"\"\"))
	@htl"\$script"
end
```
is functionally equivalent of writing the following javascript code within the
script tag of the cell output
```js
function onClick(event) {
	console.log('click: ',event)
}
function onKeyDown(event) {
	console.log('keydown: ',event)
}
window.addEventListener('click', onClick)
window.addEventListener('keydown', onKeyDown)

invalidation.then(() => {
	window.removeEventListener('click', onClick)
	window.removeEventListener('keydown', onKeyDown)
})
```

See also: [`HTLScriptPart`](@ref), [`combine_scripts`](@ref)

# Examples:
The following code:
```julia
let
a = HTLScript("console.log('asd')")
b = HTLScript(@htl("<script>console.log('boh')</script>"), "console.log('lol')")
script = combine_scripts([a,b];id="test")
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
\"\"\"
</script>
```
"""
Base.@kwdef struct HTLScript
    body::HTLScriptPart
    invalidation::Union{Missing,HTLScriptPart} = missing
    id::Union{Missing, Nothing, String} = missing
    _id::String = randstring(6)
    function HTLScript(b,i,id::Union{Missing, Nothing, String},_id::String) 
        body = b isa HTLScriptPart ? b : HTLScriptPart(b)
        invalidation = i isa Union{Missing,HTLScriptPart} ? i : HTLScriptPart(i)
        new(body,invalidation,id,_id)
    end
end
# Custom Constructors
HTLScript(body; kwargs...) = HTLScript(;body, kwargs...)
HTLScript(body, invalidation; kwargs...) = HTLScript(body, invalidation, missing;kwargs...)
HTLScript(body,invalidation,id; kwargs...) = HTLScript(;body, invalidation, id, kwargs...)

# Identity/Copy with modification
HTLScript(s::HTLScript; kwargs...) = HTLScript(s.body, s.invalidation, s.id;kwargs...)

shouldskip(x::HTLScript) = shouldskip(x.body) && shouldskip(x.invalidation)
## Show Methods - HTLScript ##

# This custom content method is used when interpolating inside the @htl macro (but outside of the script tag)
HypertextLiteral.content(s::HTLScript) = make_script(s)

# The show method is instead used for showing in the Pluto output.
function Base.show(io::IO, mime::MIME"text/html", s::HTLScript)
	show(io, mime, formatted_code(s))
end

## Automatic Event Listeners - HTLScript ##

_events_listeners_preamble = HTLScript(@htl("""
<script>
	/* #### BEGINNING OF PART AUTOMATICALLY ADDED BY HTLSCRIPT #### */
	// Array where all the event listeners are stored
	const _events_listeners_ = []

	// Function that can be called to add events listeners within the script
	function addScriptEventListeners(element, listeners) {
		if (listeners.constructor != Object) {error('Only objects with keys as event names and values as listener functions are supported')}
		_events_listeners_.push({element, listeners})
	}
	/* #### END OF PART AUTOMATICALLY ADDED BY HTLSCRIPT #### */
</script>
"""));

_events_listeners_postamble = HTLScript(;
body = @htl("""
<script>
	/* #### BEGINNING OF PART AUTOMATICALLY ADDED BY HTLSCRIPT #### */
	// Assign the various events listeners defined within the script
	for (const item of _events_listeners_) {
		const { element, listeners } = item
		for (const [name, func] of _.entries(listeners)) {
  			element.addEventListener(name, func)
		}
	}
	/* #### END OF PART AUTOMATICALLY ADDED BY HTLSCRIPT #### */
</script>
"""),
invalidation = @htl("""
<script>	
		/* #### BEGINNING OF PART AUTOMATICALLY ADDED BY HTLSCRIPT #### */
		// Remove the events listeners during invalidation
		for (const item of _events_listeners_) {
			const { element, listeners } = item
			for (const [name, func] of _.entries(listeners)) {
	  			element.removeEventListener(name, func)
			}
		}
		/* #### END OF PART AUTOMATICALLY ADDED BY HTLSCRIPT #### */
</script>
"""))

## Helper functions - HTLScript ##

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

function print_invalidation(s::HTLScriptPart, addListeners::Bool = false)
	out = if (isempty(s.buffer) && !addListeners) 
        ""
    else
        contents = [
                addListeners ? _events_listeners_postamble.invalidation : HTLScriptPart("")
                s
        ]
        @htl("""
        <script>
            invalidation.then(() => {
            $(contents)
            })
        </script>
        """)
    end
	return HTLScriptPart(out)
end

# Make Script
function make_script(h::HTLScript, addListeners::Bool = h.body.addedEventListeners; is_pluto = true)
	id = coalesce(h.id, h._id)
    s = combine_scripts([
        addListeners ? _events_listeners_preamble : HTLScript("")
        h
        addListeners ? _events_listeners_postamble : HTLScript("")
    ])
	contents = [
		s.body
		is_pluto && !shouldskip(s.invalidation) ?
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

# Show the formatted code in markdown as output
function formatted_code(s::HTLScript)
	buf = IOBuffer()
	show(buf, make_script(s))
	seekstart(buf)
	codestring = strip(read(buf, String), '\n')
	Markdown.MD(Markdown.Code("html", codestring))
end

#= Fix for Julia 1.10 
The `@generated` `print_script` from HypertextLiteral is broken in 1.10
See [issue 33](https://github.com/JuliaPluto/HypertextLiteral.jl/issues/33)
We have to also define a method for `print_script` to avoid precompilation errors
=#

HypertextLiteral.print_script(io::IO, val::Union{HTLScript, HTLBypass, HTLScriptPart}) = show(io, MIME"text/javascript"(), val)



end