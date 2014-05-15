module LibGit2

include("api.jl")

__threads_handle = nothing

type __LibGitThreadsHandle
    inited::Bool

    function __LibGitThreadsHandle()
        api.git_threads_init()
        h = new(true)
        finalizer(h, h -> begin
            if h.inited
                api.git_threads_shutdown()
                h.inited = false
            end
        end)
        return h
    end
end

function __init__()
    global __threads_handle
    if __threads_handle == nothing
	    __threads_handle = __LibGitThreadsHandle()
    end
end

include("macros.jl")
include("error.jl")
include("oid.jl")
include("types.jl")
include("object.jl")
include("config.jl")
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
