export Remote, name

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
