export GitObject, GitAny, libgit_const, oid, hex

abstract GitObject
type GitAny <: GitObject end

git_otype(::Type{GitAny}) = api.OBJ_ANY
git_otype{T<:GitObject}(o::T) = git_otype(T)

free!(o::GitObject) = begin
    if o.ptr != C_NULL
        api.git_object_free(o.ptr)
        o.ptr = C_NULL
    end
end

Base.isequal(o1::GitObject, o2::GitObject) = begin
    o1.ptr == o2.ptr 
end

function oid(o::GitObject)
    @assert o.ptr != C_NULL
    oid_ptr::Ptr{Uint8} = api.git_object_id(o.ptr)
    if oid_ptr == C_NULL
        error("oid pointer is NULL")
    end
    return Oid(oid_ptr)
end

function hex(o::GitObject)
    @assert o.ptr != C_NULL
    oid_ptr::Ptr{Uint8} = api.git_object_id(o.ptr)
    if oid_ptr == C_NULL
        error("oid pointer is NULL")
    end
    hex_buff = Array(Uint8, api.OID_HEXSZ)
    @check api.git_oid_fmt(hex_buff, oid_ptr)
    return bytestring(hex_buff)
end

function raw(o::GitObject)
    repo_ptr = api.git_object_owner(o.ptr)
    oid_ptr  = api.git_object_id(o.ptr)
    odb_ptr = Array(Ptr{Void}, 1)
    obj_ptr = Array(Ptr{Void}, 1)
    @check api.git_repository_odb(odb_ptr, repo_ptr)
    err = api.git_odb_read(obj_ptr, odb_ptr[1], oid_ptr)
    api.git_odb_free(odb_ptr[1])
    if err < 0
        throw(GitError(err))
    end
    return OdbObject(obj_ptr[1])
end

function gitobj_from_ptr(ptr::Ptr{Void})
    @assert ptr != C_NULL
    obj_type = api.git_object_type(ptr) 
    if obj_type == api.OBJ_BLOB
        return GitBlob(ptr)
    elseif obj_type == api.OBJ_TREE
        return GitTree(ptr)
    elseif obj_type == api.OBJ_COMMIT
        return GitCommit(ptr)
    elseif obj_type == api.OBJ_TAG
        return GitTag(ptr)
    else
        error("cannot convert gitobj $obj_type")
    end
end
