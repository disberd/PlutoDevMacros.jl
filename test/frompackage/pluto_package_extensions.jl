using Test
import Pkg
import Pkg.Types: Context, EnvCache, PackageSpec
import Pluto: update_save_run!, update_run!, WorkspaceManager, ClientSession, ServerSession, Notebook, Cell, project_relative_path, SessionActions, load_notebook, Configuration

indirect_path = normpath(@__DIR__, "../TestIndirectExtension/")
direct_path = normpath(@__DIR__, "../TestDirectExtension/")

# We add PlotlyExtensionsHelper manually in the test as it's not registered
c = Context(;env = EnvCache(joinpath(direct_path, "Project.toml")))
let
    url = "https://github.com/disberd/PlotlyExtensionsHelper.jl" 
    rev = "main"
    Pkg.add(c, [
        PackageSpec(; url, rev, repo = Pkg.Types.GitRepo(;source = url, rev) )
    ])
end

function noerror(cell; verbose=true)
    if cell.errored && verbose
        @show cell.output.body
    end
    !cell.errored
end


options = Configuration.from_flat_kwargs(; disable_writing_notebook_files=true, workspace_use_distributed_stdlib = true)
eval_in_nb(sn, expr) = WorkspaceManager.eval_fetch_in_workspace(sn, expr)

@testset "Indirect Extension" begin
    ss = ServerSession(; options)
    path = joinpath(indirect_path, "test_extension.jl")
    nb = SessionActions.open(ss, path; run_async=false)
    @test eval_in_nb((ss, nb), :method_present) === true
    for cell in nb.cells
        @test noerror(cell)
    end
    SessionActions.shutdown(ss, nb)
end

@testset "Direct Extensions" begin
    ss = ServerSession(; options)
    path = joinpath(direct_path, "test_extension.jl")
    nb = SessionActions.open(ss, path; run_async=false)
    @test eval_in_nb((ss, nb), :standard_extension_output) === "Standard Extension works!"
    @test eval_in_nb((ss, nb), :weird_extension_output) === "Weird Extension name works!"
    @test eval_in_nb((ss, nb), :(p isa PlutoPlot)) === true
    for cell in nb.cells
        @test noerror(cell)
    end
    SessionActions.shutdown(ss, nb)
end
