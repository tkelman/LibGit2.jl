export GitTree

type GitTree <: GitObject
    ptr::Ptr{Void}

    function GitTree(ptr::Ptr{Void})
        t = new(ptr)
        finalizer(t, free!)
        return t
    end
end

git_otype(::Type{GitTree}) = api.OBJ_TREE
