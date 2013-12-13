module LibGit2

# inlcude wrapper libwrapgit
include(joinpath("..", "deps", "ext.jl"))

include("api.jl")
include("error.jl")

function init_threads()
    @check ccall((:git_threads_init, :libgit2), Cint, ())
end
init_threads()

function libgit_version()
    major = Cint[0]
    minor = Cint[0]
    patch = Cint[0]
    ccall((:libgit2_version, libwrapgit), Cint,
          (Ptr{Cint}, Ptr{Cint}, Ptr{Cint}),
          major, minor, patch)
    return VersionNumber(major[1], minor[1], patch[1])
end

include("types.jl")
include("oid.jl")
include("index.jl")
include("repository.jl")
include("signature.jl")

end # module
