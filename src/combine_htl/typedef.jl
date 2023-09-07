abstract type DisplayLocation end
abstract type SingleDisplayLocation <: DisplayLocation end
struct InsidePluto <: SingleDisplayLocation end
struct OutsidePluto <: SingleDisplayLocation end
struct InsideAndOutsidePluto <: DisplayLocation end

abstract type AbstractHTML{D<:DisplayLocation} end
abstract type Node{D} <: AbstractHTML{D} end
abstract type NonScript{D} <: Node{D} end
abstract type Script{D} <: Node{D} end

const SingleNode = Node{<:SingleDisplayLocation}
const SingleScript = Script{<:SingleDisplayLocation}

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

See also: [`PlutoScript`](@ref)

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
	content::String
	addedEventListeners::Bool
end

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
addScriptEventListeners(element, listeners)
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
struct PlutoScript <: Script{InsidePluto}
    body::Union{Missing,ScriptContent}
    invalidation::Union{Missing,ScriptContent}
    id::Union{Missing, String}
	returned_element::Union{Missing, String}
    function PlutoScript(b,i,id::Union{Missing, Nothing, String}, returned_element; kwargs...) 
        body = ScriptContent(b; kwargs...)
        invalidation = ScriptContent(i)
		@assert invalidation === missing || invalidation.addedEventListeners === false "You can't have added event listeners in the invalidation script"
        new(body,invalidation, something(id, missing), returned_element)
    end
end

## NormalScript
struct NormalScript <: Script{OutsidePluto}
	body::Union{Missing, ScriptContent}
	add_pluto_compat::Bool
	id::Union{Missing, String}
	returned_element::Union{Missing, String}
    function NormalScript(b, add_pluto_compat, id, returned_element; kwargs...) 
        body = ScriptContent(b; kwargs...)
        new(body, add_pluto_compat, something(id, missing), returned_element)
    end
end

## DualScript ##
@kwdef struct DualScript <: Script{InsideAndOutsidePluto}
	inside_pluto::PlutoScript = PlutoScript()
	outside_pluto::NormalScript = NormalScript()
	function DualScript(i, o; kwargs...)
		ip = PlutoScript(i; kwargs...)
		op = NormalScript(o; kwargs...)
		new(ip, op)
	end
end

## CombinedScripts ##
struct CombinedScripts <: Script{InsideAndOutsidePluto}
	scripts::Vector{DualScript}
	function CombinedScripts(v::Vector{DualScript}; returned_element = missing) 
		# We check for only one return expression and it being in the last script
		return_count = 0
		for s in v
			# If not return is present we skip this script
			hasreturn(s, InsideAndOutsidePluto()) || continue
			return_count += 1
		end
		@assert return_count < 2 "More than one return expression was found while constructing the CombinedScripts. This is not allowed."
		if return_count > 0
			@assert hasreturn(v[end], InsideAndOutsidePluto()) "The return expression is not in the last Script in the vector. This is not allowed."
		end
		if returned_element !== missing
			dn = v[end]
			v[end] = DualScript(dn; returned_element)
		end
		new(v)
	end
end
struct ShowWithPrintHTML{D<:DisplayLocation, T} <: AbstractHTML{D}
	el::T
	ShowWithPrintHTML(el::T, ::D) where {T, D<:DisplayLocation} = new{D,T}(el)
end

# HTML Nodes #
# We use a custom IO to parse the HypertextLiteral.Result for removing newlines and checking if empty
@kwdef struct ParseResultIO <: IO
	parts::Vector = []
end
# Now we define custom print method to extract the Result parts. See
# https://github.com/JuliaPluto/HypertextLiteral.jl/blob/2bb465047afdfbb227171222049f315545c307fb/src/primitives.jl
for T in (Bypass, Render, Reprint)
	Base.print(io::ParseResultIO, x::T) = shouldskip(x) || push!(io.parts, x)
end

_isnewline(x) = x in ('\n', '\r') # This won't remove tabs and whitespace
strip_nl(s::AbstractString) = lstrip(_isnewline, rstrip(s))
_remove_leading(x) = x
_remove_leading(x::Bypass{<:AbstractString}) = Bypass(lstrip(_isnewline, x.content))
_remove_trailing(x) = x
_remove_trailing(x::Bypass{<:AbstractString}) = Bypass(rstrip(isspace, x.content))
# We define PlutoNode and NormalNode
for (T, P) in ((:PlutoNode, :InsidePluto), (:NormalNode, :OutsidePluto))
	block = quote
		struct $T <: NonScript{$P}
			content::Result
			empty::Bool
		end
		# Empty Constructor
		$T() = $T(@htl(""), true)
		# Constructor from Result
		function $T(r::Result)
			io = ParseResultIO()
			# We don't use show directly to avoid the EscapeProxy here
			r.content(io)
			node = if isempty(io.parts)
				$T(r, true)
			else
				# We try to eventually remove trailing and leading redundant spaces
				xs = io.parts
				xs[begin] = _remove_leading(xs[begin])
				xs[end] = _remove_trailing(xs[end])
				$T(Result(xs...), false)
			end
			return node
		end
		# Constructor from AbstractString
		function $T(s::AbstractString)
			str = strip_nl(s)
			out = if isempty(str)
				$T(@htl(""), true)
			else
				r = @htl("$(ShowWithPrintHTML(str))")
				$T(r, false)
			end 
		end
		# No-op constructor
		$T(t::$T) = t
		# Generic constructor
		$T(content) = $T(@htl("$content"))
	end
	# Create the function constructing from HypertextLiteral or HTML
	eval(block)
end

## DualNode
struct DualNode <: NonScript{InsideAndOutsidePluto}
	inside_pluto::PlutoNode
	outside_pluto::NormalNode
	DualNode(i::PlutoNode, o::NormalNode) = new(i, o)
end

## CombinedNodes
struct CombinedNodes <: NonScript{InsideAndOutsidePluto}
	nodes::Vector{<:Node{InsideAndOutsidePluto}}
	CombinedNodes(v::Vector) = new(filter(x -> !shouldskip(x, InsideAndOutsidePluto()), map(make_node, v)))
end


const Single = Union{SingleNode, SingleScript}
const Dual = Union{DualScript, DualNode}
const Combined = Union{CombinedScripts, CombinedNodes}

function Base.getproperty(c::Combined, s::Symbol)
	if s === :children
		children(c)
	else
		getfield(c,s)
	end
end
