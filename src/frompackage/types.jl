const _stdlibs = first.(values(Pkg.Types.stdlibs()))

const fromparent_module = Ref{Module}()
const macro_cell = Ref("undefined")
const manifest_names = ("JuliaManifest.toml", "Manifest.toml")

struct PkgInfo 
	name::Union{Nothing, String}
	uuid::Base.UUID
	version::Union{Nothing, VersionNumber}
end

# LineNumberRange. This are used for skipping parts of the target package
struct LineNumberRange
	first::LineNumberNode
	last::LineNumberNode
	function LineNumberRange(ln1::LineNumberNode, ln2::LineNumberNode)
		@assert ln1.file === ln2.file "A range of LineNumbers can only be specified with LineNumbers from the same file"
		first, last = ln1.line <= ln2.line ? (ln1, ln2) : (ln2, ln1)
		new(first, last)
	end
end
LineNumberRange(ln::LineNumberNode) = LineNumberRange(ln, ln)
LineNumberRange(file::AbstractString, first::Int, last::Int) = LineNumberRange(
	LineNumberNode(first, Symbol(file)),
	LineNumberNode(last, Symbol(file))
)
## Inclusion in LinuNumberRange
function _inrange(ln::LineNumberNode, lnr::LineNumberRange)
	ln.file === lnr.first.file || return false # The file is not the same
	if ln.line >= lnr.first.line && ln.line <= lnr.last.line
		return true
	else
		return false
	end
end
_inrange(ln::LineNumberNode, ln2::LineNumberNode) = ln === ln2

# We define here the types to identify the imports
abstract type ImportType end
for name in (:FromParentImport, :FromPackageImport, :FromDepsImport, :RelativeImport)
	expr = :(struct $name <: ImportType
		mod_name::Symbol
	end) 
	eval(expr)
end