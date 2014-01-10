export GitRemote, name, isconnected, disconnect, url, set_url!, push_url, set_push_url!,
       fetch_refspecs, push_refspecs, add_fetch!, add_push!, clear_refspecs! 

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
    
function url(r::GitRemote)
    @assert r.ptr != C_NULL
    url_ptr = api.git_remote_url(r.ptr)
    if url_ptr == C_NULL
        return nothing
    end
    return bytestring(url_ptr)
end

function set_url!(r::GitRemote, url::String)
    @assert r.ptr != C_NULL
    check_valid_url(url)
    @check api.git_remote_set_url(r.ptr, bytestring(url))
    return r
end

function push_url(r::GitRemote)
    @assert r.ptr != C_NULL
    url_ptr = api.git_remote_pushurl(r.ptr)
    if url_ptr == C_NULL
        return nothing
    end
    return bytestring(url_ptr)
end

function set_push_url!(r::GitRemote, url::String)
    @assert r.ptr != C_NULL
    check_valid_url(url)
    @check api.git_remote_set_pushurl(r.ptr, bytestring(url))
    return r
end

function fetch_refspecs(r::GitRemote) 
    @assert r.ptr != C_NULL
    sarr = api.GitStrArray()
    @check ccall((:git_remote_get_fetch_refspecs, api.libgit2), Cint,
                  (Ptr{api.GitStrArray}, Ptr{Void}),
                   &sarr, r.ptr)
    refs = Array(String, sarr.count)
    for i in 1:sarr.count
        refs[i] = bytestring(unsafe_load(sarr.strings, i))
    end
    return refs
end

function push_refspecs(r::GitRemote)
    @assert r.ptr != C_NULL
    sarr = api.GitStrArray()
    @check ccall((:git_remote_get_push_refspecs, api.libgit2), Cint,
                  (Ptr{api.GitStrArray}, Ptr{Void}),
                   &sarr, r.ptr)
    refs = Array(String, sarr.count)
    for i in 1:sarr.count
        refs[i] = bytestring(unsafe_load(sarr.strings, i))
    end
    return refs
end

function add_push!(r::GitRemote, ref::String)
    @assert r.ptr != C_NULL
    @check api.git_remote_add_push(r.ptr, bytestring(ref))
    return r
end

function add_fetch!(r::GitRemote, ref::String)
    @assert r.ptr != C_NULL
    @check api.git_remote_add_fetch(r.ptr, bytestring(ref))
    return r
end

function clear_refspecs!(r::GitRemote)
    @assert r.ptr != C_NULL
    api.git_remote_clear_refspecs(r.ptr)
    return r
end

function check_valid_url(s::String)
    if !bool(api.git_remote_valid_url(bytestring(s)))
        throw(ArgumentError("invalid url"))
    end
end

