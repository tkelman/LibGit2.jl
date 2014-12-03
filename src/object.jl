Base.show(io::IO, o::GitObject) = begin
    write(io, "$(typeof(o))($(hex(o)))")
end

Base.(:(==))(o1::GitObject, o2::GitObject) = isequal(Oid(o1), Oid(o2))
Base.isequal(o1::GitObject, o2::GitObject) = isequal(Oid(o1), Oid(o2))
Base.isless(o1::GitObject, o2::GitObject)  = isless(Oid(o1), Oid(o2))

Base.hash(o::GitObject) = hash(hex(o))
Base.cmp(o1::GitObject, o2::GitObject) = cmp(Oid(o1), Oid(o2))

Oid(o::GitObject) = Oid(ccall((:git_object_id, libgit2), Ptr{Oid}, (Ptr{Void},), o))

Base.hex(o::GitObject) = begin
    oid_ptr = ccall((:git_object_id, libgit2), Ptr{UInt8}, (Ptr{Void},), o)
    hex_buff = Array(UInt8, OID_HEXSZ)
    @check ccall((:git_oid_fmt, libgit2), Cint, (Ptr{UInt8}, Ptr{UInt8}), hex_buff, oid_ptr)
    return bytestring(hex_buff)
end

function raw(o::GitObject)
    repo_ptr = ccall((:git_object_owner, libgit2), Ptr{Void}, (Ptr{Void},), o)
    oid_ptr  = ccall((:git_object_id, libgit2), Ptr{Oid}, (Ptr{Void},), o)
    odb_ptr  = Ptr{Void}[0]
    @check ccall((:git_repository_odb, libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}), odb_ptr, repo_ptr)
    obj_ptr  = Ptr{Void}[0]
    err = ccall((:git_odb_read, libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Oid}), obj_ptr, odb_ptr[1], oid_ptr)
    ccall((:git_odb_free, libgit2), Void, (Ptr{Void},), odb_ptr[1])
    if err != GitErrorConst.GIT_OK
        throw(GitError(err))
    end
    return OdbObject(obj_ptr[1])
end

function gitobj_from_ptr(ptr::Ptr{Void})
    obj_type = ccall((:git_object_type, libgit2), Cint, (Ptr{Void},), ptr)
    T = gitobj_const_type(obj_type)
    @assert T <: GitObject
    return T(ptr)
end

function gitobj_const_type(typ::Cint)
    typ == GitConst.OBJ_BLOB   && return GitBlob
    typ == GitConst.OBJ_TREE   && return GitTree
    typ == GitConst.OBJ_COMMIT && return GitCommit
    typ == GitConst.OBJ_TAG    && return GitTag
    typ == GitConst.OBJ_ANY    && return GitAnyObject
    error("Unknown git type const: $obj_type")
end
