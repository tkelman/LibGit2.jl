export GitObject, GitAny, libgit_const 

abstract GitObject
type GitAny <: GitObject end
type GitCommit <: GitObject end
type GitTag <: GitObject end

git_otype(::Type{GitAny}) = api.OBJ_ANY
git_otype(::Type{GitCommit}) = api.OBJ_COMMIT
git_otype(::Type{GitTag}) = api.OBJ_TAG 
git_otype{T<:GitObject}(o::T) = git_otype(T)

function oid(o::GitObject)
    @check api.git_commit_id(o.ptr)

end

function hex(o::GitObject)
end

function raw(o::GitObject)
end

