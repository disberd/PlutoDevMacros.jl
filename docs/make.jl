using PlutoDevMacros
using Documenter

DocMeta.setdocmeta!(PlutoDevMacros, :DocTestSetup, :(using PlutoDevMacros); recursive=true)

makedocs(;
    modules=[PlutoDevMacros],
    authors="Alberto Mengali <disberd@gmail.com>",
    repo="https://github.com/disberd/PlutoDevMacros.jl/blob/{commit}{path}#{line}",
    sitename="PlutoDevMacros.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "@frompackage/@fromparent Guide" => "frompackage.md",
    ],
)

# This controls whether or not deployment is attempted. It is based on the value
# of the `SHOULD_DEPLOY` ENV variable, which defaults to the `CI` ENV variables or
# false if not present.
should_deploy = get(ENV,"SHOULD_DEPLOY", get(ENV, "CI", "") === "true")

if should_deploy
    @info "Deploying"

deploydocs(
    repo = "github.com/disberd/PlutoDevMacros.jl.git",
)

end