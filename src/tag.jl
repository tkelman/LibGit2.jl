export git_otype, message, target_id, target, tagger, lookup_tag

Base.show(io::IO, t::GitTag) = begin
    write(io, "GitTag(\"$(name)\" @ $(target_id(t))")
end

name(t::GitTag) = bytestring(ccall((:git_tag_name, libgit2), Ptr{UInt8}, (Ptr{Void},), t))

function message(t::GitTag)
    msgptr = ccall((:git_tag_message, libgit2), Ptr{UInt8}, (Ptr{Void},), t)
    msgptr == C_NULL && return nothing
    return bytestring(msgptr)
end

function target_id(t::GitTag)
    idptr = ccall((:git_tag_target_id, libgit2), Ptr{UInt8}, (Ptr{Void},), t)
    return Oid(idptr)
end

function target(t::GitTag)
    tptr = Ptr{Void}[0]
    @check ccall((:git_tag_target, libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}), tptr, t)
    return gitobj_from_ptr(tptr[1])
end

function tagger(t::GitTag)
    # returns a reference to an existing struct so don't free
    sig_ptr = ccall((:git_tag_tagger, libgit2), Ptr{SignatureStruct}, (Ptr{Void},), t)
    sig_ptr == C_NULL && return nothing
    return Signature(sig_ptr)
end
