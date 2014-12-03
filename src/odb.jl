export Odb, OdbObject, OdbWrite, OdbRead,
       exists, data, open_wstream, read_header

#TODO: rename to GitOdb
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
        ccall((:git_odb_free, libgit2), Void, (Ptr{Void},), o.ptr)
        o.ptr = C_NULL
    end
end

Base.convert(::Type{Ptr{Void}}, o::Odb) = o.ptr

exists(o::Odb, id::Oid)  = bool(ccall((:git_odb_exists, libgit2), Cint, (Ptr{Void}, Ptr{Oid}), o, &id))
Base.in(id::Oid, o::Odb) = exists(o, id)

function read_header(odb::Odb, id::Oid)
    nbytes = Csize_t[0]
    otype  = Cint[0]
    @check ccall((:git_odb_read_header, libgit2), Cint,
                 (Ptr{Csize_t}, Ptr{Cint}, Ptr{Void}, Ptr{Oid}), nbytes, otype, odb, &id)
    return Dict{Any,Any}(:type => gitobj_const_type(otype[1]),
                         :nbytes => nbytes[1])
end

type OdbObject{T<:GitObject}
    ptr::Ptr{Void}
end

OdbObject(ptr::Ptr{Void}) = begin
    @assert ptr != C_NULL
    obj_type = ccall((:git_odb_object_type, libgit2), Cint, (Ptr{Void},), ptr)
    T = gitobj_const_type(obj_type)
    o = OdbObject{T}(ptr)
    finalizer(o, free!)
    return o
end

free!(o::OdbObject) = begin
    if o.ptr != C_NULL
        ccall((:git_odb_object_free, libgit2), Void, (Ptr{Void},), o.ptr)
        o.ptr = C_NULL
    end
end

Base.convert(::Type{Ptr{Void}}, o::OdbObject) = o.ptr

Base.sizeof(o::OdbObject) = int(ccall((:git_odb_object_size, libgit2), Csize_t, (Ptr{Void},), o))
Base.length(o::OdbObject) = div(sizeof(o), sizeof(UInt8))

function data(o::OdbObject)
    data_ptr = ccall((:git_odb_object_data, libgit2), Ptr{UInt8}, (Ptr{Void},), o)
    @assert data_ptr != C_NULL
    return bytestring(data_ptr)
end

abstract OdbIO

free!(os::OdbIO) = begin
    if os.ptr != C_NULL
        #TODO: close before gc?
        ccall((:git_odb_stream_free, libgit2), Void, (Ptr{Void},), os.ptr)
        os.ptr = C_NULL
    end
end

type OdbWrite <: OdbIO
    ptr::Ptr{Void}
    id::Oid

    function OdbWrite(ptr::Ptr{Void})
        @assert ptr != C_NULL
        oid_ptr = ccall((:git_odb_object_id, libgit2), Ptr{Oid}, (Ptr{Void},), ptr)
        @assert oid_ptr != C_NULL
        s = new(ptr, Oid(oid_ptr))
        finalizer(s, free!)
        return s
    end
end

Base.convert(::Type{Ptr{Void}}, o::OdbWrite) = o.ptr

Oid(odbw::OdbWrite) = odbw.id

function open_wstream{T<:GitObject}(::Type{T}, odb::Odb, len::Int)
    @assert odb.ptr != C_NULL
    @assert len > 0
    gtype = git_otype(T)
    stream_ptr = Ptr{Void}[0]
    @check ccall((:git_odb_open_wstream, libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Csize_t, Cint), stream_ptr, odb, len, gtype)
    return OdbWrite(stream_ptr[1])
end

#=
Base.isreadable(io::OdbWrite)  = false
Base.iswriteable(io::OdbWrite) = true
=#

#TODO: this needs to be reworked
Base.write(io::OdbWrite, buffer::ByteString) = begin
    len = length(buffer)
    @check ccall((:git_odb_stream_write, libgit2), Cint,
                 (Ptr{Void}, Ptr{UInt8}, Csize_t), io, buffer, len)
    return len
end

#TODO: this is broken...
Base.write{T}(io::OdbWrite, buffer::Array{T}) = begin
    @assert isbits(T)
    ptr = convert(Ptr{UInt8}, b)
    len = convert(Csize_t, div(length(b) * sizeof(T), sizeof(UInt8)))
    @check ccall((:git_odb_stream_write, libgit2), Cint,
                 (Ptr{Void}, Ptr{UInt8}, Csize_t), io, buffer, len)
    return io
end

Base.close(io::OdbWrite) = begin
    ioid = Oid(io)
    @check ccall((:git_odb_stream_finalize_write, libgit2), Cint, (Ptr{Oid}, Ptr{Void}), &ioid, io)
    return io
end

type OdbRead <: OdbIO
    ptr::Ptr{Void}
end

Base.convert(::Type{Ptr{Void}}, o::OdbRead) = o.ptr
#=
Base.isreadable(io::OdbRead)  = true
Base.iswriteable(io::OdbRead) = false
=#
Base.readbytes!(io::OdbRead, buffer::Vector{UInt8}, nb=length(b)) = begin
    @assert io.ptr != C_NULL
    len = convert(Csize_t, length(b))
    ret = @check ccall((:git_odb_stream_read, libgit2), Cint,
                       (Ptr{Void}, Ptr{UInt8}, Csize_t), io, buffer, len)
    @assert len > 0
    return len
end

Base.close(os::OdbRead) = return nothing # no op
