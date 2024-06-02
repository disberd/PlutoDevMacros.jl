module ReviseExt
using PlutoDevMacros.FromPackage: FromPackage, get_target_module, get_temp_module, should_log
using PlutoDevMacros.FromPackage.ReviseHelpers
using Revise: Revise, PkgData, pkgdatas, FileInfo, parse_source, wplock, srcfiles, has_writable_paths, CodeTracking, init_watching

# Helper function taken from code of `Revise.queue_includes!`
function track_file(file, mod; pkgdata)
    modexsigs = parse_source(file, mod)
    if modexsigs !== nothing
        fname = relpath(file, pkgdata)
        push!(pkgdata, fname => FileInfo(modexsigs))
    end
end

# This will modify target extension data in Revise to allow correct revision. This is because the modexsigs will be evaluated in Main.ExtName, while we want them to evaluate in the specific extension module
function ReviseHelpers._watch_package_revise(pkgid::Base.PkgId)
    pd = get(pkgdatas, pkgid, nothing)
    if pd === nothing
        @warn "Something is wrong. Could not find package data for extension $pkgid"
        return
    end
    m = Base.maybe_root_module(pkgid)
    is_dummy(_m) = parentmodule(_m) === Main && nameof(_m) === nameof(m)
    for fileinfo in pd.fileinfos
        modexsigs = fileinfo.modexsigs
        # The first key should be associated to Main, we delete that
        haskey(modexsigs, Main) && delete!(modexsigs, Main)
        # Then we change the module associated to the other expressions
        for (k, v) in modexsigs
            is_dummy(k) || continue
            # Delete the dummy
            delete!(modexsigs, k)
            # Add the exps to the correct module
            modexsigs[m] = v
        end
    end
    if has_writable_paths(pd)
        init_watching(pd, srcfiles(pd))
    end
    return
end

# Add pkgdata to Revise for the specific package
function create_pkgdata(package_dict::Dict)
    parent_module = get_temp_module()
    m = get_target_module(package_dict)
    id = Base.PkgId(m)
    pkgdata = PkgData(id)
    # We add the entrypoint
    entry_point = package_dict["file"]
    track_file(entry_point, parent_module; pkgdata)
    # We also track the various included files
    included_files = get(package_dict, "Included Files", String[])
    for file in included_files
        track_file(file, m; pkgdata)
    end
    return pkgdata
end

function ReviseHelpers._add_revise_data(d::Dict)
    @lock wplock begin
        # Create the PkgData
        pkgdata = create_pkgdata(d)
        id = pkgdata.info.id
        # update CodeTracking, as in queue_includes!
        CodeTracking._pkgfiles[id] = pkgdata.info
        # We now start watching and put the pkgdata inside the Revise.pkgdatas dict
        if has_writable_paths(pkgdata)
            init_watching(pkgdata, srcfiles(pkgdata))
        end
        pkgdatas[id] = pkgdata
    end
end

# This check if Revise is enough
function ReviseHelpers._should_reload_module(d::Dict)
    should_reload = if !isempty(Revise.queue_errors)
        # If we already have errors in the queue we just return true
        true
    else
        redirect_f = should_log() ? (f, args...) -> f() : Base.redirect_stderr 
        # Otherwise we try a Revise.revise
        redirect_f(Base.DevNull()) do
            Revise.revise()
        end
        !isempty(Revise.queue_errors)
    end
    if should_reload
        # We empty the queue and call revise
        empty!(Revise.queue_errors)
        Revise.revise()
    end
    return should_reload
end

# Enable Revise
function __init__()
    ReviseHelpers.REVISE_LOADED[] = true
end
end