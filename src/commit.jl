export git_otype, message, tree, tree_id,
       author, committer, parent, parent_id, parent_count, parents

function message(c::GitCommit, raw::Bool=false)
    local msg_ptr::Ptr{Uint8}
    if raw
        msg_ptr = ccall((:git_commit_message_raw, :libgit2), Ptr{Uint8}, (Ptr{Void},), c)
    else
        msg_ptr = ccall((:git_commit_message, :libgit2), Ptr{Uint8}, (Ptr{Void},), c)
    end
    if msg_ptr == C_NULL 
        return nothing
    end
    return bytestring(msg_ptr)
end

function GitTree(c::GitCommit)
    tree_ptr = Ptr{Void}[0]
    @check ccall((:git_commit_tree, :libgit2), Cint, (Ptr{Ptr{Void}}, Ptr{Void}), tree_ptr, c.ptr)
    return GitTree(tree_ptr[1])
end

git_tree_id(c::GitCommit) = Oid(ccall((:git_commit_tree_id, :libgit2), Ptr{Uint8}, (Ptr{Void},), c))

function author(c::GitCommit)
    ptr = ccall((:git_commit_author, :libgit2), Ptr{SignatureStruct}, (Ptr{Void},), c)
    @assert ptr != C_NULL
    #! memory leak
    return Signature(unsafe_load(ptr)::SignatureStruct)
end

function committer(c::GitCommit)
    ptr = ccall((:git_commit_committer, :libgit2), Ptr{SignatureStruct}, (Ptr{Void},), c)
    @assert ptr != C_NULL
    #! memory leak
    return Signature(unsafe_load(ptr)::SignatureStruct)
end

function parent(c::GitCommit, n::Integer)
    n >= 0 || throw(ArgumentError("n must be greater than or equal to 0"))
    commit_ptr = Ptr{Void}[0]
    @check ccall((:git_commit_parent, :libgit2), Cint, (Ptr{Ptr{Void}}, Ptr{Void}, Cuint), commit_ptr, c, n) 
    return GitCommit(commit_ptr[1])
end

function parents(c::GitCommit)
    n = parent_count(c)
    ps = GitCommit[]
    for i in 0:n-1
        push!(ps, parent(c, i))
    end
    return ps
end

function parent_id(c::GitCommit, n::Integer)
    n >= 0 || throw(ArgumentError("n must be greater than or equal to 0"))
    oid_ptr = ccall((:git_commit_parent_id, :libgit2), Ptr{Uint8}, (Ptr{Void}, Cuint), c, n)
    return Oid(oid_ptr)
end

parent_count(c::GitCommit) = int(ccall((:git_commit_parentcount, :libgit2), Csize_t, (Ptr{Void},), c))
