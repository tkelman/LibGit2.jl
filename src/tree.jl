type GitTree <: GitObject
    ptr::Ptr{Void}
end

git_otype(::Type{GitTree}) = api.OBJ_TREE
