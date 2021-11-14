using Powerful
using Documenter

DocMeta.setdocmeta!(Powerful, :DocTestSetup, :(using Powerful); recursive=true)

makedocs(;
    modules=[Powerful],
    authors="Hantao Cui <cuihantao@gmail.com>",
    repo="https://github.com/sensl/Powerful.jl/blob/{commit}{path}#{line}",
    sitename="Powerful.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://sensl.gitlab.io/Powerful.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)
