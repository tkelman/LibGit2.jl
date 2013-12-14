type Odb
    ptr::Ptr{Void}
end

#TODO: support oid in odb....
function exists(o::Odb, id::Oid)
    @check o.ptr != C_NULL
    res = api.git_odb_exists(o.ptr, id.oid)
    return res? true : false
end

Base.in(id::Oid, o::Odb) = begin
    exists(o, id)
end

type OdbObject
    ptr::Ptr{Void}
end

free!(o::OdbObject) = begin
    if o.ptr != C_NULL
        @check api.git_odb_object_free(o.ptr)
        o.ptr = C_NULL
    end
end

Base.sizeof(o::OdbObject) = begin
    @assert o.ptr != C_NULL
    return int(api.git_odb_object_size(o.ptr))
end

function data(o::OdbObject)
    @assert o.ptr != C_NULL
    blob_ptr::Ptr{Uint8} = api.git_odb_object_data(o.ptr)
    if blob_ptr == C_NULL
        error("odb object data pointer is NULL")
    end
    len = div(sizeof(o), sizeof(Uint8))
    @assert len > 0
    blob_copy = Array(Uint8, len)
    for i in 1:len
        blob_copy[i] = unsafe_load(blob_ptr, i)
    end
    return data_copy
end

abstract OdbIO

type OdbWrite <: OdbIO
    ptr::Ptr{Void}
    id::Oid
end

Base.isreadable(io::OdbWrite) = false 
Base.iswriteable(io::OdbWrite) = true

Base.write(io::OdbWrite, b::Array{Uint8}) = begin
    @assert io.ptr != C_NULL
end

type OdbRead <: OdbIO
    ptr::Ptr{Void}
end

Base.isreadable(io::OdbRead) = true
Base.iswriteable(io::OdbRead) = false

free!(os::OdbIO) = begin
    if os.ptr != C_NULL
        @check api.odb_stream_free(os.ptr)
        os.ptr = C_NULL
    end
end

Base.close(os::OdbWrite) = begin
    @assert os.ptr != C_NULL
    @check api.git_odb_stream_finalize_write(os.id, os.ptr)
    return nothing
end

Base.close(os::OdbRead) = begin
    #no op
    return nothing
end

