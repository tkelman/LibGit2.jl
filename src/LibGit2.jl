module LibGit2

include("api.jl")
include("error.jl")
include("types.jl")
include("oid.jl")
include("index.jl")
include("repository.jl")
include("signature.jl")

api.git_threads_init()

end # module
