### A Pluto.jl notebook ###
# v0.19.22

using Markdown
using InteractiveUtils

# ╔═╡ 3020de32-5b63-11ed-208f-1d2acb775b3b
using HypertextLiteral

# ╔═╡ f2abae1a-5055-41a7-9330-04d514cd5fff
using Random

# ╔═╡ 4ce0b2ab-3a7b-407e-a9d9-112e754bed82
# ╠═╡ skip_as_script = true
#=╠═╡
begin
	using PlutoUI 
	using PlutoExtras
	using BenchmarkTools
end
  ╠═╡ =#

# ╔═╡ de7a0ea7-d67d-4754-843f-5731924bbd70
#=╠═╡
ExtendedTableOfContents()
  ╠═╡ =#

# ╔═╡ af424bad-c980-4969-91b7-299d9f029691
md"""
# HTLScriptPart
"""

# ╔═╡ c5b66120-bb79-4603-ab2b-767bb684a4ae
md"""
## Definition
"""

# ╔═╡ 1aa9e236-eb68-43f5-afcd-1af51b71b34e
begin
	"""
	struct HTLScriptPart
This struct is a simple wrapper around an `IOBuffer` and is intended to provide pretty printing of script contents and custom interpolation inside the `<script>` tags of the `@htl` macro.

It is intended for use within Pluto notebooks to simply decouple parts of a javascript script into separate variables and still be able to interpolate them within <script> tags to compose a bigger script.

Compared to simply using strings wrapped in `HypertextLiteral.JavaScript`, this gives the opportunity to exploit the experimental htmlmixed synthax highlighting of code inside cells by also accepting `HypertextLiteral.Result` objects during construction.

The struct can be initialized as follows:
```julia
wrapper = HTLScriptPart(@htl(\"\"\"
<script>
code...
</script>
\"\"\"))
```
When interpolating `wrapper` above inside another `@htl` macro as `@htl "<script>\$wrapper</script>"` it would be as equivalent to directly writing `@htl "<script>code...</script>` inside the script. This is clearly only beneficial if multiple `HTLScriptPart` variables are interpolated inside a single <script> block.

On top of the interpolation, an object of type `HTLScriptPart` will show its contents as a formatted javascript code markdown element when shown in Pluto. 

The constructor also accepts either a `String` or `IOBuffer` object for its initialization instead of a `HypertextLiteral.Result` one.

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
	function HTLScriptPart(buf::IOBuffer)
		# We check if the code contains calls to the addScriptEventListeners
		checkbuf = IOBuffer()
		seekstart(buf)
		Base.readuntil_vector!(buf, codeunits("addScriptEventListeners("), false, checkbuf)
		# If the previous line didn't find any call to addScriptEventListeners, the size of trash and buf will be the same
		addedEventListeners = !(buf.size === checkbuf.size)
		new(buf, addedEventListeners)
	end		
end
function HTLScriptPart(r::HypertextLiteral.Result)
	buf = IOBuffer()
	temp = IOBuffer()
	trash = IOBuffer()
	show(temp, r)
	seekstart(temp)
	# This is adapted from readuntil in https://github.com/JuliaLang/julia/blob/f70b5e4767809c7dbc4c6c082aed67a2af4447c2/base/io.jl#L923-L943
	Base.readuntil_vector!(temp, codeunits("<script>"), false, trash)
	Base.readuntil_vector!(temp, codeunits("</script>"), false, buf)
	HTLScriptPart(buf)
end
function HTLScriptPart(s::AbstractString)
	buf = IOBuffer()
	write(buf, s)
	HTLScriptPart(buf)
end
end

# ╔═╡ b9291d89-8b30-40f6-b13f-4259f774adaa
let
	findfirst("addScriptEventListeners(", "dio gesu addScriptEventListenersa(a,1)")
end

# ╔═╡ 7dcfe459-c23b-4c4f-aa6b-5654f17934a0
md"""
## Show methods
"""

# ╔═╡ ac2b8e3e-1704-48c3-bc1f-9f12010b7e3c
# This is to have a custom printing when inside a <script> tag within @htl 
function Base.show(io::IO, ::MIME"text/javascript", s::HTLScriptPart)
	buf = s.buffer
	seekstart(buf)
	write(io, buf)
end

# ╔═╡ bb3b8e82-d556-4fbb-82b8-7e585d9d48ca
# Show the formatted code in markdown as output
function Base.show(io::IO, mime::MIME"text/html", s::HTLScriptPart)
	buf = s.buffer
	seekstart(buf)
	codestring = strip(read(buf, String), '\n')
	show(io, mime, Markdown.MD(Markdown.Code("js", codestring)))
end

# ╔═╡ 7486654e-44fc-4fd7-9cc2-4b7b76f89a91
function Base.show(io::IO, mime::MIME"text/html", v::Union{AbstractVector{HTLScriptPart}, NTuple{N,HTLScriptPart} where N})
	codestring = ""
	foreach(v) do s
		buf = s.buffer
		seekstart(buf)
		codestring *= read(buf, String)
	end
	show(io, mime, Markdown.MD(Markdown.Code("js", strip(codestring, '\n'))))
end

# ╔═╡ 0d427c09-73bd-463a-b6a1-919e18c1e794
md"""
## Test/Examples
"""

# ╔═╡ 08495423-6628-4898-8e91-28cdbc7a418c
# ╠═╡ skip_as_script = true
#=╠═╡
asd = (@htl """
<script>
	let out = html`<div></div>`
	console.log('first script')
