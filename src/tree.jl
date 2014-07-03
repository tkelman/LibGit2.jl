export GitTreeEntry, 
       entry_byname, entry_bypath,
       each_tree, each_blob,
       walk_trees, walk_blobs

type GitTreeEntry{T<:GitObject}
    name::ByteString
    id::Oid
    filemode::Cint
    owns::Bool
end

Oid(te::GitTreeEntry)  = te.id
name(te::GitTreeEntry) = te.name

Base.isless(te1::GitTreeEntry, te2::GitTreeEntry) = isless(Oid(te1), Oid(te2))

Base.length(t::GitTree) = 
    int(ccall((:git_tree_entrycount, :libgit2), Csize_t, (Ptr{Void},), t))
                               
Base.filemode(te::GitTreeEntry) = te.filemode

let 
    function tree_entry_name(ptr::Ptr{Void})
        nptr = ccall((:git_tree_entry_name, :libgit2), Ptr{Uint8}, (Ptr{Void},), ptr)
        return bytestring(nptr)
    end

    function tree_entry_oid(ptr::Ptr{Void})
        idptr = ccall((:git_tree_entry_id, :libgit2), Ptr{Uint8}, (Ptr{Void},), ptr)
        return Oid(idptr)
    end

    function tree_entry_type(ptr::Ptr{Void})
        t = ccall((:git_tree_entry_type, :libgit2), Cint, (Ptr{Void},), ptr)
        t == api.OBJ_BLOB   && return GitBlob
        t == api.OBJ_COMMIT && return GitCommit
        t == api.OBJ_TAG    && return GitTag
        t == api.OBJ_TREE   && return GitTree
        error("unknown git_type $(t)")
    end

    function tree_entry_filemode(ptr::Ptr{Void})
        ccall((:git_tree_entry_filemode, :libgit2), Cint, (Ptr{Void},), ptr)
    end

    function GitTreeEntry(ptr::Ptr{Void}, owns::Bool=false)
        @assert ptr != C_NULL
        ty   = tree_entry_type(ptr)
        name = tree_entry_name(ptr)
        id   = tree_entry_oid(ptr)
        fm   = tree_entry_filemode(ptr)
        owns && ccall((:git_tree_entry_free, :libgit2), Void, (Ptr{Void},), ptr)
        return GitTreeEntry{ty}(name, id, fm, owns)
    end
end

function entry_byname(t::GitTree, filename::String)
    eptr = ccall((:git_tree_entry_byname, :libgit2), Ptr{Void},
                 (Ptr{Void}, Ptr{Uint8}), t, filename)
    return eptr == C_NULL ? nothing : 
                            GitTreeEntry(eptr, false)
end

function entry_bypath(t::GitTree, path::String)
    entry_ptr = Ptr{Void}[0]
    @check ccall((:git_tree_entry_bypath, :libgit2), Cint,
                  (Ptr{Ptr{Void}}, Ptr{Uint8}), entry_ptr, path)
    return entry_ptr[1] == C_NULL ? nothing :
                                    GitTreeEntry(entry_ptr[1], true)
end

function entry_byindex(t::GitTree, idx::Integer)
    entry_ptr = ccall((:git_tree_entry_byindex, :libgit2), Ptr{Void},
                      (Ptr{Void}, Csize_t), t, idx - 1) 
    return entry_ptr == C_NULL ? nothing :
                                 GitTreeEntry(entry_ptr, false)
end

function entry_byid(t::GitTree, id::Oid)
    entry_ptr = ccall((:git_tree_entry_byid, :libgit2), Ptr{Void},
                      (Ptr{Void}, Ptr{Oid}), t, &id)
    return entry_ptr == C_NULL ? nothing :
                                 GitTreeEntry(entry_ptr, false)
end

Base.getindex(t::GitTree, entry::Integer) = entry_byindex(t, entry)
Base.getindex(t::GitTree, entry::String)  = entry_byname(t, entry)
Base.getindex(t::GitTree, entry::Oid)     = entry_byid(t, entry)

Base.start(t::GitTree) = begin
    te = entry_byindex(t, 1)
    return (1, te)
end

Base.done(t::GitTree, state) = state[1] > length(t)

Base.next(t::GitTree, state) = begin
    nidx = state[1] + 1
    (state[2], (nidx, entry_byindex(t, nidx)))
end

function each_blob(t::GitTree)
    @task for te in t
        isa(te, GitTreeEntry{GitBlob}) && produce(te)
    end
end

function each_tree(t::GitTree)
    @task for te in t
        isa(te, GitTreeEntry{GitTree}) && produce(te)
    end
end

function cb_treewalk(root::Ptr{Uint8}, entry::Ptr{Void}, data::Ptr{Void})
    try 
        produce(bytestring(root), GitTreeEntry(entry))
        return api.GIT_OK
    catch err
        return api.ERROR
    end
end

const c_cb_treewalk = cfunction(cb_treewalk, Cint, 
                                (Ptr{Uint8}, Ptr{Void}, Ptr{Void}))
 
function walk(t::GitTree, order=:postorder)
    local mode::Cint
    if order == :postorder
        mode = api.TREEWALK_POST
    elseif order == :preorder
        mode = api.TREEWALK_PRE
    else
        throw(ArgumentError("walk order can be :preorder or :postorder, got :$order"))
    end
    @task ccall((:git_tree_walk, :libgit2), Cint,
                (Ptr{Void}, Cint, Ptr{Void}, Ptr{Void}), 
                t, mode, c_cb_treewalk, C_NULL)
end

function walk_blobs(t::GitTree, order::Symbol=:postorder)
    @task for res in walk(t, order)
        isa(res[2], GitTreeEntry{GitBlob}) && produce(res)
    end
end

function walk_blobs(f::Function, t::GitTree, order::Symbol=:postorder)
    for res in walk_blobs(t, order) 
        f(res)
    end
end

function walk_trees(t::GitTree, order::Symbol=:postorder)
    @task for res in walk(t, order)
        isa(res[2], GitTreeEntry{GitTree}) && produce(res)
    end
end

function walk_trees(f::Function, t::GitTree, order::Symbol=:postorder)
    for te in walk_trees(t, order)
        f(te)
    end
end

#------- Tree Builder -------
type GitTreeBuilder
    ptr::Ptr{Void}
    repo::GitRepo
    
    function GitTreeBuilder(ptr::Ptr{Void}, r::GitRepo)
        @assert ptr != C_NULL
        tb = new(ptr, r)
        finalizer(tb, free!)
        return tb
    end
end

GitTreeBuilder(r::GitRepo) = begin
    tbptr = Ptr{Void}[0] 
    @check ccall((:git_treebuilder_create, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}), tbptr, C_NULL)
    return GitTreeBuilder(tbptr[1], r)
end 

free!(tb::GitTreeBuilder) = begin
    if tb.ptr != C_NULL
        ccall((:git_treebuilder_free, :libgit2), Void, (Ptr{Void},), tb.ptr)
        tb.ptr = C_NULL
    end
end

Base.convert(::Type{Ptr{Void}}, tb::GitTreeBuilder) = tb.ptr

Base.insert!(tb::GitTreeBuilder, filename::String, id::Oid, filemode::Int) = begin
    @check ccall((:git_treebuilder_insert, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}, Ptr{Oid}, Cint),
                 C_NULL, tb, filename, &id, filemode)
    return tb
end

function write!(tb::GitTreeBuilder)
    id = Oid()
    @check ccall((:git_treebuilder_write, :libgit2), Cint,
                 (Ptr{Oid}, Ptr{Void}, Ptr{Void}), &id, tb.repo, tb) 
    return id
end
