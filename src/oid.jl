typealias CGitOid Void

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

Base.string(oid::Oid) = begin
    
end

Base.isequal(oid1::Oid, oid2::Oid) = begin
    for i in 1:GIT_OID_RAWSZ
        if oid1.oid[i] != oid2.oid[i]
            return false
        end
    end
    return true
end

#TODO: comparisons
Base.isless(oid1::Oid, oid2::Oid) = begin
    sum(oid1.oid) < sum(oid2.oid)
end

Base.hash(oid::Oid) = begin
    #TODO: this is incorrect, hash on ptr location
    hash(oid.oid)
end

#TODO: hook this up when ccall is figured out
#Base.cmp(oid1::Oid, oid2::Oid) = begin
#    git_cmp = ccall((:git_oid_cmp, libgit2),
#                    Cint,
#                    (Ptr{Uint8}, Ptr{Uint8}),
#                    oid1.oid, oid2.oid)
#    return git_cmp
#end
