module LibGit2

export Oid, GitConfig,GitRepository, Repository,
       isbare, isempty, workdir

include("error.jl")

function init_threads()
    @check ccall((:git_threads_init, :libgit2), Cint, ())
end
init_threads()

function libgit2_version()
    #TODO: version is not exported 
    major = cglobal((:LIBGIT2_VERSION_MAJOR, :libgit2), Cint)
    minor = cglobal((:LIBGIT2_VERSION_MINOR, :libgit2), Cint)
    rev   = cglobal((:LIBGIT2_VERSION_REVISION, :libgit2), Cint)
    @show (major, minor, rev)
end

include("types.jl")
include("oid.jl")
include("repository.jl")

end # module
