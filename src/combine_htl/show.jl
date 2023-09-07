
# Show - text/javascript #
## ScriptContent ##
function Base.show(io::IO, ::MIME"text/javascript", s::ScriptContent)
	shouldskip(s) && return
	println(io, s.content) # Add the newline
end

## SingleScript - DualScript ##
function Base.show(io::IO, mime::MIME"text/javascript", s::Union{SingleScript, DualScript}; pluto = plutodefault(s), kwargs...) 
	show(io, mime, CombinedScripts(s); pluto, kwargs...)
	nothing
end

## CombinedScripts ##
# This function just iterates and print the javascript of an iterable containing DualScript elements
function _iterate_scriptcontents(io::IO, iter, selec::Function, location::SingleDisplayLocation)
	mime = MIME"text/javascript"()
	# We cycle through the DualScript iterable
	for ds in iter
		s = inner_node(ds, location)
		sc = selec(s)
		shouldskip(sc) && continue
		show(io, mime, sc)
	end
	return nothing
end

function write_script(io::IO, contents::Vector{DualScript}, location::InsidePluto, ret_el = missing)
	# We cycle through the contents to write the body part
	_iterate_scriptcontents(io, contents, x -> x.body, location)
	# If there is no valid invalidation, we simply return
	if hasinvalidation(contents)
		# We add a separating newline
		println(io)
		# Start processing the invalidation
		println(io, "invalidation.then(() => {")
		_iterate_scriptcontents(io, contents, x -> x.invalidation, location)
		println(io, "})")
	end
	maybe_add_return(io, ret_el, location)
	return
end
function write_script(io::IO, contents::Vector{DualScript}, location::OutsidePluto, ret_el = missing)
	# We wrap everything in an async call as we want to use await
	println(io, "(async (currentScript) => {")
	# If the script should have the added Pluto compat packages we load them
	if add_pluto_compat(contents)
		println(io, """
	// Load the Pluto compat packages from the custom module
	const {DOM, Files, Generators, Promises, now, svg, html, require, _} = await import('$(LOCAL_MODULE_URL[])')
""")
	end
	# We cycle through the contents to write the body part
	_iterate_scriptcontents(io, contents, x -> x.body, location)
	# We print the returned element if provided
	maybe_add_return(io, ret_el, location)
	# We close the async function definition and call it with the currentScript
	println(io, "})(document.currentScript)")
	return
end

function Base.show(io::IO, mime::MIME"text/javascript", ms::CombinedScripts; pluto = is_inside_pluto(io))
	location = displaylocation(pluto)
	shouldskip(ms, location) && return
	# We add the listeners handlers if any of the script requires it
	contents = children(ms) |> copy # We copy to avoid mutating in the next line
	if haslisteners(ms, location)
		pushfirst!(contents, _events_listeners_preamble)
		push!(contents, _events_listeners_postamble)
	end
	write_script(io, contents, location, returned_element(ms, location))
end

## text/javascript - ShowAsHTML ##
Base.show(io::IO, ::MIME"text/javascript", sah::ShowWithPrintHTML) = error("Objects of
type `ShowWithPrintHTML` are not supposed to be shown with mime 'text/javascript'")

# Helper functions #
# Maybe add return
maybe_add_return(::IO, ::Missing, ::SingleDisplayLocation) = nothing
maybe_add_return(io::IO, code::String, ::InsidePluto) = println(io, "return $code")
maybe_add_return(io::IO, code::String, ::OutsidePluto) = print(io, "
	/* Code added by PlutoDevMacros to simulate script return */
	let _return_node_ = $code
	currentScript.insertAdjacentElement('beforebegin', _return_node_)
")

# This function will simply write into IO the html code of the script, including the <script> tag
function print_html(io::IO, s::Script{InsideAndOutsidePluto}; pluto = plutodefault(s))
	location = displaylocation(pluto)
	shouldskip(s, location) && return
	# We write the script tag
	id = script_id(s, location)
	println(io, "<script id='$id'>")
	# Print the content
	show(io, MIME"text/javascript"(), s; pluto)
	# Print the closing tag
	println(io, "</script>")
	return
end
print_html(io::IO, s::SingleScript; pluto = plutodefault(s)) = print_html(io, DualScript(s); pluto)
print_html(io::IO, s::AbstractString; kwargs...) = write(io, strip_nl(s))
print_html(io::IO, r::Union{HypertextLiteral.Result, HTML}; kwargs...) = show(io, MIME"text/html"(), r)
function print_html(io::IO, n::NonScript{L}; pluto = plutodefault(n)) where L <: SingleDisplayLocation 
	_pluto = plutodefault(n)
	# If the location doesn't match the provided kwarg we do nothing
	xor(pluto, _pluto) && return
	println(io, n.content)
	return
end
print_html(io::IO, dn::DualNode; pluto = plutodefault(dn)) = print_html(io, inner_node(dn, displaylocation(pluto)); pluto)
function print_html(io::IO, cn::CombinedNodes; pluto = plutodefault(cn))
	for n in cn.nodes
		print_html(io, n; pluto)
	end
end

## Formatted Code ##
function formatted_code(s::ScriptContent; kwargs...)
	codestring = s.content
	Markdown.MD(Markdown.Code("js", codestring))
end
function formatted_code(n::Node; pluto=plutodefault(n))
	io = IOBuffer()
	print_html(io, n; pluto)
	seekstart(io)
	codestring = read(io, String)
	Markdown.MD(Markdown.Code("html", codestring))
end

# Show - text/html #
function Base.show(io::IO, mime::MIME"text/html", s::Union{Node, ScriptContent}; pluto = is_inside_pluto(io))
	if pluto
		show(io, mime, formatted_code(s))
	else
		s isa ScriptContent ? show(io, s) : print_html(io, s; pluto)
	end
	return
end

function Base.show(io::IO, ::MIME"text/html", s::ShowWithPrintHTML; pluto = plutodefault(io, s))
	print_html(io, s.el; pluto)
end

HypertextLiteral.content(n::Node) = HypertextLiteral.Render(ShowWithPrintHTML(n, InsideAndOutsidePluto()))

#= Fix for Julia 1.10 
The `@generated` `print_script` from HypertextLiteral is broken in 1.10
See [issue 33](https://github.com/JuliaPluto/HypertextLiteral.jl/issues/33)
We have to also define a method for `print_script` to avoid precompilation errors
=#

HypertextLiteral.print_script(io::IO, val::ScriptContent) = show(io, MIME"text/javascript"(), val)
HypertextLiteral.print_script(io::IO, v::Vector{ScriptContent}) = for s in v
	HypertextLiteral.print_script(io, s)
end

HypertextLiteral.print_script(::IO, ::Script) = error("Interpolation of `Script` subtypes is not allowed within a script tag.
Use `make_node` to generate a `<script>` node directly in HTML")