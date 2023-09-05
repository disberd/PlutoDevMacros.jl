abstract type DisplayLocation end
abstract type SingleDisplayLocation <: DisplayLocation end
struct InsidePluto <: SingleDisplayLocation end
struct OutsidePluto <: SingleDisplayLocation end
struct InsideAndOutsidePluto <: DisplayLocation end

abstract type Node{T<:DisplayLocation} end
abstract type NonScript{T} <: Node{T} end
abstract type Script{T} <: Node{T} end

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
_isnewline(x) = x in ('\n', '\r') # This won't remove tabs and whitespace
function strip_nl(s::AbstractString)
	str = lstrip(_isnewline, rstrip(s))
end
function ScriptContent(s::AbstractString; addedEventListeners = missing)
	# We strip eventual leading newline or trailing `isspace`
	str = strip_nl(s)
	ael = if addedEventListeners === missing
		contains(str, "addScriptEventListeners(")
	else
		addedEventListeners
	end
	ScriptContent(str, ael)
end

function ScriptContent(r::Result; kwargs...)
	temp = IOBuffer()
	show(temp, r)
	str_content = strip(String(take!(temp)))
	isempty(str_content) && return ScriptContent("", false)
	n_matches = 0
	first_idx = 0
	first_offset = 0
	last_idx = 0
	start_regexp = r"<script[^>]*>"
	end_regexp = r"</script>"
	for m in eachmatch(r"<script[^>]*>", str_content)
		n_matches += 1
		n_matches > 1 && break
		first_offset = m.offset
		first_idx = first_offset + length(m.match)
		m_end = match(end_regexp, str_content, first_idx)
		m_end === nothing && error("No closing </script> tag was found in the input")
		last_idx = m_end.offset - 1
	end
	if n_matches === 0
		@warn "No <script> tag was found. 
Remember that the `ScriptContent` constructor only extract the content between the first <script> tag it finds when using an input of type `HypertextLiteral.Result`"
		return ScriptContent("", false)
	elseif n_matches > 1
		@warn "More than one <script> tag was found. 
Only the contents of the first one have been extracted"
	elseif first_offset > 1 || last_idx < length(str_content) - length("</script>")
		@warn "The provided input also contained contents outside of the <script> tag. 
This content has been discarded"
	end
	ScriptContent(str_content[first_idx:last_idx]; kwargs...)
end
ScriptContent(p::ScriptContent) = p
ScriptContent() = ScriptContent("", false)
ScriptContent(::Union{Missing, Nothing}) = missing

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
@kwdef struct PlutoScript <: Script{InsidePluto}
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
@kwdef struct NormalScript <: Script{OutsidePluto}
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
NormalScript(ns::NormalScript; kwargs...) = NormalScript(ns.body; show_as_module = ns.show_as_module, id = ns.id, kwargs...)

## DualScript ##
@kwdef struct DualScript <: Script{InsideAndOutsidePluto}
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
DualScript(i, o; kwargs...) = DualScript(PlutoScript(i), NormalScript(o); kwargs...)
DualScript(i::PlutoScript; kwargs...) = DualScript(i, NormalScript(); kwargs...)
DualScript(o::NormalScript; kwargs...) = DualScript(PlutoScript(), o; kwargs...)
DualScript(ds::DualScript; kwargs...) = DualScript(ds.inside_pluto, ds.outside_pluto; kwargs...)
DualScript(body; kwargs...) = DualScript(PlutoScript(body; kwargs...))


## CombinedScripts ##
struct CombinedScripts <: Script{InsideAndOutsidePluto}
	scripts::Vector{DualScript}
	CombinedScripts(v::Vector) = new(filter(!shouldskip, map(make_script, v)))
end

CombinedScripts(cs::CombinedScripts) = cs
CombinedScripts(s) = CombinedScripts([DualScript(s)])

struct ShowWithPrintHTML{T}
	el::T
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
DualNode(i, o) = DualNode(PlutoNode(i), NormalNode(o))
DualNode(i::PlutoNode) = DualNode(i, "")
DualNode(o::NormalNode) = DualNode("", o)
DualNode(x) = DualNode(PlutoNode(x))

## CombinedNodes
struct CombinedNodes <: NonScript{InsideAndOutsidePluto}
	nodes::Vector{<:Node{InsideAndOutsidePluto}}
	CombinedNodes(v::Vector) = new(filter(!shouldskip, map(make_node, v)))
end



