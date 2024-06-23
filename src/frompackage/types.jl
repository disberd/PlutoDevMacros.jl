
const default_pkg_io = Ref{IO}(devnull)

const TEMP_MODULE_NAME = :_FromPackage_TempModule_
const EMPTY_PIPE = Pipe()
const STDLIBS_DATA = Dict{String,Base.UUID}()
for (uuid, (name, _)) in Pkg.Types.stdlibs()
    STDLIBS_DATA[name] = uuid
end

# This structure is just a placeholder that is put in place of expressions that are to be removed when parsing a file
struct RemoveThisExpr end

# This structure is used to manipulate import statements
mutable struct ImportStatementData
    modname_path::Vector{Symbol}
    imported_names::Vector{Symbol}
    imported_fullnames::Vector{Vector{Symbol}}

    function ImportStatementData(modname_path::Vector{Symbol}, imported_names::Vector{Symbol} = Symbol[], imported_fullnames::Vector{Vector{Symbol}} = map(x -> Symbol[x], imported_names))
        new(modname_path, imported_names, imported_fullnames)
    end
end
ImportStatementData(s::Symbol, args...) = ImportStatementData([s], args...)
ImportStatementData(s::NTuple{<:Any, Symbol}, args...) = ImportStatementData(collect(s), args...)

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
    current_module::Union{Module, Nothing} = nothing
    "The current line being evaluated"
    current_line::Union{Nothing, LineNumberNode} = nothing
    "The dict of manifest deps"
    manifest_deps::Dict{Base.UUID, String} = Dict{Base.UUID, String}()
    "The tracked names imported into the current module by `using` statements"
    using_expressions::Dict{Module, Set{Expr}} = Dict{Module, Set{Expr}}()
    "Specifies wheter the target was reached while including the module"
    target_location::Union{Nothing,LineNumberNode} = nothing
    "Module of where the target is included if the target is found. Nothing otherwise"
    target_module::Union{Nothing, Module} = nothing
    "Flag that is set to true when the macro target is found in the code, to skip all the remaining expressions. It is set back to false after loading to allow extension handling."
    target_reached::Bool = false
    "Custom walk function"
    custom_walk::Function = identity
    "Loaded Extensions"
    loaded_extensions::Set{String} = Set{String}()
end
const CURRENT_FROMPACKAGE_CONTROLLER = Ref{FromPackageController}()

# Default constructor
function FromPackageController(target_path::AbstractString, caller_module::Module)
    # We remove pluto cell id in the name if present
    target_path = cleanpath(target_path)
    @assert isabspath(target_path) "You can only construct the FromPackageController with an absolute path"
    # Find the project
    project_file = Base.current_project(target_path) 
    project_file isa Nothing && error("No project was found starting from $target_path")
    project = ProjectData(project_file)
    @assert project.name !== nothing "@frompackage can only be called with a Package as target.\nThe pointed project does not have `name` and `uuid` fields"
    entry_point = joinpath(dirname(project_file), "src", project.name * ".jl")
    name = project.name
    manifest_deps = generate_manifest_deps(project_file)
    p = FromPackageController{Symbol(name)}(;entry_point, manifest_deps, target_path, project, caller_module)
    p.custom_walk = custom_walk!(p)
    return p
end