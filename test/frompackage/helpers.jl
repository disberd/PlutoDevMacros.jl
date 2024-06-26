import Pkg
import Pkg.Types: Context, EnvCache, PackageSpec, GitRepo 

function eval_with_load_path(ex, path)
    push!(LOAD_PATH, path)
    try
        eval(ex)
    finally
        pop!(LOAD_PATH)
    end
end

function dev_package_in_proj(path::AbstractString)
    package_path = @__DIR__
    package_path_names = splitpath(package_path)
    test_idxs = findall(==("test"), package_path_names)
    for idx in test_idxs
        package_path = joinpath(package_path_names[1:idx])
        "runtests.jl" in readdir(package_path) && break
    end
    package_path = dirname(package_path)
    c = Context(;env = EnvCache(Base.current_project(path)))
    ps = PackageSpec(;
        repo = GitRepo(;source = package_path)
    )
    Pkg.develop(c, [ps])
end

function instantiate_from_path(path::AbstractString)
    c = Context(;env = EnvCache(Base.current_project(path)))
    Pkg.instantiate(c; update_registry = false, allow_build = false, allow_autoprecomp = false)
end