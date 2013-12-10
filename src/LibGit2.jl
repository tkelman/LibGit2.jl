module LibGit2

export Oid,GitConfig

const libgit2 = "libgit2"

include("types.jl")
include("error.jl")
include("oid.jl")

end # module
