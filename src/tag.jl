export GitTag, git_otype

type GitTag <: GitObject
    ptr::Ptr{Void}

    function GitTag(ptr::Ptr{Void})
        @assert ptr != C_NULL 
        t = new(ptr)
        finalizer(t, free!)
        return t
    end
end

git_otype(::Type{GitTag}) = api.OBJ_TAG 


