export Oid, hex, raw, iszero

type Oid
    oid::Array{Uint8,1}

    function Oid()
        new(zeros(Uint8, api.OID_RAWSZ))
    end

    function Oid(b::Array{Uint8,1})
        if length(b) != api.OID_RAWSZ
            throw(ArgumentError("invalid raw buffer size"))
        end
        new(b)
    end
    
    function Oid(h::String)
        if length(h) != api.OID_HEXSZ
            throw(ArgumentError("invalid hex size"))
        end
        bytes = hex2bytes(bytestring(h))
        Oid(bytes)
    end

    function Oid(ptr::Ptr{Uint8})
        if ptr == C_NULL
            throw(ArgumentError("pointer is NULL"))
        end
        oid = Array(Uint8, api.OID_RAWSZ)
        for i in 1:api.OID_RAWSZ
            oid[i] = unsafe_load(ptr, i)
        end
        return Oid(oid)
    end
end


function hex(oid::Oid)
    bytes2hex(oid.oid)
end


function raw(oid::Oid)
    copy(oid.oid)
end


Base.show(io::IO, oid::Oid) = begin
    print(io, "Oid($(hex(oid)))")
end


Base.isequal(oid1::Oid, oid2::Oid) = begin
    cmp(oid1, oid2) == 0
end


Base.isless(oid1::Oid, oid2::Oid) = begin
    cmp(oid1, oid2) < 0
end


Base.hash(oid::Oid) = begin
    hash(hex(oid))
end

Base.string(oid::Oid) = begin
    hex(oid)
end

Base.cmp(oid1::Oid, oid2::Oid) = begin
    git_cmp = ccall((:git_oid_cmp, :libgit2),
                    Cint,
                    (Ptr{Uint8}, Ptr{Uint8}),
                    oid1.oid, oid2.oid)
    return git_cmp
end

Base.copy(oid::Oid) = begin
    return Oid(copy(oid.oid))
end

iszero(oid::Oid) = begin
    for i in api.OID_RAWSZ
        if oid.oid[i] != zero(Uint8)
            return false
        end
    end
    return true
end