</script>
""") |> HTLScriptPart
  ╠═╡ =#

# ╔═╡ 25419f8c-9983-4cc4-9bda-f5f734482d7a
# ╠═╡ skip_as_script = true
#=╠═╡
lol = (@htl """
<script>
	let a = Math.random()
	out.innerText = a
	console.log('second script')
	return out
</script>
""") |> HTLScriptPart
  ╠═╡ =#

# ╔═╡ 13c02158-c8e2-40a2-ae05-9d9793a1009d
#=╠═╡
@htl """
<script>
	$asd
	$lol
</script>
"""
  ╠═╡ =#

# ╔═╡ 0febddd9-6143-4b6c-ba64-b5d209c82603
#=╠═╡
[asd,lol]
  ╠═╡ =#

# ╔═╡ 8552047f-192f-493a-8b1a-8d51f32f81ae
#=╠═╡
@htl """
<script>
	$([asd, lol])
</script>
"""
  ╠═╡ =#

# ╔═╡ 3b5648d4-9421-461a-8aa2-34ce466f1a43
md"""
# HTLBypass
"""

# ╔═╡ 71521eb4-95b0-4006-9239-bad66eb31a30
md"""
## Definition
"""

# ╔═╡ 14a59245-b87d-4afd-a0d5-2e4bcf2a6409
md"""
## Show methods
"""

# ╔═╡ d2487a65-576c-4adf-b809-c1991a4c2106
md"""
## Test/Examples
"""

# ╔═╡ 31df6aae-443e-42df-8710-9925453a7ed0
# ╠═╡ skip_as_script = true
#=╠═╡
bpclass = "magic";
  ╠═╡ =#

# ╔═╡ 92ad3e14-3c51-43a2-9772-720d205af75a
#=╠═╡
bplol = @htl """
<div class=$bpclass>
	MAGIC
