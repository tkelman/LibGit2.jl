module LibGit2

include("api.jl")
export api

include("error.jl")
include("types.jl")
include("oid.jl")
include("config.jl")
include("index.jl")
include("object.jl")
include("tree.jl")
include("signature.jl")
include("commit.jl")
include("tag.jl")
include("blob.jl")
include("patch.jl")
include("reference.jl")
include("odb.jl")
include("remote.jl")
include("note.jl")
include("diff.jl")
include("repository.jl")
include("walk.jl")

type __GitThreadsHandle
    
    function __GitThreadsHandle()
        h = new()
        finalizer(h, x -> api.git_threads_shutdown())
        return h
    end
end

const __threads_handle = begin
    api.git_threads_init()
    __GitThreadsHandle()
end

end # module
