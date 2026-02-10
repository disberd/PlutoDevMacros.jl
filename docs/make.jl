using PlutoDevMacros
using Documenter
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
    pages=[
        "Home" => "index.md",
        "@frompackage/@fromparent" => Any[
            "Introduction" => "frompackage/introduction.md",
            "Basic Use" => "frompackage/basic_use.md",
            "Supported import statements" => "frompackage/import_statements.md",
            "Skipping Package Parts" => "frompackage/skipping_parts.md",
            "Use with PlutoPkg" => "frompackage/use_with_plutopkg.md",
            "Package Extensions" => "frompackage/package_extensions.md",
            "Custom Settings" => "frompackage/custom_settings.md",
        ],
        "Other Exports" => "other_functions.md",
        # "PlutoHTLCombine" => "htl_combine.md",
    ],
    warnonly=[:cross_references, :missing_docs]
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
