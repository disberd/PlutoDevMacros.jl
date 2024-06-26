import Pluto: update_save_run!, update_run!, WorkspaceManager, ClientSession, ServerSession, Notebook, Cell, project_relative_path, SessionActions, load_notebook, Configuration

include(joinpath(@__DIR__, "helpers.jl"))

function noerror(cell; verbose=true)
    if cell.errored && verbose
        @show cell.output.body
    end
    !cell.errored
end

indirect_path = normpath(@__DIR__, "../TestIndirectExtension/")
direct_path = normpath(@__DIR__, "../TestDirectExtension/")
testpackage_path = joinpath(@__DIR__, "../TestPackage/")

instantiate_from_path(indirect_path)
instantiate_from_path(testpackage_path)

options = Configuration.from_flat_kwargs(; disable_writing_notebook_files=true, workspace_use_distributed_stdlib = true)

eval_in_nb(sn, expr) = WorkspaceManager.eval_fetch_in_workspace(sn, expr)