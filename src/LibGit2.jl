module LibGit2
#=
# libgit threads must be initialized before any library calls,
# these functions are a no-op if libgit is built without thread support
if isfile(joinpath(dirname(dirname(@__FILE__)),"deps","deps.jl"))
    include("../deps/deps.jl")
else
    error("LibGit2 not properly installed. Please run Pkg.build(\"LibGit2\")")
end
=#

function __init__()
    err = ccall((:git_threads_init, :libgit2), Cint, ())
    if err != zero(Cint)
        error("error initializing LibGit2 module")
    end
end

# when the module is GC'd, call git_threads_shutdown
type LibGitHandle
    LibGitHandle() = begin
        handle = new()
        finalizer(handle, h -> begin
            err = ccall((:git_threads_shutdown, :libgit2), Cint, ())
            if err != zero(Cint)
                error("error uninitalizing LibGit2 module")
            end
        end)
        return handle
    end
end

const __threads_handle = LibGitHandle()

include("constants.jl")
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
include("repository.jl")
include("remote.jl")
include("diff.jl")
include("patch.jl")
include("walker.jl")

end # module
