export git_otype, is_binary, raw_content, sloc, text, isbinary

git_otype(::Type{GitBlob}) = api.OBJ_BLOB

Base.sizeof(b::GitBlob) = begin
    @assert b.ptr != C_NULL
    return api.git_blob_rawsize(b.ptr)::Int64
end

function is_binary(b::GitBlob)
    @assert b.ptr != C_NULL
    api.git_blob_is_binary(b.ptr) > 0 ? true : false
end

function raw_content(b::GitBlob, max_bytes=-1)
    @assert b.ptr != C_NULL
    data_ptr = api.git_blob_rawcontent(b.ptr)
    data_size = api.git_blob_rawsize(b.ptr)
    if data_ptr == C_NULL || max_bytes == 0
        return ""
    end
    if max_bytes < 0 || max_bytes > data_size
        return utf8(bytestring(data_ptr))
    end
    if max_bytes > 0 && max_bytes < data_size
        data_copy = Array(Uint8, max_bytes)
        data_copy_ptr = convert(Ptr{Uint8}, data_copy)
        unsafe_copy!(data_copy_ptr, data_ptr, max_bytes)
        return UTF8String(data_copy)
    end
end

function sloc(b::GitBlob)
    @assert b.ptr != nothing
    data_ptr = api.git_blob_rawcontent(b.ptr)
    data_end = data_ptr + api.git_blob_rawsize(b.ptr)
    if uint(data_ptr) == uint(data_end)
        return 0
    end
    loc = 0
    while uint(data_ptr) < uint(data_end)
        val = unsafe_load(data_ptr)
        data_ptr += 1
        if val == uint8(10) #"\n"
            while uint(data_ptr) < uint(data_end) && 
                  isspace(char(unsafe_load(data_ptr)))
                data_ptr += 1
            end
            loc += 1
        end
    end
    if unsafe_load(data_ptr-1) != uint8(10) #"\n"
        loc += 1
    end
    return loc
end

function text(b::GitBlob, max_lines=-1)
    @assert b.ptr != C_NULL
    data_ptr = api.git_blob_rawcontent(b.ptr)
    if data_ptr == C_NULL || max_lines == 0
        return ""
    end
    if max_lines < 0
        return bytestring(data_ptr)
    end
    i = 1
    lines = 0
    data_size = api.git_blob_rawsize(b.ptr)
    while i <= data_size && lines < max_lines
        if unsafe_load(data_ptr, i) == uint8(10) # "\n"
            lines += 1
        end
        i += 1
    end
    data_size = i - 1
    data_copy = Array(Uint8, data_size)
    data_copy_ptr = convert(Ptr{Uint8}, data_copy)
    unsafe_copy!(data_copy_ptr, data_ptr, data_size)
    return UTF8String(data_copy) 
end

function isbinary(b::GitBlob)
    @assert b.ptr != C_NULL
    res = api.git_blob_is_binary(b.ptr)
    return bool(res)
end
