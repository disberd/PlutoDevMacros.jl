
import Pluto: update_save_run!, update_run!, WorkspaceManager, ClientSession,
ServerSession, Notebook, Cell, project_relative_path, SessionActions,
load_notebook, Configuration
using PlutoDevMacros

function noerror(cell; verbose=true)
    if cell.errored && verbose
        @show cell.output.body
    end
    !cell.errored
end

@testset "Outside Pluto" begin
    @current_pluto_cell_id() === ""
    @current_pluto_notebook_file() === ""
    @only_in_nb(3) === nothing
    @only_out_nb(3) === 3

    asd(x::Int) = 3
    @addmethod asd(x::Float64) = 4.0
    @addmethod asd(x::String) = "LOL" * string(asd(1))
    @test asd(3.0) === 4.0
    @test asd("ASD") === "LOL3"
    @test PlutoDevMacros.is_notebook_local() === false
end

options = Configuration.from_flat_kwargs(; disable_writing_notebook_files=true, workspace_use_distributed_stdlib = true)
srcdir = normpath(@__DIR__, "./notebooks")
eval_in_nb(sn, expr) = WorkspaceManager.eval_fetch_in_workspace(sn, expr)

@testset "basics test notebook" begin
    ss = ServerSession(; options)
    path = joinpath(srcdir, "basics.jl")
    nb = SessionActions.open(ss, path; run_async=false)
    for cell in nb.cells
        @test noerror(cell)
    end
    SessionActions.shutdown(ss, nb)
end