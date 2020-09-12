using Documenter, libCEED

makedocs(sitename="libCEED.jl Docs",
         format=Documenter.HTML(prettyurls=false),
         pages=[
             "Home" => "index.md",
             "Ceed Objects" => [
                "Ceed.md",
                "ElemRestriction.md",
                "Basis.md",
                "QFunction.md",
                "Operator.md"
             ],
             "Utilities" => [
                "Misc.md",
                "Globals.md",
                "Quadrature.md",
             ],
             "C interface" => ["C.md"]
         ])