</div>
"""
  ╠═╡ =#

# ╔═╡ 2dc15e2a-9a8f-4ce9-b5e9-89ccd6e19468
md"""
# HTLScript
"""

# ╔═╡ 06bdb7d6-2963-4cf0-8e67-d3c7559bdacf
md"""
## Definition
"""

# ╔═╡ 69ebc2a6-3e0d-4050-865b-96128e3d2889
begin
	# Definition
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

For the body and invalidation fields, the constructor also accepts inputs of type `String`, `HypertextLiteral.Result` and `IOBuffer`, translating them into `HTLScriptPart` internally.

	HTLScript(s::HTLScript; kwargs...)
This constructor is used to copy the elements from another HTLScript with the option of overwriting the fields provided as `kwargs`

# Description

This struct is used to create and compose scripts together with the `@htl` macro from HypertextLiteral. 

It is intended for use inside Pluto notebooks to ease composition of bigger scripts via smaller parts.

When an HTLScript is interpolated inside the `@htl` macro, the following code is generated:
```html
<script id=\$id>
\$body

invalidation.then(() => {
	\$invalidation
})
```
If the `id = missing` (default), a random string id is associated to the script. If `id = nothing`, a script without id is created.

If the `invalidation` field is `missing`, the whole invalidation block is skipped.

Multiple `HTLScript` elements can be combined together using the [`combine_script`](@ref) function also exported by this package, allowing to generate bigger scripts by composing multiple building blocks.

When shown inside the output of Pluto cells, the HTLScript object prints its containing formatted code as a `Markdown.Code` element.

# Javascript Events Listeners

`HTLScript` provides some simplified way of adding event listeners in javascript that are automatically removed upon cell invalidation. Scripts created using `HTLScript` expose an internal javascript function 
```js
addScriptEventListener(element, listeners)
```
which accepts any givent JS `element` to which listeners have to be attached, and an object of with the following key-values:
```js
{ 
  eventName1: listenerFunction1, 
  eventName2: listenerFunction2,
  ... 
}
```
When generating the script to execute, `HTLScript` automatically adds all the provided listeners to the provided element, and also takes care of removing all the listeners upon cell invalidation.

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
is functionally equivalent of writing the following javascript code within the script tag of the cell output
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
end

# ╔═╡ 1fcbc5cb-2d26-4951-ba93-df8e45588d67
md"""
## Show Methods
"""

# ╔═╡ a4ef253a-6254-4fbf-abde-58f98295f7c7
md"""
## Automatic Event Listeners
"""

# ╔═╡ 3b1e9a72-6550-4478-89f9-ccf1089eefdb
_events_listeners_preamble = HTLScriptPart(@htl("""
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

# ╔═╡ e1e35e7a-efce-45c2-8f67-120755081179
_events_listeners_postamble = HTLScriptPart(@htl("""
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
"""));

# ╔═╡ ae402f64-409d-4c95-94a3-778348514b0e
_events_listeners_invalidation = HTLScriptPart(@htl("""
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
"""));

# ╔═╡ 36484b50-7f16-40c9-8c0e-25f66a85add4
# ╠═╡ skip_as_script = true
#=╠═╡
testt = HTLScript(@htl("""
<script>
	let a = Math.random()

	addScriptEventListeners(window, {
		click: function (e) {
			console.log(a)
		}
	})
</script>
"""))
  ╠═╡ =#

# ╔═╡ a39f02b8-6681-42e4-a216-966e9884b91a
md"""
## Helper functions
"""

# ╔═╡ 6605dfe7-299f-4a40-bae2-c90e19ac809c
const ValidInputs = Union{HTLScript, AbstractString, IOBuffer, HTLScriptPart}

# ╔═╡ 9bbd8ffd-3579-421e-a457-aace7bf66920
_convert_combine(h::Vararg{ValidInputs};id) = _convert_combine(h;id)

# ╔═╡ 699d5df1-357b-4e0e-a0a6-032c19f74415
_combine(h::Vararg{HTLScript};id) = _combine(h;id)

# ╔═╡ 74cc8a48-7d18-4e08-a492-3240e37efdc8
function _combine(h;id)
	body = IOBuffer()
	invalidation = IOBuffer()
	_id = missing
	f(x, y) = if !ismissing(y)
		buf = y.buffer
		seekstart(buf)
		write(x, buf)
		write(x, '\n')
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
		body = body.size == 0 ? missing : HTLScriptPart(body),
		invalidation = invalidation.size == 0 ? missing : HTLScriptPart(invalidation),
		id = ismissing(id) ? _id : id
	)	
