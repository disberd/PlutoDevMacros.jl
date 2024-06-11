const _stdlibs = first.(values(Pkg.Types.stdlibs()))

const default_pkg_io = Ref{IO}(devnull)

const TEMP_MODULE_NAME = :_FromPackage_TempModule_
const STORED_MODULE = Ref{Union{Module, Nothing}}(nothing)
const PREVIOUS_CATCHALL_NAMES = Set{Symbol}()
const macro_cell = Ref("undefined")
const manifest_names = ("JuliaManifest.toml", "Manifest.toml")

const created_modules = Dict{String, Module}()

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
	issamepath(ln.file, lnr.first.file) || return false # The file is not the same
	if ln.line >= lnr.first.line && ln.line <= lnr.last.line
		return true
	else
		return false
	end
end
_inrange(ln::LineNumberNode, ln2::LineNumberNode) = ln === ln2

# We define here the types to identify the imports
abstract type ImportType end
for name in (:FromParentImport, :FromPackageImport, :RelativeImport)
	expr = :(struct $name <: ImportType
		mod_name::Symbol
	end) 
	eval(expr)
end
# We define the FromDepsImport outside as it has custom fields
struct FromDepsImport <: ImportType
    mod_name::Symbol
    id::Base.PkgId
    direct::Bool
end
function FromDepsImport(mod_name, pkginfo::PkgInfo, direct::Bool)
    id = to_pkgid(pkginfo)
    FromDepsImport(mod_name, id, direct)
end

struct ProjectData
    file::String
    deps::Dict{String, Base.UUID}
    weakdeps::Dict{String, Base.UUID}
    extensions::Dict{String, Vector{String}}
    name::Union{Nothing, String}
    uuid::Union{Nothing, Base.UUID}
    version::Union{Nothing, VersionNumber}
    function ProjectData(file::AbstractString)
        raw = TOML.parsefile(file)
        deps = Dict{String, Base.UUID}()
        for (name, uuid) in get(raw, "deps", ())
            deps[name] = Base.UUID(uuid)
        end
        weakdeps = Dict{String, Base.UUID}()
        for (name, uuid) in get(raw, "weakdeps", ())
            weakdeps[name] = Base.UUID(uuid)
        end
        extensions = Dict{String, Vector{String}}()
        for (name, deps) in get(raw, "extensions", ())
            deps = deps isa String ? [deps] : deps
            extensions[name] = deps
        end
        name = get(raw, "name", nothing)
        uuid = get(raw, "uuid", nothing)
        isnothing(uuid) || (uuid = Base.UUID(uuid))
        version = get(raw, "version", nothing)
        isnothing(version) || (version = VersionNumber(version))
        new(file, deps, weakdeps, extensions, name, uuid, version)
    end
end

abstract type AbstractEvalController end

# We do not store the ECG directly inside as 
@kwdef mutable struct FromPackageController{package_name} <: AbstractEvalController
    "The entry point of the package"
    entry_point::String
    "The path that was provided to the macro call"
    target_path::String
    "The data of the project at of the target"
    project::ProjectData
    "The module where the macro was called"
    caller_module::Module
    "The current module where code evaluation is happening"
    current_module::Module = maybe_create_module()
    "The current line being evaluated"
    current_line::Union{Nothing, LineNumberNode} = nothing
    "The dict of manifest deps"
    manifest_deps::Dict{Base.UUID, PackageEntry} = Dict{Base.UUID, PackageEntry}()
    "The tracked names imported into the current module by `using` statements"
    using_names::Dict{Vector{Symbol}, Set{Symbol}} = Dict{Symbol, Set{Symbol}}()
    "The catchall names being imported by this package into the caller module"
    imported_catchall_names::Set{Symbol} = Set{Symbol}()
    "Specifies wheter the target was reached while including the module"
    target_location::Union{Nothing,LineNumberNode} = nothing
    "Flag that is set to true when the macro target is found in the code, to skip all the remaining expressions. It is set back to false after loading to allow extension handling."
    target_reached::Bool = false
    "Custom walk function"
    custom_walk::Function = identity
    "Loaded Extensions"
    loaded_extensions::Set{String} = Set{String}()
end

# Default constructor
function FromPackageController(target_path::String, caller_module::Module)
    @assert isabspath(target_path) "You can only construct the FromPackageController with an absolute path"
    # Find the project
    project_file = Base.current_project(target_path) 
    project_file isa Nothing && error("No project was found starting from $target_path")
    # Take the ecg to 
    ecg = default_ecg()
    # We set the notebook env, assuming it's the active environment
    maybe_update_envcache(Base.active_project(), ecg; notebook = true)
    # We set the target env, based on the identified proj file
    maybe_update_envcache(project_file, ecg; notebook = false)
    target_env = get_target(ecg)
    manifest_deps = target_env.manifest.deps
    project = ProjectData(project_file)
    entry_point = get_entrypoint(target_env)
    name = project.name
    p = FromPackageController{Symbol(name)}(;entry_point, manifest_deps, target_path, project, caller_module)
    p.custom_walk = custom_walk!(p)
    return p
end