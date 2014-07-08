export Sha1, Oid, raw, iszero, @sha1_str

const OID_RAWSZ = 20
const OID_HEXSZ = OID_RAWSZ * 2
const OID_MINPREFIXLEN = 4

# immutable Oid
#   id1::Uint8
#   id2::Uint8
#   ...
#   id20::Uint8
# end 

@eval begin
    $(Expr(:type, false, :Oid,
        Expr(:block, 
            [Expr(:(::), symbol("id$i"), :Uint8) for i=1:OID_RAWSZ]...)))
end

# default Oid constructor (all zeros)
Oid() = @eval begin
    $(Expr(:call, :Oid, [:(zero(Uint8)) for _=1:OID_RAWSZ]...))
end

Oid(ptr::Ptr{Oid}) = unsafe_load(ptr)::Oid

Oid(ptr::Ptr{Uint8}) = begin
    if ptr == C_NULL
        throw(ArgumentError("NULL pointer passed to Oid() constructor"))
    end
    id = Oid()
    ccall((:git_oid_fromraw, libgit2), Void, (Ptr{Oid}, Ptr{Uint8}), &id, ptr)
    return id 
end

Oid(id::Array{Uint8,1}) = begin
    if length(id) != OID_RAWSZ
        throw(ArgumentError("invalid raw buffer size"))
    end
    return Oid(pointer(id))
end

Oid(id::String) = begin
    bstr = bytestring(id)
    if sizeof(bstr) != OID_HEXSZ
        throw(ArgumentError("invalid hex size"))
    end
    oid = Oid()
    @check ccall((:git_oid_fromstrp, libgit2), Cint,
                 (Ptr{Oid}, Ptr{Cchar}), &oid, bstr)
    return oid
end

Oid(id::Oid) = id

Base.copy!(arr::Array{Uint8, 1}, id::Oid) = begin
    unsafe_copy!(convert(Ptr{Uint8}, arr), convert(Ptr{Uint8},  hex2bytes(hex(id))), OID_RAWSZ)
    return arr
end

raw(id::Oid) = copy!(Array(Uint8, OID_RAWSZ), id)

const _hexstr = Array(Uint8, OID_HEXSZ)
Base.hex(id::Oid) = begin
    ccall((:git_oid_nfmt, libgit2), Void,
          (Ptr{Uint8}, Csize_t, Ptr{Oid}), _hexstr, OID_HEXSZ, &id)
    return bytestring(convert(Ptr{Uint8}, _hexstr), OID_HEXSZ)
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
        if bytes[i] != zero(Uint8)
            return false
        end
    end
    return true
end

immutable Sha1
    data::ASCIIString 
    
    Sha1(s::String) = begin
        bstr = bytestring(s)::ASCIIString
        if sizeof(bstr) != OID_HEXSZ
            throw(ArgumentError("invalid sha1 string length $(length(bstr))"))
        end
        for c in bstr 
            if !('0' <= c <= '9' || 'a' <= c <= 'f' || 'A' <= c <= 'F')
                throw(ArgumentError("not a hexadecimal string: $(repr(s))"))
            end
        end
        return new(bstr)
    end
end    

macro sha1_str(s)
    Sha1(s)
end

Oid(sha::Sha1) = Oid(hex2bytes(sha.data))
