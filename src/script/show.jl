## HTLScriptPart ##

# This is to have a custom printing when inside a <script> tag within @htl 
function Base.show(io::IO, ::MIME"text/javascript", s::HTLScriptPart)
	buf = s.buffer
	seekstart(buf)
	println(io, buf)
end

# Show the formatted code in markdown as output
function Base.show(io::IO, mime::MIME"text/html", s::HTLScriptPart)
	buf = s.buffer
	seekstart(buf)
	codestring = strip(read(buf, String), '\n')
	show(io, mime, Markdown.MD(Markdown.Code("js", codestring)))
end
function Base.show(io::IO, mime::MIME"text/html", v::Union{AbstractVector{HTLScriptPart}, NTuple{N,HTLScriptPart} where N})
	outbuf = IOBuffer()
	foreach(v) do s
		buf = s.buffer
		seekstart(buf)
		println(outbuf, buf)
	end
	codestring = String(take!(outbuf))
	show(io, mime, Markdown.MD(Markdown.Code("js", strip(codestring, '\n'))))
end

## HTLBypass ##

function Base.show(io::IO, ::MIME"text/javascript", s::HTLBypass)
	buf = s.buffer
	seekstart(buf)
	write(io, buf)
end
function Base.show(io::IO, mime::MIME"text/html", s::HTLBypass)
	show(io, mime, s.result)
end

## HTLScript ##
function Base.show(io::IO, mime::MIME"text/javascript", s::HTLScript; pluto = is_inside_pluto(io))
	show(io, mime, HTLMultiScript(s); pluto)
end

# The show method is instead used for showing in the Pluto output.
function Base.show(io::IO, mime::MIME"text/html", s::HTLScript)
	show(io, mime, formatted_code(s))
end

## HTLMultiScript ##
function Base.show(io::IO, mime::MIME"text/javascript", ms::HTLMultiScript; pluto = is_inside_pluto(io))
	has_listeners = haslisteners(ms)
	scripts = if has_listeners
		vcat(
			_events_listeners_preamble,
			ms.scripts,
			_events_listeners_postamble,
		)
	else
		ms.scripts
	end
	no_write_yet = true
	# We do write the body parts first
	for s in scripts
		if pluto || s.show_outside_pluto
			if no_write_yet
				no_write_yet = false
			else
				println(io)
			end
			show(io, mime, s.body)
		end
	end
	# If we are inside pluto, we also write invalidation
	pluto || return
	println(io, "invalidation.then(() => {")
	for s in scripts
		show(io, mime, s.invalidation)
	end
	println(io, "})")
end


## MakeScript ##
function Base.show(io::IO, ::MIME"text/html", mks::MakeScript; pluto = is_inside_pluto(io))
	script = mks.script
	shouldskip(script) && return
	id = script_id(script)
	println(io, "<script id=$id>")
	show(io, MIME"text/javascript"(), script; pluto)
	println(io, "</script>")
	return
end

## Generic ##

function formatted_js(s::Union{HTLScriptPart, HTLBypass})
	buf = s.buffer
	seekstart(buf)
	codestring = strip(read(buf, String), '\n')
	Markdown.MD(Markdown.Code("js", codestring))
end

# Show the formatted code in markdown as output
function formatted_code(s::HTLScript; kwargs...)
	buf = IOBuffer()
	show(buf, make_script(s;kwargs...))
	seekstart(buf)
	codestring = strip(read(buf, String), '\n')
	Markdown.MD(Markdown.Code("html", codestring))
end

#= Fix for Julia 1.10 
The `@generated` `print_script` from HypertextLiteral is broken in 1.10
See [issue 33](https://github.com/JuliaPluto/HypertextLiteral.jl/issues/33)
We have to also define a method for `print_script` to avoid precompilation errors
=#

HypertextLiteral.print_script(io::IO, val::Union{HTLScript, HTLBypass, HTLScriptPart, HTLMultiScript}) = show(io, MIME"text/javascript"(), val)