end

# ╔═╡ f79152d5-7dac-411e-8335-9eeafc989ba6
_convert_combine(h; id) = _combine(Iterators.map(x -> x isa HTLScript ? x : HTLScript(x), h); id)

# ╔═╡ 152c6530-4cf5-4541-8cde-fb88a4d539b6
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

# ╔═╡ dc1d32ef-1c9a-4703-93a6-b61676bc7b98
#=╠═╡
let
	a = HTLScript("console.log('asd')")
	b = HTLScript(@htl("<script>console.log('boh')</script>"), "console.log('lol')")
	script = combine_scripts([a,b, testt];id="test")
end
  ╠═╡ =#

# ╔═╡ f1f1fe15-2402-4c75-966a-c4cb1fb32b03
function print_invalidation(s::HTLScriptPart, addListeners::Bool = false)
	out = (s.buffer.size == 0 && !addListeners) ? "" : @htl("""
	<script>
	invalidation.then(() => {
		$(addListeners ? _events_listeners_invalidation : "")
		$s
	})
</script>
""")
	return HTLScriptPart(out)
end

# ╔═╡ 6bd8f9ad-b821-4997-abdc-ce6cf28238ba
print_invalidation(s::Missing, addListeners::Bool = false) = print_invalidation(HTLScriptPart(""), addListeners)

# ╔═╡ 882236d8-8bd9-4386-b3c7-00b7842a28cf
print_invalidation(s::HTLScript, addListeners::Bool = false) = print_invalidation(s.invalidation, addListeners)

# ╔═╡ 3ca7beb7-2a4d-448f-9c9a-c26c51fa83fb
function make_script(h::HTLScript, addListeners::Bool = h.body.addedEventListeners)  
	id = coalesce(h.id, h._id)
	@htl """
<script id='$id'>
	$(addListeners ? _events_listeners_preamble : "")
	$(h.body)
	$(addListeners ? _events_listeners_postamble : "")
	$(print_invalidation(h, addListeners))
</script>
"""
end

# ╔═╡ edc0857a-0a41-4952-b5e4-f0dfbc7c18e0
# This custom content method is used when interpolating inside the @htl macro (but outside of the script tag)
HypertextLiteral.content(s::HTLScript) = make_script(s)

# ╔═╡ ea3e8ec4-556d-452e-a136-1441804cc03e
#=╠═╡
make_script(testt)
  ╠═╡ =#

# ╔═╡ 7492b935-f4f4-415d-8305-9de40ca20382
# Show the formatted code in markdown as output
function formatted_code(s::HTLScript)
	buf = IOBuffer()
	show(buf, make_script(s))
	seekstart(buf)
	codestring = strip(read(buf, String), '\n')
	Markdown.MD(Markdown.Code("html", codestring))
end

# ╔═╡ b2d909ba-8d11-4718-9f7d-aa55506cbcde
# The show method is instead used for showing in the Pluto output.
function Base.show(io::IO, mime::MIME"text/html", s::HTLScript)
	show(io, mime, formatted_code(s))
end

