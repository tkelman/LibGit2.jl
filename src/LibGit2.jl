module LibGit2

include("api.jl")

__threads_handle = nothing

type __GitThreadsHandle
    function __GitThreadsHandle()
        h = new()
        finalizer(h, _ -> api.git_threads_shutdown())
        return h
    end
end

function init()
    global __threads_handle
    if __threads_handle == nothing
        api.git_threads_init()
	__threads_handle = __GitThreadsHandle()
    end
    return
end

init()

include("error.jl")
include("macros.jl")
include("oid.jl")
include("types.jl")
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
