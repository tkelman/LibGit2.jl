export name, isconnected, disconnect, url, set_url!, 
       push_url, set_push_url!, fetch_refspecs, push_refspecs, 
       add_fetch!, add_push!, clear_refspecs!, save!, rename!,
       update_tips!

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

function save!(r::GitRemote)
    @assert r.ptr != C_NULL
    @check api.git_remote_save(r.ptr)
    return r
end

function cb_remote_rename(refspec_name::Ptr{Cchar}, payload::Ptr{Void})
    errs = unsafe_pointer_to_objref(payload)::Array{String, 1}
    push!(errs, bytestring(refspec_name))
    return api.GIT_OK
end

const c_cb_remote_rename = cfunction(cb_remote_rename, Cint, (Ptr{Cchar}, Ptr{Void}))

function rename!(r::GitRemote, name::String) 
    @assert r.ptr != C_NULL
    errs = String[]
    @check ccall((:git_remote_rename, api.libgit2), Cint,
                  (Ptr{Void}, Ptr{Cchar}, Ptr{Void}, Any),
                  r.ptr, bytestring(name), c_cb_remote_rename, &errs)
    return length(errs) == 0 ? nothing : errs
end

type RemoteHead
    islocal::Bool
    oid::Oid
    loid::Union(Nothing, Oid)
    name::String
end

RemoteHead(ghead::api.GitRemoteHead) = begin
    oid_arr = Array(Uint8, api.OID_RAWSZ)
    @get_oid_fieldnames(oid_arr, ghead, oid)
    oid = Oid(oid_arr)
    
    loid_arr = Array(Uint8, api.OID_RAWSZ)
    @get_oid_fieldnames(loid_arr, ghead, loid)
    loid = Oid(loid_arr)
    
    return RemoteHead(bool(ghead.islocal),
                      oid,
                      iszero(loid)? nothing : loid,
                      ghead.name == C_NULL ? "" : bytestring(ghead.name))
end

Base.ls(r::GitRemote) = begin
    @assert r.ptr != C_NULL
    nheads = Csize_t[0]
    head_ptrs = Array(Ptr{Ptr{api.GitRemoteHead}}, 1)
    err = api.git_remote_ls(head_ptrs, nheads, r.ptr)
    head_ptr = head_ptrs[1]
    remote_heads = RemoteHead[]
    for i in 1:nheads[1]
        ghead = unsafe_load(unsafe_load(head_ptr, i))
        push!(remote_heads, RemoteHead(ghead))
    end
    return remote_heads
end

Base.download(r::GitRemote) = begin
    @assert r.ptr != C_NULL
    @check api.git_remote_download(r.ptr)
    return r
end

#TODO: this should accept a signature and message
function update_tips!(r::GitRemote)
    @assert r.ptr != C_NULL
    @check ccall((:git_remote_update_tips, api.libgit2), Cint,
                 (Ptr{Void}, Ptr{api.GitSignature}, Ptr{Cchar}),
                 r.ptr, C_NULL, C_NULL)
    return r
end

function check_valid_url(s::String)
    if !bool(api.git_remote_valid_url(bytestring(s)))
        throw(ArgumentError("invalid url"))
    end
end

