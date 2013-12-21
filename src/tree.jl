export GitTree, git_otype, GitTreeEntry, 
       entry_byname, entry_bypath,
       each_tree, each_blob,
       walk_trees, walk_blobs

type GitTree <: GitObject
    ptr::Ptr{Void}

    function GitTree(ptr::Ptr{Void})
        @assert ptr != C_NULL
        t = new(ptr)
        finalizer(t, free!)
        return t
    end
end

git_otype(::Type{GitTree}) = api.OBJ_TREE

Base.length(t::GitTree) = begin
    return int(api.git_tree_entrycount(t.ptr))
end

type GitTreeEntry{T<:GitObject}
    name::String
    oid::Oid
    filemode::Cint
end

oid(te::GitTreeEntry) = te.oid
name(te::GitTreeEntry) = te.name

Base.filemode(te::GitTreeEntry) = begin
    convert(Cint, te.filemode)
end

let 
    function tree_entry_name(ptr::Ptr{Void})
        ptr::Ptr{Cchar} = api.git_tree_entry_name(ptr)
        if ptr == C_NULL
            error("tree entry name pointer is NULL")
        end
        return bytestring(ptr)
    end

    function tree_entry_oid(ptr::Ptr{Void})
        oid_ptr::Ptr{Uint8} = api.git_tree_entry_id(ptr)
        if oid_ptr == C_NULL
            error("tree entry oid pointer is NULL")
        end
        return Oid(oid_ptr)
    end

    function tree_entry_type(ptr::Ptr{Void})
        t = api.git_tree_entry_type(ptr)
        if t == api.OBJ_BLOB
            return GitBlob
        elseif t == api.OBJ_COMMIT
            return GitCommit
        elseif t == api.OBJ_TAG
            return GitTag
        elseif t == api.OBJ_TREE
            return GitTree
        else
            error("unknown git_type $(t)")
        end
    end

    function tree_entry_filemode(ptr::Ptr{Void})
        fm = api.git_tree_entry_filemode(ptr)
        return fm
    end

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
    if entry_ptr == C_NULL
        return nothing
    end
    te = GitTreeEntry(entry_ptr)
    #api.git_tree_entry_free(entry_ptr)
    return te
end

function entry_bypath(t::GitTree, path::String)
    @assert t.ptr != C_NULL
    bpath = bytestring(path)
    entry_ptr = Array(Ptr{Void}, 1)
    @check api.git_tree_entry_bypath(entry_ptr, t.ptr, bpath)
    @check_null entry_ptr
    te = GitTreeEntry(entry_ptr[1], true)
    #api.git_tree_entry_free(entry_ptr[1])
    return te
end

function entry_byindex(t::GitTree, idx::Integer)
    @assert t.ptr != C_NULL
    entry_ptr = api.git_tree_entry_byindex(t.ptr, idx - 1)
    if entry_ptr == C_NULL
        return nothing
    end
    te = GitTreeEntry(entry_ptr)
    #XXX: this throws a stack trace
    #api.git_tree_entry_free(entry_ptr)
    return te
end

function entry_byoid(t::GitTree, id::Oid)
    @assert t.ptr != C_NULL
    entry_ptr = api.git_tree_entry_byoid(t.ptr, id.oid)
    if entry_ptr == C_NULL
        return nothing
    end
    te = GitTreeEntry(entry_ptr)
    #api.git_tree_entry_free(entry_ptr)
    return te
end

Base.getindex(t::GitTree, entry::Integer) = entry_byindex(t, entry)
Base.getindex(t::GitTree, entry::String) = entry_byname(t, entry)
Base.getindex(t::GitTree, entry::Oid) = entry_byoid(t, entry)

Base.start(t::GitTree) = begin
    @assert t.ptr != C_NULL
    te = entry_byindex(t, 1)
    return (1, te)
end

Base.done(t::GitTree, state) = begin
    state[1] > length(t)
end

Base.next(t::GitTree, state) = begin
    nidx = state[1] + 1
    (state[2], (nidx, entry_byindex(t, nidx)))
end

function each_blob(t::GitTree)
    @assert t.ptr != C_NULL
    @task begin
        for te in t
            if isa(te, GitTreeEntry{GitBlob})
                produce(te)
            end
        end
    end
end

function each_tree(t::GitTree)
    @assert t.ptr != C_NULL
    @task begin
        for te in t
            if isa(te, GitTreeEntry{GitTree})
                produce(te)
            end
        end
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

const c_cb_treewalk = cfunction(cb_treewalk, Cint,
                                (Ptr{Cchar}, Ptr{Void}, Ptr{Void}))
 
function walk(t::GitTree, order=:postorder)
    @assert t.ptr != C_NULL
    local mode::Cint
    if order == :postorder
        mode = api.TREEWALK_POST
    elseif order == :preorder
        mode = api.TREEWALK_PRE
    else
        throw(ArgumentError("walkorder can be :preorder or :postorder"))
    end
    @task api.git_tree_walk(t.ptr, mode, c_cb_treewalk, C_NULL)  
end

function walk_blobs(t::GitTree, order=:postorder)
    @task begin
        for res in walk(t, order)
            if isa(res[2], GitTreeEntry{GitBlob})
                produce(res)
            end
        end
    end
end

function walk_blobs(f::Function, t::GitTree, order=:postorder)
    for res in walk_blobs(t, order) 
        f(res)
    end
    return nothing
end

function walk_trees(t::GitTree, order=:postorder)
    @task begin
        for res in walk(t, order)
            if isa(res[2], GitTreeEntry{GitTree})
                produce(res)
            end
        end
    end
end

function walk_trees(f::Function, t::GitTree, order=:postorder)
    for te in walk_trees(t, order)
        f(te)
    end
    return nothing
end
