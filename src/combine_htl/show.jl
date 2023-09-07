
# Helpers #
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

function write_script(io::IO, contents::Vector{DualScript}, location::InsidePluto; returns = missing, kwargs...)
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
	maybe_add_return(io, returns, location)
	return
end
function write_script(io::IO, contents::Vector{DualScript}, location::OutsidePluto; returns = missing, only_contents = false)
	# We wrap everything in an async call as we want to use await
	only_contents || println(io, "(async (currentScript) => {")
	# If the script should have the added Pluto compat packages we load them
	if add_pluto_compat(contents) && !only_contents
		println(io, """
	// Load the Pluto compat packages from the custom module
	const {DOM, Files, Generators, Promises, now, svg, html, require, _} = await import('$(LOCAL_MODULE_URL[])')
""")
	end
	# We cycle through the contents to write the body part
	_iterate_scriptcontents(io, contents, x -> x.body, location)
	# We print the returned element if provided
	maybe_add_return(io, returns, location)
	# We close the async function definition and call it with the currentScript
	only_contents || println(io, "})(document.currentScript)")
	return
end


## print_javascript ##
# ScriptContent
function print_javascript(io::IO, sc::ScriptContent; kwargs...)
	shouldskip(sc) && return
	println(io, sc.content) # Add the newline
end
# Script
function print_javascript(io::IO, s::Union{SingleScript, DualScript}; pluto =
plutodefault(s), kwargs...) 
	print_javascript(io, CombinedScripts(s); pluto, kwargs...)
end
# CombinedScripts
function print_javascript(io::IO, ms::CombinedScripts; pluto =
plutodefault(io), only_contents = false)
	location = displaylocation(pluto)
	shouldskip(ms, location) && return
	# We add the listeners handlers if any of the script requires it
	contents = children(ms) |> copy # We copy to avoid mutating in the next line
	if haslisteners(ms, location) && !only_contents
		pushfirst!(contents, _events_listeners_preamble)
		push!(contents, _events_listeners_postamble)
	end
	write_script(io, contents, location; 
	returns = returned_element(ms, location), only_contents)
end

## Maybe add return ##
maybe_add_return(::IO, ::Missing, ::SingleDisplayLocation) = nothing
maybe_add_return(io::IO, name::String, ::InsidePluto) = println(io, "return $name")
maybe_add_return(io::IO, name::String, ::OutsidePluto) = print(io, "
	/* code added by PlutoDevMacros to simulate script return */
	currentScript.insertAdjacentElement('beforebegin', $name)
")

# This function will simply write into IO the html code of the script, including the <script> tag
# This is applicable for CombinedScripts and DualScript
function print_html(io::IO, s::Script{InsideAndOutsidePluto}; pluto = plutodefault(s), only_contents = false)
	location = displaylocation(pluto)
	shouldskip(s, location) && return
	# We write the script tag
	id = script_id(s, location)
	println(io, "<script id='$id'>")
	# Print the content
	print_javascript(io, s; pluto, only_contents)
	# Print the closing tag
	println(io, "</script>")
	return
end
print_html(io::IO, s::SingleScript; pluto = plutodefault(s), kwargs...) = print_html(io, DualScript(s); pluto, kwargs...)
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
function to_string(n::Union{ScriptContent,Node}, ::M; kwargs...) where M <: MIME
	f = if M === MIME"text/javascript"
		print_javascript
	elseif M === MIME"text/html"
		print_html
	else
		error("Unsupported mime $M provided as input")
	end
	io = IOBuffer()
	f(io, n; kwargs...)
	code = String(take!(io))
	return code
end
function formatted_code(s::Union{Script, ScriptContent}, mime::MIME"text/javascript"; kwargs...)
	codestring = to_string(s, mime; kwargs...)
	Markdown.MD(Markdown.Code("js", codestring))
end
function formatted_code(n::Node, mime::MIME"text/html"; kwargs...)
	codestring = to_string(n, mime; kwargs...)
	Markdown.MD(Markdown.Code("html", codestring))
end
# Default MIMEs
default_mime(::ScriptContent) = MIME"text/javascript"()
default_mime(::Node) = MIME"text/html"()
formatted_code(s::Union{ScriptContent, Node}; kwargs...) = formatted_code(s, default_mime(s); kwargs...)
# Versions returning functions
formatted_code(mime::MIME; kwargs...) = x -> formatted_code(x, mime; kwargs...)
# This forces just the location using the DisplayLocation type
formatted_code(l::SingleDisplayLocation; kwargs...) = x -> formatted_code(x; pluto = plutodefault(l), kwargs...)
formatted_code(; kwargs...) = x -> formatted_code(x; kwargs...) # Default no argument version

formatted_contents(args...; kwargs...) = formatted_code(args...; kwargs..., only_contents = true)


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


# Show - text/javascript #
function Base.show(io::IO, ::MIME"text/javascript", s::Union{ScriptContent, Script})
	print_javascript(io, s)
end

Base.show(::IO, ::MIME"text/javascript", ::T; pluto = true) where T <: Union{ShowWithPrintHTML, NonScript} =
error("Objects of type `$T` are not supposed to be shown with mime 'text/javascript'")

# Show - text/html #
Base.show(io::IO, mime::MIME"text/html", sc::ScriptContent; pluto = true) = 
show(io, mime, formatted_code(sc))

Base.show(io::IO, ::MIME"text/html", s::Node; pluto = is_inside_pluto(io)) =
print_html(io, s; pluto)

Base.show(io::IO, ::MIME"text/html", s::ShowWithPrintHTML; pluto = plutodefault(io, s)) = 
print_html(io, s.el; pluto)