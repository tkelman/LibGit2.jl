export GitReference, Sym,
       set_target, set_symbolic_target, resolve, 
       rename, target, symbolic_target, name,
       git_reftype

#TODO:
#abstract GitRefType
#type RefSym <: GitRefType end
#type RefOid <: GitRefType end

type Sym end 

type GitReference{T}
    ptr::Ptr{Void}
end

function GitReference(ptr::Ptr{Void})
    @assert ptr != C_NULL
    ty = api.git_reference_type(ptr)
    RType = ty == 1 ? Oid : Sym 
    ref = GitReference{RType}(ptr)
    finalizer(ref, free!)
    return ref
end

free!(r::GitReference) = begin
    if r.ptr != C_NULL
        api.git_reference_free(r.ptr)
        r.ptr = C_NULL
    end
end

function set_symbolic_target(r::GitReference, target::String)
    @assert r.ptr != C_NULL
    btarget = bytestring(target)
    ref_ptr = Array(Ptr{Void}, 1)
    @check api.git_reference_symbolic_target(ref_ptr, r.ptr, btarget)
    @check_null ref_ptr
    return GitReference(ref_ptr[1])
end

function set_target(r::GitReference, id::Oid)
    @assert r.ptr != C_NULL
    ref_ptr = Array(Ptr{Void}, 1)
    @check api.git_reference_target(ref_ptr, id.oid)
    @check_null ref_ptr
    return GitReference(ref_ptr[1])
end

function resolve(r::GitReference)
    @assert r.ptr != C_NULL
    ref_ptr = Array(Ptr{Void}, 1)
    @check api.git_reference_resolve(ref_ptr, r.ptr)
    @check_null ref_ptr
    return GitReference(ref_ptr[1])
end

function rename(r::GitReference, name::String, force::Bool=false)
    @assert r.ptr != C_NULL
    ref_ptr = Array(Ptr{Void}, 1)
    bname = bytestring(name)
    @check api.git_reference_rename(ref_ptr, r.ptr, bname, force? 1 : 0)
    @check_null ref_ptr
    return GitReference(ref_ptr[1])
end

function target(r::GitReference)
    @assert r.ptr != C_NULL
    oid_ptr = api.git_reference_target(r.ptr)
    if oid_ptr == C_NULL 
        return nothing
    end
    return Oid(oid_ptr)
end

function symbolic_target(r::GitReference)
    @assert r.ptr != C_NULL
    sym_ptr = api.git_reference_symbolic_target(r.ptr)
    if sym_ptr == C_NULL
        return ""
    end
    return bytestring(sym_ptr)
end

function name(r::GitReference)
    @assert r.ptr != C_NULL
    return bytestring(api.git_reference_name(r.ptr))
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


