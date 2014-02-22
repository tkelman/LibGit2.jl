export Repository, GitObject, GitAny, GitBlob, GitCommit, GitTag,
       GitTree, GitReference, GitBranch

type Repository
    ptr::Ptr{Void}
    
    function Repository(ptr::Ptr{Void}, manage::Bool=true)
        if ptr == C_NULL
            throw(ArgumentError("Repository initialized with NULL pointer"))
        end
        r = new(ptr)
        if manage
            finalizer(r, free!)
        end
        return r
    end
end

free!(r::Repository) = begin
    if r.ptr != C_NULL
        close(r)
        api.git_repository_free(r.ptr)
        r.ptr = C_NULL
    end
end


abstract GitObject

free!(o::GitObject) = begin
    if o.ptr != C_NULL
        api.git_object_free(o.ptr)
        o.ptr = C_NULL
    end
end

immutable GitAny <: GitObject end

type GitBlob <: GitObject
    ptr::Ptr{Void}
    
    function GitBlob(ptr::Ptr{Void})
        @assert ptr != C_NULL
        b = new(ptr)
        finalizer(b, free!)
        return b
    end
end

type GitCommit <: GitObject
    ptr::Ptr{Void}

    function GitCommit(ptr::Ptr{Void})
        @assert ptr != C_NULL
        c = new(ptr)
        finalizer(c, free!)
        return c
    end
end

type GitTag <: GitObject
    ptr::Ptr{Void}

    function GitTag(ptr::Ptr{Void})
        @assert ptr != C_NULL 
        t = new(ptr)
        finalizer(t, free!)
        return t
    end
end

type GitTree <: GitObject
    ptr::Ptr{Void}

    function GitTree(ptr::Ptr{Void})
        @assert ptr != C_NULL
        t = new(ptr)
        finalizer(t, free!)
        return t
    end
end

immutable Sym end 
const RefType = Union(Oid, Sym)

type GitReference{T<:RefType}
    ptr::Ptr{Void}
end

free!(r::GitReference) = begin
    if r.ptr != C_NULL
        api.git_reference_free(r.ptr)
        r.ptr = C_NULL
    end
end

type GitBranch #<: GitReference{Sym}
    ptr::Ptr{Void}
    
    function GitBranch(ptr::Ptr{Void})
        @assert ptr != C_NULL
        b = new(ptr)
        finalizer(b, free!)
        return b
    end
end

free!(b::GitBranch) = begin
    if b.ptr != C_NULL
        api.git_reference_free(b.ptr)
        b.ptr = C_NULL
    end
end

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
        api.git_remote_free(r.ptr)
        r.ptr = C_NULL
    end
end
