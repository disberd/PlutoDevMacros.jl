using Pkg.Types: EnvCache, write_project, Context, read_project, read_manifest, write_manifest,  Manifest, Project, PackageEntry

@kwdef mutable struct EnvCacheGroup
    "This is the EnvCache of the environment added by @fromparent to the LOAD_PATH"
    active::EnvCache = EnvCache(mktempdir(;prefix = "frompackage_"))
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

get_manifest_file(e::EnvCache) = e.manifest_file
get_project_file(e::EnvCache) = e.project_file
get_manifest(e::EnvCache) = e.manifest
get_project(e::EnvCache) = e.project
function get_entrypoint(e::EnvCache)
	pkg = e.pkg
	isnothing(pkg) && return ""
	entrypoint = joinpath(pkg.path, "src", pkg.name * ".jl")
end
get_active(ecg::EnvCacheGroup) = ecg.active
get_target(ecg::EnvCacheGroup) = ecg.target
get_notebook(ecg::EnvCacheGroup) = ecg.notebook

# This will potentially update the target (or notebook) project the ECG is pointing to
function maybe_update_envcache(projfile::String, ecg::EnvCacheGroup; notebook = false)
	f = notebook ? get_notebook : get_target
	env = f(ecg)
	if isnothing(env) || env.project_file != projfile
		setproperty!(ecg, notebook ? :notebook : :target, EnvCache(projfile))
		if !notebook
			# We changed the target so we force an update to ecg
			update_ecg!(ecg; force = true)
		end
	end
	return nothing
end

default_context(; io = default_pkg_io[]) = Context(; io)

function update_envcache!(e::EnvCache)
	e.project = read_project(e.project_file)
	e.manifest = read_manifest(e.manifest_file)
	return e
end
update_envcache!(::Nothing) = nothing
# Update the active EnvCache by eventually copying reduced project and manifest from the package EnvCache
function update_ecg!(ecg::EnvCacheGroup; force = false, context = default_context())
	# Update the target and notebook ecg 
    target = ecg |> get_target
	update_envcache!(target)
	update_envcache!(ecg |> get_notebook)
	active = get_active(ecg)
	active_manifest = active |> get_manifest_file
	active_project = active |> get_project_file
	target_manifest = target |> get_manifest_file
	if !isfile(target_manifest)
		@info "It seems that the target package does not have a manifest file. Trying to instantiate its environment"
		context.env = target
        Pkg.instantiate(context)
	end
	if !isfile(active_manifest) || !isfile(active_project)
		force = true
	end
	if !force
		active_mtime = mtime(active_manifest)
		target_mtime = mtime(target_manifest)
        # Force an update if the target manifest is newer
		force = force || active_mtime < target_mtime
	end
    force && update_active_from_target!(ecg; context)
    return ecg
end

# This function will forcibly copy the target project/manifest to the active project/manifest. It will also add the target package as dev dependency to the active project/manifest. This will not rely on calling `Pkg.develop` directly as this will trigger pre-compilation and we are not really interested in precompiling the environment every time. This function assumes that the target environment is already instantiated
function update_active_from_target!(ecg::EnvCacheGroup; context = default_context())
    active = get_active(ecg)
    target = get_target(ecg)
    target_project = get_project(target)
    # We create a deep copy of the project and manifest
    project = active.project = let p = target_project
        # We create a generator to copy the parts of the raw dict we are interested in.
        raw = (k => p.other[k] for k in ("deps", "weakdeps", "compat") if haskey(p.other,k)) |> Dict
        out = Project(raw) # Initialize empty project
        # Try to copy deps, compat, weakdeps and extensions from the target
        for key in (:deps, :weakdeps, :compat)
            target_val = getproperty(p, key)
            isempty(target_val) && continue
            setproperty!(out, key, deepcopy(target_val))
        end
        out
    end
    manifest = active.manifest = deepcopy(target |> get_manifest)
    # We make sure to make the path in the active manifest be absolute
    target_dir = dirname(get_manifest_file(target))
    for entry in values(manifest.deps)
        path = entry.path
        (path === nothing || isabspath(path)) && continue
        # Make it absolute w.r.t to 
        path = abspath(target_dir, path)
        entry.path = path
    end
    # We now add the target package to the active env
    @assert target_project.name !== nothing && target_project.uuid !== nothing "The project found at $(get_project_file(target)) is not a package, simple environments are currently not supported"
    # Add the target within the project
    project.deps[target_project.name] = target_project.uuid
    target_pe = PackageEntry(;
        name = target_project.name,
        uuid = target_project.uuid,
        path = target_dir,
        version = target_project.version,
        deps = deepcopy(target_project.deps),
        weakdeps = deepcopy(target_project.weakdeps),
        exts = deepcopy(target_project.exts),
    )
    manifest.deps[target_project.uuid] = target_pe
    # We write the project and manifest
    write_project(active)
    write_manifest(active)
    # We instantiate the active env
    context.env = active
    Pkg.resolve(context; update_registry = false)
    Pkg.instantiate(context; update_registry = false, allow_build = false, allow_autoprecomp = false)
end

# Function to get the package dependencies from the manifest
function target_dependencies(target::EnvCache)
	manifest_deps = target.manifest.deps
	proj_deps = target.project.deps
	direct = Dict{String, PkgInfo}()
	indirect = Dict{String, PkgInfo}()
	for (uuid,pkgentry) in manifest_deps
		(;name, version) = pkgentry
		d = haskey(proj_deps, name) ? direct : indirect
		d[name] = PkgInfo(name, uuid, version)
	end
	direct, indirect
end