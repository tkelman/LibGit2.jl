export Odb, OdbObject, OdbWrite, OdbRead,
       exists, data, open_wstream, oid

type Odb
    ptr::Ptr{Void}

    function Odb(ptr::Ptr{Void})
        @assert ptr != C_NULL
        o = new(ptr)
        finalizer(o, free!)
        return o
    end
end

free!(o::Odb) = begin 
    if o.ptr != C_NULL 
        api.git_odb_free(o.ptr)
        o.ptr = C_NULL
    end
end

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

    function OdbObject(ptr::Ptr{Void})
        @assert ptr != C_NULL
        o = new(ptr)
        finalizer(o, free!)
        return o
    end
end

free!(o::OdbObject) = begin
    if o.ptr != C_NULL
        @check api.git_odb_object_free(o.ptr)
        o.ptr = C_NULL
    end
end

Base.length(o::OdbObject) = begin
    @assert o.ptr != C_NULL
    return int(api.git_odb_object_size(o.ptr))
end

Base.sizeof(o::OdbObject) = begin
    @assert o.ptr != C_NULL
    return length(o) * sizeof(Cchar)
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

free!(os::OdbIO) = begin
    if os.ptr != C_NULL
        #TODO: close before gc?
        api.git_odb_stream_free(os.ptr)
        os.ptr = C_NULL
    end
end

type OdbWrite <: OdbIO
    ptr::Ptr{Void}
    id::Oid

    function OdbWrite(ptr::Ptr{Void})
        @assert ptr != C_NULL
        oid_ptr = api.git_odb_object_id(ptr)
        if oid_ptr == C_NULL
            error("oid pointer for write stream is NULL")
        end
        s = new(ptr, Oid(oid_ptr))
        finalizer(s, free!)
        return s
    end
end

oid(os::OdbWrite) = os.id

function open_wstream{T<:GitObject}(::Type{T}, odb::Odb, len::Int)
    @assert odb.ptr != C_NULL
    @assert len > 0
    gtype = git_otype(T)
    clen = convert(Csize_t, len)
    stream_ptr = Array(Ptr{Void}, 1)
    @check api.git_odb_open_wstream(stream_ptr, odb.ptr, clen, gtype)
    @check_null stream_ptr
    return OdbWrite(stream_ptr[1])
end

Base.isreadable(io::OdbWrite) = false 
Base.iswriteable(io::OdbWrite) = true

Base.write(io::OdbWrite, b::ByteString) = begin 
    @assert io.ptr != C_NULL
    len = length(b)
    @check api.git_odb_stream_write(io.ptr, b, len)
    return len
end

#TODO: this is broken...
Base.write{T}(io::OdbWrite, b::Array{T}) = begin
    @assert io.ptr != C_NULL
    @assert isbits(T)
    ptr = convert(Ptr{Uint8}, b)
    len = convert(Csize_t, div(length(b) * sizeof(T), sizeof(Uint8)))
    @check api.git_odb_stream_write(io.ptr, b, len)
    return len
end

Base.close(os::OdbWrite) = begin
    @assert os.ptr != C_NULL
    @check api.git_odb_stream_finalize_write(os.id.oid, os.ptr)
    return nothing
end

type OdbRead <: OdbIO
    ptr::Ptr{Void}
end

Base.isreadable(io::OdbRead) = true
Base.iswriteable(io::OdbRead) = false

#TODO: this is broken ...
#Base.readbytes(io::OdbRead, nb=typemax(Int)) = begin
#    b = (Uint8, min(nb, 65536))
#    nr = readbytes!(s, b, nb)
#    resize!(b, nr)
#end
 
Base.readbytes!(io::OdbRead, b::Vector{Uint8}, nb=length(b)) = begin
    @assert io.ptr != C_NULL
    len = convert(Csize_t, length(b))
    ret = @check api.git_odb_stream_read(io.ptr, b, len)
    @assert len > 0
    return len
end

Base.close(os::OdbRead) = begin
    #no op
    return nothing
end
