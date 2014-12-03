export SHA1, PartialSHA1, Oid, raw, iszero, @sha1_str

const OID_RAWSZ = 20
const OID_HEXSZ = OID_RAWSZ * 2
const OID_MINPREFIXLEN = 4

# immutable Oid
#   id1::UInt8
#   id2::UInt8
#   ...
#   id20::UInt8
# end

@eval begin
    $(Expr(:type, false, :Oid,
        Expr(:block,
            [Expr(:(::), symbol("id$i"), :UInt8) for i=1:OID_RAWSZ]...)))
end

# default Oid constructor (all zeros)
@eval begin
    Oid() = $(Expr(:call, :Oid, [:(0x00) for _=1:OID_RAWSZ]...))
end

Oid(ptr::Ptr{Oid}) = unsafe_load(ptr)::Oid

Oid(ptr::Ptr{UInt8}) = begin
    if ptr == C_NULL
        throw(ArgumentError("NULL pointer passed to Oid() constructor"))
    end
    oid_ptr = Oid[Oid()]
    ccall((:git_oid_fromraw, libgit2), Void, (Ptr{Oid}, Ptr{UInt8}), oid_ptr, ptr)
    return oid_ptr[1]
end

Oid(id::Array{UInt8,1}) = begin
    if length(id) != OID_RAWSZ
        throw(ArgumentError("invalid raw buffer size"))
    end
    return Oid(pointer(id))
end

Oid(id::AbstractString) = begin
    bstr = bytestring(id)
    if sizeof(bstr) != OID_HEXSZ
        throw(ArgumentError("invalid hex size"))
    end
    oid_ptr = Oid[Oid()]
    @check ccall((:git_oid_fromstrp, libgit2), Cint,
                 (Ptr{Oid}, Ptr{Cchar}), oid_ptr, bstr)
    return oid_ptr[1]
end

Oid(id::Oid) = id

Base.copy!(arr::Array{UInt8, 1}, id::Oid) = begin
    unsafe_copy!(convert(Ptr{UInt8}, arr), convert(Ptr{UInt8},  hex2bytes(hex(id))), OID_RAWSZ)
    return arr
end

raw(id::Oid) = copy!(Array(UInt8, OID_RAWSZ), id)

const _hexstr = Array(UInt8, OID_HEXSZ)
Base.hex(id::Oid) = begin
    ccall((:git_oid_nfmt, libgit2), Void,
          (Ptr{UInt8}, Csize_t, Ptr{Oid}), _hexstr, OID_HEXSZ, &id)
    return bytestring(convert(Ptr{UInt8}, _hexstr), OID_HEXSZ)
end

Base.string(id::Oid) = hex(id)

Base.show(io::IO, id::Oid) = print(io, "Oid($(string(id)))")

Base.hash(id::Oid) = hash(hex(id))

Base.cmp(id1::Oid, id2::Oid) = int(ccall((:git_oid_cmp, libgit2), Cint,
                                         (Ptr{Oid}, Ptr{Oid}), &id1, &id2))

Base.(:(==))(id1::Oid, id2::Oid) = cmp(id1, id2) == 0
Base.isequal(id1::Oid, id2::Oid) = cmp(id1, id2) == 0
Base.isless(id1::Oid, id2::Oid)  = cmp(id1, id2) < 0

iszero(id::Oid) = begin
    bytes = raw(id)
    for i=1:OID_RAWSZ
        if bytes[i] != 0x00
            return false
        end
    end
    return true
end

#throw(ArgumentError("not a hexadecimal string: $(repr(s))"))

function allhexchar(s::ByteString)
    for c in s
        if !('0' <= c <= '9' || 'a' <= c <= 'f' || 'A' <= c <= 'F')
            return false
        end
    end
    return true
end

immutable PartialSHA1
    data::ASCIIString

    PartialSHA1(s::AbstractString) = begin
        len = length(s)
        if len == 0
            throw(ArgumentError("PartialSHA1 string cannot be empty"))
        elseif len >= OID_HEXSZ
            throw(ArgumentError("PartialSHA1 string length must be <= $(OID_HEXSZ)"))
        end
        str = ASCIIString(s)
        if !allhexchar(str)
            throw(ArgumentError("SHA1 string is not a hexadecimal string: $(repr(str))"))
        end
        return new(str)
    end
end

immutable SHA1
    data::ASCIIString

    SHA1(s::AbstractString) = begin
        len = length(s)
        if len == 0
            throw(ArgumentError("SHA1 string cannot be empty"))
        elseif len < OID_HEXSZ
            throw(ArgumentError("SHA1 string length < $(OID_HEXSZ)"))
        elseif len > OID_HEXSZ
            throw(ArgumentError("SHA1 string length > $(OID_HEXSZ)"))
        end
        str = ASCIIString(s)
        if !allhexchar(str)
            throw(ArgumentError("SHA1 string is not a hexadecimal string: $(repr(str))"))
        end
        return new(str)
    end
end

macro sha1_str(s)
    len = length(s)
    if len < OID_HEXSZ
        :(PartialSHA1($s))
    else
        :(SHA1($s))
    end
end

Oid(sha::SHA1) = Oid(hex2bytes(sha.data))