# ╔═╡ bc82895d-ecf0-4d94-9071-0e8407c1b92d
"""
	struct HTLBypass
This struct is a simple wrapper around HypertextLiteral.Result intended to provide interpolation inside <script> tags as if writing the code that generated the result directly. 

This is intended for use inside Pluto notebooks to ease variable interpolation inside html element generated within <script> tags using the `html\`\`` command that is imported from Observable.

This way, one can generate the intended HTML inside other cells to more easily see the results and with support of nested @htl interpolation.

The struct only accepts the output of the @htl macro as an input.

On top of the interpolation, an object of type `HTLBypass` will simply show the wrapped `HypertextLiteral.Result` when shown with `MIME"text/html"`.

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

# ╔═╡ a80dd217-bd5f-463c-adcd-56722f4f3027
export HTLScriptPart, HTLBypass, HTLScript, combine_scripts

# ╔═╡ 0cf60bda-56b7-484d-9ae4-2a2c0cbad722
function Base.show(io::IO, ::MIME"text/javascript", s::HTLBypass)
	buf = s.buffer
	seekstart(buf)
	write(io, buf)
end

# ╔═╡ 3d1721ac-6e16-446a-8fcc-f1f941f04601
function Base.show(io::IO, mime::MIME"text/html", s::HTLBypass)
	show(io, mime, s.result)
end

# ╔═╡ 9efdecea-27b1-4e9e-892f-c5475ebcf9d5
function HypertextLiteral.print_script(io::IO, v::Union{AbstractVector{HTLScriptPart}, NTuple{N,HTLScriptPart} where N})
	foreach(v) do s
		show(io, MIME"text/javascript"(), s)
	end
end

# ╔═╡ 574a0054-2639-409a-ae2a-380aa187f4d2
#=╠═╡
bpasd = HTLBypass(@htl """
<div>This is $bplol</div>
""")
  ╠═╡ =#

# ╔═╡ fa270576-c7aa-4941-85d1-9ae3ccc697ea
#=╠═╡
@htl """
<script>
	let out = html`$bpasd`
	console.log(out)
	return out
</script>
"""
  ╠═╡ =#

# ╔═╡ 1451074e-dec7-4bfe-8ed2-a0855cbb35a8
md"""
## Test/Examples
"""

# ╔═╡ 9f328995-d47e-4f8e-85af-86fa7ce6b287
# ╠═╡ skip_as_script = true
#=╠═╡
s = HTLScript("console.log('asd')")
  ╠═╡ =#

# ╔═╡ 5c36a1d6-aa09-4cfc-b952-677a8867b2d8
#=╠═╡
_convert_combine((s for _ in 1:4)..., "console.log('lol')";id=missing)
  ╠═╡ =#

# ╔═╡ 579f4974-8afe-42ab-aee3-ce13a6f8dfaa
# ╠═╡ skip_as_script = true
#=╠═╡
dio = let
	a = HTLScript("console.log('asd1')", "console.log('lol1')", "lol")
	b = HTLScript("console.log('asd2');", "console.log('lol2')", "gesu")
	combine_scripts([a,b]; id = "lol")
end
  ╠═╡ =#

# ╔═╡ eb61e6ad-445f-49d1-b9f2-565a26d7e3fa
#=╠═╡
@htl "$dio"
  ╠═╡ =#

# ╔═╡ d794d3e8-9456-4f45-8902-abc59ee722f9
md"""
# General Functions
"""

# ╔═╡ 4ee62fb1-8f88-4219-8ec2-6e2a16794c7b
function formatted_js(s::Union{HTLScriptPart, HTLBypass})
	buf = s.buffer
	seekstart(buf)
	codestring = strip(read(buf, String), '\n')
	Markdown.MD(Markdown.Code("js", codestring))
end

# ╔═╡ 63b7eb42-e631-444b-a8c1-714ce9431e02
#=╠═╡
formatted_js(bpasd)
  ╠═╡ =#

# ╔═╡ 56e4ebcf-7b6a-415b-ab84-2d5f553e7e11
test = HTLBypass(@htl """
<div>
	CIAO
</div>
<scriptA>
	console.log(document.currentScript.environment)
	console.log(html)
</scriptA>
""")

# ╔═╡ 86b21ebc-f075-48db-9160-4a4551e56d0e
@htl """
<script>
	let asd = html`$test`
	let sp = asd.querySelector('scriptA')
	const sc = document.createElement('script')
	sc.innerHTML = sp.innerHTML
	sc.environment = {asd: 3, lol: 2}
	sp.replaceWith(sc)
	console.log(asd)
	return asd
