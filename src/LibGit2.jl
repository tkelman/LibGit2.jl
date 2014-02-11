module LibGit2

include("api.jl")

type __GitThreadsHandle
    function __GitThreadsHandle()
        h = new()
        finalizer(h, _ -> api.git_threads_shutdown())
        return h
    end
end

api.git_threads_init()
const __threads_handle = __GitThreadsHandle()

include("error.jl")
include("types.jl")
include("macros.jl")
include("oid.jl")
include("config.jl")
include("object.jl")
include("tree.jl")
include("index.jl")
include("signature.jl")
include("commit.jl")
include("tag.jl")
include("blob.jl")
include("reference.jl")
include("odb.jl")
include("branch.jl")
include("note.jl")
include("remote.jl")
include("repository.jl")
include("diff.jl")
include("patch.jl")
include("walk.jl")

end # module
