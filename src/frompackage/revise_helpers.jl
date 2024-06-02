module ReviseHelpers
using ..FromPackage: get_stored_module

const REVISE_LOADED = Ref{Bool}(false)

# This will be called whenever a package is loaded
function watch_package(pkgid::Base.PkgId)
    is_revise_loaded() || return
    parent = get(Base.EXT_PRIMED, pkgid, nothing)
    # If this is not an extension, we skip
    parent !== nothing || return
    m = get_stored_module()
    m !== nothing || return
    target_id = Base.PkgId(m)
    parent == target_id || return
    @info "Found extension" pkgid
    _watch_package_revise(pkgid)
end
function _watch_package_revise end

is_revise_loaded() = REVISE_LOADED[]

# This will tell if the target module should be reloaded. It willl always return true if revise is not loaded. If Revise is loaded, only reload if Revise is not enough to update
function should_reload_module(d::Dict)
    # First we check if the current module is the same as the target, and return true if not
    m = get_stored_module()
    isnothing(m) && return true
    id = Base.PkgId(m)
    Base.UUID(d["uuid"]) === id.uuid || return true
    # We now check if Revise should be checked
    !is_revise_loaded() || return _should_reload_module(d)
end
function _should_reload_module end

function _add_revise_data end
function maybe_add_revise_data(d)
    lines_to_skip = get(d,"Lines to Skip",())
    # If we are skipping lines, we don't use revise as it readds those
    isempty(lines_to_skip) || return
    is_revise_loaded() && _add_revise_data(d)
    return
end

function __init__()
    push!(Base.package_callbacks, watch_package)
end
end