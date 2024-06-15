import Pkg: Pkg, Types.Context, Types.EnvCache

function instantiate_and_import(ex, path)
    curr_proj = Base.active_project()
    Pkg.activate(path)
    Pkg.instantiate()
    Pkg.activate(curr_proj)
    push!(LOAD_PATH, path)
    eval(ex)
    pop!(LOAD_PATH)
end

function instantiate_from_path(path::AbstractString)
    c = Context(;env = EnvCache(Base.current_project(path)))
    Pkg.instantiate(c; update_registry = false, allow_build = false, allow_autoprecomp = false)
end