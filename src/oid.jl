const GIT_OID_RAWSZ = 20
const GIT_OID_HEXSZ = 40

type Oid
    oid::Array{Uint8,1}

    function Oid()
        new(zeros(Uint8, GIT_OID_RAWSZ))
    end

    function Oid(b::Array{Uint8,1})
        if length(b) != GIT_OID_RAWSZ
            throw(ArgumentError("invalid raw buffer size"))
        end
        new(b)
    end
    
    function Oid(h::String)
        if length(h) != GIT_OID_HEXSZ
            throw(ArgumentError("invalid hex size"))
        end
        bytes = hex2bytes(bytestring(h))
        Oid(bytes)
    end
end


function hex(oid::Oid)
    bytes2hex(oid.oid)
end


function raw(oid::Oid)
    copy(oid.oid)
end


Base.show(io::IO, oid::Oid) = begin
    print(io, "Oid(\"$(hex(oid))\")")
end


Base.isequal(oid1::Oid, oid2::Oid) = begin
    cmp(oid1, oid2) == 0
end


Base.isless(oid1::Oid, oid2::Oid) = begin
    cmp(oid1, oid2) < 0
end


Base.hash(oid::Oid) = begin
    hash(oid.oid)
end


Base.cmp(oid1::Oid, oid2::Oid) = begin
    git_cmp = ccall((:git_oid_cmp, :libgit2),
                    Cint,
                    (Ptr{Uint8}, Ptr{Uint8}),
                    oid1.oid, oid2.oid)
    return git_cmp
end
