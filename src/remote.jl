export name, isconnected, disconnect, url, set_url!, 
       push_url, set_push_url!, fetch_refspecs, push_refspecs, 
       add_fetch!, add_push!, clear_refspecs!, save!, rename!,
       update_tips!

function check_valid_url(url::String)
    if !bool(ccall((:git_remote_valid_url, :libgit2), Cint, (Ptr{Uint8},), url))
        throw(ArgumentError("Invalid URL : $url"))
    end
    return true
end

GitRemote(r::GitRepo, url::String) = begin
    check_valid_url(url)
    remote_ptr = Ptr{Void}[0]
    @check ccall((:git_remote_create_anonymous, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}, Ptr{Void}), remote_ptr, r, url, C_NULL)
    return GitRemote(remote_ptr[1])
end

function name(r::GitRemote)
    name_ptr = ccall((:git_remote_name, :libgit2), Ptr{Uint8}, (Ptr{Void},), r)
    return name_ptr != C_NULL ? bytestring(name_ptr) : nothing
end

function isconnected(r::GitRemote)
    return bool(ccall((:git_remote_connected, :libgit2), Cint, (Ptr{Void},), r))
end

function disconnect(r::GitRemote)
    @check ccall((:git_remote_disconnect, :libgit2), Cint, (Ptr{Void},), r)
    return r
end

# direction can be :fetch or :push
Base.connect(r::GitRemote, direction::Symbol) = begin
    local dir::Cint
    dir = direction == :fetch ? api.DIRECTION_FETCH :
          direction == :push  ? api.DIRECTION_PUSH  :
          throw(ArgumentError("direction can be :fetch or :push, got :$direction"))
    @check ccall((:git_remote_connect, :libgit2), Cint, (Ptr{Void}, Cint), r, dir)
    return r 
end

Base.connect(f::Function, r::GitRemote, direction::Symbol) = begin
    connect(r, direction)
    try
        f(r)
    finally
        disconnect(r)
    end
end

function url(r::GitRemote)
    url_ptr = ccall((:git_remote_url, :libgit2), Ptr{Uint8}, (Ptr{Void},), r)
    return url_ptr != C_NULL ? bytestring(url_ptr) : nothing
end

function set_url!(r::GitRemote, url::String)
    check_valid_url(url)
    @check ccall((:git_remote_set_url, :libgit2), Cint, (Ptr{Void}, Ptr{Uint8}), r, url)
    return r
end

function push_url(r::GitRemote)
    url_ptr = ccall((:git_remote_pushurl, :libgit2), Ptr{Uint8}, (Ptr{Void},), r)
    return url_ptr != C_NULL ? bytestring(url_ptr) : nothing
end

function set_push_url!(r::GitRemote, url::String)
    check_valid_url(url)
    @check ccall((:git_remote_set_pushurl, :libgit2), Cint, (Ptr{Void}, Ptr{Uint8}), r, url)
    return r
end

function fetch_refspecs(r::GitRemote) 
    sarr = StrArrayStruct()
    @check ccall((:git_remote_get_fetch_refspecs, :libgit2), Cint,
                  (Ptr{StrArrayStruct}, Ptr{Void}), &sarr, r)
    refs = Array(UTF8String, sarr.count)
    for i in 1:sarr.count
        refs[i] = utf8(bytestring(unsafe_load(sarr.strings, i)))
    end
    return refs
end

function push_refspecs(r::GitRemote)
    sarr = StrArrayStruct()
    @check ccall((:git_remote_get_push_refspecs, :libgit2), Cint,
                  (Ptr{StrArrayStruct}, Ptr{Void}), &sarr, r)
    refs = Array(UTF8String, sarr.count)
    for i in 1:sarr.count
        refs[i] = utf8(bytestring(unsafe_load(sarr.strings, i)))
    end
    return refs
end

function add_push!(r::GitRemote, ref::String)
    @check ccall((:git_remote_add_push, :libgit2), Cint, (Ptr{Void}, Ptr{Uint8}), r, ref) 
    return r
end

function add_fetch!(r::GitRemote, ref::String)
    @check ccall((:git_remote_add_fetch, :libgit2), Cint, (Ptr{Void}, Ptr{Uint8}), r, ref)
    return r
end

function clear_refspecs!(r::GitRemote)
    api.git_remote_clear_refspecs(r.ptr)
    return r
end

function save!(r::GitRemote)
    @check ccall((:git_remote_save, :libgit2), Cint, (Ptr{Void},), r)
    return r
end

function cb_remote_rename(refspec_name::Ptr{Uint8}, payload::Ptr{Void})
    errs = unsafe_pointer_to_objref(payload)::Array{UTF8String, 1}
    push!(errs, utf8(bytestring(refspec_name)))
    return api.GIT_OK
end

const c_cb_remote_rename = cfunction(cb_remote_rename, Cint, (Ptr{Uint8}, Ptr{Void}))

function rename!(r::GitRemote, name::String) 
    errs = UTF8String[]
    @check ccall((:git_remote_rename, :libgit2), Cint,
                  (Ptr{Void}, Ptr{Uint8}, Ptr{Void}, Any), r, name, c_cb_remote_rename, &errs)
    return length(errs) == 0 ? nothing : errs
end

type RemoteHead
    remoteid::Oid
    islocal::Bool
    localid::Union(Nothing, Oid)
    name::ByteString
end

RemoteHead(struct::RemoteHeadStruct) = RemoteHead(bool(ghead.islocal),
                                                  struct.id,
                                                  iszero(struct.lid)? nothing : lid,
                                                  struct.name == C_NULL ? "" : bytestring(struct.name))

Base.ls(r::GitRemote) = begin
    nheads = Csize_t[0]
    head_ptrs = Array(Ptr{Ptr{RemoteHeadStruct}}, 1)
    @check ccall((:git_remote_ls, :libgit2), Cint,
                 (Ptr{Ptr{RemoteHeadStruct}}, Ptr{Csize_t}, Ptr{Void}), head_ptrs, nheads, r)
    head_ptr = head_ptrs[1]
    remote_heads = RemoteHead[]
    for i in 1:nheads[1]
        ghead = unsafe_load(unsafe_load(head_ptr, i))::RemoteHeadStruct
        push!(remote_heads, RemoteHead(ghead))
    end
    return remote_heads
end

Base.download(r::GitRemote) = begin
    @check ccall((:git_remote_download, :libgit2), Cint, (Ptr{Void},), r)
    return r
end

#TODO: this should accept a signature and message
function update_tips!(r::GitRemote)
    @check ccall((:git_remote_update_tips, :libgit2), Cint,
                 (Ptr{Void}, Ptr{SignatureStruct}, Ptr{Uint8}), r, C_NULL, C_NULL)
    return r
end
