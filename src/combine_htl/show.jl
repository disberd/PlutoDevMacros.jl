
# Show - text/javascript #
## ScriptContent ##
function Base.show(io::IO, ::MIME"text/javascript", s::ScriptContent)
	shouldskip(s) && return
	println(io, s.content) # Add the newline
end

## SingleScript - DualScript ##
function Base.show(io::IO, mime::MIME"text/javascript", s::Union{SingleScript, DualScript}; pluto = plutodefault(s)) 
	show(io, mime, CombinedScripts(s); pluto)
	nothing
end

## CombinedScripts ##
# This function just iterates and print the javascript of an iterable containing DualScript elements
function _iterate_scriptcontents(io::IO, iter, selec::Function; pluto)
	mime = MIME"text/javascript"()
	# We cycle through the DualScript iterable
	for ds in iter
		s = inner_node(ds; pluto)
		sc = selec(s)
		shouldskip(sc) && continue
		show(io, mime, sc)
	end
	return nothing
end

function Base.show(io::IO, mime::MIME"text/javascript", ms::CombinedScripts; pluto = is_inside_pluto(io))
	shouldskip(ms; pluto) && return
	# We add the listeners handlers if any of the script requires it
	contents = haslisteners(ms; pluto) ? [
		_events_listeners_preamble,
		ms.scripts...,
		_events_listeners_postamble,
	] : ms.scripts

	# We cycle through the contents to write the body part
	_iterate_scriptcontents(io, contents, x -> x.body; pluto)

	# If we are outside pluto or there is no valid invalidation, we skip the rest
	pluto && any(ms.scripts) do ds
		s = inner_node(ds; pluto)
		!shouldskip(s.invalidation)
	end || return # If we are not inside pluto, we just stop here

	println(io)
	# We add a separating newline
	# Start processing the invalidation
	println(io, "invalidation.then(() => {")
	_iterate_scriptcontents(io, ms.scripts, x -> x.invalidation; pluto)
	println(io, "})")

	return nothing
end

## text/javascript - ShowAsHTML ##
Base.show(io::IO, ::MIME"tex/javascript", sah::ShowWithPrintHTML) = error("Objects of
type `ShowAsHTML` are not supposed to be shown with mime 'text/javascript'")

# Helper functions #
# This function will simply write into IO the html code of the script, including the <script> tag
function print_html(io::IO, s::Script{InsideAndOutsidePluto}; pluto = plutodefault(s))
	shouldskip(s; pluto) && return
	# We write the script tag
	id = script_id(s; pluto)
	if pluto || !show_as_module(s)
		println(io, "<script id='$id'>")
	else
		println(io, "<script type='module' id='$id'>")
	end
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
print_html(io::IO, dn::DualNode; pluto = plutodefault(dn)) = print_html(io, inner_node(dn; pluto); pluto)
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

function Base.show(io::IO, mime::MIME"text/html", s::ShowWithPrintHTML; pluto = is_inside_pluto(io))
	print_html(io, s.el; pluto)
end

HypertextLiteral.content(n::Node) = HypertextLiteral.Render(ShowWithPrintHTML(n))

#= Fix for Julia 1.10 
The `@generated` `print_script` from HypertextLiteral is broken in 1.10
See [issue 33](https://github.com/JuliaPluto/HypertextLiteral.jl/issues/33)
We have to also define a method for `print_script` to avoid precompilation errors
=#

HypertextLiteral.print_script(io::IO, val::ScriptContent) = show(io, MIME"text/javascript"(), val)
HypertextLiteral.print_script(io::IO, v::Vector{ScriptContent}) = for s in v
	HypertextLiteral.print_script(io, s)
end

HypertextLiteral.print_script(io::IO, val::Script) = error("Interpolation of `Script` subtypes is not allowed within a script tag.
Use `make_node` to generate a `<script>` node directly in HTML")