module LibGit2

export Oid, GitConfig, GitRepositry, Repository, libgit2_version

const libgit2 = "libgit2"

function libgit2_version()
    #TODO: version is not exported 
    major = cglobal((:LIBGIT2_VERSION_MAJOR, :libgit2), Cint)
    minor = cglobal((:LIBGIT2_VERSION_MINOR, :libgit2), Cint)
    rev   = cglobal((:LIBGIT2_VERSION_REVISION, :libgit2), Cint)
    @show (major, minor, rev)
end

include("types.jl")
include("error.jl")
include("oid.jl")
include("repository.jl")

end # module
