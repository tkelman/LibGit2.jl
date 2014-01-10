export GitRemote, name, isconnected, disconnect

type GitRemote
    ptr::Ptr{Void}

    function GitRemote(ptr::Ptr{Void})
        @assert ptr != C_NULL
        r = new(ptr)
        finalizer(r, free!)
        return r
    end
end

free!(r::GitRemote) = begin
    if r.ptr != C_NULL
        api.git_remote_free(r.ptr)
        r.ptr = C_NULL
    end
end

function name(r::GitRemote)
    @assert r.ptr != C_NULL
    name_ptr = api.git_remote_name(r.ptr)
    return name_ptr != C_NULL ? bytestring(name_ptr) : nothing
end

function isconnected(r::GitRemote)
    @assert r.ptr != C_NULL
    return bool(api.git_remote_connected(r.ptr))
end

function disconnect(r::GitRemote)
    @assert r.ptr != C_NULL
    api.git_remote_disconnect(r.ptr)
    return nothing
end

Base.connect(r::GitRemote, dir::Symbol) = begin
    direction = zero(Cint)
    if dir == :fetch
        direction = api.DIRECTION_FETCH
    elseif dir == :push
        direction = api.DIRECTION_PUSH
    else
        throw(ArgumentError("dir can be :fetch or :push"))
    end
    @check api.git_remote_connect(r.ptr, direction)
    return nothing
end

Base.connect(f::Function, r::GitRemote, dir::Symbol) = begin
    connect(r, dir)
    try
        f(r)
    finally
        disconnect(r)
    end
end
    