</script>
"""

# ╔═╡ 8ab65fa7-a691-449b-8cb9-ac03788ed166
aaa = 1

# ╔═╡ 789200b5-ec0e-4442-9233-76403ce057b7
gesu = let
	aaa
	@htl """
<hltblock>
	<div>
		<script id='gesu'>
			const { reactive, html: thtml, watch } = await import('https://esm.sh/@arrow-js/core')

			const boh = document.create

			const children = {
				true: html`<div>TRUE`,
				false: html`<div>FALSE`
			}

			const data = reactive({
			value: true
			});
			
			const temp = thtml`
			<button @click="\${() => data.value = !data.value}">
			Toggle
			</button>
   			<span class='container'><span>
			`

			const out = html`<span>`
			temp(out)
			watch(() => {
				const toReplace = out.querySelector('span.container').firstChild
				toReplace.replaceWith(data.value ? children.true : children.false)
			})
			
			return out
		</script>
	</div>
</hltblock>
"""
end

# ╔═╡ 6dd8dd17-306c-4ab3-b0ca-be38a41e40b7
let
	aaa
	@htl """
$gesu
<script>
	const cell = currentScript.closest('pluto-cell')
	const htlblock = cell.querySelector('hltblock')
	const out = htlblock.firstElementChild
	console.log(out)
	htlblock.remove()
	return out
</script>
"""
end

# ╔═╡ 8ba70b18-75fe-4384-a104-ad836f32076e
# ╠═╡ skip_as_script = true
#=╠═╡
test_bind = @htl """
<script>	
	const { r,t,w } = await import('https://esm.sh/@arrow-js/core')
	const template = t`
 	<div @input="\${(e) => console.log('div input', e)}">MAGIC
  		<span @click="\${(e) => {
				e.target.value = "SPAN"
				console.log(e, e.target, e.target.value)
				e.target.dispatchEvent(new CustomEvent('input'))
		}}">SPAN
	`
	const out = currentScript.parentElement
	template(out)
</script>
"""
  ╠═╡ =#

# ╔═╡ 962b1c69-88f4-46ae-91c7-182f17c44f01
@htl """
<div class='gesu'>GESU
<span class = 'bambino'>BAMBINO</span></div>
	<script>
		const dv = currentScript.parentElement.querySelector('div.gesu')
		dv.addEventListener('input', (e) => {
			console.log('div input',e)
		})
		const sp = dv.querySelector('span')
		sp.addEventListener('click', e => {
			console.log('click')
			sp.dispatchEvent(new CustomEvent('input', {bubbles: true,}))
		})
	</script>
