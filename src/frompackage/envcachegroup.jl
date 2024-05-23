using Pkg.Types: EnvCache, write_project, Context, read_project, read_manifest, write_manifest

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

function extensions_dir(env::EnvCache)
	pkg = env.pkg
	isnothing(pkg) && return nothing
	ext_dir = joinpath(pkg.path, "ext")
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


function update_envcache!(e::EnvCache)
	e.project = read_project(e.project_file)
	e.manifest = read_manifest(e.manifest_file)
	return e
end
update_envcache!(::Nothing) = nothing
# Update the active EnvCache by eventually copying reduced project and manifest from the package EnvCache
function update_ecg!(ecg::EnvCacheGroup; force = false, io::IO = devnull)
	c = Context(; io)
	# Update the target and notebook ecg 
	update_envcache!(ecg |> get_target)
	update_envcache!(ecg |> get_notebook)
	active = get_active(ecg)
	active_manifest = active |> get_manifest_file
	active_project = active |> get_project_file
	target_manifest = get_target(ecg) |> get_manifest_file
	if !isfile(target_manifest)
		@info "It seems that the target package does not have a manifest file. Trying to instantiate its environment"
		c.env = ecg.target
        Pkg.instantiate(c)
	end
	if !isfile(active_manifest) || !isfile(active_project)
		force = true
	end
	if !force
		active_mtime = mtime(active_manifest)
		target_mtime = mtime(ecg |> get_target |> get_manifest_file)
        # Force an update if the target manifest is newer
		force = force || active_mtime < target_mtime
	end
    if force
        # This path will update the active Env by copying the project and manifest from the target
		mkpath(dirname(active_manifest))
		# We copy a reduced version of the project, only with deps, weakdeps and compat
        pd = ecg.target.project.other
        ad = Dict{String, Any}((k => pd[k] for k in ("deps", "compat", "weakdeps") if haskey(pd, k)))
        write_project(ad, active_project)
        # We copy the Manifest
        copy_manifest(target_manifest, active_manifest)
        # We call instantiate
		update_envcache!(ecg.active)
		c.env = ecg.active
        Pkg.instantiate(c)
    end
    return ecg
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

# This function will copy the manifest from the target environment to the active environment, taking care of making any relative path (i.e. for dev or added packages) absolute.
function copy_manifest(target::AbstractString, active::AbstractString)
    # We construct a TOML dict from the target manifest
    raw_dict = TOML.parsefile(target)
    deps = raw_dict["deps"]
    for depval in values(deps)
        for d in depval
            path = get(d, "path", nothing)
            isnothing(path) && continue
            if !isabspath(path)
                abs_path = abspath(dirname(target), path)
                d["path"] = abs_path
            end
        end
    end
    write_manifest(raw_dict, active)
    return nothing
end