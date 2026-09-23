using PlutoDevMacros
using Documenter
using DocumenterLandingPage
using Documenter.Remotes: GitHub

DocMeta.setdocmeta!(PlutoDevMacros, :DocTestSetup, :(using PlutoDevMacros); recursive=true)

makedocs(;
    modules=[PlutoDevMacros],
    authors="Alberto Mengali <disberd@gmail.com>",
    repo=GitHub("disberd/PlutoDevMacros.jl"),
    sitename="PlutoDevMacros.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        edit_link="master",
        assets=String[],
    ),
    plugins=[LandingPage()],
    # `is_notebook_local` has a docstring but is internal, so check only exported names.
    checkdocs=:exports,
    pages=[
        "Home" => "index.md",
        "Tutorials" => [
            "Develop your first package in a notebook" => "tutorials/first_package.md",
            "Develop a package extension in a notebook" => "tutorials/package_extension.md",
        ],
        "How-to guides" => [
            "Import specific names and submodules" => "howto/import_names.md",
            "Use packages that only the notebook needs" => "howto/notebook_only_packages.md",
            "Instantiate the environment" => "howto/instantiate_environment.md",
            "Load as a root module" => "howto/root_module.md",
            "Find loading problems" => "howto/loading_problems.md",
            "Run code only inside or outside the notebook" => "howto/notebook_only_code.md",
            "Add methods from the notebook" => "howto/addmethod.md",
        ],
        "Reference" => [
            "@frompackage and @fromparent" => "reference/frompackage.md",
            "Other exports" => "reference/other_exports.md",
        ],
        "Explanation" => [
            "How @frompackage loads the target package" => "explanation/loading.md",
            "How package extensions load" => "explanation/extensions.md",
        ],
    ],
)

# This controls whether or not deployment is attempted. It is based on the value
# of the `SHOULD_DEPLOY` ENV variable, which defaults to the `CI` ENV variable or
# false if not present. CI sets `CI=true`, also on pull request builds, which
# `deploydocs` needs to push the preview.
should_deploy = get(ENV, "SHOULD_DEPLOY", get(ENV, "CI", "false")) == "true"

if should_deploy
    @info "Deploying"

deploydocs(
    repo = "github.com/disberd/PlutoDevMacros.jl.git",
    devbranch = "master",
    # Pull request builds go to previews/PR<number>/. Documenter skips this
    # for pull requests from forks.
    push_preview = true,
)

end