"""

# ╔═╡ 7cd6b44b-0249-46e3-b99f-e2c19db8d936
#=╠═╡
@bind boh test_bind
  ╠═╡ =#

# ╔═╡ 9b645f27-8f2b-4a15-937e-68a5d5487d55
#=╠═╡
(boh, rand())
  ╠═╡ =#

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
HypertextLiteral = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
PlutoExtras = "ed5d0301-4775-4676-b788-cf71e66ff8ed"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[compat]
BenchmarkTools = "~1.3.2"
HypertextLiteral = "~0.9.4"
PlutoExtras = "~0.6.1"
PlutoUI = "~0.7.48"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.9.0-beta4"
manifest_format = "2.0"
project_hash = "8592c55db71e5eed2d6d4ec606cb287eeea7f6c7"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "8eaf9f1b4921132a4cff3f36a1d9ba923b14a481"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.4"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "d9a9701b899b30332bbcb3e1679c41cce81fb0e8"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.3.2"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "eb7f0f8307f71fac7c606984ea5fb2817275d6e4"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.4"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.0.2+0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "c47c5fa4c5308f27ccaac35504858d8914e102f9"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.4"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "f7be53659ab06ddc986428d3a9dcc95f6fa6705a"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.2"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "3c837543ddb02250ef42f4738347454f95079d4e"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.3"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.3"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "7.84.0+0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.10.2+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MIMEs]]
git-tree-sha1 = "65f28ad4b594aebe22157d6fac869786a255b7eb"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "0.1.4"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "42324d08725e200c23d4dfb549e0d5d89dede2d2"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.10"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.0+0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.10.11"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.21+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.Parsers]]
deps = ["Dates", "SnoopPrecompile"]
git-tree-sha1 = "cceb0257b662528ecdf0b4b4302eb00e767b38e7"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.5.0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.9.0"

[[deps.PlutoDevMacros]]
deps = ["HypertextLiteral", "InteractiveUtils", "MacroTools", "Markdown", "Random", "Requires"]
git-tree-sha1 = "fa04003441d7c80b4812bd7f9678f721498259e7"
uuid = "a0499f29-c39b-4c5c-807c-88074221b949"
version = "0.5.0"

[[deps.PlutoExtras]]
deps = ["AbstractPlutoDingetjes", "HypertextLiteral", "InteractiveUtils", "Markdown", "OrderedCollections", "PlutoDevMacros", "PlutoUI"]
git-tree-sha1 = "8ec757f56d593959708dcd0b2d99b3c18cef428c"
uuid = "ed5d0301-4775-4676-b788-cf71e66ff8ed"
version = "0.6.1"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "efc140104e6d0ae3e7e30d56c98c4a927154d684"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.48"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.SnoopPrecompile]]
git-tree-sha1 = "f604441450a3c0569830946e5b33b78c928e1a85"
uuid = "66db9d55-30c0-4569-8b51-7e840670fc0c"
version = "1.0.1"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.9.0"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "Pkg", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "5.10.1+6"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.Tricks]]
git-tree-sha1 = "6bac775f2d42a611cdfcd1fb217ee719630c4175"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.6"

[[deps.URIs]]
git-tree-sha1 = "e59ecc5a41b000fa94423a578d29290c7266fc10"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.4.0"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.4.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.48.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+0"
"""

