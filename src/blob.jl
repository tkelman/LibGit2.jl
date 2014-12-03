export rawcontent, sloc, text, isbinary, lookup_blob,
       blob_from_buffer, blob_from_workdir, blob_from_disk, blob_from_stream

Base.sizeof(b::GitBlob) = int(ccall((:git_blob_rawsize, libgit2), Coff_t, (Ptr{Void},), b))

# TODO: it would be better to implement julia's file api's to work with blobs

function rawcontent(b::GitBlob, max_bytes=-1)
    data_ptr  = ccall((:git_blob_rawcontent, libgit2), Ptr{UInt8}, (Ptr{Void},), b)
    data_size = ccall((:git_blob_rawsize, libgit2), Coff_t, (Ptr{Void},), b)
    if data_ptr == C_NULL || max_bytes == 0
        return Array(UInt8, 0)
    end
    if max_bytes < 0 || max_bytes > data_size
        data_copy = Array(UInt8, data_size)
        unsafe_copy!(convert(Ptr{UInt8}, data_copy), data_ptr, data_size)
        return data_copy
    end
    if max_bytes > 0 && max_bytes < data_size
        data_copy = Array(UInt8, max_bytes)
        unsafe_copy!(convert(Ptr{UInt8}, data_copy), data_ptr, max_bytes)
        return data_copy
    end
end

Base.bytestring(b::GitBlob) = bytestring(rawcontent(b))

function sloc(b::GitBlob)
    data_ptr  = ccall((:git_blob_rawcontent, libgit2), Ptr{UInt8}, (Ptr{Void},), b)
    data_size = ccall((:git_blob_rawsize, libgit2), Coff_t, (Ptr{Void},), b)
    data_end = data_ptr + data_size
    if data_ptr == data_end
        return 0
    end
    loc = 0
    while uint(data_ptr) < uint(data_end)
        val = unsafe_load(data_ptr)
        data_ptr += 1
        if val == uint8('\n')
            while uint(data_ptr) < uint(data_end) && isspace(char(unsafe_load(data_ptr)))
                data_ptr += 1
            end
            loc += 1
        end
    end
    if unsafe_load(data_ptr-1) != uint8('\n')
        loc += 1
    end
    return loc
end

function text(b::GitBlob, max_lines=-1)
    data_ptr = ccall((:git_blob_rawcontent, libgit2), Ptr{UInt8}, (Ptr{Void},), b)
    if data_ptr == C_NULL || max_lines == 0
        return UTF8String(UInt8[])
    elseif max_lines < 0
        return bytestring(data_ptr)
    end
    lines, i = 0, 1
    data_size = ccall((:git_blob_rawsize, libgit2), Coff_t, (Ptr{Void},), b)
    while i <= data_size && lines < max_lines
        if unsafe_load(data_ptr, i) == uint8('\n')
            lines += 1
        end
        i += 1
    end
    data_size = i - 1
    data_copy = Array(UInt8, data_size)
    unsafe_copy!(convert(Ptr{UInt8}, data_copy), data_ptr, data_size)
    return UTF8String(data_copy)
end

isbinary(b::GitBlob) = bool(ccall((:git_blob_is_binary, libgit2), Cint, (Ptr{Void},), b))

function blob_from_buffer(r::GitRepo, bufptr::Ptr{UInt8}, len::Int)
    id_ptr = [Oid()]
    @check ccall((:git_blob_create_frombuffer, libgit2), Cint,
                 (Ptr{Oid}, Ptr{Void}, Ptr{UInt8}, Csize_t),
                 id_ptr, r, bufptr, len)
    return id_ptr[1]
end

blob_from_buffer(r::GitRepo, buf::Vector{UInt8}) = blob_from_buffer(r::GitRepo, convert(Ptr{UInt8}, buf), length(buf))
blob_from_buffer(r::GitRepo, buf::ByteString)    = blob_from_buffer(r::GitRepo, buf.data)
blob_from_buffer(r::GitRepo, buf::IOBuffer)      = blob_from_buffer(r::GitRepo, buf.data)

function blob_from_workdir(r::GitRepo, path::AbstractString)
    id_ptr = [Oid()]
    @check ccall((:git_blob_create_fromworkdir, libgit2), Cint,
                  (Ptr{Oid}, Ptr{Void}, Ptr{Cchar}),
                  id_ptr, r, bytestring(path))
    return id_ptr[1]
end

function blob_from_disk(r::GitRepo, path::AbstractString)
    id_ptr = [Oid()]
    @check ccall((:git_blob_create_fromdisk, libgit2), Cint,
                 (Ptr{Oid}, Ptr{Void}, Ptr{UInt8}), id_ptr, r, path)
    return id_ptr[1]
end

function cb_blob_get_chunk(contentptr::Ptr{UInt8}, maxlen::Csize_t, payloadptr::Ptr{Void})
    payload = unsafe_pointer_to_objref(payloadptr)::Array{Any,1}
    io = payload[1]::IO
    local buff::Vector{UInt8}
    try
        buff = readbytes(io, maxlen)
    catch err
        payload[2] = err
        return GitErrorConst.ERROR
    end
    len = length(buff)
    len > maxlen && (len = maxlen)
    unsafe_copy!(contentptr, convert(Ptr{UInt8}, buff), len)
    return convert(Cint, len)
end

const c_cb_blob_get_chunk = cfunction(cb_blob_get_chunk, Cint,
                                      (Ptr{UInt8}, Csize_t, Ptr{Void}))

function blob_from_stream(r::GitRepo, io::IO, hintpath::AbstractString="")
    id_ptr = [Oid()]
    payload = Any[io, nothing]
    err = ccall((:git_blob_create_fromchunks, libgit2), Cint,
                (Ptr{Oid}, Ptr{Void}, Ptr{UInt8}, Ptr{Void}, Any),
                id_ptr, r, !isempty(hintpath) ? hintpath : C_NULL,
                c_cb_blob_get_chunk, &payload)
    if isa(payload[2], Exception)
        throw(payload[2])
    end
    if err != GitErrorConst.GIT_OK
        throw(LibGitError(err))
    end
    return id_ptr[1]
end
