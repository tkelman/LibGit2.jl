export git_otype, GitTreeEntry, 
       entry_byname, entry_bypath,
       each_tree, each_blob,
       walk_trees, walk_blobs

type GitTreeEntry{T<:GitObject}
    name::String
    oid::Oid
    filemode::Cint
end

git_otype(::Type{GitTree}) = api.OBJ_TREE

oid(te::GitTreeEntry) = te.oid
name(te::GitTreeEntry) = te.name

Base.length(t::GitTree) = int(api.git_tree_entrycount(t.ptr))
Base.filemode(te::GitTreeEntry) = convert(Cint, te.filemode)

let 
    function tree_entry_name(ptr::Ptr{Void})
        nptr::Ptr{Cchar} = api.git_tree_entry_name(ptr)
        if nptr == C_NULL
            error("tree entry name pointer is NULL")
        end
        return bytestring(nptr)
    end

    function tree_entry_oid(ptr::Ptr{Void})
        idptr::Ptr{Uint8} = api.git_tree_entry_id(ptr)
        if idptr == C_NULL
            error("tree entry oid pointer is NULL")
        end
        return Oid(idptr)
    end

    function tree_entry_type(ptr::Ptr{Void})
        t = api.git_tree_entry_type(ptr)
        t == api.OBJ_BLOB   && return GitBlob
        t == api.OBJ_COMMIT && return GitCommit
        t == api.OBJ_TAG    && return GitTag
        t == api.OBJ_TREE   && return GitTree
        error("unknown git_type $(t)")
    end

    tree_entry_filemode(ptr::Ptr{Void}) = api.git_tree_entry_filemode(ptr)

    function GitTreeEntry(ptr::Ptr{Void}, owns::Bool=false)
        @assert ptr != C_NULL
        ty   = tree_entry_type(ptr)
        name = tree_entry_name(ptr)
        oid  = tree_entry_oid(ptr)
        fm   = tree_entry_filemode(ptr)
        entry = GitTreeEntry{ty}(name, oid, fm)
        return entry
    end
end

function entry_byname(t::GitTree, filename::String)
    @assert t.ptr != C_NULL
    bname = bytestring(filename)
    entry_ptr = api.git_tree_entry_byname(t.ptr, bname)
    entry_ptr == C_NULL && return nothing
    te = GitTreeEntry(entry_ptr)
    #api.git_tree_entry_free(entry_ptr)
    return te
end

function entry_bypath(t::GitTree, path::String)
    @assert t.ptr != C_NULL
    bpath = bytestring(path)
    entry_ptr = Array(Ptr{Void}, 1)
    @check api.git_tree_entry_bypath(entry_ptr, t.ptr, bpath)
    te = GitTreeEntry(entry_ptr[1], true)
    #api.git_tree_entry_free(entry_ptr[1])
    return te
end

function entry_byindex(t::GitTree, idx::Integer)
    @assert t.ptr != C_NULL
    entry_ptr = api.git_tree_entry_byindex(t.ptr, idx - 1)
    entry_ptr == C_NULL && return nothing
    te = GitTreeEntry(entry_ptr)
    #XXX: this throws a stack trace
    #api.git_tree_entry_free(entry_ptr)
    return te
end

function entry_byid(t::GitTree, id::Oid)
    @assert t.ptr != C_NULL
    entry_ptr = api.git_tree_entry_byid(t.ptr, id.oid)
    entry_ptr == C_NULL && return nothing
    te = GitTreeEntry(entry_ptr)
    #api.git_tree_entry_free(entry_ptr)
    return te
end

Base.getindex(t::GitTree, entry::Integer) = entry_byindex(t, entry)
Base.getindex(t::GitTree, entry::String)  = entry_byname(t, entry)
Base.getindex(t::GitTree, entry::Oid)     = entry_byid(t, entry)

Base.start(t::GitTree) = begin
    @assert t.ptr != C_NULL
    te = entry_byindex(t, 1)
    return (1, te)
end

Base.done(t::GitTree, state) = state[1] > length(t)

Base.next(t::GitTree, state) = begin
    nidx = state[1] + 1
    (state[2], (nidx, entry_byindex(t, nidx)))
end

function each_blob(t::GitTree)
    @assert t.ptr != C_NULL
    @task for te in t
        isa(te, GitTreeEntry{GitBlob}) && produce(te)
    end
end

function each_tree(t::GitTree)
    @assert t.ptr != C_NULL
    @task for te in t
        isa(te, GitTreeEntry{GitTree}) && produce(te)
    end
end

function cb_treewalk(root::Ptr{Cchar}, entry::Ptr{Void}, data::Ptr{Void})
    try 
        produce(bytestring(root), GitTreeEntry(entry))
        return api.GIT_OK
    catch
        return api.ERROR
    end
end

const c_cb_treewalk = cfunction(cb_treewalk, Cint, (Ptr{Cchar}, Ptr{Void}, Ptr{Void}))
 
function walk(t::GitTree, order=:postorder)
    @assert t.ptr != C_NULL
    local mode::Cint
    if order == :postorder
        mode = api.TREEWALK_POST
    elseif order == :preorder
        mode = api.TREEWALK_PRE
    else
        throw(ArgumentError("walk order can be :preorder or :postorder, got :$order"))
    end
    @task api.git_tree_walk(t.ptr, mode, c_cb_treewalk, C_NULL)  
end

function walk_blobs(t::GitTree, order=:postorder)
    @task for res in walk(t, order)
        isa(res[2], GitTreeEntry{GitBlob}) && produce(res)
    end
end

function walk_blobs(f::Function, t::GitTree, order=:postorder)
    for res in walk_blobs(t, order) 
        f(res)
    end
    return nothing
end

function walk_trees(t::GitTree, order=:postorder)
    @task for res in walk(t, order)
        isa(res[2], GitTreeEntry{GitTree}) && produce(res)
    end
end

function walk_trees(f::Function, t::GitTree, order=:postorder)
    for te in walk_trees(t, order)
        f(te)
    end
    return nothing
end
