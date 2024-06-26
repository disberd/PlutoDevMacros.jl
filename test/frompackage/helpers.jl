import Pkg: Pkg, Types.Context, Types.EnvCache

function eval_with_load_path(ex, path)
    push!(LOAD_PATH, path)
    try
        eval(ex)
    finally
        pop!(LOAD_PATH)
    end
end

function instantiate_from_path(path::AbstractString)
    c = Context(;env = EnvCache(Base.current_project(path)))
    Pkg.instantiate(c; update_registry = false, allow_build = false, allow_autoprecomp = false)
end