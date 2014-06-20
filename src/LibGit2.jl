module LibGit2

if isfile(joinpath(dirname(dirname(@__FILE__)),"deps","deps.jl"))
    include("../deps/deps.jl")
else
    error("LibGit2 not properly installed. Please run Pkg.build(\"LibGit2\")")
end

type LibGitThreadsHandle

    function LibGitThreadsHandle()
        handle = new()
        finalizer(handle, h -> begin
            err = ccall((:git_threads_shutdown, libgit2), Cint, ())
            if err != zero(Cint)
                error("error uninitalizing LibGit2 library")
            end
        end)
        return handle
    end
end

function __init__()
    err = ccall((:git_threads_init, libgit2), Cint, ())
    if err != zero(Cint)
        error("could not initialize LibGit2 library")
    end
end

__threads_handle = LibGitThreadsHandle()

include("api.jl")
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
include("walker.jl")

end # module
