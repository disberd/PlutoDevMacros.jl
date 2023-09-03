## ScriptContent ##
	"""
	struct ScriptContent
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
wrapper = ScriptContent(@htl(\"\"\"
<script>
code...
</script>
\"\"\"))
```
When interpolating `wrapper` above inside another `@htl` macro as `@htl
"<script>\$wrapper</script>"` it would be as equivalent to directly writing
`@htl "<script>code...</script>` inside the script. This is clearly only
beneficial if multiple `ScriptContent` variables are interpolated inside a
single <script> block.

On top of the interpolation, an object of type `ScriptContent` will show its
contents as a formatted javascript code markdown element when shown in Pluto. 

The constructor also accepts either a `String` or `IOBuffer` object for its
initialization instead of a `HypertextLiteral.Result` one.

See also: [`PlutoScript`](@ref), [`HTLBypass`](@ref)

Examples:

```julia
let
	asd = ScriptContent(@htl \"\"\"
	<script>
		let out = html`<div></div>`
		console.log('first script')
	</script>
	\"\"\")
	lol = ScriptContent(@htl \"\"\"
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
struct ScriptContent
	buffer::IOBuffer
	addedEventListeners::Bool
end
function ScriptContent(buf::IOBuffer; addedEventListeners = missing)
	# We check if the code contains calls to the addScriptEventListeners
	ael = if addedEventListeners === missing
		checkbuf = IOBuffer()
		seekstart(buf)
		Base.readuntil_vector!(buf, codeunits("addScriptEventListeners("), false, checkbuf)
		# If the previous line didn't find any call to addScriptEventListeners, the size of trash and buf will be the same
		!(buf.size === checkbuf.size)
	else
		addedEventListeners
	end
	ScriptContent(buf, ael)
end		

function ScriptContent(r::HypertextLiteral.Result; kwargs...)
	buf = IOBuffer()
	temp = IOBuffer()
	trash = IOBuffer()
	show(temp, r)
	seekstart(temp)
	# This is adapted from readuntil in
	# https://github.com/JuliaLang/julia/blob/f70b5e4767809c7dbc4c6c082aed67a2af4447c2/base/io.jl#L923-L943
	Base.readuntil_vector!(temp, codeunits("<script>"), false, trash)
	Base.readuntil_vector!(temp, codeunits("</script>"), false, buf)
	str = String(take!(buf)) # We do this (instead of using directly the buffer) to strip newlines
	ScriptContent(str; kwargs...)
end
function ScriptContent(s::AbstractString; kwargs...)
	isnewline(x) = x in ('\n', '\r') # This won't remove tabs and whitespace
	str = lstrip(isnewline, rstrip(s))
	buf = IOBuffer()
	write(buf, str)
	ScriptContent(buf; kwargs...)
end
ScriptContent(p::ScriptContent) = p
ScriptContent() = ScriptContent(IOBuffer(), false)
ScriptContent(m::Union{Missing, Nothing}) = missing

## HTLBypass ##
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

See also: [`ScriptContent`](@ref), [`PlutoScript`](@ref)

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

abstract type ValidScript end
abstract type SingleScript <: ValidScript end
## PlutoScript ##
"""
```julia
Base.@kwdef struct PlutoScript
	body::ScriptContent
	invalidation::Union{ScriptContent, Missing}
	id::Union{Missing, Nothing, String}
end
```
# Fields
- `body::ScriptContent` -> The main body of the script
- `invalidation::Union{ScriptContent, Missing}` -> The code to be executed inside the invalidation promise. Defaults to `missing`
- `id::Union{Missing, Nothing, String}` -> The id to assign to the script. Defaults to `missing`

# Additional Constructors
	PlutoScript(body; kwargs...)
	PlutoScript(body, invalidation; kwargs...)

For the body and invalidation fields, the constructor also accepts inputs of
type `String`, `HypertextLiteral.Result` and `IOBuffer`, translating them into
`ScriptContent` internally.

	PlutoScript(s::PlutoScript; kwargs...)
This constructor is used to copy the elements from another PlutoScript with the
option of overwriting the fields provided as `kwargs`

# Description

This struct is used to create and compose scripts together with the `@htl` macro
from HypertextLiteral. 

