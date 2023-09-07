
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

function Base.show(io::IO, mime::MIME"text/javascript", ms::CombinedScripts; pluto = is_inside_pluto(io), id = script_id(ms, displaylocation(pluto)))
	location = displaylocation(pluto)
	shouldskip(ms, location) && return
	# We add the listeners handlers if any of the script requires it
	contents = children(ms) |> copy
	if haslisteners(ms, location)
		pushfirst!(contents, _events_listeners_preamble)
		push!(contents, _events_listeners_postamble)
	end
	# We maybe have to add the currentScript object
	maybe_add_pluto_compat(io, ms, location, id)
	# We cycle through the contents to write the body part
	_iterate_scriptcontents(io, contents, x -> x.body, location)

	# If we are outside pluto or there is no valid invalidation, we skip the rest
	if !pluto || !hasinvalidation(contents)
		# We print the eventual return statement
		maybe_print_return(io, ms, location)
		return
	end

	println(io)
	# We add a separating newline
	# Start processing the invalidation
	println(io, "invalidation.then(() => {")
	_iterate_scriptcontents(io, ms.scripts, x -> x.invalidation, location)
	println(io, "})")
	# We print the eventual return statement
	maybe_print_return(io, ms, location)
	return
end

## text/javascript - ShowAsHTML ##
Base.show(io::IO, ::MIME"tex/javascript", sah::ShowWithPrintHTML) = error("Objects of
type `ShowAsHTML` are not supposed to be shown with mime 'text/javascript'")

# Helper functions #
#= 
This function will add the currentScript, observable stdlib and lodash to the
available names in the current cell when displayed outside pluto (and when the
add_pluto_compat for the script is true)
=#
maybe_add_pluto_compat(::IO, ::Script, ::InsidePluto, ::String) = return
maybe_add_pluto_compat(::IO, ::PlutoScript, ::OutsidePluto, ::String) = return
function maybe_add_pluto_compat(io::IO, s::Script, ::OutsidePluto, id::String)
	if add_pluto_compat(s)
		# We can't use currentScript so we extract it knowing that we have the id
		println(io, """
	/* ### Beginning of Pluto Compat code added by PlutoDevMacros ### */

	const currentScript = document.querySelector("script[id='$id']")
	async function make_library() {
		// We fix the same versions used by Pluto
        let { Library } = await import("https://esm.sh/@observablehq/stdlib@3.3.1")
        let { default: lodash} = await import("https://esm.sh/lodash-es@4.17.20")
        let library = new Library()
        return {
            DOM: library.DOM,
            Files: library.Files,
            Generators: library.Generators,
            Promises: library.Promises,
            now: library.now,
            svg: library.svg(),
            html: library.html(),
            require: library.require(),
            _: lodash,
        }
	}
	const { DOM, Files, Generators, Promises, now, svg, html, require, _} = await make_library()

	/* ### End of Pluto Compat code added by PlutoDevMacros ### */
""")
	end
end
# Maybe print return
function maybe_print_return(io::IO, ds::Union{DualScript, CombinedScripts}, location::SingleDisplayLocation)
	code = returned_element(ds, location)
	code === missing && return
	print_return(io, code, location)
end
print_return(io::IO, code::String, ::InsidePluto) = println(io, "return $code")
print_return(io::IO, code::String, ::OutsidePluto) = print(io, "
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
	if pluto
		println(io, "<script id='$id'>")
	else
		println(io, "<script type='module' id='$id'>")
	end
	# Print the content
	show(io, MIME"text/javascript"(), s; pluto, id)
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