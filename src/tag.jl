export git_otype, message, target_id, target, tagger, lookup_tag

name(t::GitTag) = bytestring(ccall((:git_tag_name, api.libgit2), Ptr{Uint8}, (Ptr{Void},), t))

function message(t::GitTag)
    msgptr = ccall((:git_tag_message, api.libgit2), Ptr{Uint8}, (Ptr{Void},), t)
    if msgptr == C_NULL
        return nothing
    end
    return bytestring(msgptr)
end

function target_id(t::GitTag)
    idptr = ccall((:git_tag_target_id, api.libgit2), Ptr{Uint8}, (Ptr{Void},), t)
    return Oid(idptr)
end

function target(t::GitTag)
    tptr = Ptr{Void}[0]
    @check ccall((:git_tag_target, api.libgit2), Cint, 
                 (Ptr{Ptr{Void}}, Ptr{Void}), tptr, t)
    return gitobj_from_ptr(tptr[1])
end

#TODO: rework Signature handling
function tagger(t::GitTag)
    sig_ptr = api.git_tag_tagger(t.ptr)
    if sig_ptr == C_NULL
        return nothing
    end
    gsig = unsafe_load(sig_ptr)
    sig =  Signature(gsig)
    #TODO: all this signature stuff has
    #to be cleaned up
    #api.free!(gsig)
    return sig
end

#TODO: foreach(tag)...
