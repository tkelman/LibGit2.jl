module LibGit2

include("api.jl")
include("error.jl")
include("types.jl")
include("oid.jl")
include("index.jl")
include("repository.jl")
include("signature.jl")

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