# ╔═╡ Cell order:
# ╠═3020de32-5b63-11ed-208f-1d2acb775b3b
# ╠═f2abae1a-5055-41a7-9330-04d514cd5fff
# ╠═a80dd217-bd5f-463c-adcd-56722f4f3027
# ╠═4ce0b2ab-3a7b-407e-a9d9-112e754bed82
# ╠═de7a0ea7-d67d-4754-843f-5731924bbd70
# ╟─af424bad-c980-4969-91b7-299d9f029691
# ╟─c5b66120-bb79-4603-ab2b-767bb684a4ae
# ╠═1aa9e236-eb68-43f5-afcd-1af51b71b34e
# ╠═b9291d89-8b30-40f6-b13f-4259f774adaa
# ╟─7dcfe459-c23b-4c4f-aa6b-5654f17934a0
# ╠═ac2b8e3e-1704-48c3-bc1f-9f12010b7e3c
# ╠═9efdecea-27b1-4e9e-892f-c5475ebcf9d5
# ╠═bb3b8e82-d556-4fbb-82b8-7e585d9d48ca
# ╠═7486654e-44fc-4fd7-9cc2-4b7b76f89a91
# ╟─0d427c09-73bd-463a-b6a1-919e18c1e794
# ╠═08495423-6628-4898-8e91-28cdbc7a418c
# ╠═25419f8c-9983-4cc4-9bda-f5f734482d7a
# ╠═13c02158-c8e2-40a2-ae05-9d9793a1009d
# ╠═0febddd9-6143-4b6c-ba64-b5d209c82603
# ╠═8552047f-192f-493a-8b1a-8d51f32f81ae
# ╟─3b5648d4-9421-461a-8aa2-34ce466f1a43
# ╟─71521eb4-95b0-4006-9239-bad66eb31a30
# ╠═bc82895d-ecf0-4d94-9071-0e8407c1b92d
# ╟─14a59245-b87d-4afd-a0d5-2e4bcf2a6409
# ╠═0cf60bda-56b7-484d-9ae4-2a2c0cbad722
# ╠═3d1721ac-6e16-446a-8fcc-f1f941f04601
# ╟─d2487a65-576c-4adf-b809-c1991a4c2106
# ╠═31df6aae-443e-42df-8710-9925453a7ed0
# ╠═92ad3e14-3c51-43a2-9772-720d205af75a
# ╠═574a0054-2639-409a-ae2a-380aa187f4d2
# ╠═63b7eb42-e631-444b-a8c1-714ce9431e02
# ╠═fa270576-c7aa-4941-85d1-9ae3ccc697ea
# ╟─2dc15e2a-9a8f-4ce9-b5e9-89ccd6e19468
# ╟─06bdb7d6-2963-4cf0-8e67-d3c7559bdacf
# ╠═69ebc2a6-3e0d-4050-865b-96128e3d2889
# ╠═1fcbc5cb-2d26-4951-ba93-df8e45588d67
# ╠═edc0857a-0a41-4952-b5e4-f0dfbc7c18e0
# ╠═b2d909ba-8d11-4718-9f7d-aa55506cbcde
# ╟─a4ef253a-6254-4fbf-abde-58f98295f7c7
# ╠═3b1e9a72-6550-4478-89f9-ccf1089eefdb
# ╠═e1e35e7a-efce-45c2-8f67-120755081179
# ╠═ae402f64-409d-4c95-94a3-778348514b0e
# ╠═36484b50-7f16-40c9-8c0e-25f66a85add4
# ╠═ea3e8ec4-556d-452e-a136-1441804cc03e
# ╠═dc1d32ef-1c9a-4703-93a6-b61676bc7b98
# ╟─a39f02b8-6681-42e4-a216-966e9884b91a
# ╠═152c6530-4cf5-4541-8cde-fb88a4d539b6
# ╠═f79152d5-7dac-411e-8335-9eeafc989ba6
# ╠═6605dfe7-299f-4a40-bae2-c90e19ac809c
# ╠═9bbd8ffd-3579-421e-a457-aace7bf66920
# ╠═699d5df1-357b-4e0e-a0a6-032c19f74415
# ╠═74cc8a48-7d18-4e08-a492-3240e37efdc8
# ╠═f1f1fe15-2402-4c75-966a-c4cb1fb32b03
# ╠═6bd8f9ad-b821-4997-abdc-ce6cf28238ba
# ╠═882236d8-8bd9-4386-b3c7-00b7842a28cf
# ╠═3ca7beb7-2a4d-448f-9c9a-c26c51fa83fb
# ╠═7492b935-f4f4-415d-8305-9de40ca20382
# ╟─1451074e-dec7-4bfe-8ed2-a0855cbb35a8
# ╠═9f328995-d47e-4f8e-85af-86fa7ce6b287
# ╠═5c36a1d6-aa09-4cfc-b952-677a8867b2d8
# ╠═579f4974-8afe-42ab-aee3-ce13a6f8dfaa
# ╠═eb61e6ad-445f-49d1-b9f2-565a26d7e3fa
# ╟─d794d3e8-9456-4f45-8902-abc59ee722f9
# ╠═4ee62fb1-8f88-4219-8ec2-6e2a16794c7b
# ╠═56e4ebcf-7b6a-415b-ab84-2d5f553e7e11
# ╠═86b21ebc-f075-48db-9160-4a4551e56d0e
# ╠═8ab65fa7-a691-449b-8cb9-ac03788ed166
# ╠═789200b5-ec0e-4442-9233-76403ce057b7
# ╠═6dd8dd17-306c-4ab3-b0ca-be38a41e40b7
# ╠═8ba70b18-75fe-4384-a104-ad836f32076e
# ╠═962b1c69-88f4-46ae-91c7-182f17c44f01
# ╠═7cd6b44b-0249-46e3-b99f-e2c19db8d936
# ╠═9b645f27-8f2b-4a15-937e-68a5d5487d55
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
