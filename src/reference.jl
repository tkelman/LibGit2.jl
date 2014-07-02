export ReflogEntry,
       set_target, set_symbolic_target, resolve, 
       rename, target, symbolic_target, name,
       git_reftype, isvalid_ref, reflog, has_reflog, peel, log!

function GitReference(ptr::Ptr{Void})
    ty = ccall((:git_reference_type, :libgit2), Cint, (Ptr{Void},), ptr)
    RType = ty == 1 ? Oid : Sym 
    ref = GitReference{RType}(ptr)
    finalizer(ref, free!)
    return ref
end

isvalid_ref(ref::String) = bool(ccall((:git_reference_is_valid_name, :libgit2), Cint, (Ptr{Uint8},), ref))

function set_symbolic_target(r::GitReference, target::String;
                             sig::Union(Nothing, Signature)=nothing,
                             logmsg::Union(Nothing, String)=nothing)
    ref_ptr = Ptr{Void}[0]
    @check ccall((:git_reference_set_symbolic_target, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}, Ptr{SignatureStruct}, Ptr{Uint8}),
                 ref_ptr, r, target,
                 sig != nothing ? sig : C_NULL, 
                 msg != nothing ? msg : C_NULL)
    return GitReference(ref_ptr[1])
end

function set_target(r::GitReference, id::Oid; 
                    sig::Union(Nothing, Signature)=nothing, 
                    logmsg::Union(Nothing, Signature)=nothing)
    ref_ptr = Ptr{Void}[0]
    @check ccall((:git_reference_set_target, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Oid}, Ptr{SignatureStruct}, Ptr{Uint8}),
                 ref_ptr, r, &id, 
                 sig != nothing ? sig : C_NULL,
                 logmsg != nothing ? logmsg : C_NULL)
    return GitReference(ref_ptr[1])
end

function resolve(r::GitReference)
    ref_ptr = Ptr{Void}[0]
    @check ccall((:git_reference_resolve, :libgit2), Cint, 
                 (Ptr{Ptr{Void}}, Ptr{Void}), ref_ptr, r)
    return GitReference(ref_ptr[1])
end

function rename(r::GitReference, name::String; force::Bool=false, sig=nothing, logmsg=nothing)
    ref_ptr = Ptr{Void}[0]
    @check ccall((:git_reference_rename, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}, Cint, Ptr{SignatureStruct}, Ptr{Uint8}),
                 ref_ptr, r, name, force? 1:0,
                 sig != nothing ? sig : C_NULL,
                 logmsg != nothing ? logmsg : C_NULL)
    return GitReference(ref_ptr[1])
end

function target(r::GitReference)
    oid_ptr = ccall((:git_reference_target, :libgit2), Ptr{Oid}, (Ptr{Void},), r)
    if oid_ptr == C_NULL 
        return nothing
    end
    return Oid(oid_ptr)
end

function symbolic_target(r::GitReference)
    sym_ptr = ccall((:git_reference_symbolic_target, :libgit2), Ptr{Uint8}, (Ptr{Void},), r)
    if sym_ptr == C_NULL
        return utf8("")
    end
    return utf8(bytestring(sym_ptr))
end

name(r::GitReference) = utf8(bytestring(ccall((:git_reference_name, :libgit2), Ptr{Uint8}, (Ptr{Void},), r)))

function peel{T}(r::GitReference{T})
    obj_ptr = Ptr{Void}[0]
    err = ccall((:git_reference_peel, :libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Void}, Cint), obj_ptr, r, api.OBJ_ANY)
    if err == api.ENOTFOUND
        return nothing
    elseif err != api.GIT_OK
        throw(LibGitError(err))
    end
    if is(T, Oid) 
        oid = Oid(ccall((:git_object_id, :libgit2), Ptr{Oid}, (Ptr{Void},), obj_ptr[1])) 
        tid = Oid(ccall((:git_reference_target, :libgit2), Ptr{Oid}, (Ptr{Void},), r))
        if oid == tid
            ccall((:git_object_free, :libgit2), Void, (Ptr{Void},), obj_ptr[1])
            return nothing
        end
    end
    id = Oid(ccall((:git_object_id, :libgit2), Ptr{Oid}, (Ptr{Void},), obj_ptr[1]))
    ccall((:git_object_free, :libgit2), Void, (Ptr{Void},), obj_ptr[1])
    return id
end

