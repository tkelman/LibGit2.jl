export Repository, GitRepo, GitObject, GitAnyObject, GitBlob, GitCommit, GitTag,
       GitTree, GitReference, GitBranch, GitRemote, Sym

typealias GitOffT Int64
typealias GitTimeT Int64

# time in a signature

immutable TimeStruct
    time::GitTimeT # time in seconds from epoch
    offset::Cint   # timezone offset in minutes
end
TimeStruct() = TimeStruct(zero(GitTimeT), zero(Cint))

# an action signature (committers, taggers, etc)

immutable SignatureStruct
    name::Ptr{Cchar}  # full name of the author
    email::Ptr{Cchar} # email of the author
    when::GitTimeT    # time when the action happened
end
SignatureStruct() = SignatureStruct(zero(Ptr{Cchar}),
                                    zero(Ptr{Cchar}),
                                    zero(GitTimeT))
immutable TransferProgressStruct
    total_objects::Cuint
    indexed_objects::Cuint
    received_objects::Cuint
    local_objects::Cuint
    total_deltas::Cuint
    indexed_deltas::Cuint
    received_bytes::Csize_t
end
TransferProgressStruct() = TransferProgressStruct(zero(Cuint),
                                                  zero(Cuint),
                                                  zero(Cuint),
                                                  zero(Cuint),
                                                  zero(Cuint),
                                                  zero(Cuint),
                                                  zero(Csize_t))

# pointers to string data must not be valid references
# for the entire lifetime of the ccall
type StrArrayStruct
   strings::Ptr{Ptr{Uint8}}
   count::Csize_t
end
StrArrayStruct() = StrArrayStruct(zero(Ptr{Uint8}), zero(Csize_t))

# --------------
# Git Repository
# --------------
type GitRepo
    ptr::Ptr{Void}
    
    function GitRepo(ptr::Ptr{Void}, own::Bool=true)
        @assert ptr != C_NULL
        r = new(ptr)
        own && finalizer(r, free!)
        return r
    end
end

typealias Repository GitRepo

free!(r::GitRepo) = begin
    if r.ptr != C_NULL
        try 
            close(r)
        finally
            ccall((:git_repository_free, api.libgit2), Void, (Ptr{Void},), r.ptr)
            r.ptr = C_NULL
        end
    end
end

Base.convert(::Type{Ptr{Void}}, r::GitRepo) = r.ptr
Base.pointer(r::GitRepo) = r.ptr

# -------------
# Git Objects
# -------------
abstract GitObject

free!(o::GitObject) = begin
    if o.ptr != C_NULL
        ccall((:git_object_free, api.libgit2), Void, (Ptr{Void},), o.ptr)
        o.ptr = C_NULL
    end
end

type GitAnyObject <: GitObject end

GitAnyObject(ptr::Ptr{Void}) = begin
    @assert ptr != C_NULL
    typ = ccall((:git_object_type, api.libgit2), Cint, (Ptr{Void},), ptr)
    T = gitobj_const_type(typ)
    return T(ptr)
end

type GitBlob <: GitObject
    ptr::Ptr{Void}
    
    function GitBlob(ptr::Ptr{Void})
        @assert ptr != C_NULL
        this = new(ptr)
        finalizer(this, free!)
        return this 
    end
end

Base.pointer(o::GitBlob) = o.ptr

type GitCommit <: GitObject
    ptr::Ptr{Void}

    function GitCommit(ptr::Ptr{Void})
        @assert ptr != C_NULL
        this = new(ptr)
        finalizer(this, free!)
        return this
    end
end

Base.convert(::Type{Ptr{Void}}, o::GitCommit) = o.ptr
Base.pointer(o::GitCommit) = o.ptr

type GitTag <: GitObject
    ptr::Ptr{Void}

    function GitTag(ptr::Ptr{Void})
        @assert ptr != C_NULL 
        this = new(ptr)
        finalizer(this, free!)
        return this
    end
end

Base.convert(::Type{Ptr{Void}}, o::GitTag) = o.ptr 

type GitTree <: GitObject
    ptr::Ptr{Void}

    function GitTree(ptr::Ptr{Void})
        @assert ptr != C_NULL
        this = new(ptr)
        finalizer(this, free!)
        return this
    end
end

Base.convert(::Type{Ptr{Void}}, o::GitTree) = o.ptr

git_otype(::Type{GitBlob})      = api.OBJ_BLOB
git_otype(::Type{GitCommit})    = api.OBJ_COMMIT
git_otype(::Type{GitTag})       = api.OBJ_TAG 
git_otype(::Type{GitTree})      = api.OBJ_TREE
git_otype(::Type{GitAnyObject}) = api.OBJ_ANY

git_otype{T<:GitObject}(o::T) = git_otype(T)

# ---------------
# Git Reftypes
# ---------------
immutable Sym end 
const RefType = Union(Oid, Sym)

type GitReference{T<:RefType}
    ptr::Ptr{Void}
end

free!(r::GitReference) = begin
    if r.ptr != C_NULL
        ccall((:git_reference_free, api.libgit2), Void, (Ptr{Void},), r.ptr)
        r.ptr = C_NULL
    end
end

Base.pointer(r::GitReference) = r.ptr

type GitBranch #<: GitReference{Sym}
    ptr::Ptr{Void}
    
    function GitBranch(ptr::Ptr{Void})
        @assert ptr != C_NULL
        this = new(ptr)
        finalizer(this, free!)
        return this
    end
end

free!(b::GitBranch) = begin
    if b.ptr != C_NULL
        ccall((:git_reference_free, api.libgit2), Void, (Ptr{Void},), b.ptr)
        b.ptr = C_NULL
    end
end

Base.pointer(b::GitBranch) = b.ptr

# ---------------
# Git Remote
# ---------------
type GitRemote
    ptr::Ptr{Void}

    function GitRemote(ptr::Ptr{Void})
        @assert ptr != C_NULL
        r = new(ptr)
        finalizer(r, free!)
        return r
    end
end

free!(r::GitRemote) = begin
    if r.ptr != C_NULL
        ccall((:git_remote_free, api.libgit2), Void, (Ptr{Void},), r.ptr)
        r.ptr = C_NULL
    end
end

Base.pointer(r::GitRemote) = r.ptr
