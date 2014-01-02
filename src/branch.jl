export GitBranch, tip, resolve, owner, name, canonical_name, ishead, move

#TODO: git branch is subtype of git reference
type GitBranch #<: GitReference{T}
    ptr::Ptr{Void}
    
    function GitBranch(ptr::Ptr{Void})
        @assert ptr != C_NULL
        b = new(ptr)
        #finalizer(b, free!)
        return b
    end
end

free!(b::GitBranch) = begin
    if b.ptr != C_NULL
        api.git_reference_free(b.ptr)
        b.ptr = C_NULL
    end
end

Base.delete!(b::GitBranch) = begin
    @assert b.ptr != C_NULL  
    @check api.git_branch_delete(b.ptr)
    return nothing
end

function tip(b::GitBranch)
    lookup(owner(b), target(resolve(b)))
end

function owner(b::GitBranch)
    @assert b.ptr != C_NULL
    repo_ptr = api.git_reference_owner(b.ptr)
    #XXX: do not free repository handle
    return Repository(repo_ptr, false)
end

function resolve(b::GitBranch)
    @assert b.ptr != C_NULL
    ref_ptr = Array(Ptr{Void}, 1)
    @check api.git_reference_resolve(ref_ptr, b.ptr)
    @check_null ref_ptr
    return GitReference(ref_ptr[1])
end

function name(b::GitBranch)
    @assert b.ptr != C_NULL
    name_ptr = Array(Ptr{Cchar}, 1)
    api.git_branch_name(name_ptr, b.ptr)
    ret = bytestring(name_ptr[1])
    #TODO: memory leak...
    #c_free(name_ptr[1])
    return ret
end

#TODO: this is redundant with git_reference
function canonical_name(b::GitBranch)
    @assert b.ptr != C_NULL
    return bytestring(api.git_reference_name(b.ptr))
end

function ishead(b::GitBranch)
    @assert b.ptr != C_NULL
    return bool(api.git_branch_is_head(b.ptr))
end

function move(b::GitBranch, new_name::String, force::Bool=false)
    @assert b.ptr != C_NULL
    branch_ptr = Array(Ptr{Void}, 1)
    @check api.git_branch_move(branch_ptr, b.ptr, bytestring(new_name),
                               force? 1 : 0)
    @check_null branch_ptr
    return GitBranch(branch_ptr[1])
end

function rename(b::GitBranch, new_name::String, force::Bool=false)
    return move(b, new_name, force)
end 

Base.isequal(b1::GitBranch, b2::GitBranch) = begin
    canonical_name(b1) == canonical_name(b2)
end

function remote(b::GitBranch)
end

#lookup
#each_name
#each
#delete!
#rename
#ishead
#name
#remote_name
#upstream
#upstream=
