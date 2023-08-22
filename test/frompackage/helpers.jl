import Pkg

function instantiate_and_import(ex, path)
    curr_proj = Base.active_project()
    Pkg.activate(path)
    Pkg.instantiate()
    Pkg.activate(curr_proj)
    push!(LOAD_PATH, path)
    eval(ex)
    pop!(LOAD_PATH)
end