import Pkg
import Pkg.Types: EnvCache, write_project, Context, read_project, read_manifest

const _stdlibs = first.(values(Pkg.Types.stdlibs()))

const fromparent_module = Ref{Module}()
const macro_cell = Ref("undefined")
const manifest_names = ("JuliaManifest.toml", "Manifest.toml")

@kwdef mutable struct EnvCacheGroup
    "This is the EnvCache of the environment added by @fromparent to the LOAD_PATH"
    active::EnvCache = EnvCache(mktempdir())
    "This is the environment of the target of @fromparent"
    target::Union{Nothing, EnvCache} = nothing
    "This is the environment of the notebook calling @fromparent"
    notebook::Union{Nothing, EnvCache} = nothing
end

const DEFAULT_ECG = Ref{EnvCacheGroup}()
function default_ecg()
	if !isassigned(DEFAULT_ECG)
		DEFAULT_ECG[] = EnvCacheGroup()
	end
	return DEFAULT_ECG[]
end

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