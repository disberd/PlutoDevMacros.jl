
# This structure is just a placeholder that is put in place of expressions that are to be removed when parsing a file
struct RemoveThisExpr end

@kwdef mutable struct FromPackageOptions
    "Specifies whether the target package shall be registered as root module while loading"
    rootmodule::Bool = false
    "Symbol to select whether the target environment should be instantiated or resolved before loading the package"
    manifest::Symbol = :none
    "Flag to enable verbose logging of FromPackage functions"
    verbose::Bool = false
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
    "Custom walk function"
    custom_walk::Function = identity
    "Loaded Extensions"
    loaded_extensions::Set{String} = Set{String}()
    "Names imported by the macro"
    imported_names::Set{Symbol} = Set{Symbol}()
    "ID of the cell where the macro was called, nothing if not called from Pluto"
    cell_id::Union{Nothing, Base.UUID} = nothing
    "Options to customize loading"
    options::FromPackageOptions = FromPackageOptions()
    "Time when the controller was created"
    nloads::Int = -1
end

# Default constructor
function FromPackageController(target_path::AbstractString, caller_module::Module; cell_id = nothing)
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
    # We parse the cell_id if string
    cell_id = cell_id isa AbstractString ? (isempty(cell_id) ? nothing : Base.UUID(cell_id)) : cell_id
    p = FromPackageController{Symbol(name)}(;entry_point, target_path, project, caller_module, cell_id)
    p.custom_walk = custom_walk!(p)
    return p
end