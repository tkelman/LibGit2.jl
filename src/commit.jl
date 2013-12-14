export GitCommit

type GitCommit <: GitObject
    ptr::Ptr{Void}

    function GitCommit(ptr::Ptr{Void})
        c = new(ptr)
        finalizer(c, free!)
        return c
    end
end

git_otype(::Type{GitCommit}) = api.OBJ_COMMIT

function message(c::GitCommit, raw::Bool=false)
    local msg_ptr::Ptr{Cchar}
    if raw
        msg_ptr = api.git_commit_message_raw(c.ptr)
    else
        msg_ptr = api.git_commit_message(c.ptr)
    end
    if msg_ptr == C_NULL 
        return nothing
    end
    return bytestring(msg_ptr)
end

function tree(c::GitCommit)
    tree_ptr = Array(Ptr{Void}, 1)
    @check api.git_commit_tree(tree_ptr, c.ptr)
    @check_null tree_ptr
    return GitTree(tree_ptr[1])
end

function tree_id(c::GitCommit)
    oid_ptr = api.get_commit_tree_id(c.ptr)
    if oid_ptr == C_NULL
        error("tree id pointer is NULL")
    end
    return Oid(oid_ptr)
end

function author(c::GitCommit)
    ptr::Ptr{Signature} = api.git_commit_author(c.ptr)
    if ptr == C_NULL
        error("git commit author pointer is NULL")
    end
    return unsafe_load(ptr)
end

function committer(c::GitCommit)
    ptr::Ptr{Signature} = api.git_commit_committer(c.ptr)
    if ptr == C_NULL
        error("git committer pointer is NULL")
    end
    return unsafe_load(ptr)
end

function parent(c::GitCommit, n::Integer)
    if n < 0
        throw(ArgumentError("n must be greater than or equal to 0"))
    end
    cn = convert(Cuint, n)
    commit_ptr = Array(Ptr{Void}, 1)
    @check api.git_commit_parent(commit_ptr, c.ptr, cn)
    @check_null commit_ptr
    return GitCommit(commit_ptr[1])
end

function parent_id(c::GitCommit, n::Integer)
    if n < 0
        throw(ArgumentError("n must be greater than or equal to 0"))
    end
    cn = convert(Cuint, n)
    oid_ptr::Ptr{Uint8} = api.git_commit_parent_id(c.ptr, cn)
    if oid_ptr == C_NULL
        error("parent id pointer is NULL")
    end
    return Oid(oid_ptr)
end

function parent_count(c::GitCommit)
    return int(api.git_commit_parent_count(c.ptr))
end
