export name, connected, disconnected, disconnect, url, set_url!,
       push_url, set_push_url!, fetch_refspecs, push_refspecs,
       add_fetch!, add_push!, clear_refspecs!, save!, rename!,
       update_tips!

function check_valid_url(url::AbstractString)
    if !bool(ccall((:git_remote_valid_url, libgit2), Cint, (Ptr{UInt8},), url))
        throw(ArgumentError("Invalid URL : $url"))
    end
    return true
end

GitRemote(r::GitRepo, url::AbstractString) = begin
    check_valid_url(url)
    remote_ptr = Ptr{Void}[0]
    @check ccall((:git_remote_create_anonymous, libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{UInt8}, Ptr{Void}), remote_ptr, r, url, C_NULL)
    return GitRemote(remote_ptr[1])
end

Base.show(io::IO, r::GitRemote) = begin
    write(io, "GitRemote(\"$(name(r))\" @ $(url(r)))")
end

function name(r::GitRemote)
    name_ptr = ccall((:git_remote_name, libgit2), Ptr{UInt8}, (Ptr{Void},), r)
    return name_ptr != C_NULL ? bytestring(name_ptr) : nothing
end

connected(r::GitRemote) = bool(ccall((:git_remote_connected, libgit2), Cint, (Ptr{Void},), r))
disconnected(r::GitRemote) = !connected(r)

function disconnect(r::GitRemote)
    @check ccall((:git_remote_disconnect, libgit2), Cint, (Ptr{Void},), r)
    return r
end

# direction can be :fetch or :push
Base.connect(r::GitRemote, direction::Symbol) = begin
    local dir::Cint
    dir = direction == :fetch ? GitConst.DIRECTION_FETCH :
          direction == :push  ? GitConst.DIRECTION_PUSH  :
          throw(ArgumentError("direction can be :fetch or :push, got :$direction"))
    @check ccall((:git_remote_connect, libgit2), Cint, (Ptr{Void}, Cint), r, dir)
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
    url_ptr = ccall((:git_remote_url, libgit2), Ptr{UInt8}, (Ptr{Void},), r)
    return url_ptr != C_NULL ? bytestring(url_ptr) : nothing
end

function set_url!(r::GitRemote, url::AbstractString)
    check_valid_url(url)
    @check ccall((:git_remote_set_url, libgit2), Cint, (Ptr{Void}, Ptr{UInt8}), r, url)
    return r
end

function push_url(r::GitRemote)
    url_ptr = ccall((:git_remote_pushurl, libgit2), Ptr{UInt8}, (Ptr{Void},), r)
    return url_ptr != C_NULL ? bytestring(url_ptr) : nothing
end

function set_push_url!(r::GitRemote, url::AbstractString)
    check_valid_url(url)
    @check ccall((:git_remote_set_pushurl, libgit2), Cint, (Ptr{Void}, Ptr{UInt8}), r, url)
    return r
end

function fetch_refspecs(r::GitRemote)
    sa_ptr = [StrArrayStruct()]
    @check ccall((:git_remote_get_fetch_refspecs, libgit2), Cint,
                  (Ptr{StrArrayStruct}, Ptr{Void}), sa_ptr, r)
    sa = sa_ptr[1]
    refs = Array(UTF8String, sa.count)
    for i in 1:sa.count
        refs[i] = utf8(bytestring(unsafe_load(sa.strings, i)))
    end
    return refs
end

function push_refspecs(r::GitRemote)
    sa_ptr = [StrArrayStruct()]
    @check ccall((:git_remote_get_push_refspecs, libgit2), Cint,
                  (Ptr{StrArrayStruct}, Ptr{Void}), sa_ptr, r)
    sa = sa_ptr[1]
    refs = Array(UTF8String, sa.count)
    for i in 1:sa.count
        refs[i] = utf8(bytestring(unsafe_load(sa.strings, i)))
    end
    return refs
end

function add_push!(r::GitRemote, ref::AbstractString)
    @check ccall((:git_remote_add_push, libgit2), Cint, (Ptr{Void}, Ptr{UInt8}), r, ref)
    return r
end

function add_fetch!(r::GitRemote, ref::AbstractString)
    @check ccall((:git_remote_add_fetch, libgit2), Cint, (Ptr{Void}, Ptr{UInt8}), r, ref)
    return r
end

function clear_refspecs!(r::GitRemote)
    ccall((:git_remote_clear_refspecs, libgit2), Void, (Ptr{Void},), r)
    return r
end

function save!(r::GitRemote)
    @check ccall((:git_remote_save, libgit2), Cint, (Ptr{Void},), r)
    return r
end

function rename!(r::GitRemote, newname::AbstractString)
    sa_ptr = [StrArrayStruct()]
    @check ccall((:git_remote_rename, libgit2), Cint,
                  (Ptr{StrArrayStruct}, Ptr{Void}, Ptr{UInt8}), sa_ptr, r, newname)
    sa = sa_ptr[1]
    errs = UTF8String[]
    for i=1:sa.count
        push!(errs, utf8(bytestring(unsafe_load(sa.strings, i))))
    end
    return errs
end

type RemoteHead
    islocal::Bool
    id::Oid
    lid::MaybeOid
    name::ByteString
end

RemoteHead(struct::RemoteHeadStruct) =  begin
    id  = Oid(string(struct.id))
    lid = Oid(string(struct.lid))
    name = struct.name != C_NULL ? "" : bytestring(struct.name)
    return RemoteHead(bool(struct.islocal), id, iszero(lid) ? nothing : lid, name)
end

ls(r::GitRemote) = begin
    nheads = Csize_t[0]
    head_ptrs = Ptr{Ptr{RemoteHeadStruct}}[0]
    @check ccall((:git_remote_ls, libgit2), Cint,
                 (Ptr{Ptr{Ptr{RemoteHeadStruct}}}, Ptr{Csize_t}, Ptr{Void}), head_ptrs, nheads, r)
    head_ptr = head_ptrs[1]
    remote_heads = RemoteHead[]
    for i in 1:nheads[1]
        struct = unsafe_load(unsafe_load(head_ptr, i))::RemoteHeadStruct
        push!(remote_heads, RemoteHead(struct))
    end
    return remote_heads
end

Base.download(r::GitRemote) = begin
    @check ccall((:git_remote_download, libgit2), Cint, (Ptr{Void},), r)
    return r
end

function update_tips!(r::GitRemote,
                     sig::MaybeSignature=nothing,
                     logmsg::MaybeString=nothing)
    @check ccall((:git_remote_update_tips, libgit2), Cint,
                 (Ptr{Void}, Ptr{SignatureStruct}, Ptr{UInt8}),
                 r, sig != nothing ? sig : C_NULL, logmsg != nothing ? logmsg : C_NULL)
    return r
end

function fetch(r::GitRemote, sig::MaybeSignature=nothing, logmsg::MaybeString=nothing)
    @check ccall((:git_remote_fetch, libgit2), Cint,
                 (Ptr{Void}, Ptr{SignatureStruct}, Ptr{UInt8}),
                 r, sig != nothing ? sig : C_NULL, logmsg != nothing ? logmsg : C_NULL)
    return r
end

function default_branch(r::GitRemote)
    buf_ptr = [BufferStruct()]
    @check ccall((:git_remote_default_branch, libgit2), Cint,
                 (Ptr{BufferStruct}, Ptr{Void}), buf_ptr, r)
    name = utf8(bytestring(buf_ptr[1]))
    ccall((:git_buf_free, libgit2), Void, (Ptr{BufferStruct},), buf_ptr)
    return name
end