#TODO: rename to GitReflog / GitReflogEntry
type Reflog
    ptr::Ptr{Void}

    function Reflog(ptr::Ptr{Void})
        @assert ptr != C_NULL
        rl = new(ptr)
        finalizer(fl, free!)
        return rl
    end
end

free!(r::Reflog) = begin
    if r.ptr != C_NULL
        api.git_reflog_free(r.ptr)
        r.ptr = C_NULL
    end
end

Base.convert(::Type{Ptr{Void}}, r::Reflog) = r.ptr 

type ReflogEntry
    id_old::Oid
    id_new::Oid
    committer::Signature
    message::UTF8String
end

function new_reflog_entry(entry_ptr::Ptr{Void})
    id_old  = Oid(ccall((:git_reflog_entry_id_old, :libgit2), Ptr{Oid}, (Ptr{Void},), entry_ptr))
    id_new  = Oid(ccall((:git_reflog_entry_id_new, :libgit2), Ptr{Oid}, (Ptr{Void},), entry_ptr))
    sig_ptr = ccall((:git_reflog_entry_committer, :libgit2), Ptr{SignatureStruct}, (Ptr{Void},), entry_ptr)
    msg_ptr = ccall((:git_reflog_entry_message, :libgit2), Ptr{Uint8}, (Ptr{Void},), entry_ptr)
    msg = msg_ptr == C_NULL ? utf8("") : utf8(bytestring(msg_ptr))
    sig = Signature(sig_ptr)
    return ReflogEntry(id_old, id_new, sig, msg)
end

function reflog(r::GitReference)
    reflog_ptr = Ptr{Void}[0]
    owner_ptr = ccall((:git_reference_owner, :libgit2), Ptr{Void}, (Ptr{Void},), r)
    @check ccall((:git_reflog_read, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}), reflog_ptr, owner_ptr, name(r))
    refcount = ccall((:git_reflog_entrycount, :libgit2), Csize_t, (Ptr{Void},), reflog_ptr[1]) 
    entries = ReflogEntry[]
    for i in 0:refcount-1
        entry_ptr = ccall((:git_reflog_entry_byindex, :libgit2), Ptr{Void},
                          (Ptr{Void}, Csize_t), reflog_ptr[1], refcount - i - 1)
        @assert entry_ptr != C_NULL
        push!(entries, new_reflog_entry(entry_ptr))
    end
    ccall((:git_reflog_free, :libgit2), Void, (Ptr{Void},), reflog_ptr[1])
    return entries
end

has_reflog(r::GitReference) = bool(ccall((:git_reference_has_log, :libgit2), Cint, (Ptr{Void},), r.ptr))

function log!(r::GitReference, msg::String="", committer::Union(Nothing, Signature)=nothing)
    reflog_ptr = Ptr{Void}[0]
    repo_ptr = ccall((:git_reference_owner, :libgit2), Ptr{Void}, (Ptr{Void},), r)
    name_ptr = ccall((:git_reference_name, :libgit2), Ptr{Uint8}, (Ptr{Void},), r)
    @check ccall((:git_reflog_read, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}), reflog_ptr, repo_ptr, name_ptr) 
    local sig_ptr::Ptr{SignatureStruct}
    if committer == nothing
        ptr = Ptr{SignatureStruct}[0]
        @check ccall((:git_signature_default, :libgit2), Cint,
                     (Ptr{Ptr{SignatureStruct}}, Ptr{Void}), ptr, repo_ptr) 
        sig_ptr = ptr[1]
    else
        sig_ptr = convert(Ptr{SignatureStruct}, committer)
    end
    target_ptr = ccall((:git_reference_target, :libgit2), Ptr{Void}, (Ptr{Void},), r)
    err = ccall((:git_reflog_append, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{SignatureStruct}, Ptr{Uint8}),
                 reflog_ptr[1], target_ptr, sig_ptr, msg)
    if err == api.GIT_OK
        err = ccall((:git_reflog_write, :libgit2), Cint, (Ptr{Void},), reflog_ptr[1])
    end
    @assert reflog_ptr[1] != C_NULL
    ccall((:git_reflog_free, :libgit2), Void, (Ptr{Void},), reflog_ptr[1])
    if err != api.GIT_OK
        throw(LibGitError(err))
    end
    return nothing
end

git_reftype{T}(r::GitReference{T}) = begin
    if T <: Sym
        return api.REF_SYMBOLIC
    elseif T <: Oid
        return api.REF_OID
    else
        error("Unknown reference type $T")
    end
end
