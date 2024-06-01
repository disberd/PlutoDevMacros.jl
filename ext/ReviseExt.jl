module ReviseExt
using PlutoDevMacros.FromPackage: FromPackage, get_target_module, get_temp_module
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

function ReviseHelpers.add_revise_data(d::Dict)
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

# Enable Revise
function __init__()
    ReviseHelpers.REVISE_LOADED[] = true
end
end