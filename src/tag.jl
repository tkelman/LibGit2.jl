export git_otype, message, target_id, target, tagger, lookup_tag

name(t::GitTag) = bytestring(ccall((:git_tag_name, :libgit2), Ptr{Uint8}, (Ptr{Void},), t))

function message(t::GitTag)
    msgptr = ccall((:git_tag_message, :libgit2), Ptr{Uint8}, (Ptr{Void},), t)
    if msgptr == C_NULL
        return nothing
    end
    return bytestring(msgptr)
end

function target_id(t::GitTag)
    idptr = ccall((:git_tag_target_id, :libgit2), Ptr{Uint8}, (Ptr{Void},), t)
    return Oid(idptr)
end

function target(t::GitTag)
    tptr = Ptr{Void}[0]
    @check ccall((:git_tag_target, :libgit2), Cint, 
                 (Ptr{Ptr{Void}}, Ptr{Void}), tptr, t)
    return gitobj_from_ptr(tptr[1])
end

#TODO: rework Signature handling
function tagger(t::GitTag)
    sig_ptr = ccall((:git_tag_tagger, :libgit2), Ptr{SignatureStruct}, (Ptr{Void},), t)
    if sig_ptr == C_NULL
        return nothing
    end
    struct = unsafe_load(sig_ptr)::SignatureStruct
    sig = Signature(struct)
    #TODO: all this signature stuff has
    #to be cleaned up
    #api.free!(gsig)
    return sig
end

#TODO: tag iteration foreach(tag)...