It is intended for use inside Pluto notebooks to ease composition of bigger
scripts via smaller parts.

When an PlutoScript is interpolated inside the `@htl` macro, the following code is generated:
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

Multiple `PlutoScript` elements can be combined together using the
[`combine_script`](@ref) function also exported by this package, allowing to
generate bigger scripts by composing multiple building blocks.

When shown inside the output of Pluto cells, the PlutoScript object prints its
containing formatted code as a `Markdown.Code` element.

# Javascript Events Listeners

`PlutoScript` provides some simplified way of adding event listeners in javascript
that are automatically removed upon cell invalidation. Scripts created using
`PlutoScript` expose an internal javascript function 
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
When generating the script to execute, `PlutoScript` automatically adds all the
provided listeners to the provided element, and also takes care of removing all
the listeners upon cell invalidation.

For example, the following julia code:
```julia
let
	script = PlutoScript(@htl(\"\"\"
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

See also: [`ScriptContent`](@ref), [`combine_scripts`](@ref)

# Examples:
The following code:
```julia
let
a = PlutoScript("console.log('asd')")
b = PlutoScript(@htl("<script>console.log('boh')</script>"), "console.log('lol')")
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
@kwdef struct PlutoScript <: SingleScript
    body::Union{Missing,ScriptContent} = missing
    invalidation::Union{Missing,ScriptContent} = missing
    id::Union{Missing, String} = missing
    function PlutoScript(b,i,id::Union{Missing, Nothing, String}) 
        body = ScriptContent(b)
        invalidation = ScriptContent(i)
        new(body,invalidation, something(id, missing))
    end
end
# Custom Constructors
PlutoScript(body; kwargs...) = PlutoScript(;body, kwargs...)
PlutoScript(body, invalidation; kwargs...) = PlutoScript(body; invalidation, kwargs...)

# Identity/Copy with modification
PlutoScript(s::PlutoScript; kwargs...) = PlutoScript(;body = s.body, invalidation = s.invalidation, id = s.id, kwargs...)

## NormalScript
@kwdef struct NormalScript <: SingleScript
	body::Union{Missing, ScriptContent} = missing
	show_as_module::Bool = true
	id::Union{Missing, String} = missing
    function NormalScript(b,show_as_module::Bool,id::Union{Missing, Nothing, String}) 
        body = ScriptContent(b)
        new(body, show_as_module, something(id, missing))
    end
end
NormalScript(body; kwargs...) = NormalScript(;body, kwargs...)
NormalScript(ps::PlutoScript; kwargs...) = NormalScript(ps.body; id = ps.id, kwargs...)
NormalScript(ns::NormalScript; kwargs...) = NormalScript(ns.body; show_as_module = ns.show_as_module, id = ps.id, kwargs...)

## DualScript ##
@kwdef struct DualScript <: ValidScript
	inside_pluto::PlutoScript = PlutoScript()
	outside_pluto::NormalScript = NormalScript()
	function DualScript(i::PlutoScript, o::NormalScript; kwargs...)
		id = get(kwargs, :id, missing)
		if id === missing
			new(i,o)
		else
			ip = PlutoScript(i; id)
			op = NormalScript(o; id)
			new(ip, op)
		end
	end
end
# Custom Constructors
DualScript(i::PlutoScript; kwargs...) = DualScript(i, NormalScript(); kwargs...)
DualScript(o::NormalScript; kwargs...) = DualScript(PlutoScript(), o; kwargs...)
DualScript(ds::DualScript; kwargs...) = DualScript(ds.inside_pluto, ds.outside_pluto; kwargs...)
DualScript(body; kwargs...) = DualScript(PlutoScript(body; kwargs...))


## CombinedScripts ##
struct CombinedScripts <: ValidScript
	scripts::Vector{DualScript}
	CombinedScripts(v::Vector) = new(filter(!shouldskip, map(DualScript, v)))
end
const ValidInputs = Union{DualScript, AbstractString, IOBuffer, ScriptContent, SingleScript}

CombinedScripts(s::ValidInputs) = CombinedScripts([DualScript(s)])

## ShowAsHTML ##
struct ShowAsHTML{T}
	el::T
end

