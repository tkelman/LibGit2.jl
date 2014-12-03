module LibGit2

if isfile(joinpath(dirname(dirname(@__FILE__)),"deps","deps.jl"))
    include("../deps/deps.jl")
else
    error("LibGit2 not properly installed. Please run Pkg.build(\"LibGit2\")")
end

# libgit threads must be initialized before any library calls,
# these functions are a no-op if libgit is built without thread support
function __init__()
    err = ccall((:git_threads_init, libgit2), Cint, ())
    err == 0 || error("error initializing LibGit2 module")
    atexit() do
        ccall((:git_threads_shutdown, libgit2), Cint, ())
    end
end

include("constants.jl")
include("error.jl")
include("oid.jl")
include("types.jl")
include("object.jl")
include("config.jl")
include("tree.jl")
include("index.jl")
include("signature.jl")
include("cred.jl")
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

# debug tracing / this needs libgit to be built with tracing support
function cb_trace(level::Cint, msg::Ptr{UInt8})
    println("LibGit2.jl Trace [$level] => $(bytestring(msg))")
    return
end

const c_cb_trace = cfunction(cb_trace, Void, (Cint, Ptr{UInt8}))

function set_trace(level::Symbol)
    l = level === :none  ? 0 :
        level === :fatal ? 1 :
        level === :error ? 2 :
        level === :warn  ? 3 :
        level === :info  ? 4 :
        level === :debug ? 5 :
        level === :trace ? 6 :
        throw(ArgumentError("unknown trace level :$level"))
    @check ccall((:git_trace_set, libgit2), Cint, (Cint, Ptr{Void}), l, c_cb_trace)
    return
end

end # module
