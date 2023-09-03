
# Show - text/javascript #
## ScriptContent ##
function Base.show(io::IO, ::MIME"text/javascript", s::ScriptContent)
	shouldskip(s) && return
	buf = s.buffer
	seekstart(buf)
	write(io, buf)
	println(io) # Add the newline
end

## SingleScript ##
function Base.show(io::IO, mime::MIME"text/javascript", s::SingleScript; pluto = true) 
	pluto = s isa PlutoScript ? true : false
	show(io, mime, CombinedScripts(s); pluto)
	nothing
end

## DualScript ##
function Base.show(io::IO, mime::MIME"text/javascript", ds::DualScript; pluto = true) 
	show(io, mime, CombinedScripts(ds); pluto)
	nothing
end

## CombinedScripts ##
# This function just iterates and print the javascript of an iterable containing DualScript elements
function _iterate_scriptcontents(io::IO, iter, selec::Function; pluto)
	mime = MIME"text/javascript"()
	# We cycle through the DualScript iterable
	for ds in iter
		s = inner_script(ds; pluto)
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
		s = inner_script(ds; pluto)
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

## text/javascript - HTLBypass ##
function Base.show(io::IO, ::MIME"text/javascript", s::HTLBypass)
	buf = s.buffer
	seekstart(buf)
	write(io, buf)
end

## text/javascript - ShowAsHTML ##
Base.show(io::IO, ::MIME"tex/javascript", sah::ShowAsHTML) = error("Objects of
type `ShowAsHTML` are not supposed to be shown with mime 'text/javascript'")

# Helper functions #
# This function will simply write into IO the html code of the script, including the <script> tag
function print_html(io::IO, s::ValidScript; pluto = true)
	pluto = if s isa SingleScript
		s isa PlutoScript ? true : false
	else
		pluto
	end
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

## Formatted Code ##
function formatted_code(s::ScriptContent; pluto=true)
	io = IOBuffer()
	show(io, MIME"text/javascript"(), s)
	seekstart(io)
	codestring = read(io, String)
	Markdown.MD(Markdown.Code("js", codestring))
end
function formatted_code(s::ValidScript; pluto=true)
	io = IOBuffer()
	print_html(io, s; pluto)
	seekstart(io)
	codestring = read(io, String)
	Markdown.MD(Markdown.Code("html", codestring))
end

# Show - text/html #
function Base.show(io::IO, mime::MIME"text/html", s::Union{ValidScript, ScriptContent}; pluto = is_inside_pluto(io))
	show(io, mime, formatted_code(s; pluto))
end

function Base.show(io::IO, mime::MIME"text/html", s::HTLBypass)
	show(io, mime, s.result)
end

#= Fix for Julia 1.10 
The `@generated` `print_script` from HypertextLiteral is broken in 1.10
See [issue 33](https://github.com/JuliaPluto/HypertextLiteral.jl/issues/33)
We have to also define a method for `print_script` to avoid precompilation errors
=#

HypertextLiteral.print_script(io::IO, val::ScriptContent) = show(io, MIME"text/javascript"(), val)
HypertextLiteral.print_script(io::IO, val::ValidScript) = error("Interpolation of `ValidScript` subtypes is not allowed within a script tag.
Use `ShowAsHTML` to generate a `<script>` node directly in HTML")