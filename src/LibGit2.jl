module LibGit2

include("api.jl")
export api

include("error.jl")
include("types.jl")
include("oid.jl")
include("index.jl")
include("object.jl")
include("tree.jl")
include("signature.jl")
include("commit.jl")
include("blob.jl")
include("repository.jl")

type GitThreadsHandle
    
    function GitThreadsHandle()
        h = new()
        finalizer(h, x -> api.git_threads_shutdown())
        return h
    end
end

const __threads_handle = begin
    api.git_threads_init()
    GitThreadsHandle()
end

end # module
